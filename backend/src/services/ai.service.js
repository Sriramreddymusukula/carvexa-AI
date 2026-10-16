import { Preference } from '../models/index.js';
import { ApiError } from '../utils/apiError.js';
import { logger } from '../utils/logger.js';
import { getCarDetail, listCars } from './carCatalog.service.js';
import {
  dedupKey,
  getFallbackCarById,
  getLocalCarCards,
  tokenizeQuery,
} from './carCatalog/fallbackCatalog.js';
import { generateAnswer } from './gemini.service.js';

/** How many specific vehicles may be grounded into one chat answer. */
const MAX_GROUNDED_VEHICLES = 6;

/** How many catalog rows the model gets for "best SUV under 30 lakh" style questions. */
const MAX_INDEX_VEHICLES = 15;

/**
 * Local records that intentionally overlap popular external models (e.g. Tata
 * Nexon, Hyundai Creta): their external rows always survive the sparse-row
 * filter below so a live price or photograph is never thrown away.
 */
const BUSY_LOCAL_KEYS = new Set(
  getLocalCarCards('new').map((car) => dedupKey(car)),
);

/** True when the record carries at least one decision-useful catalog fact. */
function hasUsableFacts(car) {
  return (
    car.price != null ||
    car.bodyType != null ||
    car.fuelType != null ||
    car.transmission != null ||
    (Array.isArray(car.features) && car.features.length > 0) ||
    (Array.isArray(car.engineSpecs) && car.engineSpecs.length > 0)
  );
}

/** Bounds a grounding fetch so one slow call cannot eat the chat budget. */
function withTimeout(promise, ms, label) {
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error(`${label} timed out after ${ms}ms`)), ms);
  });
  return Promise.race([promise, timeout]).finally(() => clearTimeout(timer));
}

/** Card/detail -> the JSON the model reads. Missing facts stay absent. */
function publicVehicle(car) {
  return {
    id: car.id,
    source: car.source,
    title: car.title,
    make: car.make,
    model: car.model,
    year: car.year,
    price: car.price,
    formattedPrice: car.formattedPrice,
    priceRange: car.priceRange,
    bodyType: car.bodyType,
    fuelType: car.fuelType,
    fuelTypes: car.fuelTypes,
    transmission: car.transmission,
    mileage: car.mileage,
    mileageKm: car.mileageKm,
    safetyRating: car.safetyRating,
    seatingCapacity: car.seatingCapacity,
    city: car.city,
    owner: car.owner,
    features: car.features?.slice(0, 16),
    engineSpecs: car.engineSpecs?.slice(0, 12),
    dimensions: car.dimensions?.slice(0, 8),
  };
}

/** Compact catalog row for the model's decision-making ("under 30 lakh"). */
function indexEntry(car) {
  return {
    title: car.title,
    source: car.source,
    price: car.formattedPrice ?? null,
    priceValue: car.price ?? null,
    bodyType: car.bodyType ?? null,
    fuelType: car.fuelType ?? null,
    transmission: car.transmission ?? null,
    seatingCapacity: car.seatingCapacity ?? null,
  };
}

/**
 * Every new-car the app can currently show: external first (primary), plus
 * the local layer so grounding works even when the provider is down.
 *
 * External rows with no decision-useful facts (no price, body type, fuel,
 * transmission, features or specs) cannot answer "best SUV under 30 lakh" or
 * ground a comparison, so they are skipped inside this working set only.
 * Sparse external rows still appear in normal browsing; they are only kept
 * out of the AI's shortlist so they cannot crowd out local rows that can
 * actually answer. Busy local keys are exempt so popular-model overrides
 * always survive.
 *
 * The external index fetch is bounded: it must not eat the chat budget when
 * the provider is slow. On timeout the local layer alone still grounds us.
 */
async function availableNewVehicles() {
  const local = getLocalCarCards('new');

  let external = [];
  try {
    const page = await withTimeout(listCars({ source: 'new' }), 9000, 'catalog index');
    external = page.cars;
  } catch (error) {
    logger.warn('AI grounding: external catalogue unavailable', {
      reason: error?.code ?? error?.message ?? 'unknown',
    });
  }

  const usableExternal = external.filter(
    (car) => BUSY_LOCAL_KEYS.has(dedupKey(car)) || hasUsableFacts(car),
  );
  const skippedSparse = external.length - usableExternal.length;
  if (skippedSparse > 0) {
    logger.debug('AI grounding: skipped sparse external rows', { skippedSparse });
  }

  const seen = new Set(usableExternal.map((car) => dedupKey(car)));
  const merged = [...usableExternal];
  for (const car of local) {
    const key = dedupKey(car);
    if (!seen.has(key)) {
      seen.add(key);
      merged.push(car);
    }
  }
  return merged;
}

/**
 * Vehicles the message actually names (brand or model words), so "Give me
 * Sorento information" is grounded in the Sorento record instead of leaving
 * the model to its own knowledge.
 */
function vehiclesNamedIn(pool, text) {
  const tokens = tokenizeQuery(text).filter((token) => token.length >= 3);
  if (tokens.length === 0) return [];

  return pool.filter((car) => {
    const nameTokens = tokenizeQuery(`${car.make ?? ''} ${car.model ?? ''} ${car.title ?? ''}`);
    return nameTokens.some((token) => tokens.includes(token));
  });
}

/**
 * Runs cheap catalog reads that must not fail the chat when a single
 * vehicle is unavailable (external hiccup, signed-id expiry...).
 * @param {string} id
 */
async function tryDetail(id) {
  try {
    return await getCarDetail(id);
  } catch {
    return null;
  }
}

export const aiService = {
  /**
   * One grounded chat turn.
   *
   * Grounding layers, in order:
   *  1. `vehicleIds` the app opened the chat from (full details),
   *  2. vehicles the message names, resolved against the live+local catalog,
   *  3. a compact index of everything currently available, so budget/body
   *     questions ("Best SUV under 30 lakh") are answered from real records.
   */
  async chat(userId, input) {
    const lastUserMessage =
      [...input.messages].reverse().find((message) => message.role === 'user')?.text ?? '';

    const [preference, pool] = await Promise.all([
      Preference.findOne({ user: userId }).lean().exec().catch(() => null),
      availableNewVehicles(),
    ]);

    // One broken vehicle id must not sink the whole conversation.
    const explicit = await Promise.allSettled(input.vehicleIds.map((id) => getCarDetail(id)));
    const detailed = explicit
      .filter((result) => result.status === 'fulfilled')
      .map((result) => result.value);

    const seen = new Set(detailed.map((car) => car.id));
    const named = vehiclesNamedIn(pool, lastUserMessage).filter((car) => !seen.has(car.id));

    const grounded = [...detailed];
    const expandable = named.slice(0, Math.max(0, MAX_GROUNDED_VEHICLES - grounded.length));
    // Local detail is in-memory (instant); external detail is bounded so two
    // slow calls cannot eat the 45s chat budget. A timed-out external card
    // still grounds from its published card fields - never invented.
    const expanded = await Promise.all(
      expandable.map((card) =>
        card.catalogOrigin === 'local_demo'
          ? getFallbackCarById(card.id)
          : withTimeout(getCarDetail(card.id), 8000, 'detail ' + card.id).catch(() => card),
      ),
    );
    for (const full of expanded) {
      if (full !== null && full !== undefined) {
        grounded.push(full);
        seen.add(full.id);
      }
    }

    const catalogIndex = pool.slice(0, MAX_INDEX_VEHICLES).map(indexEntry);

    const reply = await generateAnswer({
      messages: input.messages.slice(-12),
      catalogVehicles: grounded.map(publicVehicle),
      catalogIndex,
      preferences: preference,
    });

    return {
      reply,
      groundedVehicles: grounded
        .slice(0, MAX_GROUNDED_VEHICLES)
        .map(({ id, title, source }) => ({ id, title, source })),
    };
  },

  /**
   * Preference-scored recommendations over the vehicles the catalogue
   * actually offers (external primary, local fallback merged in).
   */
  async recommendations(userId) {
    const preference = await Preference.findOne({ user: userId }).lean().exec();
    if (!preference) {
      throw ApiError.badRequest(
        'Save your buying preferences before requesting personalized recommendations.',
      );
    }

    const pool = await availableNewVehicles();

    const makes = (preference.makes ?? []).map((value) => value.toLowerCase());
    const bodyTypes = (preference.bodyTypes ?? []).map((value) => value.toLowerCase());
    const fuelTypes = (preference.fuelTypes ?? []).map((value) => value.toLowerCase());
    const budget = preference.budget ?? {};

    const scored = pool
      .filter((car) => car.source === 'new')
      .map((car) => {
        let score = 0;
        const make = String(car.make ?? '').toLowerCase();
        if (makes.length && makes.some((entry) => make.includes(entry))) score += 4;
        if (
          bodyTypes.length &&
          bodyTypes.some((entry) => String(car.bodyType ?? '').toLowerCase().includes(entry))
        ) {
          score += 2;
        }
        if (
          fuelTypes.length &&
          fuelTypes.some((entry) => String(car.fuelType ?? '').toLowerCase().includes(entry))
        ) {
          score += 2;
        }
        if (car.price != null && budget.min != null && car.price >= budget.min) score += 1;
        if (car.price != null && budget.max != null && car.price <= budget.max) score += 1;
        return { car, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, 6)
      .map(({ car }) => car);

    if (scored.length === 0) {
      return {
        vehicles: [],
        explanation: 'The catalogue has no new-car vehicles available right now.',
      };
    }

    try {
      const explanation = await generateAnswer({
        messages: [
          {
            role: 'user',
            text: 'Explain which of these supplied catalog vehicles best fit my saved preferences. Only refer to the supplied vehicles. Call out any preference details the catalog does not publish, especially price or fuel/transmission. Give a short "Recommended because…" reason and practical trade-offs.',
          },
        ],
        catalogVehicles: scored.map(publicVehicle),
        preferences: preference,
      });
      return { vehicles: scored, explanation };
    } catch (error) {
      // The vehicles are real; only the AI summary failed. Return them with an
      // honest note instead of failing the request or pretending the AI wrote
      // an answer.
      logger.warn('Recommendation summary failed', {
        code: error?.code ?? 'unknown',
        message: error?.message ?? '',
      });
      const top = scored.slice(0, 3).map((car) => car.title).join(', ');
      return {
        vehicles: scored,
        explanation:
          `Carvexa AI could not summarise right now, so here is a plain catalogue match instead: ` +
          `these vehicles score highest against your saved preferences - ${top}.`,
      };
    }
  },
};

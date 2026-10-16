import { createHash } from 'node:crypto';
import {
  dedupKey,
  getFallbackCarById,
  getFallbackUsedCars,
  getLocalByBrandModel,
  matchesBrand,
  searchLocalCars,
  slugify,
} from './carCatalog/fallbackCatalog.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/apiError.js';
import { logger } from '../utils/logger.js';
import { createTtlCache } from './carCatalog/cache.js';
import { decodeCarId } from './carCatalog/idCodec.js';
import { resolveProvider } from './carCatalog/index.js';

/**
 * Car catalogue business logic.
 *
 * Sits between the HTTP layer (which validates and shapes a response) and the
 * provider adapter (which speaks CarDekho). Everything the app depends on lives
 * here: which source is used, what a search means, how paging is decided, and
 * the capability descriptor the UI renders itself from.
 *
 * A provider call is expensive (a credit plus 1-5 seconds), so list and detail
 * reads go through a TTL cache keyed by the real provider inputs.
 */
const cache = createTtlCache({ ttlMs: env.carCatalogCacheTtlMs });

/** The provider's default city when the client does not choose one. */
const DEFAULT_CITY = 'hyderabad';

/** How many brand-scoped lookups one search may add. */
const MAX_SEARCH_BRAND_EXPANSIONS = 2;

function sha1(value) {
  return createHash('sha1').update(String(value)).digest('base64url').slice(0, 24);
}

function capabilitiesFor(sourceSpec) {
  return {
    source: sourceSpec.id,
    search: sourceSpec.search,
    pagination: sourceSpec.pagination,
    detailKind: sourceSpec.detailKind,
    filters: sourceSpec.filters,
  };
}

/** Words of two or more characters, which is what a car query is made of. */
function queryTokens(query) {
  return String(query ?? '')
    .toLowerCase()
    .split(/[^a-z0-9-]+/)
    .filter((token) => token.length >= 2);
}

/** Every token must appear somewhere in the real vehicle text. */
function matchesQuery(car, tokens) {
  if (tokens.length === 0) return true;
  const haystack = `${car.title} ${car.make ?? ''} ${car.model}`.toLowerCase();
  return tokens.every((token) => haystack.includes(token));
}

/**
 * External results first (the external catalogue is primary), then any local
 * vehicle it does not carry, de-duplicated so `Mahindra Scorpio N` (provider)
 * and `Mahindra Scorpio-N` (local) never appear twice.
 */
function mergeCarLists(primary, supplement) {
  const seen = new Set(primary.map((car) => dedupKey(car)));
  const merged = [...primary];
  for (const car of supplement) {
    const key = dedupKey(car);
    if (!seen.has(key)) {
      seen.add(key);
      merged.push(car);
    }
  }
  return merged;
}

/**
 * True when the failure is one the local fallback catalogue can answer for:
 * rate limit (429 surfaced as 503), timeout (503) or a 502/503 upstream
 * problem. Client errors (400/404) are real answers and are never masked.
 */
function isTransientProviderFailure(error) {
  if (error instanceof ApiError) return error.statusCode >= 500;
  return true;
}

/**
 * What the catalogue can do, and the filters the app should render.
 * Costs no provider credits.
 */
export function describeCapabilities() {
  const descriptor = resolveProvider().describeCatalog();

  return {
    ...descriptor,
    ready: descriptor.sources.length > 0,
    defaultPageSize: env.carCatalogPageSize,
  };
}

/**
 * Lists catalogue cards.
 *
 * @param {{ source?: string, city?: string, brand?: string, q?: string, page?: number }} query
 */
export async function listCars(query = {}) {
  const provider = resolveProvider();
  const descriptor = provider.describeCatalog();

  // No adapter wired up: say so plainly instead of answering a confusing
  // "unknown source", and never reach for the network.
  if (descriptor.sources.length === 0) {
    throw ApiError.serviceUnavailable('The car catalogue is not configured on the server.');
  }

  const requestedSource = query.source ?? descriptor.defaultSource;
  const sourceSpec = descriptor.sources.find((entry) => entry.id === requestedSource);

  if (sourceSpec === undefined) {
    throw ApiError.badRequest(
      `Unknown catalogue source. Supported: ${descriptor.sources.map((entry) => entry.id).join(', ')}.`,
    );
  }

  return sourceSpec.id === 'used'
    ? listUsedCars(provider, sourceSpec, query)
    : listNewCarModels(provider, sourceSpec, query);
}

async function listUsedCars(provider, sourceSpec, query) {
  if (query.q !== undefined && query.q.trim() !== '') {
    throw ApiError.badRequest(
      'Text search is not available for Hyderabad used listings. Choose the "new" source to search.',
    );
  }

  const city = query.city ?? DEFAULT_CITY;
  const page = query.page ?? 1;

  try {
    const result = await cache.resolve(`used:${city}:${page}`, () =>
      provider.fetchUsedCarPage({ city, page }),
    );

    // A page that answers with nothing is not an answer: the local layer
    // fills in rather than showing an empty showroom.
    const cityCars = result.cars.filter(
      (car) => slugify(car.city ?? '') === city,
    );
    if (cityCars.length === 0) {
      logger.warn('External used catalogue returned no vehicles; using local fallback', { city });
      return localUsedResult(query, city, page, sourceSpec);
    }

    return {
      cars: cityCars,
      source: 'used',
      page,
      pageSize: env.carCatalogPageSize,
      hasMore: cityCars.length >= env.carCatalogPageSize,
      totalKnown: false,
      appliedFilters: { city },
      capabilities: capabilitiesFor(sourceSpec),
      origin: 'external',
    };
  } catch (error) {
    if (!isTransientProviderFailure(error)) throw error;

    logger.warn('Using fallback used-car catalogue', {
      reason: error?.code ?? error?.message ?? 'unknown',
    });

    return localUsedResult(query, city, page, sourceSpec);
  }
}

/** Local used-car answer, honest about which city it can actually serve. */
function localUsedResult(query, city, page, sourceSpec) {
  let cars = getFallbackUsedCars().cars;

  // Fallback records are not relabelled as Hyderabad inventory. If no local
  // Hyderabad listing exists, return an honest empty page.
  cars = cars.filter((car) => slugify(car.city ?? '') === city);

  return {
    cars,
    source: 'used',
    page,
    pageSize: env.carCatalogPageSize,
    hasMore: false,
    totalKnown: false,
    appliedFilters: { city },
    capabilities: capabilitiesFor(sourceSpec),
    origin: 'local_fallback',
  };
}

async function listNewCarModels(provider, sourceSpec, query) {
  const brand = query.brand;
  const tokens = queryTokens(query.q);
  const queryActive = brand !== undefined || tokens.length > 0;

  let index = [];
  let externalFailed = false;

  try {
    index = await cache.resolve(`new:${brand ?? ''}`, () =>
      provider.fetchNewCarModelIndex({ brand }),
    );
  } catch (error) {
    // Rate limited, timed out or upstream trouble: the local layer answers,
    // but a client error (400/404) is a real answer and is never masked.
    if (!isTransientProviderFailure(error)) throw error;
    externalFailed = true;

    logger.warn('Using fallback new-car catalogue', {
      reason: error?.code ?? error?.message ?? 'unknown',
    });
  }

  const cars = [...index];
  const seen = new Set(cars.map((car) => car.id));

  if (!externalFailed) {
    // A query that names a brand ("tata nexon") is served properly by asking the
    // provider for that brand's models too — a real call, not a guess — which is
    // how a brand-scoped search reaches models outside the popular index.
    const expansions = tokens
      .slice(0, MAX_SEARCH_BRAND_EXPANSIONS)
      .filter((token) => token !== brand);
    const scopedResults = await Promise.all(
      expansions.map((token) =>
        cache
          .resolve(`new:${token}`, () => provider.fetchNewCarModelIndex({ brand: token }))
          .catch(() => []),
      ),
    );

    for (const scoped of scopedResults) {
      for (const car of scoped) {
        if (car.id !== null && !seen.has(car.id)) {
          seen.add(car.id);
          cars.push(car);
        }
      }
    }
  }

  // The brand filter is applied locally as well: the provider's `brand`
  // parameter is not honoured by every index build, so without this a
  // `brand=kia` request would return the whole popular list.
  const externalMatches = cars.filter(
    (car) => matchesBrand(car, brand) && matchesQuery(car, tokens),
  );

  // The external index is a *popular* list, so a search or brand filter can
  // legitimately miss vehicles it does not carry (there is no Kia Sorento in
  // it). The local layer fills exactly those gaps — and is the whole answer
  // when the provider failed or returned nothing. Plain browsing stays
  // external-first and never pads itself with local duplicates.
  const needsLocal = externalFailed || externalMatches.length === 0 || queryActive;
  const localMatches = needsLocal
    ? searchLocalCars({ source: 'new', brand, q: query.q })
    : [];

  const merged = mergeCarLists(externalMatches, localMatches);

  const origin = externalFailed || externalMatches.length === 0
    ? 'local_fallback'
    : localMatches.length > 0
      ? 'mixed'
      : 'external';

  return {
    cars: merged,
    source: 'new',
    page: 1,
    pageSize: env.carCatalogPageSize,
    hasMore: false,
    totalKnown: true,
    appliedFilters: {
      ...(brand === undefined ? {} : { brand }),
      ...(query.q === undefined ? {} : { q: query.q }),
    },
    capabilities: capabilitiesFor(sourceSpec),
    origin,
  };
}

/**
 * Full detail for one catalogue item. The id was minted by us, so its shape
 * decides which provider endpoint to use — the client never chooses that.
 */
export async function getCarDetail(id) {
  // Cards minted by the local layer are answered from it directly: those ids
  // were never signed, so the codec would reject them. For new-car cards, try
  // the live provider as well: the local index is used during provider outages,
  // but its records intentionally contain no photos or trim-level pricing.
  // This also keeps legacy `fallback-*` favourites resolving forever.
  const localCar = getFallbackCarById(id);
  if (localCar !== null) {
    if (localCar.source !== 'new') return localCar;

    const brand = slugify(localCar.make ?? localCar.brand);
    const model = slugify(localCar.model);
    const provider = resolveProvider();
    if (
      brand === '' ||
      model === '' ||
      provider.describeCatalog().sources.length === 0
    ) {
      return localCar;
    }

    try {
      const liveDetail = await cache.resolve(`detail:model:${brand}:${model}`, () =>
        provider.fetchModelDetail({ brand, model }),
      );
      // Keep the card's stable local id so its favorites and navigation remain
      // valid even though its richer details came from the provider.
      return { ...liveDetail, id };
    } catch (error) {
      logger.warn('Using local detail while live model details are unavailable', {
        id,
        reason: error?.code ?? error?.message ?? 'unknown',
      });
      return localCar;
    }
  }

  const decoded = decodeCarId(id); // 400 for anything we did not mint
  const provider = resolveProvider();

  if (provider.describeCatalog().sources.length === 0) {
    throw ApiError.serviceUnavailable('The car catalogue is not configured on the server.');
  }

  if (decoded.kind === 'model') {
    try {
      return await cache.resolve(`detail:model:${decoded.brand}:${decoded.model}`, () =>
        provider.fetchModelDetail({ brand: decoded.brand, model: decoded.model }),
      );
    } catch (error) {
      if (!isTransientProviderFailure(error)) throw error;

      // Upstream trouble must not dead-end a page the local layer can answer
      // for the same vehicle model. When we carry no local equivalent the real
      // failure propagates unchanged - never an invented detail.
      const substitute = getLocalByBrandModel(decoded.brand, decoded.model);
      if (substitute === null) throw error;

      logger.warn('Using local detail for provider model', {
        brand: decoded.brand,
        model: decoded.model,
        reason: error?.code ?? error?.message ?? 'unknown',
      });
      return substitute;
    }
  }

  return cache.resolve(`detail:listing:${sha1(decoded.url)}`, () =>
    provider.fetchListingDetail({ url: decoded.url }),
  );
}

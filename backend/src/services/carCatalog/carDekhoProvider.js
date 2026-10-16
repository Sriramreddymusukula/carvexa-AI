import { encodeCarId } from './idCodec.js';
import { callProviderEndpoint } from './parseTransport.js';
import {
  getLocalImageGallery,
  getLocalImageGalleryForTitle,
} from './normalizedCatalog.js';

/**
 * CarDekho provider adapter (CarDekho data via the Parse marketplace).
 *
 * This is the ONLY file that understands the provider's JSON. Everything it
 * returns is already expressed in our own vocabulary, so a future provider is a
 * new sibling file plus one line in `./index.js` — no controller, route or
 * Flutter change.
 *
 * Field-level truth, taken from the provider's published spec and confirmed
 * against live responses:
 *  * `get_new_cars` returns `{ name, url, image, price }` — **`price` is
 *    commonly `null`** because CarDekho does not publish pricing for every
 *    model. We pass that through as `null` ("price on request") rather than
 *    inventing a figure.
 *  * `search_used_cars` returns `{ id, sku_id, model, variant, year, price,
 *    formatted_price, km, fuel_type, transmission, image, url, city, owner }`
 *    plus `total_count`, which in practice equals the page size. We therefore
 *    derive paging from the page length, never from `total_count`.
 *  * `formatted_price` arrives double-encoded (`â‚¹84 Lakh`), so currency is
 *    rendered here from the numeric `price` instead.
 *  * Used listings carry no separate brand field, so `make` is `null` for them
 *    and the provider's own `model` string is used as the title verbatim.
 */

export const PROVIDER_ID = 'parse-cardekho';

/** The provider quotes in Indian rupees; there is no currency field to read. */
const CURRENCY = 'INR';

// ------------------------------------------------------------------ helpers --

/** `Tata_Sierra` -> `Tata Sierra`; collapses runs of whitespace. */
function normalizeLabel(value) {
  return String(value ?? '')
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** `land-rover` -> `Land Rover`. */
function titleCaseSlug(slug) {
  return String(slug ?? '')
    .split('-')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

/** `"13,584"` -> `13584`. Provider gives formatted strings for mileage. */
function parseCount(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const digits = String(value ?? '').replace(/[^\d]/g, '');
  if (digits.length === 0) return null;
  const parsed = Number(digits);
  return Number.isFinite(parsed) ? parsed : null;
}

function parseAmount(value) {
  if (typeof value === 'number' && Number.isFinite(value)) return value;
  const parsed = Number(String(value ?? '').replace(/[^\d.]/g, ''));
  return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
}

function trimTrailingZeros(value) {
  return value.toFixed(2).replace(/\.?0+$/, '');
}

/**
 * Indian digit grouping, rendered from the numeric price. Lakh/crore is how the
 * provider (and the market) actually speaks about car prices, so a premium card
 * reads "₹84 Lakh" rather than "₹8400000".
 */
function formatInr(amount) {
  if (amount === null) return null;
  if (amount >= 10_000_000) return `₹${trimTrailingZeros(amount / 10_000_000)} Crore`;
  if (amount >= 100_000) return `₹${trimTrailingZeros(amount / 100_000)} Lakh`;

  const digits = String(Math.round(amount));
  const lastThree = digits.slice(-3);
  const rest = digits.slice(0, -3);
  const grouped = rest === '' ? lastThree : `${rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',')},${lastThree}`;
  return `₹${grouped}`;
}

/** `first-owner` -> `First owner`. */
function humanizeToken(value) {
  const text = normalizeLabel(value);
  if (text === '') return null;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/**
 * Brand slug from a provider model URL.
 * `/tata/aeris` -> `tata`; `/carmodels/Tata/Tata_Sierra` -> `tata`.
 */
function brandSlugFromUrl(value) {
  const segments = urlPathSegments(value);
  if (segments.length === 0) return null;

  const first = segments[0];
  if (first === 'new-cars' || first === 'used-cars' || first === 'cars') return null;

  const candidate = first === 'carmodels' ? segments[1] : first;
  return candidate !== undefined && /^[a-z0-9-]+$/i.test(candidate)
    ? candidate.toLowerCase()
    : null;
}

/** Model slug from a provider model URL, with any brand prefix removed. */
function modelSlugFromUrl(value, brandSlug) {
  const segments = urlPathSegments(value);
  if (segments.length === 0) return null;

  let last = segments[segments.length - 1].replace(/\.html?$/i, '');
  if (brandSlug && last.toLowerCase().startsWith(`${brandSlug}_`)) {
    last = last.slice(brandSlug.length + 1);
  }
  return /^[a-z0-9-]+$/i.test(last) ? last.toLowerCase() : null;
}

function urlPathSegments(value) {
  try {
    return new URL(String(value))
      .pathname.split('/')
      .map((segment) => segment.trim())
      .filter((segment) => segment !== '');
  } catch {
    return [];
  }
}

// ------------------------------------------------------------------ mappers --

/**
 * `get_new_cars` model -> our catalog summary.
 * `price` stays `null` when the provider has not published it.
 */
function toSummaryFromNewModel(raw) {
  const sourceUrl = typeof raw?.url === 'string' ? raw.url : null;
  const brandSlug = sourceUrl === null ? null : brandSlugFromUrl(sourceUrl);
  const modelSlug = sourceUrl === null ? null : modelSlugFromUrl(sourceUrl, brandSlug);

  const rawName = normalizeLabel(raw?.name);
  const brandLabel = brandSlug === null ? null : titleCaseSlug(brandSlug);
  const model =
    brandLabel !== null && rawName.toLowerCase().startsWith(`${brandLabel.toLowerCase()} `)
      ? rawName.slice(brandLabel.length + 1)
      : rawName;
  const fallbackGallery = getLocalImageGallery(brandSlug, modelSlug);

  const price = parseAmount(raw?.price);

  return {
    id: brandSlug !== null && modelSlug !== null ? encodeCarId({ kind: 'model', brand: brandSlug, model: modelSlug }) : null,
    source: 'new',
    title: brandLabel === null ? model : `${brandLabel} ${model}`,
    make: brandLabel,
    model,
    variant: null,
    year: null,
    price,
    formattedPrice: formatInr(price),
    currency: CURRENCY,
    mileageKm: null,
    fuelType: null,
    transmission: null,
    bodyType: null,
    city: null,
    owner: null,
    imageUrl: typeof raw?.image === 'string' && raw.image !== ''
      ? raw.image
      : fallbackGallery[0]?.url ?? null,
    detailAvailable: brandSlug !== null && modelSlug !== null,
    // Kept for provider-side diagnostics only; never surfaced to the client.
    _ref: { brandSlug, modelSlug },
  };
}

/** `search_used_cars` listing -> our catalog summary. */
function toSummaryFromUsedCar(raw) {
  const sourceUrl = typeof raw?.url === 'string' ? raw.url : null;
  const model = normalizeLabel(raw?.model);
  const variant = normalizeLabel(raw?.variant) || null;
  const price = parseAmount(raw?.price);
  const fallbackGallery = getLocalImageGalleryForTitle(`${model} ${variant ?? ''}`);

  return {
    id: sourceUrl === null ? null : encodeCarId({ kind: 'listing', url: sourceUrl }),
    source: 'used',
    // The provider's `model` already contains the brand ("Volvo XC90"), and it
    // exposes no separate brand field, so it is used as-is.
    title: variant === null ? model : `${model} ${variant}`,
    make: null,
    model,
    variant,
    year: typeof raw?.year === 'number' ? raw.year : parseCount(raw?.year),
    price,
    formattedPrice: formatInr(price),
    currency: CURRENCY,
    mileageKm: parseCount(raw?.km),
    fuelType: normalizeLabel(raw?.fuel_type) || null,
    transmission: normalizeLabel(raw?.transmission) || null,
    bodyType: null,
    city: normalizeLabel(raw?.city) || null,
    owner: humanizeToken(raw?.owner),
    imageUrl: typeof raw?.image === 'string' && raw.image !== ''
      ? raw.image
      : fallbackGallery[0]?.url ?? null,
    detailAvailable: sourceUrl !== null,
    _ref: { skuId: typeof raw?.sku_id === 'string' ? raw.sku_id : null },
  };
}

/** Drops the provider-internal `_ref` and any card that cannot be opened. */
function publish(summary) {
  if (summary === null || summary.id === null) return null;
  const { _ref, ...car } = summary;
  return car;
}

// ---------------------------------------------------------------- endpoints --

/**
 * The popular new-car model index. One provider call; the returned set is the
 * provider's complete popular list, which is what makes searching it a real
 * search rather than a filter over one page.
 */
export async function fetchNewCarModelIndex({ brand } = {}) {
  const data = await callProviderEndpoint('get_new_cars', { brand });
  const models = Array.isArray(data.models) ? data.models : [];
  return models.map(toSummaryFromNewModel).map(publish).filter((car) => car !== null);
}

/** The complete model list for one brand (`get_brand_models`). */
export async function fetchBrandModelNames({ brand }) {
  const data = await callProviderEndpoint('get_brand_models', { brand });
  const models = Array.isArray(data.models) ? data.models : [];
  return models
    .map((raw) => ({
      name: normalizeLabel(raw?.model_name),
      slug: typeof raw?.model_slug === 'string' ? raw.model_slug.toLowerCase() : null,
    }))
    .filter((model) => model.slug !== null);
}

/** One page of used-car listings. Paging is derived from the page length. */
export async function fetchUsedCarPage({ city, page }) {
  const data = await callProviderEndpoint('search_used_cars', { city, page });
  const cars = Array.isArray(data.cars) ? data.cars : [];
  return {
    cars: cars.map(toSummaryFromUsedCar).map(publish).filter((car) => car !== null),
    reportedTotal: parseCount(data.total_count),
    city: typeof data.city === 'string' ? data.city : null,
    page: typeof data.page === 'number' ? data.page : page ?? null,
  };
}

// ------------------------------------------------------- detail primitives --

/**
 * Provider keys we know how to label. Anything unknown is humanised rather than
 * dropped, so a provider adding a field never silently loses information.
 */
const ENGINE_SPEC_LABELS = {
  engine: 'Engine',
  power: 'Max power',
  torque: 'Max torque',
  displacement: 'Displacement',
  seating_capacity: 'Seating',
  drive_type: 'Drive type',
  mileage: 'Mileage',
  transmission: 'Transmission',
};

const DIMENSION_LABELS = {
  length: 'Length',
  width: 'Width',
  height: 'Height',
  wheelbase: 'Wheelbase',
  boot_space: 'Boot space',
  ground_clearance: 'Ground clearance',
};

/** Keys surfaced elsewhere on the page, so they are not repeated as spec rows. */
const SPEC_KEYS_SHOWN_ELSEWHERE = new Set(['Ground clearance', 'Global ncap safety rating']);

function humanizeKey(key) {
  const text = String(key ?? '')
    .replace(/[_-]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  if (text === '') return null;
  return text.charAt(0).toUpperCase() + text.slice(1);
}

/** `{ length: '3995 mm' }` -> `[{ label: 'Length', value: '3995 mm' }]`. */
function toLabelValuePairs(source, labels) {
  if (source === null || typeof source !== 'object') return [];

  return Object.entries(source)
    .map(([key, value]) => ({
      label: labels[key] ?? humanizeKey(key),
      // The provider uses "" to mean "not published"; that is omitted rather
      // than rendered as an empty row.
      value: normalizeLabel(value),
    }))
    .filter((pair) => pair.label !== null && pair.value !== '');
}

/**
 * Real image URLs from either gallery shape, de-duplicated and
 * order-preserving. Exterior images come first because they carry a category
 * and alt text.
 */
function toGallery(images, exteriorImages) {
  const gallery = [];
  const seen = new Set();

  const push = (url, alt, category) => {
    if (typeof url !== 'string' || url === '' || seen.has(url)) return;
    seen.add(url);
    gallery.push({ url, alt: alt ?? null, category: category ?? null });
  };

  if (Array.isArray(exteriorImages)) {
    for (const item of exteriorImages) push(item?.image, item?.alt, item?.category);
  }
  if (Array.isArray(images)) {
    for (const url of images) push(url, null, null);
  }

  return gallery;
}

/** Fill a sparse provider gallery with curated photos for that model. */
function supplementGallery(primary, fallback, minimum = 4) {
  const gallery = [...primary];
  const seen = new Set(gallery.map((image) => image.url));
  for (const image of fallback) {
    if (gallery.length >= minimum) break;
    if (seen.has(image.url)) continue;
    seen.add(image.url);
    gallery.push(image);
  }
  return gallery;
}

function toSpecificationSections(sections) {
  if (!Array.isArray(sections)) return [];

  return sections
    .map((section) => ({
      title: normalizeLabel(section?.title) || 'Specifications',
      items: (Array.isArray(section?.items) ? section.items : [])
        .map((item) => ({
          label: normalizeLabel(item?.name),
          value: normalizeLabel(item?.value),
        }))
        .filter((item) => item.label !== '' && item.value !== ''),
    }))
    .filter((section) => section.items.length > 0);
}

/**
 * A year must look like a year.
 *
 * `parseCount` is right for "21,500" but wrong for a registration value such as
 * "05/2015" or "Nov 2026", where stripping non-digits would produce nonsense
 * like 052015 or 112026. Only a plausible four-digit year is accepted, and
 * anything else stays null rather than showing a wrong year.
 */
function parseYear(value) {
  const text = String(value ?? '');
  const match = text.match(/\b(19|20)\d{2}\b/);
  if (match === null) return null;

  const year = Number(match[0]);
  return Number.isInteger(year) && year >= 1900 && year <= 2100 ? year : null;
}

/** Reads one real value out of a listing's `overview` rows by label. */
function overviewValue(overview, ...labels) {
  const wanted = labels.map((label) => label.toLowerCase());
  const hit = overview.find((item) => wanted.includes(item.label.toLowerCase()));
  return hit ? hit.value : null;
}

/** Variants and features are capped so one model cannot dominate the payload. */
const MAX_VARIANTS = 24;
const MAX_FEATURES = 32;

// ------------------------------------------------------------------ details --

/**
 * Full detail for a new-car model.
 *
 * `get_model_details` already carries price range, variants, engine specs,
 * dimensions, features, safety rating and a real image gallery, so it is the
 * only mandatory call. Full sectioned specifications are requested in parallel
 * and are treated as a bonus: a failure there must never lose the page.
 */
export async function fetchModelDetail({ brand, model }) {
  const details = await callProviderEndpoint('get_model_details', { brand, model });

  // Fetch independently: model details provide normal photographs; the view
  // endpoint provides ordered spin frames. Never treat spin frames as photos.
  const [specifications, view] = await Promise.all([
    callProviderEndpoint('get_specifications', { brand, model }).catch(() => null),
    callProviderEndpoint('get_360_view', { model_slug: `${brand}-${model}` }).catch(() => null),
  ]);
  const viewItems = Array.isArray(view?.items) ? view.items : [];
  const interiorImages = viewItems
    .filter((item) => item?.isInterior === true)
    .map((item) => ({
      image: item?.image,
      alt: normalizeLabel(item?.title) || null,
      category: 'interior',
    }));
  const providerGallery = toGallery(
    details.images,
    [...(Array.isArray(details.exterior_images) ? details.exterior_images : []), ...interiorImages],
  );
  const gallery = supplementGallery(
    providerGallery,
    getLocalImageGallery(brand, model),
  );
  const spinImages = toGallery(
    [],
    viewItems
      .filter((item) => item?.isInterior !== true)
      .map((item) => ({
        image: item?.image,
        alt: normalizeLabel(item?.title) || null,
        category: '360 frame',
      })),
  );

  const brandLabel = titleCaseSlug(brand);
  const rawName = normalizeLabel(details.model_name) || `${brandLabel} ${titleCaseSlug(model)}`;
  const modelDisplay =
    rawName.toLowerCase().startsWith(`${brandLabel.toLowerCase()} `)
      ? rawName.slice(brandLabel.length + 1)
      : rawName;

  const allVariants = (Array.isArray(details.variants) ? details.variants : [])
    .map((raw) => ({
      name: normalizeLabel(raw?.name) || null,
      priceLabel: normalizeLabel(raw?.price) || null,
      price: parseAmount(raw?.ex_showroom_price),
      fuelType: normalizeLabel(raw?.fuel_type) || null,
      summary: normalizeLabel(raw?.sub_text) || null,
    }))
    .filter((variant) => variant.name !== null);

  const allFeatures = (Array.isArray(details.features) ? details.features : [])
    .map(normalizeLabel)
    .filter((feature) => feature !== '');

  const priceRange = normalizeLabel(details.price_range) || null;

  return {
    id: encodeCarId({ kind: 'model', brand, model }),
    source: 'new',
    title: rawName,
    make: brandLabel,
    model: modelDisplay,
    variant: null,
    year: null,
    // The provider publishes a *range* for models, not a single figure, so the
    // numeric price stays null and the published range is what we display.
    price: null,
    formattedPrice: priceRange,
    priceRange,
    currency: CURRENCY,
    bodyType: normalizeLabel(details.body_type) || null,
    fuelType: null,
    fuelTypes: (Array.isArray(details.fuel_types) ? details.fuel_types : [])
      .map(normalizeLabel)
      .filter((fuel) => fuel !== ''),
    transmission: null,
    mileage: normalizeLabel(details.mileage) || null,
    safetyRating: normalizeLabel(details.safety_rating) || null,
    seatingCapacity: normalizeLabel(details.engine_specs?.seating_capacity) || null,
    mileageKm: null,
    city: null,
    owner: null,
    images: gallery,
    spinImages,
    variants: allVariants.slice(0, MAX_VARIANTS),
    variantCount: allVariants.length,
    features: allFeatures.slice(0, MAX_FEATURES),
    featureCount: allFeatures.length,
    engineSpecs: toLabelValuePairs(details.engine_specs, ENGINE_SPEC_LABELS).filter(
      (pair) => !SPEC_KEYS_SHOWN_ELSEWHERE.has(pair.label),
    ),
    dimensions: toLabelValuePairs(details.dimensions, DIMENSION_LABELS),
    specificationSections: toSpecificationSections(specifications?.sections),
    overview: [],
    moreInfoUrl: typeof details.url === 'string' ? details.url : null,
  };
}

/** Full detail for one used-car listing, keyed by its real listing URL. */
export async function fetchListingDetail({ url }) {
  const data = await callProviderEndpoint('get_car_details', { url });

  const overview = (Array.isArray(data.overview) ? data.overview : [])
    .map((raw) => ({
      label: normalizeLabel(raw?.key),
      value: normalizeLabel(raw?.value),
    }))
    .filter((item) => item.label !== '' && item.value !== '');

  const price = parseAmount(data.price);
  const title = normalizeLabel(data.model) || 'Used car listing';
  const providerGallery = toGallery(data.images, []);
  const fallbackGallery = getLocalImageGalleryForTitle(title).map((image) => ({
    ...image,
    alt: `Representative model photo, not this specific listing: ${title}`,
    category: 'model reference',
  }));

  return {
    id: encodeCarId({ kind: 'listing', url }),
    source: 'used',
    title,
    make: null,
    model: title,
    variant: null,
    // Read from the listing's own overview rows rather than guessed from the
    // SEO title string.
    year: parseYear(overviewValue(overview, 'Registration Year', 'Make Year', 'Year')),
    price,
    formattedPrice: formatInr(price),
    priceRange: null,
    currency: CURRENCY,
    bodyType: normalizeLabel(overviewValue(overview, 'Body Type')) || null,
    fuelType: normalizeLabel(overviewValue(overview, 'Fuel Type')) || null,
    fuelTypes: [],
    transmission: normalizeLabel(overviewValue(overview, 'Transmission')) || null,
    mileage: null,
    safetyRating: null,
    seatingCapacity: normalizeLabel(overviewValue(overview, 'Seating Capacity')) || null,
    mileageKm: parseCount(overviewValue(overview, 'KM Driven', 'Kilometers Driven')),
    city: normalizeLabel(overviewValue(overview, 'City', 'Location')) || null,
    owner: normalizeLabel(overviewValue(overview, 'Ownership', 'Owner')) || null,
    images: providerGallery.length > 0 ? providerGallery : fallbackGallery,
    variants: [],
    variantCount: 0,
    features: [],
    featureCount: 0,
    engineSpecs: [],
    dimensions: [],
    specificationSections: toSpecificationSections(data.specifications),
    overview,
    moreInfoUrl: normalizeLabel(data.url) || url,
  };
}

// ------------------------------------------------------------- capabilities --

/**
 * Example values published by the provider's own input specification
 * (`input_params[].domain.sample`). These are the API's documented examples —
 * never inventory we invented.
 */
const DOCUMENTED_BRANDS = ['hyundai', 'tata', 'maruti', 'mahindra'];

/**
 * What this provider can actually do, expressed as data rather than prose.
 *
 * The app renders its search box and its filters from this descriptor, which is
 * what guarantees a control is never shown when it would not change the
 * result — the provider has no free-text search over used listings, so the app
 * does not pretend otherwise.
 *
 * Costs no credits: it is derived from the provider's published contract.
 */
export function describeCatalog() {
  return {
    provider: PROVIDER_ID,
    sourceName: 'CarDekho',
    defaultSource: 'used',
    sources: [
      {
        id: 'used',
        label: 'Used cars',
        description: 'Used-car listings in Hyderabad with real prices and photographs.',
        search: false,
        pagination: true,
        detailKind: 'listing',
        filters: [],
      },
      {
        id: 'new',
        label: 'New cars',
        description: 'Current new-car models with published specifications.',
        search: true,
        pagination: false,
        detailKind: 'model',
        filters: [
          {
            id: 'brand',
            label: 'Brand',
            kind: 'slug',
            placeholder: 'tata',
            examples: DOCUMENTED_BRANDS,
          },
        ],
      },
    ],
    notes: [
      'Used listings report a total_count equal to the page size, so paging is derived from the page length.',
      'New-car prices are frequently unpublished; those cards read "Price on request" rather than showing a guess.',
      'Free-text search is offered only for the new-car model index, which the provider exposes in full.',
    ],
  };
}


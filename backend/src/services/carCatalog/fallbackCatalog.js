/**
 * Local fallback catalogue facade.
 *
 * All data lives in `normalizedCatalog.js` (the normalized vehicle layer).
 * This module keeps the historical entry points the catalogue service has
 * always used, so the service and any older imports keep working unchanged:
 *
 *  * `getFallbackNewCars()` / `getFallbackUsedCars()` - list-shaped results.
 *  * `getFallbackCarById()` - detail for a locally minted id, else null.
 *  * `searchLocalCars()` / `isLocalCatalogId()` / `getLocalByBrandModel()` /
 *    `dedupKey()` - the search and identity helpers the service and AI use.
 *
 * Served when the live provider fails, times out, returns nothing, or does not
 * carry the requested vehicle. Cards use the provider's vocabulary so the
 * Flutter DTO, favourites and comparison screens work without change.
 */
import {
  dedupKey,
  getLocalByBrandModel,
  getLocalCarCards,
  getLocalCarDetail,
  isLocalCatalogId,
  matchesBrand,
  matchesTokens,
  searchLocalCars,
  slugify,
  tokenizeQuery,
} from './normalizedCatalog.js';

/** One page of the local used-car list (the local layer does not page). */
export function getFallbackUsedCars() {
  return {
    cars: getLocalCarCards('used'),
    page: 1,
    hasMore: false,
    source: 'fallback',
  };
}

/** The complete local new-car list. */
export function getFallbackNewCars() {
  return {
    cars: getLocalCarCards('new'),
    hasMore: false,
    source: 'fallback',
  };
}

/**
 * Detail for one locally served card, shaped like the live provider's detail
 * response. Facts this catalogue does not hold stay null/empty rather than
 * invented.
 *
 * @param {string} id
 * @returns {Record<string, unknown> | null} null when the id is not ours.
 */
export function getFallbackCarById(id) {
  return getLocalCarDetail(id);
}

export {
  dedupKey,
  getLocalByBrandModel,
  getLocalCarCards,
  isLocalCatalogId,
  matchesBrand,
  matchesTokens,
  searchLocalCars,
  slugify,
  tokenizeQuery,
};


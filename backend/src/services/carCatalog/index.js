import { env } from '../../config/env.js';
import { ApiError } from '../../utils/apiError.js';
import { logger } from '../../utils/logger.js';
import * as carDekho from './carDekhoProvider.js';

/**
 * Provider registry.
 *
 * The single place a provider adapter is chosen. Add an adapter that implements
 * the same six functions, register it here, set `CAR_CATALOG_PROVIDER` in
 * `backend/.env`, and neither the service, the controller, the routes nor any
 * Flutter code changes.
 *
 * Every adapter must export:
 *   PROVIDER_ID
 *   describeCatalog()
 *   fetchNewCarModelIndex({ brand })
 *   fetchBrandModelNames({ brand })
 *   fetchUsedCarPage({ city, page })
 *   fetchModelDetail({ brand, model })
 *   fetchListingDetail({ url })
 */

/** A provider that refuses every call with one clear, actionable failure. */
const unconfigured = {
  PROVIDER_ID: 'none',
  describeCatalog() {
    return {
      provider: 'none',
      sourceName: null,
      defaultSource: null,
      sources: [],
      notes: ['No car catalogue provider is configured on the server.'],
    };
  },
  fetchNewCarModelIndex: reject,
  fetchBrandModelNames: reject,
  fetchUsedCarPage: reject,
  fetchModelDetail: reject,
  fetchListingDetail: reject,
};

function reject() {
  return Promise.reject(
    ApiError.serviceUnavailable('The car catalogue is not configured on the server.'),
  );
}

const providers = new Map([
  [carDekho.PROVIDER_ID, carDekho],
  ['parse-cardekho', carDekho],
  ['none', unconfigured],
]);

/**
 * @returns {typeof carDekho | typeof unconfigured} The adapter for the
 * configured provider.
 */
export function resolveProvider() {
  const configured = env.carCatalogProvider;

  if (configured === 'none') return unconfigured;

  const provider = providers.get(configured);
  if (provider === undefined) {
    // A typo must fail loudly at the boundary rather than silently disabling
    // the catalogue or, worse, calling the wrong service.
    logger.error('Unknown car catalogue provider configured', { provider: configured });
    return unconfigured;
  }

  if (!env.isCarCatalogConfigured) {
    logger.error('Car catalogue provider is configured but incomplete', {
      provider: configured,
      missing: [
        env.carCatalogBaseUrl() === '' ? 'baseUrl' : null,
        env.carCatalogScraperId === '' ? 'scraperId' : null,
        env.carCatalogApiKey === '' ? 'credentials' : null,
      ].filter((item) => item !== null),
    });
    return unconfigured;
  }

  return provider;
}

/** True when a real provider is wired up and ready to be called. */
export function isCatalogReady() {
  return resolveProvider() !== unconfigured;
}

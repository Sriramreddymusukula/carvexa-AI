import { env } from '../../config/env.js';
import { ApiError } from '../../utils/apiError.js';
import { logger } from '../../utils/logger.js';
import { createRetryAfterGate } from './retryAfterGate.js';

/**
 * The only code that talks to the external car catalog.
 *
 * Everything provider-specific about *transport* lives here: the URL shape, the
 * authentication header, the timeout, the success envelope and the error
 * envelope. Everything provider-specific about *data* lives in the provider
 * adapter (`carDekhoProvider.js`). Swapping providers means a new adapter and a
 * new entry in `index.js` — this file does not know what a car is.
 *
 * Security rules enforced here:
 *  * the key is added to the outbound request and is never logged, never
 *    included in a thrown message, and never echoed to a client;
 *  * a provider error body is logged for operators (redacted) but replaced with
 *    our own message before it reaches the user.
 */

/** Upstream status value for "the thing you named is gone", per provider docs. */
const KIND_INPUT_NOT_FOUND = 'input_not_found';
const endpointRetryGate = createRetryAfterGate();

function rateLimitedError(retryAfter) {
  return new ApiError(503, 'Too many catalogue requests right now. Please try again shortly.', {
    code: 'catalog_rate_limited',
    details:
      retryAfter === null
        ? undefined
        : [{ field: 'retryAfterSeconds', message: String(retryAfter) }],
  });
}

function requestUrl(endpointName, params) {
  const url = new URL(
    `${env.carCatalogBaseUrl()}/scraper/${encodeURIComponent(env.carCatalogScraperId)}/${encodeURIComponent(endpointName)}`,
  );

  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || value === '') continue;
    url.searchParams.set(key, String(value));
  }

  // Support the rarer providers that authenticate by query parameter.
  if (env.carCatalogApiKeyQueryParam) {
    url.searchParams.set(env.carCatalogApiKeyQueryParam, env.carCatalogApiKey);
  }

  return url;
}

function requestHeaders() {
  const header = env.carCatalogApiKeyHeader || 'X-API-Key';
  return {
    accept: 'application/json',
    [header]: `${env.carCatalogApiKeyScheme}${env.carCatalogApiKey}`,
  };
}

/** The provider wraps successes as `{ status: 'success', data: ... }`. */
function unwrapSuccess(payload) {
  if (payload === null || typeof payload !== 'object' || Array.isArray(payload)) {
    throw ApiError.serviceUnavailable('The car catalogue returned an unexpected response.');
  }
  if (payload.data !== null && typeof payload.data === 'object') return payload.data;
  throw ApiError.serviceUnavailable('The car catalogue returned an unexpected response.');
}

function retryAfterSeconds(response, envelope) {
  const header = Number(response.headers.get('retry-after'));
  if (Number.isFinite(header) && header > 0) return Math.ceil(header);

  const body = envelope?.error?.retry_after;
  if (Number.isFinite(body) && body > 0) return Math.ceil(body);
  return null;
}

/**
 * Translate a provider failure into the failure our own API contract promises.
 * The client only ever sees one of: 400, 404, 502, 503.
 */
function failureFromResponse(response, envelope, endpointName) {
  const status = response.status;
  const providerStatus = envelope?.error?.status ?? null;
  const providerKind = envelope?.error?.kind ?? null;
  const retryAfter = retryAfterSeconds(response, envelope);

  // Operators get the detail; users get a sentence they can act on.
  logger.error('Car catalogue request failed', {
    endpoint: endpointName,
    status,
    providerStatus,
    providerKind,
    retryAfter,
  });

  // 401 wrong/expired key and 402 exhausted credits are both server-side issues
  // the user can do nothing about, so they are not reported as their problem.
  if (status === 401 || status === 402) {
    return ApiError.serviceUnavailable('The car catalogue is temporarily unavailable.');
  }

  if (status === 429) {
    if (retryAfter !== null) endpointRetryGate.block(endpointName, retryAfter);
    return rateLimitedError(retryAfter);
  }

  if (status === 422) {
    // The provider's own vocabulary for "the thing you named is gone".
    if (providerKind === KIND_INPUT_NOT_FOUND) {
      return ApiError.notFound('That vehicle is no longer listed.');
    }
    return ApiError.badRequest('That catalogue request is not valid.');
  }

  // A missing path or unknown scraper id is our misconfiguration, not a 404 for
  // the user. 502 upstream_error, 503 blocked and 500 scraper bugs all land
  // here too: transient or provider-side, so the user gets one retryable answer.
  return new ApiError(502, 'The car catalogue could not answer that request. Please try again.', {
    code: 'catalog_upstream_error',
  });
}

/**
 * Calls one provider endpoint with query parameters and returns its `data`.
 *
 * @param {string} endpointName
 * @param {Record<string, string | number | undefined | null>} params
 * @returns {Promise<Record<string, unknown>>}
 */
export async function callProviderEndpoint(endpointName, params = {}) {
  if (!env.isCarCatalogConfigured) {
    logger.error('Car catalogue call attempted while unconfigured', {
      provider: env.carCatalogProvider,
      endpoint: endpointName,
    });
    throw ApiError.serviceUnavailable('The car catalogue is not configured on the server.');
  }

  const retryAfter = endpointRetryGate.remaining(endpointName);
  if (retryAfter !== null) throw rateLimitedError(retryAfter);

  const startedAt = Date.now();

  let response;
  try {
    response = await fetch(requestUrl(endpointName, params), {
      method: 'GET',
      headers: requestHeaders(),
      signal: AbortSignal.timeout(env.carCatalogTimeoutMs),
    });
  } catch (error) {
    // Name, status and duration only: for providers that authenticate by query
    // parameter the URL carries the key, so it is never logged.
    logger.error('Car catalogue transport error', {
      endpoint: endpointName,
      durationMs: Date.now() - startedAt,
      reason: error?.name ?? 'unknown',
      causeCode: error?.cause?.code ?? null,
    });
    throw error?.name === 'TimeoutError' || error?.name === 'AbortError'
      ? ApiError.serviceUnavailable('The car catalogue is responding slowly. Please try again.')
      : ApiError.serviceUnavailable('Could not reach the car catalogue. Please try again.');
  }

  const text = await response.text();
  let payload = null;
  if (text.length > 0) {
    try {
      payload = JSON.parse(text);
    } catch {
      payload = null;
    }
  }

  if (!response.ok) {
    throw failureFromResponse(response, payload, endpointName);
  }

  logger.debug('Car catalogue request ok', {
    endpoint: endpointName,
    status: response.status,
    durationMs: Date.now() - startedAt,
  });

  return unwrapSuccess(payload);
}

/** True when a provider call can be made at all. */
export function isCatalogConfigured() {
  return env.isCarCatalogConfigured;
}

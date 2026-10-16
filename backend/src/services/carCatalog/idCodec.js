import { createHmac, timingSafeEqual } from 'node:crypto';

import { env } from '../../config/env.js';
import { ApiError } from '../../utils/apiError.js';

/**
 * Opaque identifiers for catalog items.
 *
 * Why ids are encoded rather than passed through:
 *  * `get_car_details` takes a **full upstream URL**, so a raw id would let a
 *    caller make our server fetch an arbitrary address (SSRF). Every decoded id
 *    is re-validated against a host allowlist.
 *  * The Flutter app must never learn provider-specific structures, and an
 *    opaque id is the cleanest expression of that.
 *  * The HMAC tag makes an id tamper-evident, so a crafted id cannot smuggle a
 *    different vehicle or host past the allowlist check.
 *
 * The signing key is derived from server-only configuration and never leaves
 * this process.
 */

/** Detail pages may only ever be fetched from these hosts. */
const ALLOWED_URL_SUFFIXES = ['.cardekho.com', 'cardekho.com'];

/** Provider slugs: lowercase, digits and hyphens (`tata`, `hyundai-creta`, `i20`). */
const SLUG_PATTERN = /^[a-z0-9][a-z0-9-]{0,63}$/;

const MAX_ID_LENGTH = 512;

function signingKey() {
  return `car-catalog-id:${env.carCatalogProvider}:${env.carCatalogScraperId}:${env.carCatalogApiKey}`;
}

function sign(body) {
  return createHmac('sha256', signingKey()).update(body).digest('base64url').slice(0, 22);
}

/** Ids are opaque to the client; a bad one is a client error, not a 500. */
function invalidId() {
  return ApiError.badRequest('That vehicle reference is not valid.');
}

/**
 * @param {{ kind: 'model', brand: string, model: string } | { kind: 'listing', url: string }} payload
 * @returns {string}
 */
export function encodeCarId(payload) {
  const compact =
    payload.kind === 'model'
      ? { k: 'n', b: payload.brand, m: payload.model }
      : { k: 'u', u: payload.url };

  const body = Buffer.from(JSON.stringify(compact), 'utf8').toString('base64url');
  return `${body}.${sign(body)}`;
}

/**
 * @param {string} id
 * @returns {{ kind: 'model', brand: string, model: string } | { kind: 'listing', url: string }}
 */
export function decodeCarId(id) {
  if (typeof id !== 'string' || id.length === 0 || id.length > MAX_ID_LENGTH) throw invalidId();

  const separator = id.lastIndexOf('.');
  if (separator <= 0) throw invalidId();

  const body = id.slice(0, separator);
  const tag = id.slice(separator + 1);

  const expected = Buffer.from(sign(body), 'utf8');
  const received = Buffer.from(tag, 'utf8');
  if (expected.length !== received.length) throw invalidId();
  if (!timingSafeEqual(expected, received)) throw invalidId();

  let decoded;
  try {
    decoded = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
  } catch {
    throw invalidId();
  }
  if (decoded === null || typeof decoded !== 'object') throw invalidId();

  if (decoded.k === 'n') {
    const brand = String(decoded.b ?? '');
    const model = String(decoded.m ?? '');
    // Re-validated after decode: the signature proves we minted it, the pattern
    // proves it can only ever address a provider slug.
    if (!SLUG_PATTERN.test(brand) || !SLUG_PATTERN.test(model)) throw invalidId();
    return { kind: 'model', brand, model };
  }

  if (decoded.k === 'u') {
    return { kind: 'listing', url: assertAllowedDetailUrl(String(decoded.u ?? '')) };
  }

  throw invalidId();
}

/**
 * Guards the one place a caller-influenced URL reaches an outbound request.
 * @param {string} value
 * @returns {string} The same URL, when it is a safe upstream detail page.
 */
export function assertAllowedDetailUrl(value) {
  let parsed;
  try {
    parsed = new URL(value);
  } catch {
    throw invalidId();
  }

  const host = parsed.hostname.toLowerCase();
  const hostAllowed = ALLOWED_URL_SUFFIXES.some(
    (suffix) => host === suffix.replace(/^\./, '') || host.endsWith(suffix),
  );

  if (parsed.protocol !== 'https:' || !hostAllowed) {
    throw ApiError.badRequest('That vehicle reference is not valid.');
  }

  return parsed.toString();
}

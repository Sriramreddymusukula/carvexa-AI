import { connectionState } from '../config/db.js';
import { ApiError } from '../utils/apiError.js';

/**
 * Guards every database-backed route.
 *
 * Without this, a request that arrives while the database is down sits in
 * Mongoose's command buffer for `bufferCommands`/server-selection timeouts and
 * then surfaces as an opaque 500. Rejecting immediately with 503 is both
 * faster for the caller and honest about the real cause.
 */
export function requireDatabase(_req, _res, next) {
  const state = connectionState();

  if (state === 'connected') return next();

  return next(
    ApiError.serviceUnavailable(
      state === 'not_configured'
        ? 'Database is not configured. Set MONGODB_URI in backend/.env and restart the server.'
        : `Database is not available (state: ${state}). The request was not processed.`,
    ),
  );
}

import { env } from '../config/env.js';
import { logger } from '../utils/logger.js';

/**
 * Metadata-only request log: method, path (query string stripped), status,
 * duration. Bodies, headers, cookies and query strings are never logged —
 * this API handles names, e-mails and phone numbers.
 */
export function requestLogger(req, res, next) {
  if (!env.httpRequestLogging) return next();

  const startedAt = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - startedAt) / 1e6;
    const path = req.originalUrl.split('?')[0];
    const level = res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info';
    logger[level](`${req.method} ${path} ${res.statusCode}`, {
      statusCode: res.statusCode,
      durationMs: Number(durationMs.toFixed(1)),
    });
  });

  next();
}

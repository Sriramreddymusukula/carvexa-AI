import rateLimit from 'express-rate-limit';

import { env } from '../config/env.js';

/**
 * Coarse abuse protection for the whole API. Deliberately windowed and
 * generous: it exists to stop runaway scripts and trivial floods, not to
 * throttle a real user. Authenticated features apply their own narrower
 * limits when a trustworthy identity is available to key on.
 */
export const apiLimiter = rateLimit({
  windowMs: env.rateLimitWindowMs,
  limit: env.rateLimitMax,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: { code: 'rate_limited', message: 'Too many requests, please retry shortly' } },
});

/** Health checks are cheap but must stay reachable while debugging. */
export const healthLimiter = rateLimit({
  windowMs: 60_000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: { code: 'rate_limited', message: 'Too many health checks, please retry shortly' } },
});

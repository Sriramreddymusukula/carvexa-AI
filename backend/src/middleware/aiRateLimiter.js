import rateLimit from 'express-rate-limit';

export const aiRateLimiter = rateLimit({
  windowMs: 15 * 60_000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: { code: 'rate_limited', message: 'Carvexa AI is receiving requests too quickly. Try again shortly.' } },
});

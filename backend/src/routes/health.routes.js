import { Router } from 'express';

import { healthHandler } from '../controllers/health.controller.js';
import { healthLimiter } from '../middleware/rateLimiter.js';

const router = Router();

// Liveness: proves the process is up, independent of the database, so a
// database outage never causes the API to look dead.
router.get('/live', (_req, res) => {
  res.json({ status: 'ok', service: 'flutter-car-backend' });
});

// Readiness: API + database.
router.get('/', healthLimiter, healthHandler);

export default router;

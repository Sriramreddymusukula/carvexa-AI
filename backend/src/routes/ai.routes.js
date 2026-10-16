import { Router } from 'express';

import { aiCapabilities, chat, recommendations } from '../controllers/ai.controller.js';
import { aiRateLimiter } from '../middleware/aiRateLimiter.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireDatabase } from '../middleware/requireDatabase.js';
import { validate } from '../middleware/validate.js';
import { chatSchema, recommendationsSchema } from '../validators/ai.validator.js';

const router = Router();

router.get('/capabilities', aiCapabilities);
router.post('/chat', aiRateLimiter, validate({ body: chatSchema }), requireDatabase, requireAuth, chat);
router.post(
  '/recommendations',
  aiRateLimiter,
  validate({ body: recommendationsSchema }),
  requireDatabase,
  requireAuth,
  recommendations,
);

export default router;

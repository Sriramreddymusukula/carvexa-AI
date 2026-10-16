import { Router } from 'express';

import { login, logout, register } from '../controllers/auth.controller.js';
import { authRateLimiter } from '../middleware/authRateLimiter.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireDatabase } from '../middleware/requireDatabase.js';
import { validate } from '../middleware/validate.js';
import { loginSchema, registerSchema } from '../validators/auth.validator.js';

const router = Router();

router.post('/register', authRateLimiter, validate({ body: registerSchema }), requireDatabase, register);
router.post('/login', authRateLimiter, validate({ body: loginSchema }), requireDatabase, login);
router.post('/logout', requireDatabase, requireAuth, logout);

export default router;

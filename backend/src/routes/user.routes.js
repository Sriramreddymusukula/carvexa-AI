import { Router } from 'express';

import { getUser, updateUser } from '../controllers/user.controller.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireDatabase } from '../middleware/requireDatabase.js';
import { validate } from '../middleware/validate.js';
import { profileUpdateSchema } from '../validators/auth.validator.js';

const router = Router();

router.get('/me', requireDatabase, requireAuth, getUser);
router.put('/me', validate({ body: profileUpdateSchema }), requireDatabase, requireAuth, updateUser);

export default router;

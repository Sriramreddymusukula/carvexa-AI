import { Router } from 'express';

import { getInterests, upsertInterests } from '../controllers/preference.controller.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireDatabase } from '../middleware/requireDatabase.js';
import { validate } from '../middleware/validate.js';
import { upsertPreferenceSchema } from '../validators/preference.validator.js';

const router = Router();

router.get('/', requireDatabase, requireAuth, getInterests);
router.put('/', validate({ body: upsertPreferenceSchema }), requireDatabase, requireAuth, upsertInterests);

export default router;

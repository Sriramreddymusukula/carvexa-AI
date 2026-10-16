import { Router } from 'express';

import { createLead } from '../controllers/lead.controller.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { requireDatabase } from '../middleware/requireDatabase.js';
import { validate } from '../middleware/validate.js';
import { createLeadSchema } from '../validators/lead.validator.js';

const router = Router();

router.post('/', validate({ body: createLeadSchema }), requireDatabase, requireAuth, createLead);

export default router;

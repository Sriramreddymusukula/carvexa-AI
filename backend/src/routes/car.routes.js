import { Router } from 'express';

import {
  capabilitiesHandler,
  carDetailHandler,
  listCarsHandler,
} from '../controllers/car.controller.js';
import { validate } from '../middleware/validate.js';
import { carIdParams, listCarsQuery } from '../validators/car.validator.js';

/**
 * The car catalogue.
 *
 * Deliberately *not* behind `requireDatabase`: the catalogue is served by an
 * external provider and our own database only holds user data. A database
 * outage must therefore not take browsing down with it.
 *
 * The API-wide rate limiter is applied in `routes/index.js`, so a catalogue
 * request is counted against the same budget as everything else.
 */
const router = Router();

router.get('/', validate({ query: listCarsQuery }), listCarsHandler);

// Before '/:id', otherwise 'capabilities' would be parsed as a catalogue id.
router.get('/capabilities', capabilitiesHandler);

router.get('/:id', validate({ params: carIdParams }), carDetailHandler);

export default router;

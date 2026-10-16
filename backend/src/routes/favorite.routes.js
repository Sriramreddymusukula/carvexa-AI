import { Router } from 'express';

import { createFavorite, deleteFavorite, listFavorites } from '../controllers/favorite.controller.js';
import { requireDatabase } from '../middleware/requireDatabase.js';
import { requireAuth } from '../middleware/requireAuth.js';
import { validate } from '../middleware/validate.js';
import {
  createFavoriteSchema,
  favoriteIdParamsSchema,
  listFavoritesSchema,
} from '../validators/favorite.validator.js';

const router = Router();

// Validate first, then require a live database connection.
router.post('/', validate({ body: createFavoriteSchema }), requireDatabase, requireAuth, createFavorite);
router.get('/', validate({ query: listFavoritesSchema }), requireDatabase, requireAuth, listFavorites);
router.delete('/:id', validate({ params: favoriteIdParamsSchema }), requireDatabase, requireAuth, deleteFavorite);

export default router;

import { z } from 'zod';

import { FAVORITE_SOURCES } from '../models/favorite.model.js';
import { objectId } from './common.js';

/** Mirrors the model's snapshot whitelist — keep both in sync. */
export const favoriteSnapshotSchema = z
  .object({
    title: z.string().trim().max(160).optional(),
    year: z.number().int().min(1900).max(2100).optional(),
    make: z.string().trim().max(60).optional(),
    model: z.string().trim().max(80).optional(),
    trim: z.string().trim().max(80).optional(),
    owner: z.string().trim().max(80).optional(),
    price: z.number().min(0).optional(),
    currency: z.string().trim().length(3, 'currency must be a 3-letter ISO code').transform((v) => v.toUpperCase()).optional(),
    bodyType: z.string().trim().max(40).optional(),
    fuelType: z.string().trim().max(40).optional(),
    transmission: z.string().trim().max(40).optional(),
    imageUrl: z.string().trim().url('imageUrl must be an absolute URL').max(500).optional(),
    formattedPrice: z.string().trim().max(100).optional(),
    mileage: z.number().min(0).optional(),
    location: z.string().trim().max(120).optional(),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, {
    message: 'snapshot must contain at least one field',
  })
  .optional();

export const createFavoriteSchema = z
  .object({
    externalCarId: z
      .string({ error: 'externalCarId is required' })
      .trim()
      .min(1, 'externalCarId must not be empty')
      .max(512, 'externalCarId must be at most 512 characters'),
    vehicleType: z.enum(['new', 'used']),
    source: z.enum(FAVORITE_SOURCES).default('external_catalog'),
    snapshot: favoriteSnapshotSchema,
  })
  .strict();

// `user` is mandatory: there is no "list everybody's favourites" operation.
export const listFavoritesSchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(100).default(25),
    page: z.coerce.number().int().min(1).max(10_000).default(1),
  })
  .strict();

export const favoriteIdParamsSchema = z.object({ id: objectId }).strict();

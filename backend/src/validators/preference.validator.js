import { z } from 'zod';

import { TRANSMISSION_FILTERS } from '../models/preference.model.js';

const filterList = z.array(z.string().trim().min(1).max(60)).max(25).default([]);

export const upsertPreferenceSchema = z
  .object({
    budget: z
      .object({
        min: z.number().min(0).optional(),
        max: z.number().min(0).optional(),
        currency: z.string().trim().length(3).transform((v) => v.toUpperCase()).optional(),
      })
      .strict()
      .refine((value) => value.min === undefined || value.max === undefined || value.max >= value.min, {
        message: 'budget.max must be greater than or equal to budget.min',
        path: ['max'],
      })
      .optional(),
    bodyTypes: filterList,
    fuelTypes: filterList,
    transmission: z.enum(TRANSMISSION_FILTERS).default('any'),
    makes: filterList,
    notes: z.string().trim().max(1000).optional(),
  })
  .strict();


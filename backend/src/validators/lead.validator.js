import { z } from 'zod';

export const createLeadSchema = z
  .object({
    externalCarId: z.string().trim().min(1).max(512),
    contactConsent: z.literal(true),
    note: z.string().trim().max(500).optional(),
  })
  .strict();

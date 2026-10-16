import { z } from 'zod';

export const chatSchema = z
  .object({
    messages: z
      .array(
        z
          .object({ role: z.enum(['user', 'model']), text: z.string().trim().min(1).max(2000) })
          .strict(),
      )
      .min(1)
      .max(16),
    vehicleIds: z.array(z.string().trim().min(1).max(512)).max(3).default([]),
  })
  .strict();

export const recommendationsSchema = z.object({}).strict();

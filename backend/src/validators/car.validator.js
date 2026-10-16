import { z } from 'zod';

/**
 * Provider slugs: lowercase, digits and hyphens (`tata`, `new-delhi`, `i20`).
 * Validated at the edge so a malformed slug never reaches a provider call.
 */
const catalogSlug = z
  .string()
  .trim()
  .toLowerCase()
  .regex(/^[a-z0-9][a-z0-9-]{0,63}$/, 'must be a lowercase slug such as "tata" or "new-delhi"');

/**
 * Query contract for `GET /api/cars`.
 *
 * Strict on purpose: an unknown filter is a client bug, and answering it with a
 * silently ignored parameter is how a UI ends up offering a filter that does
 * nothing. `q` is capped so a pathological query cannot be forwarded upstream.
 */
export const listCarsQuery = z
  .object({
    source: z.enum(['used', 'new']).optional(),
    city: z.literal('hyderabad').optional(),
    brand: catalogSlug.optional(),
    q: z.string().trim().max(80).optional(),
    page: z.coerce.number().int().min(1).max(200).optional(),
  })
  .strict();

/**
 * Catalogue ids are opaque, signed strings minted by us, so the only thing worth
 * checking here is that one was supplied at a sane length. `idCodec` performs
 * the real validation, because only it can verify the signature.
 */
export const carIdParams = z
  .object({
    id: z.string().trim().min(1).max(512),
  })
  .strict();

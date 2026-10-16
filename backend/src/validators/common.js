import { z } from 'zod';

/** 24-char hex Mongo ObjectId, validated at the edge so bad ids never reach a query. */
export const objectId = z
  .string({ error: 'id must be a string' })
  .trim()
  .regex(/^[a-f\d]{24}$/i, 'must be a valid 24-character identifier');

/** Optional trimmed string limited to a safe query length. */
export const searchParam = z.string().trim().max(120).optional();

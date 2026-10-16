import { ApiError } from '../utils/apiError.js';

/**
 * Exposes req.valid — the validated, sanitised view of the request. Handlers
 * read ONLY from req.valid so they can never act on unvalidated input.
 */
function toIssues(error, where) {
  return error.issues.flatMap((issue) => {
    // Zod reports every unrecognised key of a strict object as ONE issue
    // with an empty path, so expand it to give each field its own error.
    if (issue.code === 'unrecognized_keys') {
      return issue.keys.map((key) => ({
        field: [where, key].join('.'),
        message: 'is not an accepted field',
      }));
    }
    return [{ field: [where, ...issue.path].join('.'), message: issue.message }];
  });
}

/**
 * @param {{ body?: import('zod').ZodTypeAny, query?: import('zod').ZodTypeAny, params?: import('zod').ZodTypeAny }} schemas
 * @returns {(req: any, res: any, next: any) => void}
 */
export function validate(schemas) {
  return (req, res, next) => {
    const details = [];
    const valid = {};

    for (const where of ['params', 'query', 'body']) {
      const schema = schemas[where];
      if (!schema) continue;

      const result = schema.safeParse(req[where] ?? {});
      if (result.success) valid[where] = result.data;
      else details.push(...toIssues(result.error, where));
    }

    if (details.length > 0) {
      return next(ApiError.badRequest('Request validation failed', details));
    }

    req.valid = valid;
    return next();
  };
}


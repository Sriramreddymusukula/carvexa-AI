import { env } from '../config/env.js';
import { logger } from '../utils/logger.js';
import { ApiError } from '../utils/apiError.js';
import { safeMessage } from '../utils/secrets.js';

/** 404 for unknown paths. Keeps the payload shape identical to other errors. */
export function notFoundHandler(req, res) {
  res.status(404).json({
    error: { code: 'not_found', message: `Route ${req.method} ${req.originalUrl} is not served` },
  });
}

/** Mongoose ValidationError -> 400 details list. */
function fromValidationError(error) {
  const details = Object.values(error.errors ?? {}).map((item) => ({
    field: item.path,
    message: item.message,
  }));
  return { statusCode: 400, code: 'validation_failed', message: 'Data validation failed', details };
}

/** MongoDB duplicate-key / index errors -> 409. */
function fromMongoError(error) {
  if (error.code === 11000) {
    const field = Object.keys(error.keyPattern ?? { value: 1 })[0];
    return {
      statusCode: 409,
      code: 'duplicate_value',
      message: `A record with this ${field} already exists`,
      details: [{ field, message: 'must be unique' }],
    };
  }
  if (error.name === 'CastError') {
    return {
      statusCode: 400,
      code: 'invalid_identifier',
      message: `Invalid value for ${error.path ?? 'identifier'}`,
    };
  }
  if (error.name === 'MongoServerError' && /index/i.test(error.message ?? '')) {
    logger.error('Index creation failed on the server', { error: safeMessage(error) });
    return {
      statusCode: 503,
      code: 'database_error',
      message: 'The database rejected an index operation',
    };
  }
  return null;
}

/**
 * Central error handler. It is the only place that decides what a client may
 * see: known/expected failures get a specific message, everything else is a
 * generic 500 so driver internals, paths and credentials never leak.
 */
export function errorHandler(error, req, res, next) {
  if (res.headersSent) return next(error);

  let statusCode = 500;
  let code = 'internal_error';
  let message = 'Internal server error';
  let details;

  if (error instanceof ApiError) {
    statusCode = error.statusCode;
    code = error.code;
    message = error.message;
    details = error.details;
  } else if (error?.name === 'ValidationError' && error.errors) {
    ({ statusCode, code, message, details } = fromValidationError(error));
  } else if (error?.name === 'CastError' || error?.code === 11000 || error?.name === 'MongoServerError') {
    const mapped = fromMongoError(error);
    if (mapped) ({ statusCode, code, message, details } = mapped);
  } else if (error?.type === 'entity.parse.failed') {
    statusCode = 400;
    code = 'invalid_json';
    message = 'Request body is not valid JSON';
  } else if (error?.type === 'entity.too.large') {
    statusCode = 413;
    code = 'payload_too_large';
    message = 'Request body is too large';
  }

  const logPayload = {
    method: req.method,
    path: req.originalUrl.split('?')[0],
    statusCode,
    code,
    error: safeMessage(error),
  };
  if (statusCode >= 500) logger.error('Request failed', logPayload);
  else logger.warn('Request rejected', logPayload);

  res.status(statusCode).json({
    error: {
      code,
      message: env.isProduction && statusCode >= 500 ? 'Internal server error' : message,
      ...(details ? { details } : {}),
    },
  });
}

/**
 * Operational error carrying an HTTP status code. Anything thrown that is not
 * an ApiError is treated as a bug and reported as a generic 500.
 */
export class ApiError extends Error {
  /**
   * @param {number} statusCode
   * @param {string} message Client-safe message. Never include credentials.
   * @param {{ details?: unknown, code?: string }} [options]
   */
  constructor(statusCode, message, { details, code } = {}) {
    super(message);
    this.name = 'ApiError';
    this.statusCode = statusCode;
    this.code = code ?? 'request_failed';
    if (details !== undefined) this.details = details;
    Error.captureStackTrace?.(this, ApiError);
  }

  static badRequest(message, details) {
    return new ApiError(400, message, { details, code: 'bad_request' });
  }

  static notFound(message = 'Resource not found') {
    return new ApiError(404, message, { code: 'not_found' });
  }

  static conflict(message, details) {
    return new ApiError(409, message, { details, code: 'conflict' });
  }

  static unauthorized(message = 'Sign in to continue') {
    return new ApiError(401, message, { code: 'unauthorized' });
  }

  static serviceUnavailable(message) {
    return new ApiError(503, message, { code: 'service_unavailable' });
  }
}

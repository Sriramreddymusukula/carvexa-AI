import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

import { isAllowedOrigin } from './config/env.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { requestLogger } from './middleware/requestLogger.js';
import apiRoutes from './routes/index.js';

const API_PREFIX = '/api';

/**
 * Builds the Express application. Kept separate from server.js so tests can
 * mount the app without binding a port or opening a database connection.
 *
 * @returns {import('express').Express}
 */
export function createApp() {
  const app = express();

  // Required for correct req.ip (and therefore correct rate-limit keys) behind
  // a proxy or tunnel, and required by Node 22 Express 5 anyway.
  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  app.use(
    helmet({
      // A JSON API has no HTML documents, so the CSP/page-oriented defaults
      // add noise; the headers below still apply.
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    }),
  );

  app.use(
    cors({
      origin(origin, callback) {
        if (isAllowedOrigin(origin)) return callback(null, true);
        return callback(null, false); // no CORS headers -> browser blocks it
      },
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Accept', 'Authorization'],
      maxAge: 600,
    }),
  );

  // Small limit: this API only accepts small JSON documents.
  app.use(express.json({ limit: '100kb' }));
  app.use(express.urlencoded({ extended: false, limit: '100kb' }));

  app.use(requestLogger);

  app.use(API_PREFIX, apiRoutes);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

export { API_PREFIX };
export default createApp;

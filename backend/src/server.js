import process from 'node:process';

import { createApp } from './app.js';
import { connectDatabase, disconnectDatabase, ensureIndexes } from './config/db.js';
import { env } from './config/env.js';
import { startBackendDiscovery } from './services/backendDiscovery.js';
import { logger } from './utils/logger.js';
import { safeMessage } from './utils/secrets.js';

const app = createApp();
const server = app.listen(env.port, '0.0.0.0', () => {
  logger.info('API listening', { port: env.port, environment: env.nodeEnv });
  process.stdout.write(`API ready on 0.0.0.0:${env.port}/api\n`);
});

const discoveryServer = startBackendDiscovery({ apiPort: env.port });
discoveryServer.on('listening', () => {
  logger.info('LAN discovery listening', { port: discoveryServer.address().port });
});
discoveryServer.on('error', (error) => {
  logger.warn('LAN discovery unavailable', { error: safeMessage(error) });
});

server.on('error', (error) => {
  if (error.code === 'EADDRINUSE') {
    logger.error(`Port ${env.port} is already in use. Set PORT in backend/.env and retry.`);
  } else {
    logger.error('HTTP server error', { error: safeMessage(error) });
  }
  process.exitCode = 1;
});

/**
 * Database boot sequence.
 *
 * The HTTP server starts first so /api/health can report "database
 * unavailable" while Atlas is still unreachable. In production, a failed
 * connection is fatal — a half-working API is worse than no API.
 */
async function bootstrap() {
  try {
    await connectDatabase();
    await ensureIndexes();
  } catch (error) {
    logger.error('Startup aborted: database unavailable', { error: safeMessage(error) });
    if (env.isProduction) {
      server.close(() => process.exit(1));
      return;
    }
    logger.warn('Continuing without a database connection (development). /api/health will report 503.');
  }
}

bootstrap();

let shuttingDown = false;
async function shutdown(signal) {
  if (shuttingDown) return;
  shuttingDown = true;
  logger.info('Shutting down', { signal });
  discoveryServer.close();

  const forced = setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10_000);
  forced.unref();

  server.close(async () => {
    try {
      await disconnectDatabase();
      logger.info('Shutdown complete');
      process.exit(0);
    } catch (error) {
      logger.error('Error during shutdown', { error: safeMessage(error) });
      process.exit(1);
    }
  });
}

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => shutdown(signal));
}

// Last-resort handlers: log the reason, then exit so a supervisor restarts us
// from a clean state instead of running in undefined behaviour.
process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled promise rejection', { error: safeMessage(reason) });
  process.exitCode = 1;
  shutdown('unhandledRejection');
});

process.on('uncaughtException', (error) => {
  logger.error('Uncaught exception', { error: safeMessage(error) });
  process.exit(1);
});





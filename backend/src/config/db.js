import mongoose from 'mongoose';

import { env } from './env.js';
import { models } from '../models/index.js';
import { logger } from '../utils/logger.js';
import { redactSecrets, safeMessage } from '../utils/secrets.js';
import { reconcileIndexes } from '../utils/indexReconciler.js';

mongoose.set('strictQuery', true);

let wired = false;
let connecting = null;
let indexesReady = false;

const READY_STATES = {
  0: 'disconnected',
  1: 'connected',
  2: 'connecting',
  3: 'disconnecting',
};

/** Connection events are wired once; logs never contain the connection string. */
function wireConnectionEvents() {
  if (wired) return;
  wired = true;

  const conn = mongoose.connection;
  conn.on('connected', () => logger.info('MongoDB connection established', { db: conn.name }));
  conn.on('disconnected', () => logger.warn('MongoDB connection lost'));
  conn.on('reconnected', () => logger.info('MongoDB reconnected'));
  conn.on('error', (error) => logger.error('MongoDB connection error', { error: safeMessage(error) }));
}

/**
 * @returns {'connected'|'connecting'|'disconnecting'|'disconnected'|'not_configured'}
 */
export function connectionState() {
  if (!env.mongoUri) return 'not_configured';
  if (mongoose.connection.readyState === 1 && !indexesReady) return 'connecting';
  return READY_STATES[mongoose.connection.readyState] ?? 'disconnected';
}

/**
 * Create or verify every application index before data routes become ready.
 * Mongoose autoIndex is disabled, so the server and DB check call this
 * explicitly after connecting. Indexes are additive; this never drops data.
 */
export async function ensureIndexes() {
  if (mongoose.connection.readyState !== 1) {
    throw new Error('MongoDB must be connected before application indexes are ensured.');
  }
  if (indexesReady) return;

  try {
    for (const model of Object.values(models)) {
      await reconcileIndexes(model.collection, model.schema.indexes());
    }
    indexesReady = true;
  } catch (error) {
    await mongoose.disconnect().catch(() => {});
    indexesReady = false;
    throw new Error(`MongoDB application indexes could not be initialized (${safeMessage(error)}).`);
  }
}

/**
 * Open the MongoDB Atlas connection.
 *
 * Failures are never swallowed: connectDatabase() rejects, server.js exits the
 * process, and scripts/check-db.js prints the diagnosis.
 *
 * @param {object} [options]
 * @param {boolean} [options.exitOnFailure] production only: exit(1) instead of rejecting
 * @returns {Promise<import('mongoose').Connection>}
 */
export async function connectDatabase({ exitOnFailure = false } = {}) {
  if (!env.mongoUri) {
    const message =
      'MONGODB_URI is not set. Copy backend/.env.example to backend/.env and add your ' +
      'MongoDB Atlas connection string.';
    logger.error(message);
    if (exitOnFailure) process.exitCode = 1;
    throw new Error(message);
  }

  wireConnectionEvents();

  if (mongoose.connection.readyState === 1) return mongoose.connection;
  if (connecting) return connecting;

  const options = {
    serverSelectionTimeoutMS: env.dbServerSelectionTimeoutMs,
    maxPoolSize: 10,
    // Never queue work while the connection is down: a request that cannot be
    // served should fail immediately, not hang until a timeout.
    bufferCommands: false,
    // All environments use the additive reconciler below; Mongoose's automatic
    // build would race it and can recreate the legacy email_1 name conflict.
    autoIndex: false,
  };
  if (env.mongoDbName) options.dbName = env.mongoDbName;

  logger.info('Connecting to MongoDB Atlas', {
    database: env.mongoDbName || '(from MONGODB_URI)',
    timeoutMs: env.dbServerSelectionTimeoutMs,
  });

  connecting = mongoose
    .connect(env.mongoUri, options)
    .then((conn) => {
      connecting = null;
      return conn;
    })
    .catch((error) => {
      connecting = null;
      throw new Error(
        `MongoDB Atlas connection failed (${redactSecrets(safeMessage(error))}). ` +
          'Check that the URI is correct, the current IP is allowed in Atlas Network Access, ' +
          'the database user exists, and the cluster is not paused.',
      );
    });

  return connecting;
}

/** Graceful shutdown helper. */
export async function disconnectDatabase() {
  await mongoose.disconnect();
  indexesReady = false;
}

/**
 * Round-trip latency measurement used by /api/health.
 * @returns {Promise<number>}
 */
export async function measurePingMs() {
  const startedAt = process.hrtime.bigint();
  await mongoose.connection.db.admin().command({ ping: 1 });
  return Number(process.hrtime.bigint() - startedAt) / 1e6;
}

/**
 * Collection names currently present in the target database.
 * @returns {Promise<string[]>}
 */
export async function listCollections() {
  const collections = await mongoose.connection.db.listCollections({}, { nameOnly: true }).toArray();
  return collections.map((collection) => collection.name).sort();
}

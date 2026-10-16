import mongoose from 'mongoose';

import { connectionState, listCollections, measurePingMs } from '../config/db.js';
import { ownedCollections } from '../models/index.js';
import { env } from '../config/env.js';
import { safeMessage } from '../utils/secrets.js';

/**
 * Database state for the health endpoint.
 *
 * Only non-sensitive facts are reported: state, database name, latency and the
 * presence of the owned collections. The connection string, credentials and
 * Atlas host are never included; raw driver errors are redacted.
 *
 * @returns {Promise<Record<string, unknown>>}
 */
export async function getDatabaseHealth() {
  const state = connectionState();

  if (state !== 'connected') {
    return {
      status: state === 'not_configured' ? 'not_configured' : 'unavailable',
      readyState: mongoose.connection.readyState,
      name: env.mongoDbName || null,
      collections: [],
      checkedAt: new Date().toISOString(),
    };
  }

  try {
    const [latencyMs, collections] = await Promise.all([measurePingMs(), listCollections()]);
    const missing = ownedCollections.filter((name) => !collections.includes(name));

    return {
      status: 'connected',
      readyState: mongoose.connection.readyState,
      name: mongoose.connection.name,
      pingMs: Number(latencyMs.toFixed(1)),
      collections,
      // Empty once each model has been written to at least once; Mongoose only
      // creates a collection on first write.
      missingOwnedCollections: missing,
      checkedAt: new Date().toISOString(),
    };
  } catch (error) {
    return {
      status: 'error',
      readyState: mongoose.connection.readyState,
      name: env.mongoDbName || mongoose.connection.name || null,
      collections: [],
      error: safeMessage(error),
      checkedAt: new Date().toISOString(),
    };
  }
}

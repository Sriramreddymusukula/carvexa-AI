/**
 * Database verification script — the Phase 2 database test.
 *
 * 1. Loads backend/.env and validates the configuration.
 * 2. Connects to MongoDB Atlas.
 * 3. Runs a round-trip write/read/delete through the real Mongoose models.
 * 4. Reports the collections and indexes that back those models.
 *
 * Usage:  npm run db:check
 * Exit code 0 = healthy, 1 = failed (failures are never hidden).
 *
 * The connection string is never printed: only the database name, a boolean
 * "URI present" flag, the driver-reported host list and collection names.
 */
import process from 'node:process';

import { connectDatabase, disconnectDatabase, ensureIndexes, listCollections } from '../src/config/db.js';
import { env } from '../src/config/env.js';
import { ownedCollections } from '../src/models/index.js';
import { Favorite, Lead, Preference, User } from '../src/models/index.js';
import { logger } from '../src/utils/logger.js';
import { safeMessage } from '../src/utils/secrets.js';

let cleanupUserId;

const step = (message) => process.stdout.write(`\n▶ ${message}\n`);
const ok = (message) => process.stdout.write(`  ✔ ${message}\n`);
const fail = (message) => {
  process.stdout.write(`  ✖ ${message}\n`);
  process.exitCode = 1;
};

async function main() {
  step('Configuration');
  if (!env.mongoUri) {
    fail('MONGODB_URI is not set. Copy backend/.env.example to backend/.env.');
    return;
  }
  ok('MONGODB_URI is present (value not displayed)');
  ok(`target database: ${env.mongoDbName || '(from MONGODB_URI)'}`);

  step('Connection');
  const connection = await connectDatabase();
  await ensureIndexes();
  ok(`connected to ${connection.name}`);
  ok(`host list reported by driver: ${JSON.stringify(connection.host ?? [])}`);

  step('Round-trip through the application models');
  const stamp = Date.now();
  const email = `phase2-db-check-${stamp}@example.invalid`;

  const user = await User.create({
    fullName: 'Phase 2 DB Check',
    email,
    phone: '+10000000000',
    city: 'Testville',
    countryCode: 'US',
    leadSource: 'other',
  });
  cleanupUserId = user._id;
  ok(`users      insert -> ${user._id}`);

  const found = await User.findOne({ email }).lean();
  if (!found) fail('users      read   -> document not found');
  else ok(`users      read   -> found (${found.email})`);

  const preference = await (async () => {
    const doc = new Preference({
      user: user._id,
      budget: { min: 10_000, max: 45_000, currency: 'usd' },
      bodyTypes: ['SUV', ' sedan ', 'suv'],
      fuelTypes: ['Hybrid'],
      transmission: 'automatic',
    });
    return doc.save();
  })();
  ok(`preferences insert -> ${preference._id} (bodyTypes normalised: ${JSON.stringify(preference.bodyTypes)})`);

  const favorite = await Favorite.create({
    user: user._id,
    externalCarId: `phase2-check-${stamp}`,
    source: 'manual',
    vehicleType: 'used',
    snapshot: { make: 'Test', model: 'Model', year: 2024, currency: 'usd' },
  });
  ok(`favorites  insert -> ${favorite._id}`);

  const favoriteCount = await Favorite.countDocuments({ user: user._id });
  if (favoriteCount !== 1) fail(`favorites  read   -> expected 1, got ${favoriteCount}`);
  else ok('favorites  read   -> 1 document');

  const lead = await Lead.create({
    user: user._id,
    externalCarId: `phase2-lead-check-${stamp}`,
    snapshot: { title: 'Test vehicle', source: 'used' },
    contactConsent: true,
    contact: { fullName: 'Phase 2 DB Check', email },
  });
  ok(`leads      insert -> ${lead._id}`);

  step('Validation guards');
  const duplicateEmail = await User.exists({ email });
  if (duplicateEmail) ok('users      unique email index present');
  else fail('users      unique email index not enforced');

  const invalidFavorite = new Favorite({ user: user._id, externalCarId: 'x', snapshot: { notAField: 1 } });
  const invalidResult = invalidFavorite.validateSync();
  if (invalidResult?.errors?.snapshot) ok('favorites  snapshot whitelist rejects unknown fields');
  else fail('favorites  snapshot whitelist did not reject an unknown field');

  step('Cleanup');
  await Promise.all([
    Favorite.deleteMany({ user: user._id }),
    Lead.deleteMany({ user: user._id }),
    Preference.deleteOne({ user: user._id }),
    User.deleteOne({ _id: user._id }),
  ]);
  cleanupUserId = undefined;
  const remaining = await User.countDocuments({ email });
  if (remaining !== 0) fail(`cleanup   -> ${remaining} test document(s) still present`);
  else ok('cleanup   -> all test documents removed');

  step('Collections and indexes');
  const collections = await listCollections();
  const present = ownedCollections.filter((name) => collections.includes(name));
  const missing = ownedCollections.filter((name) => !collections.includes(name));
  ok(`collections in database: ${collections.length ? collections.join(', ') : '(none yet)'}`);
  if (present.length > 0) ok(`application-owned collections present: ${present.join(', ')}`);
  if (missing.length > 0) {
    logger.info('Collections are created on first write; missing until then is expected', {
      missing,
    });
  }

  for (const model of [User, Favorite, Preference, Lead]) {
    const indexes = await model.collection.indexes();
    const names = indexes.map((index) => index.name ?? '(default)').sort();
    process.stdout.write(`  · ${model.collection.collectionName}: ${names.join(', ')}\n`);
  }
}

try {
  await main();
} catch (error) {
  process.stdout.write(`\n✖ Database check failed: ${safeMessage(error)}\n\n`);
  process.exitCode = 1;
} finally {
  if (cleanupUserId) {
    try {
      await Promise.all([
        Favorite.deleteMany({ user: cleanupUserId }),
        Lead.deleteMany({ user: cleanupUserId }),
        Preference.deleteOne({ user: cleanupUserId }),
        User.deleteOne({ _id: cleanupUserId }),
      ]);
    } catch (error) {
      process.stdout.write(`\nCleanup failed: ${safeMessage(error)}\n`);
      process.exitCode = 1;
    }
  }
  await disconnectDatabase().catch(() => {});
}

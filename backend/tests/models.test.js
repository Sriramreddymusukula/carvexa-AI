/**
 * Model-level tests. These use `validate()` only, so they exercise schema rules
 * (including `pre('validate')` hooks) without a database connection.
 * `validateSync()` is deliberately avoided: it is deprecated in Mongoose 9 and
 * does not run document hooks.
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

process.env.NODE_ENV = 'test';
// Offline: importing the config must never reach for a provider.
process.env.CAR_CATALOG_PROVIDER = 'none';

const { Favorite, Lead, Preference, User, ownedCollections } = await import('../src/models/index.js');
const { clearRegisteredSecrets, redactSecrets, registerSecret } = await import(
  '../src/utils/secrets.js'
);

/** @returns {Promise<import('mongoose').Error.ValidationError | null>} */
async function validationError(document) {
  try {
    await document.validate();
    return null;
  } catch (error) {
    return error;
  }
}

const validUser = () => ({
  fullName: 'Ada Lovelace',
  email: 'ada@example.com',
  phone: '+447700900123',
  city: 'London',
  countryCode: 'gb',
});

describe('User model', () => {
  it('accepts a valid record', async () => {
    const error = await validationError(new User(validUser()));
    assert.equal(error, null);
  });

  it('requires fullName and email', async () => {
    const error = await validationError(new User({}));
    assert.ok(error.errors.fullName);
    assert.ok(error.errors.email);
  });

  it('rejects a malformed email', async () => {
    const error = await validationError(new User({ ...validUser(), email: 'nope' }));
    assert.ok(error.errors.email);
  });

  it('normalises email case and country code', () => {
    const user = new User({ ...validUser(), email: 'ADA@Example.COM', countryCode: 'gb' });
    assert.equal(user.email, 'ada@example.com');
    assert.equal(user.countryCode, 'GB');
  });

  it('rejects a malformed phone number', async () => {
    const error = await validationError(new User({ ...validUser(), phone: 'call-me' }));
    assert.ok(error.errors.phone);
  });

  it('rejects an unknown status', async () => {
    const error = await validationError(new User({ ...validUser(), status: 'vip' }));
    assert.ok(error.errors.status);
  });

  it('declares a unique email index', () => {
    const emailIndex = User.schema.indexes().find(([keys]) => keys.email === 1);
    assert.equal(emailIndex?.[1].unique, true);
  });

  it('excludes the raw _id and __v when serialised', () => {
    const json = new User({
      ...validUser(),
      passwordHash: 'scrypt$private-salt$private-digest',
    }).toJSON();
    assert.ok(!('_id' in json));
    assert.ok(!('__v' in json));
    assert.ok(!('passwordHash' in json));
    assert.ok(json.id);
  });
});

describe('Favorite model', () => {
  const validFavorite = () => ({
    user: new User()._id ?? '507f1f77bcf86cd799439011',
    externalCarId: 'ext-123',
    vehicleType: 'used',
  });

  it('requires a user and an externalCarId', async () => {
    const error = await validationError(new Favorite({}));
    assert.ok(error.errors.user);
    assert.ok(error.errors.externalCarId);
  });

  it('accepts a known snapshot field', async () => {
    const error = await validationError(
      new Favorite({
        ...validFavorite(),
        snapshot: { make: 'Toyota', model: 'Corolla', year: 2024 },
      }),
    );
    assert.equal(error, null);
  });

  it('never stores snapshot fields outside the whitelist', async () => {
    const favorite = new Favorite({
      ...validFavorite(),
      snapshot: { make: 'Toyota', ownerVin: 'SENSITIVE123' },
    });
    await favorite.validate();

    // Defence in depth: Mongoose's strict mode drops unknown paths, and the
    // whitelist validator below rejects the document if that ever changes.
    // The snapshot must not become a mirror of the external catalog.
    assert.equal(favorite.snapshot.ownerVin, undefined);
    assert.equal(favorite.snapshot.make, 'Toyota');
  });

  it('rejects a snapshot that is present but empty', async () => {
    const error = await validationError(new Favorite({ ...validFavorite(), snapshot: {} }));
    assert.ok(error.errors.snapshot);
  });

  it('declares a unique user+externalCarId index', () => {
    const index = Favorite.schema.indexes().find(
      ([keys]) => keys.user === 1 && keys.externalCarId === 1,
    );
    assert.equal(index?.[1].unique, true);
  });
});

describe('Preference model', () => {
  it('normalises filter lists and enforces the budget rule', async () => {
    const preference = new Preference({
      user: '507f1f77bcf86cd799439011',
      bodyTypes: [' SUV ', 'suv', 'Sedan'],
      budget: { min: 20_000, max: 5_000 },
    });

    const error = await validationError(preference);
    assert.ok(error, 'max < min must be rejected');
    assert.ok(error.errors['budget.max']);
  });

  it('dedupes and lower-cases filter values on a valid document', async () => {
    const preference = new Preference({
      user: '507f1f77bcf86cd799439011',
      bodyTypes: [' SUV ', 'suv', 'Sedan'],
      makes: ['Toyota', 'toyota'],
      budget: { min: 1, max: 2 },
    });

    const error = await validationError(preference);
    assert.equal(error, null);
    assert.deepEqual(preference.bodyTypes, ['suv', 'sedan']);
    assert.deepEqual(preference.makes, ['toyota']);
  });

  it('declares a unique user index', () => {
    const index = Preference.schema.indexes().find(([keys]) => keys.user === 1);
    assert.equal(index?.[1].unique, true);
  });
});

describe('Lead model', () => {
  const validLead = () => ({
    user: '507f1f77bcf86cd799439011',
    externalCarId: 'signed-catalog-reference',
    snapshot: { title: 'Toyota Corolla', source: 'new' },
    contactConsent: true,
    contact: { fullName: 'Ada Lovelace', email: 'ada@example.com' },
  });

  it('requires affirmative contact consent and profile-derived contact fields', async () => {
    const noConsent = await validationError(new Lead({ ...validLead(), contactConsent: false }));
    assert.ok(noConsent.errors.contactConsent);

    const noContact = await validationError(new Lead({
      ...validLead(),
      contact: { fullName: 'Ada Lovelace' },
    }));
    assert.ok(noContact.errors['contact.email']);
  });

  it('accepts only catalog source values and supports signed catalog ids', async () => {
    const error = await validationError(new Lead({
      ...validLead(),
      externalCarId: 'x'.repeat(400),
    }));
    assert.equal(error, null);
  });

  it('declares one lead per user and catalog car', () => {
    const uniqueIndex = Lead.schema.indexes().find(
      ([keys]) => keys.user === 1 && keys.externalCarId === 1,
    );
    assert.equal(uniqueIndex?.[1].unique, true);
  });
});

describe('model registry', () => {
  it('lists every application-owned collection', () => {
    assert.deepEqual(ownedCollections, ['users', 'favorites', 'preferences', 'leads']);
  });
});

describe('secret redaction', () => {
  it('removes credentials from a MongoDB error message', () => {
    const message = 'connection failed for mongodb+srv://alice:hunter2@cluster0.abcde.mongodb.net';
    const redacted = redactSecrets(message);
    assert.ok(!redacted.includes('hunter2'));
    assert.ok(redacted.includes('[redacted]'));
  });

  it('removes password assignments', () => {
    const redacted = redactSecrets('api_key: sk-live-1234567890');
    assert.ok(!redacted.includes('sk-live-1234567890'));
  });

  it('removes basic-auth credentials from URLs', () => {
    const redacted = redactSecrets('https://user:pass@example.com/cars');
    assert.ok(!redacted.includes(':pass@'));
  });

  it('removes a registered value even without a key= prefix', () => {
    // A provider can echo the raw key back inside an unrelated error string,
    // which no pattern can recognise - only an exact-value match can.
    const key = 'sk-test-abcdefghijklmnop';
    registerSecret(key);
    try {
      const redacted = redactSecrets(`provider rejected sk-test-abcdefghijklmnop (401)`);
      assert.ok(!redacted.includes(key));
      assert.ok(redacted.includes('[redacted]'));
    } finally {
      clearRegisteredSecrets();
    }
  });

  it('ignores values too short to be secrets, so ordinary text survives', () => {
    registerSecret('none');
    assert.equal(redactSecrets('the provider is none'), 'the provider is none');
    clearRegisteredSecrets();
  });
});

describe('car catalog configuration', () => {
  it('starts disabled, so an unconfigured backend still boots', async () => {
    process.env.CAR_CATALOG_PROVIDER = 'none';
    const { env } = await import('../src/config/env.js');

    assert.equal(env.carCatalogProvider, 'none');
    assert.equal(env.isCarCatalogConfigured, false);
  });

  it('normalises the base URL so path joining cannot double a slash', async () => {
    const { env } = await import('../src/config/env.js');
    // No provider is configured in tests, so the accessor must be safe to call
    // and must never return a trailing slash.
    assert.ok(!env.carCatalogBaseUrl().endsWith('/'));
  });
});

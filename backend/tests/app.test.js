/**
 * HTTP-layer tests that need no database connection.
 *
 * Run with: npm test
 */
import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';

// Must be set before src/config/env.js is imported. dotenv does not override
// variables that already exist, so these win over backend/.env.
process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'error';
process.env.HTTP_REQUEST_LOGGING = 'false';
process.env.MONGODB_URI = '';
// Force the catalogue off so the suite is fully offline: it must never spend a
// provider credit, and its assertions must not depend on live upstream data.
process.env.CAR_CATALOG_PROVIDER = 'none';

const { createApp } = await import('../src/app.js');

let baseUrl;
let server;

before(async () => {
  server = createApp().listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
});

const get = (path, init) => fetch(`${baseUrl}${path}`, init);
const postJson = (path, body) =>
  get(path, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(body),
  });

describe('GET /api/health/live', () => {
  it('reports the service is up without touching the database', async () => {
    const response = await get('/api/health/live');
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.status, 'ok');
  });
});

describe('GET /api/health', () => {
  it('fails loudly with 503 when the database is not configured', async () => {
    const response = await get('/api/health');
    assert.equal(response.status, 503, 'an unusable backend must not answer 200');
    const body = await response.json();
    assert.equal(body.status, 'degraded');
    assert.equal(body.database.status, 'not_configured');
  });

  it('never exposes a connection string or credentials', async () => {
    const raw = await (await get('/api/health')).text();
    assert.ok(!/mongodb(\+srv)?:\/\//i.test(raw), 'health output must not contain a URI');
    assert.ok(!/password|secret|api[_-]?key/i.test(raw));
  });
});

describe('routing', () => {
  it('exposes the API index', async () => {
    const response = await get('/api');
    assert.equal(response.status, 200);
    const body = await response.json();
    assert.equal(body.service, 'flutter-car-backend');
    assert.ok(body.endpoints.users);
  });

  it('returns a structured 404 for unknown routes', async () => {
    const response = await get('/api/does-not-exist');
    assert.equal(response.status, 404);
    const body = await response.json();
    assert.equal(body.error.code, 'not_found');
  });

  it('returns 400 for malformed JSON', async () => {
    const response = await get('/api/users', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: '{"fullName": ',
    });
    assert.equal(response.status, 400);
    assert.equal((await response.json()).error.code, 'invalid_json');
  });
});

describe('input validation (rejects before any database access)', () => {
  it('rejects a user without an email', async () => {
    const response = await postJson('/api/auth/register', { fullName: 'Ada Lovelace' });
    assert.equal(response.status, 400);
    const body = await response.json();
    assert.equal(body.error.code, 'bad_request');
    assert.ok(body.error.details.some((detail) => detail.field === 'body.email'));
  });

  it('rejects an invalid email and unknown fields', async () => {
    const response = await postJson('/api/auth/register', {
      fullName: 'Ada',
      email: 'not-an-email',
      password: 'long-enough-password',
      isAdmin: true,
    });
    assert.equal(response.status, 400);
    const fields = (await response.json()).error.details.map((detail) => detail.field);
    assert.ok(fields.includes('body.email'));
    assert.ok(fields.includes('body.isAdmin'));
  });

  it('rejects a malformed id in the path', async () => {
    const response = await get('/api/favorites/not-an-id', { method: 'DELETE' });
    assert.equal(response.status, 400);
  });

  it('rejects an out-of-range page size', async () => {
    const response = await get('/api/favorites?limit=5000');
    assert.equal(response.status, 400);
  });

  it('rejects a caller-supplied owner id', async () => {
    const response = await postJson('/api/favorites', {
      user: '1',
      externalCarId: 'abc',
      vehicleType: 'new',
    });
    assert.equal(response.status, 400);
  });

  it('rejects an interests upsert with an unknown filter field', async () => {
    const upsert = await get('/api/interests', {
      method: 'PUT',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ colour: 'red' }),
    });
    assert.equal(upsert.status, 400);
  });
});

describe('catalog credential containment', () => {
  it('never returns the provider key, or even names it, from a public endpoint', async () => {
    const { env } = await import('../src/config/env.js');

    for (const path of ['/api', '/api/health', '/api/health/live', '/api/ai/capabilities']) {
      const raw = await (await get(path)).text();

      // Meaningful the moment a real key is configured; harmless while it is not.
      if (env.carCatalogApiKey.length > 0) {
        assert.ok(!raw.includes(env.carCatalogApiKey), `${path} must not echo the provider key`);
      }

      assert.ok(!/CAR_CATALOG_API_KEY/i.test(raw), `${path} must not name the provider key`);
      assert.ok(!/carCatalogApiKey/i.test(raw), `${path} must not expose the key accessor`);
      if (env.geminiApiKey.length > 0) assert.ok(!raw.includes(env.geminiApiKey));
      if (env.authTokenSecret.length > 0) assert.ok(!raw.includes(env.authTokenSecret));
      if (env.resendApiKey.length > 0) assert.ok(!raw.includes(env.resendApiKey));
      assert.ok(!/GEMINI_API_KEY|AUTH_TOKEN_SECRET|authTokenSecret/i.test(raw));
      assert.ok(!/RESEND_API_KEY|resendApiKey/i.test(raw));
    }
  });
});

describe('car catalogue', () => {
  it('reports its capabilities without any provider credit', async () => {
    const response = await get('/api/cars/capabilities');
    assert.equal(response.status, 200);
    const body = await response.json();
    // Disabled in tests, so the descriptor must say so rather than lie.
    assert.equal(body.data.ready, false);
    assert.deepEqual(body.data.sources, []);
  });

  it('answers 503 with an actionable message when no provider is configured', async () => {
    const response = await get('/api/cars');
    assert.equal(response.status, 503);
    const body = await response.json();
    assert.equal(body.error.code, 'service_unavailable');
    assert.ok(/not configured/i.test(body.error.message));
  });

  it('validates the query before it ever considers fetching', async () => {
    for (const path of [
      '/api/cars?bodyType=suv',
      '/api/cars?minPrice=100',
      '/api/cars?source=nope',
      '/api/cars?city=New%20Delhi',
      '/api/cars?page=0',
    ]) {
      const response = await get(path);
      assert.equal(response.status, 400, `${path} should be rejected`);
      assert.equal((await response.json()).error.code, 'bad_request');
    }
  });

  it('rejects a forged or malformed catalogue id without fetching anything', async () => {
    for (const id of ['not-an-id', 'aaaa.bbbb', 'x'.repeat(600)]) {
      const response = await get(`/api/cars/${encodeURIComponent(id)}`);
      assert.equal(response.status, 400, `${id} should be rejected`);
    }
  });

  it('never leaks provider credentials through the catalogue', async () => {
    const { env } = await import('../src/config/env.js');
    for (const path of ['/api/cars/capabilities', '/api/cars']) {
      const raw = await (await get(path)).text();
      if (env.carCatalogApiKey.length > 0) {
        assert.ok(!raw.includes(env.carCatalogApiKey), `${path} must not echo the provider key`);
      }
      assert.ok(!/CAR_CATALOG_API_KEY/i.test(raw));
      if (env.geminiApiKey.length > 0) assert.ok(!raw.includes(env.geminiApiKey));
      if (env.authTokenSecret.length > 0) assert.ok(!raw.includes(env.authTokenSecret));
      assert.ok(!/GEMINI_API_KEY|AUTH_TOKEN_SECRET|authTokenSecret/i.test(raw));
    }
  });
});

describe('database-backed routes refuse to pretend', () => {
  const validBody = {
    fullName: 'Ada Lovelace',
    email: 'ada@example.com',
    password: 'a-long-password-for-tests',
    phone: '+447700900123',
    countryCode: 'gb',
  };

  it('answers 503 immediately when the database is unavailable', async () => {
    const startedAt = Date.now();
    const response = await postJson('/api/auth/register', validBody);
    const elapsed = Date.now() - startedAt;

    assert.equal(response.status, 503, 'a write must not be reported as a server bug');
    assert.ok(elapsed < 1000, `must fail fast, took ${elapsed}ms`);
    const body = await response.json();
    assert.equal(body.error.code, 'service_unavailable');
    assert.ok(/MONGODB_URI/.test(body.error.message));
  });

  it('does the same for reads and for the other resources', async () => {
    for (const path of [
      '/api/users/me',
      '/api/favorites',
      '/api/interests',
    ]) {
      const response = await get(path);
      assert.equal(response.status, 503, `${path} should report 503`);
    }
  });

  it('still validates the body before checking the database', async () => {
    const response = await postJson('/api/auth/register', { fullName: 'A' });
    assert.equal(response.status, 400, 'validation is cheaper and more precise than a 503');
  });
});

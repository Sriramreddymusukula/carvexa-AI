import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { describe, it } from 'node:test';

process.env.NODE_ENV = 'test';
process.env.AUTH_TOKEN_SECRET = 'auth-unit-test-secret-that-is-long-enough';

const { hashPassword, verifyPassword, verifyAccessToken } = await import('../src/services/auth.service.js');

function signTestToken(payload, header = { alg: 'HS256', typ: 'JWT' }) {
  const encodedHeader = Buffer.from(JSON.stringify(header)).toString('base64url');
  const encodedPayload = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const body = `${encodedHeader}.${encodedPayload}`;
  const signature = createHmac('sha256', process.env.AUTH_TOKEN_SECRET).update(body).digest('base64url');
  return `${body}.${signature}`;
}

describe('account credential primitives', () => {
  it('stores passwords as salted scrypt hashes and checks the password', async () => {
    const stored = await hashPassword('correct horse battery staple');
    assert.match(stored, /^scrypt\$[A-Za-z0-9_-]+\$[A-Za-z0-9_-]+$/);
    assert.notEqual(stored, await hashPassword('correct horse battery staple'));
    assert.equal(await verifyPassword('correct horse battery staple', stored), true);
    assert.equal(await verifyPassword('wrong password', stored), false);
  });

  it('accepts an unexpired signed session and returns only identity claims', () => {
    const now = Math.floor(Date.now() / 1000);
    const token = signTestToken({ sub: '0123456789abcdef01234567', ver: 2, iat: now, exp: now + 60 });
    assert.deepEqual(verifyAccessToken(token), {
      userId: '0123456789abcdef01234567',
      tokenVersion: 2,
    });
  });

  it('rejects expired, tampered, malformed, and non-HS256 tokens', () => {
    const expired = signTestToken({ sub: '0123456789abcdef01234567', ver: 0, exp: 1 });
    const valid = signTestToken({ sub: '0123456789abcdef01234567', ver: 0, exp: Math.floor(Date.now() / 1000) + 60 });
    // Mutate a significant header byte; changing only the final base64url
    // character can alter unused padding bits without changing the signature.
    const tampered = `${valid[0] === 'e' ? 'f' : 'e'}${valid.slice(1)}`;
    const wrongAlgorithm = signTestToken(
      { sub: '0123456789abcdef01234567', ver: 0, exp: Math.floor(Date.now() / 1000) + 60 },
      { alg: 'none', typ: 'JWT' },
    );

    assert.equal(verifyAccessToken(expired), null);
    assert.equal(verifyAccessToken(tampered), null);
    assert.equal(verifyAccessToken('not.a.token'), null);
    assert.equal(verifyAccessToken(wrongAlgorithm), null);
  });
});

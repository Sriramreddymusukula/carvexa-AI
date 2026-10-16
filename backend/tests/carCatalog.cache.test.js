import assert from 'node:assert/strict';
import test from 'node:test';

import { createTtlCache } from '../src/services/carCatalog/cache.js';

test('shares an in-flight provider request and caches its successful result', async () => {
  const cache = createTtlCache({ ttlMs: 1000 });
  let calls = 0;
  let release;
  const gate = new Promise((resolve) => {
    release = resolve;
  });
  const produce = async () => {
    calls += 1;
    await gate;
    return { vehicles: 2 };
  };

  const first = cache.resolve('new:', produce);
  const second = cache.resolve('new:', produce);
  await Promise.resolve();
  assert.equal(calls, 1);
  release();

  const [firstValue, secondValue] = await Promise.all([first, second]);
  assert.strictEqual(firstValue, secondValue);
  assert.equal(await cache.resolve('new:', produce), firstValue);
  assert.equal(calls, 1);
});

test('does not cache a failed provider request and permits a retry', async () => {
  const cache = createTtlCache({ ttlMs: 1000 });
  let calls = 0;

  await assert.rejects(
    cache.resolve('used:new-delhi:1', async () => {
      calls += 1;
      throw new Error('temporary upstream error');
    }),
    /temporary upstream error/,
  );

  assert.deepEqual(await cache.resolve('used:new-delhi:1', async () => {
    calls += 1;
    return ['retry succeeded'];
  }), ['retry succeeded']);
  assert.equal(calls, 2);
});

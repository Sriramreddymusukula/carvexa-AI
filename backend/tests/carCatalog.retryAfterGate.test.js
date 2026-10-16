import assert from 'node:assert/strict';
import test from 'node:test';

import { createRetryAfterGate } from '../src/services/carCatalog/retryAfterGate.js';

test('blocks an endpoint until its provider retry window expires', () => {
  let now = 10_000;
  const gate = createRetryAfterGate({ now: () => now });

  gate.block('search_used_cars', 5);
  assert.equal(gate.remaining('search_used_cars'), 5);
  assert.equal(gate.remaining('get_model_details'), null);

  now += 4_001;
  assert.equal(gate.remaining('search_used_cars'), 1);
  now += 1_000;
  assert.equal(gate.remaining('search_used_cars'), null);
});

test('keeps the longer retry window and ignores invalid durations', () => {
  let now = 0;
  const gate = createRetryAfterGate({ now: () => now });

  gate.block('detail', 30);
  now += 1_000;
  gate.block('detail', 4);
  gate.block('other', Number.NaN);

  assert.equal(gate.remaining('detail'), 29);
  assert.equal(gate.remaining('other'), null);
});

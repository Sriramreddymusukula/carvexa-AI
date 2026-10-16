import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { reconcileIndexes } from '../src/utils/indexReconciler.js';

function fakeCollection(indexes = []) {
  return {
    current: indexes.map((index) => structuredClone(index)),
    created: [],
    async indexes() {
      return this.current;
    },
    async createIndex(key, options = {}) {
      this.created.push({ key, options });
      this.current.push({ key, ...options, name: options.name || Object.keys(key).join('_') });
    },
  };
}

describe('Mongo index reconciliation', () => {
  it('accepts a legacy email_1 index with matching uniqueness without renaming it', async () => {
    const collection = fakeCollection([
      { key: { email: 1 }, name: 'email_1', unique: true, v: 2 },
    ]);

    await reconcileIndexes(collection, [[{ email: 1 }, { unique: true, name: 'uniq_email' }]]);

    assert.deepEqual(collection.created, []);
    assert.equal(collection.current[0].name, 'email_1');
  });

  it('adds only absent indexes and preserves compound key ordering', async () => {
    const collection = fakeCollection([
      { key: { user: 1 }, name: 'user_1', unique: true },
    ]);

    await reconcileIndexes(collection, [
      [{ user: 1 }, { unique: true, name: 'uniq_user' }],
      [{ user: 1, createdAt: -1 }, { name: 'idx_user_createdAt' }],
    ]);

    assert.equal(collection.created.length, 1);
    assert.deepEqual(collection.created[0].key, { user: 1, createdAt: -1 });
  });

  it('fails safely on a same-key index with incompatible uniqueness', async () => {
    const collection = fakeCollection([{ key: { email: 1 }, name: 'email_1', unique: false }]);

    await assert.rejects(
      reconcileIndexes(collection, [[{ email: 1 }, { unique: true, name: 'uniq_email' }]]),
      /incompatible options.*email_1.*No index or data was removed/,
    );
    assert.deepEqual(collection.created, []);
    assert.equal(collection.current.length, 1);
  });

  it('creates an index when its collection does not exist yet', async () => {
    const collection = fakeCollection();
    collection.indexes = async () => {
      if (collection.current.length === 0) {
        const error = new Error('namespace does not exist');
        error.code = 26;
        throw error;
      }
      return collection.current;
    };

    await reconcileIndexes(collection, [[{ email: 1 }, { unique: true, name: 'uniq_email' }]]);

    assert.equal(collection.created.length, 1);
  });
});

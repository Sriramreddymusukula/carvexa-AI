const SEMANTIC_OPTIONS = [
  'unique',
  'sparse',
  'expireAfterSeconds',
  'partialFilterExpression',
  'collation',
  'wildcardProjection',
  'weights',
  'default_language',
  'language_override',
  'textIndexVersion',
  '2dsphereIndexVersion',
  'bits',
  'min',
  'max',
  'bucketSize',
  'hidden',
];

function canonical(value) {
  if (Array.isArray(value)) return value.map(canonical);
  if (value && typeof value === 'object') {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, canonical(value[key])]),
    );
  }
  return value;
}

function sameValue(a, b) {
  return JSON.stringify(canonical(a)) === JSON.stringify(canonical(b));
}

function sameKeyPattern(existing, desired) {
  const left = Object.entries(existing ?? {});
  const right = Object.entries(desired ?? {});
  return left.length === right.length && left.every(([key, value], index) => {
    const [otherKey, otherValue] = right[index] ?? [];
    return key === otherKey && value === otherValue;
  });
}

function sameIndexMeaning(existing, keys, options) {
  if (!sameKeyPattern(existing.key, keys)) return false;
  return SEMANTIC_OPTIONS.every((name) => sameValue(existing[name], options[name]));
}

/**
 * Add missing schema indexes without dropping or renaming existing indexes.
 * An index with the same key and enforcement options already satisfies the
 * schema even if MongoDB gave it a different name (for example `email_1`).
 */
export async function reconcileIndexes(collection, definitions) {
  let existing;
  try {
    existing = await collection.indexes();
  } catch (error) {
    // MongoDB returns NamespaceNotFound for a collection not yet created.
    if (error?.code !== 26 && error?.codeName !== 'NamespaceNotFound') throw error;
    existing = [];
  }

  for (const [keys, options = {}] of definitions) {
    const sameKeys = existing.filter((index) => sameKeyPattern(index.key, keys));
    const equivalent = sameKeys.find((index) => sameIndexMeaning(index, keys, options));
    if (equivalent) continue;

    if (sameKeys.length > 0) {
      const names = sameKeys.map((index) => index.name).join(', ');
      throw new Error(
        `Index for ${Object.keys(keys).join(', ')} already exists with incompatible options (${names}); ` +
          'review the existing MongoDB index manually. No index or data was removed.',
      );
    }

    await collection.createIndex(keys, options);
    existing = await collection.indexes();
  }
}

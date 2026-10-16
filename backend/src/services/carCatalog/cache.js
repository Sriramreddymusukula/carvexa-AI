/**
 * A tiny TTL cache for provider responses.
 *
 * Why it exists: every call to the external catalog costs a credit and 1-5
 * seconds, and the same screens are revisited constantly while a user browses
 * (back and forth between a list and a detail page, filter changes, retries).
 * Caching the *provider* response - not our own HTTP response - means the
 * second visitor of a page gets it instantly and we stay inside a free-tier
 * quota without ever showing stale data for longer than [ttlMs].
 *
 * Deliberately in-process and dependency-free: a single Node process serves the
 * whole API, and introducing Redis for a cache this small would be premature.
 */
export function createTtlCache({ ttlMs, maxEntries = 300 } = {}) {
  /** @type {Map<string, { expiresAt: number, value: unknown }>} */
  const entries = new Map();
  /** @type {Map<string, Promise<unknown>>} */
  const inFlight = new Map();

  function evictExpired(now) {
    for (const [key, entry] of entries) {
      if (entry.expiresAt <= now) entries.delete(key);
    }
  }

  return {
    /**
     * @param {string} key
     * @returns {unknown | undefined} The cached value, or undefined on a miss.
     */
    get(key) {
      const entry = entries.get(key);
      if (!entry) return undefined;
      if (entry.expiresAt <= Date.now()) {
        entries.delete(key);
        return undefined;
      }
      return entry.value;
    },

    /**
     * @param {string} key
     * @param {unknown} value
     */
    set(key, value) {
      if (ttlMs <= 0) return;

      // Cheap bound: drop everything that has already expired, then the oldest
      // insertion (Map preserves insertion order) if we are still over budget.
      const now = Date.now();
      evictExpired(now);
      while (entries.size >= maxEntries) {
        const oldest = entries.keys().next();
        if (oldest.done) break;
        entries.delete(oldest.value);
      }

      entries.set(key, { expiresAt: now + ttlMs, value });
    },

    /**
     * Wraps a producer so concurrent callers of the same key share one
     * provider call instead of stampeding the provider.
     *
     * @template T
     * @param {string} key
     * @param {() => Promise<T>} produce
     * @returns {Promise<T>}
     */
    resolve(key, produce) {
      const cached = this.get(key);
      if (cached !== undefined) return Promise.resolve(/** @type {T} */ (cached));

      const active = inFlight.get(key);
      if (active !== undefined) return /** @type {Promise<T>} */ (active);

      let request;
      request = Promise.resolve()
        .then(produce)
        .then((value) => {
          this.set(key, value);
          return value;
        })
        .finally(() => {
          if (inFlight.get(key) === request) inFlight.delete(key);
        });
      inFlight.set(key, request);
      return request;
    },
  };
}

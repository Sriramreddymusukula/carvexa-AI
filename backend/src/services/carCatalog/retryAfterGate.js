/** Keeps provider Retry-After windows from being bypassed by rapid client retries. */
export function createRetryAfterGate({ now = () => Date.now() } = {}) {
  const blockedUntil = new Map();

  return {
    block(key, seconds) {
      if (!Number.isFinite(seconds) || seconds <= 0) return;
      const next = now() + Math.ceil(seconds) * 1000;
      blockedUntil.set(key, Math.max(blockedUntil.get(key) ?? 0, next));
    },

    remaining(key) {
      const until = blockedUntil.get(key);
      if (until === undefined) return null;
      const seconds = Math.ceil((until - now()) / 1000);
      if (seconds <= 0) {
        blockedUntil.delete(key);
        return null;
      }
      return seconds;
    },
  };
}

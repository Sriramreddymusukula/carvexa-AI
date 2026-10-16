/**
 * Secret-redaction helpers.
 *
 * MongoDB driver errors can embed the full connection string, credentials
 * included. Anything derived from a driver/OS error must pass through
 * redactSecrets() before it reaches a log line or an HTTP response.
 */

// mongodb://user:pass@host  /  mongodb+srv://user:pass@host
const MONGO_URI_PATTERN = /mongodb(?:\+srv)?:\/\/[^\s"'`]+/gi;
// Basic-auth credentials inside any other URL: https://user:pass@host
const URL_CREDENTIALS_PATTERN = /\b([a-z][a-z0-9+.-]*:\/\/)[^\s/@:]+:[^\s@/]+@/gi;
// Common `key=value` / `"key": "value"` pairs that look like credentials.
const KEY_VALUE_SECRET_PATTERN =
  /\b(api[_-]?key|apikey|authorization|password|passwd|secret|access[_-]?token|refresh[_-]?token|bearer)\b(["'\s]*[:=]["'\s]*)([^\s"',}]+)/gi;

export const REDACTED = '[redacted]';

/**
 * Values discovered at runtime — for example the car-catalog key read from
 * `backend/.env` — that must never appear in a log line or an HTTP response.
 *
 * Registering the exact value matters because a provider key can be echoed back
 * by a transport or provider error *without* an `api_key=` prefix, which none of
 * the patterns above can recognise.
 */
const registeredSecrets = new Set();

/**
 * @param {unknown} value The secret's exact value, e.g. from configuration.
 */
export function registerSecret(value) {
  const trimmed = typeof value === 'string' ? value.trim() : '';
  // Very short values would redact far too much text to be worth hiding.
  if (trimmed.length >= 8) registeredSecrets.add(trimmed);
}

/**
 * Drops every registered secret. Test-only: suites must not leak registration
 * state into one another.
 */
export function clearRegisteredSecrets() {
  registeredSecrets.clear();
}

function redactRegistered(value) {
  let result = value;
  for (const secret of registeredSecrets) {
    if (result.includes(secret)) result = result.split(secret).join(REDACTED);
  }
  return result;
}

/**
 * Replace anything that looks like a credential with a placeholder.
 * @param {unknown} input
 * @returns {string}
 */
export function redactSecrets(input) {
  if (input === null || input === undefined) return '';

  const text = String(input)
    .replace(MONGO_URI_PATTERN, REDACTED)
    .replace(URL_CREDENTIALS_PATTERN, `$1${REDACTED}@`)
    .replace(KEY_VALUE_SECRET_PATTERN, `$1$2${REDACTED}`);

  return redactRegistered(text);
}

/**
 * Turn any thrown value into a safe, human-readable message.
 * @param {unknown} error
 * @returns {string}
 */
export function safeMessage(error) {
  if (!error) return 'Unknown error';
  if (typeof error === 'string') return redactSecrets(error);
  return redactSecrets(error.message || error.name || String(error));
}

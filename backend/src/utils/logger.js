/**
 * Minimal dependency-free logger.
 *
 * Deliberate choices:
 *  - No body/header/query logging anywhere. Customer records contain PII
 *    (name, email, phone), so request logging stays metadata-only.
 *  - The level is resolved lazily from process.env so this module can be
 *    imported before dotenv has run.
 *  - Never pass raw secrets here; see utils/secrets.js for redaction helpers.
 */

const LEVELS = { error: 10, warn: 20, info: 30, debug: 40 };

function activeLevel() {
  const configured = String(process.env.LOG_LEVEL ?? 'info').toLowerCase();
  return LEVELS[configured] ?? LEVELS.info;
}

function write(level, message, meta) {
  if (LEVELS[level] > activeLevel()) return;

  const line = {
    level,
    time: new Date().toISOString(),
    msg: message,
  };
  if (meta !== undefined) line.meta = meta;

  const output = JSON.stringify(line);
  if (level === 'error') process.stderr.write(`${output}\n`);
  else process.stdout.write(`${output}\n`);
}

export const logger = {
  error: (message, meta) => write('error', message, meta),
  warn: (message, meta) => write('warn', message, meta),
  info: (message, meta) => write('info', message, meta),
  debug: (message, meta) => write('debug', message, meta),
};

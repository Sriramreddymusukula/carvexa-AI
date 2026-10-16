import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

import dotenv from 'dotenv';
import { z } from 'zod';

import { logger } from '../utils/logger.js';
import { registerSecret } from '../utils/secrets.js';

/** backend/ — resolved from this module so the server starts from any cwd. */
const backendRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');

const loaded = dotenv.config({ path: path.join(backendRoot, '.env') });
if (loaded.error) {
  if (loaded.error.code !== 'ENOENT') {
    throw new Error(`Unable to read backend/.env: ${loaded.error.message}`);
  }
  logger.warn('backend/.env not found; relying on process environment variables only');
}

const booleanish = z
  .union([z.boolean(), z.string()])
  .transform((value) =>
    typeof value === 'boolean' ? value : ['1', 'true', 'yes', 'on'].includes(value.trim().toLowerCase()),
  );

const numberish = (fallback) =>
  z
    .union([z.number(), z.string()])
    .optional()
    .transform((value) => {
      if (value === undefined || value === '') return fallback;
      const parsed = Number(value);
      return Number.isFinite(parsed) ? parsed : fallback;
    });

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: numberish(4000),

  // An empty value is allowed here on purpose so the API can still boot and
  // report a precise "not configured" state from /api/health. config/db.js is
  // what refuses to connect (and, in production, refuses to start) without it.
  MONGODB_URI: z
    .string()
    .trim()
    .default('')
    .refine((value) => value === '' || /^mongodb(\+srv)?:\/\//i.test(value), {
      message:
        'MONGODB_URI must be a mongodb:// or mongodb+srv:// connection string ' +
        '(see backend/.env.example)',
    }),
  MONGODB_DB_NAME: z.string().trim().default(''),
  DB_SERVER_SELECTION_TIMEOUT_MS: numberish(10000),

  // Authentication and AI credentials are server-side only.
  AUTH_TOKEN_SECRET: z.string().trim().default(''),
  GEMINI_API_KEY: z.string().trim().default(''),
  GEMINI_MODEL: z.string().trim().default('gemini-2.0-flash'),
  GEMINI_TIMEOUT_MS: numberish(25000),

  // OpenRouter is the OpenAI-compatible AI gateway actually configured in
  // backend/.env today (see OPENROUTER_* there). Gemini is used instead when
  // GEMINI_API_KEY is present; the service picks whichever key exists.
  OPENROUTER_API_KEY: z.string().trim().default(''),
  OPENROUTER_MODEL: z.string().trim().default('openrouter/free'),
  OPENROUTER_BASE_URL: z.string().trim().default('https://openrouter.ai/api/v1'),

  // Optional transactional email provider. Notification delivery is disabled
  // cleanly until all Resend settings are supplied.
  EMAIL_PROVIDER: z.enum(['none', 'resend']).default('none'),
  RESEND_API_KEY: z.string().trim().default(''),
  EMAIL_FROM: z.string().trim().default(''),
  LEAD_NOTIFICATION_EMAIL: z
    .string()
    .email()
    .trim()
    .default('sriramreddymusukula@gmail.com'),

  // --- External car catalog -------------------------------------------------
  // The car data API is a third-party service. Its key is a server-side secret:
  // it lives here only, is read by the provider adapter only, and is never
  // returned to the Flutter app or written to a log line.
  //
  // 'none' disables the catalogue cleanly (routes answer a precise
  // "not configured" failure) instead of starting a half-wired adapter.
  CAR_CATALOG_PROVIDER: z
    .string()
    .trim()
    .toLowerCase()
    .default('none')
    .refine((value) => /^[a-z0-9][a-z0-9-]*$/.test(value), {
      message: 'must be a lowercase slug such as "none" or "api-ninjas"',
    }),
  CAR_CATALOG_BASE_URL: z
    .string()
    .trim()
    .default('')
    .refine((value) => value === '' || /^https?:\/\//i.test(value), {
      message: 'must be an http(s) URL (see backend/.env.example)',
    }),
  CAR_CATALOG_API_KEY: z.string().trim().default(''),
  // Where the key is carried: a header name (e.g. `X-Api-Key`, `Authorization`)
  // or, for the few providers that require it, a query parameter.
  CAR_CATALOG_API_KEY_HEADER: z.string().trim().default('X-Api-Key'),
  CAR_CATALOG_API_KEY_QUERY_PARAM: z.string().trim().default(''),
  // Optional prefix for the header value, e.g. `Bearer ` for Authorization.
  CAR_CATALOG_API_KEY_SCHEME: z.string().trim().default(''),
  // The provider's "scraper id" for this catalog. For Parse this is the shared
  // canonical id documented at parse.bot/marketplace — public, not a secret.
  CAR_CATALOG_SCRAPER_ID: z.string().trim().default(''),
  CAR_CATALOG_TIMEOUT_MS: numberish(10000),
  CAR_CATALOG_CACHE_TTL_MS: numberish(60000),
  CAR_CATALOG_PAGE_SIZE: numberish(20),

  CORS_ALLOWED_ORIGINS: z.string().trim().default(''),
  RATE_LIMIT_WINDOW_MS: numberish(900_000),
  RATE_LIMIT_MAX: numberish(300),

  LOG_LEVEL: z.enum(['error', 'warn', 'info', 'debug']).default('info'),
  HTTP_REQUEST_LOGGING: booleanish.pipe(z.boolean()).default(true),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  const details = parsed.error.issues
    .map((issue) => `  - ${issue.path.join('.') || '(root)'}: ${issue.message}`)
    .join('\n');
  // Only variable names and validation messages are printed — never values.
  throw new Error(`Invalid environment configuration:\n${details}`);
}

if (parsed.data.NODE_ENV !== 'test' && parsed.data.AUTH_TOKEN_SECRET.length < 32) {
  throw new Error('Invalid environment configuration:\n  - AUTH_TOKEN_SECRET: must be at least 32 characters; generate a random value for backend/.env');
}

const data = parsed.data;

// Fail fast on a half-configured provider. Without this, a missing base URL or
// key would only surface later as an opaque 401 from the provider on the first
// catalog request. Only variable NAMES appear below — never a value.
if (data.CAR_CATALOG_PROVIDER !== 'none') {
  const missing = [
    ['CAR_CATALOG_BASE_URL', data.CAR_CATALOG_BASE_URL],
    ['CAR_CATALOG_API_KEY', data.CAR_CATALOG_API_KEY],
    ['CAR_CATALOG_SCRAPER_ID', data.CAR_CATALOG_SCRAPER_ID],
  ]
    .filter(([, value]) => value === '')
    .map(([name]) => name);

  if (missing.length > 0) {
    throw new Error(
      'Invalid environment configuration:\n' +
        missing
          .map(
            (name) =>
              `  - ${name}: is required when CAR_CATALOG_PROVIDER is "${data.CAR_CATALOG_PROVIDER}"`,
          )
          .join('\n'),
    );
  }
}

if (data.EMAIL_PROVIDER === 'resend') {
  const missing = [
    ['RESEND_API_KEY', data.RESEND_API_KEY],
    ['EMAIL_FROM', data.EMAIL_FROM],
  ]
    .filter(([, value]) => value === '')
    .map(([name]) => name);
  if (missing.length > 0) {
    throw new Error(
      'Invalid environment configuration:\n' +
        missing.map((name) => `  - ${name}: is required when EMAIL_PROVIDER is "resend"`).join('\n'),
    );
  }
}

// So the provider key is scrubbed from anything derived from a transport or
// provider error before it can reach a log line or an HTTP response.
registerSecret(data.CAR_CATALOG_API_KEY);
registerSecret(data.GEMINI_API_KEY);
registerSecret(data.OPENROUTER_API_KEY);
registerSecret(data.AUTH_TOKEN_SECRET);
registerSecret(data.RESEND_API_KEY);

export const env = {
  nodeEnv: data.NODE_ENV,
  isProduction: data.NODE_ENV === 'production',
  isTest: data.NODE_ENV === 'test',
  port: Math.trunc(data.PORT),

  mongoUri: data.MONGODB_URI,
  // No default database name: when MONGODB_DB_NAME is empty, mongoose uses the
  // database embedded in MONGODB_URI, which is the Atlas convention.
  mongoDbName: data.MONGODB_DB_NAME,
  dbServerSelectionTimeoutMs: Math.trunc(data.DB_SERVER_SELECTION_TIMEOUT_MS),
  authTokenSecret: data.AUTH_TOKEN_SECRET,
  geminiApiKey: data.GEMINI_API_KEY,
  geminiModel: data.GEMINI_MODEL,
  geminiTimeoutMs: Math.trunc(data.GEMINI_TIMEOUT_MS),
  openRouterApiKey: data.OPENROUTER_API_KEY,
  openRouterModel: data.OPENROUTER_MODEL,
  openRouterBaseUrl: data.OPENROUTER_BASE_URL.replace(/\/+$/, ''),
  /**
   * True when at least one AI credential is configured. Both providers are
   * server-side only; `/api/ai/capabilities` reads this to report honestly
   * whether the assistant can answer at all.
   */
  get isGeminiConfigured() {
    return data.GEMINI_API_KEY !== '' || data.OPENROUTER_API_KEY !== '';
  },
  /** Which AI provider a chat request will use, or 'none' when unconfigured. */
  get aiProvider() {
    if (data.GEMINI_API_KEY !== '') return 'gemini';
    if (data.OPENROUTER_API_KEY !== '') return 'openrouter';
    return 'none';
  },

  emailProvider: data.EMAIL_PROVIDER,
  resendApiKey: data.RESEND_API_KEY,
  emailFrom: data.EMAIL_FROM,
  leadNotificationEmail: data.LEAD_NOTIFICATION_EMAIL,
  get isLeadEmailConfigured() {
    return data.EMAIL_PROVIDER === 'resend' && data.RESEND_API_KEY !== '' && data.EMAIL_FROM !== '';
  },

  // --- External car catalog --------------------------------------------------
  carCatalogProvider: data.CAR_CATALOG_PROVIDER,
  carCatalogApiKey: data.CAR_CATALOG_API_KEY,
  carCatalogApiKeyHeader: data.CAR_CATALOG_API_KEY_HEADER,
  carCatalogApiKeyQueryParam: data.CAR_CATALOG_API_KEY_QUERY_PARAM,
  carCatalogApiKeyScheme: data.CAR_CATALOG_API_KEY_SCHEME,
  carCatalogScraperId: data.CAR_CATALOG_SCRAPER_ID,
  carCatalogTimeoutMs: Math.trunc(data.CAR_CATALOG_TIMEOUT_MS),
  carCatalogCacheTtlMs: Math.trunc(data.CAR_CATALOG_CACHE_TTL_MS),
  carCatalogPageSize: Math.trunc(data.CAR_CATALOG_PAGE_SIZE),

  /**
   * Base URL without a trailing slash, so path joining is unambiguous wherever
   * a provider path is appended.
   */
  carCatalogBaseUrl() {
    return data.CAR_CATALOG_BASE_URL.replace(/\/+$/, '');
  },

  /**
   * True once a provider, a base URL and a key are all present. The catalog
   * service reads this to answer with one clear, actionable failure instead of
   * passing a provider's 401 through to the user.
   */
  get isCarCatalogConfigured() {
    return (
      data.CAR_CATALOG_PROVIDER !== 'none' &&
      data.CAR_CATALOG_BASE_URL !== '' &&
      data.CAR_CATALOG_API_KEY !== '' &&
      data.CAR_CATALOG_SCRAPER_ID !== ''
    );
  },

  rateLimitWindowMs: Math.trunc(data.RATE_LIMIT_WINDOW_MS),
  rateLimitMax: Math.trunc(data.RATE_LIMIT_MAX),
  httpRequestLogging: data.HTTP_REQUEST_LOGGING,

  get allowsCorsWildcard() {
    return data.CORS_ALLOWED_ORIGINS === '*';
  },
  /** @returns {string[]} */
  corsAllowedOrigins() {
    return data.CORS_ALLOWED_ORIGINS
      .split(',')
      .map((origin) => origin.trim().replace(/\/$/, ''))
      .filter((origin) => origin !== '' && origin !== '*');
  },
};

/**
 * True in development/test, or when the client sends no Origin header.
 * Native Android/iOS/Dart HTTP clients send no Origin, so they must not be
 * blocked; browsers (Flutter web, curl -H "Origin: ...") are checked properly.
 * @param {string | undefined} origin
 * @returns {boolean}
 */
export function isAllowedOrigin(origin) {
  if (!origin) return true;
  if (env.allowsCorsWildcard) return true;
  if (env.isProduction) return env.corsAllowedOrigins().includes(origin.replace(/\/$/, ''));

  if (env.corsAllowedOrigins().includes(origin.replace(/\/$/, ''))) return true;
  return /^https?:\/\/(localhost|127\.0\.0\.1|\[::1\])(:\d+)?$/i.test(origin);
}

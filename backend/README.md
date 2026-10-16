# Carvexa AI API

Node.js and Express API for Carvexa AI. It owns accounts, favorites, saved
preferences, and consent-based vehicle-interest leads. It is also the only
service that contacts the external car catalog or Gemini.

```text
Flutter app -> Express API -> MongoDB (accounts and app data)
                         -> configured catalog provider (vehicle data)
                         -> Gemini API (AI explanations and chat)
```

## Requirements and setup

- Node.js 22.15 or newer
- MongoDB for account and user data
- A catalog provider configuration for live listings
- A Gemini API key for AI features
- Optional Resend API key and a verified sender address for lead notifications

```powershell
npm install
Copy-Item .env.example .env
```

Set `MONGODB_URI` and a cryptographically random `AUTH_TOKEN_SECRET` in
`.env`. The auth secret must contain at least 32 characters; production startup
requires it. For example, generate a value locally with
`node -e "console.log(require('node:crypto').randomBytes(48).toString('base64url'))"`.
Keep `.env` private. Never put catalog or Gemini keys in Flutter source, assets,
or `--dart-define` values.

The backend scripts enable Node's system CA store. This lets Node trust
certificates installed by the operating system (including managed development
proxies) while keeping certificate-chain, hostname, and expiry checks enabled.
Use the supported Node version; do not disable TLS verification to work around
a certificate problem.

Then start the API:

```powershell
npm run dev
```

The default address is `http://localhost:4000`. `GET /api/health` reports
database readiness; `GET /api/health/live` only checks that the process is up.
Without a catalog provider, vehicle endpoints return a clear unavailable error
and never invent listings. AI requires both Gemini and a configured catalog.

## Configuration

Copy `.env.example` and set values in `.env`. Invalid configuration reports
variable names and never prints the values.

| Variable | Purpose |
| --- | --- |
| `NODE_ENV`, `PORT` | Runtime mode and HTTP port. |
| `MONGODB_URI`, `MONGODB_DB_NAME` | MongoDB connection and optional database override. |
| `AUTH_TOKEN_SECRET` | Required signing secret for revocable 30-day sessions (32+ characters). |
| `CAR_CATALOG_PROVIDER` | `none` or the configured adapter (`parse-cardekho`). |
| `CAR_CATALOG_BASE_URL`, `CAR_CATALOG_SCRAPER_ID`, `CAR_CATALOG_API_KEY` | Provider endpoint, catalog identifier, and server-side credential. |
| `CAR_CATALOG_API_KEY_HEADER`, `CAR_CATALOG_API_KEY_QUERY_PARAM`, `CAR_CATALOG_API_KEY_SCHEME` | How the provider expects its credential. |
| `CAR_CATALOG_TIMEOUT_MS`, `CAR_CATALOG_CACHE_TTL_MS`, `CAR_CATALOG_PAGE_SIZE` | Provider request, cache, and paging settings. |
| `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_TIMEOUT_MS` | Optional server-side Gemini configuration. |
| `EMAIL_PROVIDER` | `none` (default) or `resend` for lead email notifications. |
| `RESEND_API_KEY`, `EMAIL_FROM` | Required when `EMAIL_PROVIDER=resend`; server-only Resend credential and verified sender. |
| `LEAD_NOTIFICATION_EMAIL` | Lead recipient; defaults to `sriramreddymusukula@gmail.com`. |
| `CORS_ALLOWED_ORIGINS` | Comma-separated browser origins; native app requests have no Origin header. |
| `RATE_LIMIT_WINDOW_MS`, `RATE_LIMIT_MAX` | General API rate limit; auth and AI routes have tighter limits. |
| `LOG_LEVEL`, `HTTP_REQUEST_LOGGING` | Metadata-only log level and request logging switch. |
| `DB_SERVER_SELECTION_TIMEOUT_MS` | Mongo connection timeout. |

## Catalog behavior

`GET /api/cars/capabilities` describes supported controls. The UI only offers
search and filters the provider can apply. Catalog IDs are opaque, signed
references; the server validates decoded detail URLs against the provider's
host allowlist. Provider credentials never reach the client.

Used listings are restricted to Hyderabad; the backend does not relabel other
cities' fallback records. New-car cards show an estimated Hyderabad on-road
range when an ex-showroom price is published. The estimate uses Telangana
private-car life-tax slabs for a first private vehicle, the current road-safety
cess, registration fees, and a 3% insurance allowance; it is not a dealer quote
and does not include second-vehicle/company tax adjustments. Eligible electric
cars registered before 2027 use the current life-tax and registration exemption.
Cars without a published price remain unavailable for an estimate. Used-car
prices remain the seller's asking prices. Used provider `total_count` is not
reliable, so paging is derived from page length.

## API

Responses use `{ "data": ... }`; errors use
`{ "error": { "code", "message", "details?" } }`. Authenticated endpoints
expect `Authorization: Bearer <token>`. The user identity comes from the
verified token; clients cannot select an account by passing a user ID.

| Method | Path | Access | Purpose |
| --- | --- | --- | --- |
| GET | `/api` | Public | API endpoint index. |
| GET | `/api/health` | Public | API and Mongo readiness. |
| GET | `/api/health/live` | Public | Process liveness. |
| GET | `/api/cars/capabilities` | Public | Catalog provider capabilities. |
| GET | `/api/cars?source=new\|used` | Public | Catalog listings and supported filters. |
| GET | `/api/cars/:id` | Public | Vehicle detail by opaque catalog ID. |
| POST | `/api/auth/register` | Public, rate limited | Create account and session. |
| POST | `/api/auth/login` | Public, rate limited | Start account session. |
| POST | `/api/auth/logout` | Session | Revoke current sessions. |
| GET, PUT | `/api/users/me` | Session | Read or update own profile. |
| GET, PUT | `/api/interests` | Session | Read or replace own discovery preferences. |
| GET, POST | `/api/favorites` | Session | List or save own catalog favorites. |
| DELETE | `/api/favorites/:id` | Session | Remove own favorite. |
| POST | `/api/leads` | Session + consent | Submit interest in a catalog vehicle using profile contact details. |
| GET | `/api/ai/capabilities` | Public | AI configuration status. |
| POST | `/api/ai/chat` | Session, rate limited | Catalog-grounded assistant conversation. |
| POST | `/api/ai/recommendations` | Session, rate limited | Recommendations from actual new-car catalog results. |

## Data and security

- Passwords are stored as scrypt hashes. Session tokens are signed, expire
  after 30 days, and are checked against the account's revocation version.
- Flutter stores the session token with the platform secure-storage plugin.
- Favorites are scoped to the authenticated account and verified against a
  real catalog vehicle before saving; a small allowlisted snapshot supports the
  saved-cars screen.
- The AI service reads the Gemini key only on the server, bounds message input,
  uses request timeouts, and grounds vehicle facts in provider data.
- Application indexes are created or checked during backend startup before the
  database is reported ready, including in production where automatic index
  creation is disabled.
- A lead is stored only after explicit contact consent. Vehicle details and
  contact fields are assembled by the backend from the catalog and signed-in
  profile. Once stored, notification is attempted through Resend when configured;
  the API reports `accepted`, `failed`, or `not_configured`. `accepted` means
  the provider accepted the request, not that mailbox delivery was confirmed.
- Logs omit request bodies, headers, and query strings. Secret values are
  redacted from provider and AI errors.

## Checks

```powershell
npm test              # offline tests; no provider credits or Mongo required
npm run check          # syntax check for server entry point
npm run catalog:check  # live provider check; may use provider quota
npm run ai:check       # one real Gemini request; uses model quota
npm run db:check       # live Mongo write/read/delete check
```

`catalog:check`, `ai:check`, and `db:check` require their real services to be
configured and reachable. The automated offline tests do not claim those
integrations are live.

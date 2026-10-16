# Carvexa AI

Carvexa AI is a Flutter automotive discovery app backed by an Express API. It
shows live new and used vehicle listings, supports comparison and saved cars,
stores account preferences, accepts consent-based interest requests, and offers
an authenticated AI assistant grounded in the configured catalog.

## Run the backend

Use Node.js 20.19 or newer. From `backend/`:

```powershell
npm install
Copy-Item .env.example .env
```

Set `MONGODB_URI` and a random `AUTH_TOKEN_SECRET` of at least 32 characters in
`backend/.env`. Configure the catalog provider and Gemini key there to enable
live listings and AI. These credentials stay on the backend. See
[`backend/README.md`](backend/README.md) for all settings and endpoints.

```powershell
npm run dev
```

The API listens on port 4000 by default. Without a configured catalog provider,
the app reports that listings are unavailable instead of substituting sample
vehicles. Account, favorite, preference, lead, and AI endpoints also require
MongoDB.

## Run the Flutter app

From the repository root:

```powershell
flutter pub get
flutter run
```

Android automatically discovers the backend on the local network; start the
backend and connect the phone and PC to the same hotspot. Desktop, web, and iOS
simulator builds use `http://localhost:4000/api`. Override the URL with
`--dart-define=API_BASE_URL=http://192.168.x.x:4000/api` when needed. Never put
provider or AI credentials in Flutter build defines.

## Checks and release build

```powershell
flutter analyze
flutter test
cd backend
npm test
```

For a distributable Android APK, provide these environment variables from your
secret store before running `flutter build apk --release`:

- `CARVEXA_RELEASE_STORE_FILE`
- `CARVEXA_RELEASE_STORE_PASSWORD`
- `CARVEXA_RELEASE_KEY_ALIAS`
- `CARVEXA_RELEASE_KEY_PASSWORD`

For local QA only, `CARVEXA_ALLOW_DEBUG_RELEASE_SIGNING=true` explicitly allows
a debug-signed release artifact. Release builds fail closed when neither mode
is configured.

## Project layout

- `lib/`: Flutter presentation, account state, networking, and catalog models.
- `backend/`: Express API, MongoDB models, catalog provider, auth, leads, and
  server-side Gemini integration.
- `test/`: Flutter widget and controller tests.
- `backend/tests/`: offline Node.js API and service tests.


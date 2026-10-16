# Flutter app

The Carvexa AI client is organized around a small set of presentation,
application-state, and data layers:

- `presentation/screens` and `presentation/widgets` render the automotive UI.
- `presentation/state` owns account, favorites, catalog, comparison, and feed
  state.
- `data/repositories` adapts API responses into app models.
- `core/network` handles HTTP, timeouts, bearer sessions, and API failures.
- `di/app_dependencies.dart` builds production and test dependency graphs.

The Flutter app receives vehicle and AI data only through the backend. It does
not contain catalog or Gemini credentials. Production sessions use secure
platform storage; widget tests inject an in-memory session store.

Run from the repository root:

```powershell
flutter pub get
flutter analyze
flutter test
```

Android discovers the backend on the local network at startup; the backend
answers on UDP port 4001 and the API uses TCP port 4000 by default. An explicit
`API_BASE_URL` Dart define disables discovery and takes precedence.


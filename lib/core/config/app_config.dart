import 'package:flutter/foundation.dart';

/// Build-time configuration for the Flutter application.
///
/// Everything here is safe to ship inside the binary: host names, timeouts and
/// feature flags. **No secret may ever be passed via `--dart-define`** â€” they
/// are compiled into the app and can be extracted from the APK. Keys for Gemini
/// or any external car API live only in the backend (see `backend/.env`).
///
/// Override per build, for example:
/// ```sh
/// flutter run --dart-define=API_BASE_URL=http://192.168.137.164:4000/api
/// ```
@immutable
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.requestTimeout,
    required this.enableVerboseNetworkLogs,
    this.catalogRequestTimeout = const Duration(seconds: 30),
    this.autoDiscoverBackend = false,
    this.backendDiscoveryTimeout = const Duration(seconds: 3),
  });

  /// Reads configuration from compile-time defines.
  factory AppConfig.fromEnvironment() {
    const String configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    final bool hasApiOverride = configuredApiBaseUrl.trim().isNotEmpty;
    return AppConfig(
      apiBaseUrl: hasApiOverride
          ? configuredApiBaseUrl.trim()
          : defaultApiBaseUrl,
      requestTimeout: const Duration(seconds: 12),
      // A catalogue call is not a simple fetch: the provider composes each
      // endpoint from one to three upstream page fetches, so a cold or slow
      // response legitimately takes longer than an ordinary API call. Timing the
      // app out first would turn a working catalogue into a "try again" screen.
      catalogRequestTimeout: Duration(
        seconds:
            int.tryParse(
              const String.fromEnvironment(
                'CATALOG_TIMEOUT_SECONDS',
                defaultValue: '30',
              ),
            ) ??
            30,
      ),
      enableVerboseNetworkLogs: const bool.fromEnvironment(
        'VERBOSE_NETWORK_LOGS',
        defaultValue: kDebugMode,
      ),
      autoDiscoverBackend:
          !hasApiOverride &&
          !kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android,
    );
  }

  /// Base URL of our own Express API, including the `/api` prefix.
  final String apiBaseUrl;

  /// Per-request timeout. Kept short so a slow network surfaces an error the
  /// user can act on rather than an indefinite spinner.
  final Duration requestTimeout;

  /// Timeout for catalogue reads, which reach a provider that composes several
  /// upstream requests per call and therefore answers far more slowly than a
  /// normal endpoint.
  final Duration catalogRequestTimeout;

  /// On Android, find the development PC on the connected local network.
  /// An explicit API_BASE_URL always disables discovery.
  final bool autoDiscoverBackend;

  /// Bound for the UDP request/reply used to find the backend.
  final Duration backendDiscoveryTimeout;

  /// Log request method/path/status in debug only. Never logs bodies, headers
  /// or query strings, because those can carry customer data.
  final bool enableVerboseNetworkLogs;

  /// Non-Android default. Android production config discovers the backend
  /// instead of relying on a PC address that can change between networks.
  static String get defaultApiBaseUrl => 'http://localhost:4000/api';

  AppConfig copyWith({
    String? apiBaseUrl,
    Duration? requestTimeout,
    Duration? catalogRequestTimeout,
    bool? enableVerboseNetworkLogs,
    bool? autoDiscoverBackend,
    Duration? backendDiscoveryTimeout,
  }) {
    return AppConfig(
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      requestTimeout: requestTimeout ?? this.requestTimeout,
      catalogRequestTimeout:
          catalogRequestTimeout ?? this.catalogRequestTimeout,
      enableVerboseNetworkLogs:
          enableVerboseNetworkLogs ?? this.enableVerboseNetworkLogs,
      autoDiscoverBackend: autoDiscoverBackend ?? this.autoDiscoverBackend,
      backendDiscoveryTimeout:
          backendDiscoveryTimeout ?? this.backendDiscoveryTimeout,
    );
  }
}

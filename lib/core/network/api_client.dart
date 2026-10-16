import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../error/app_failure.dart';
import 'backend_discovery.dart';

/// The single place the app talks HTTP.
///
/// Responsibilities kept here so no screen ever touches `http` directly:
///  * base URL joining and URL encoding of path segments
///  * timeouts
///  * decoding the backend's `{ data, meta }` / `{ error }` envelope
///  * mapping every transport problem to an [AppFailure] the UI can present
///
/// It deliberately does not know about cars, users or favorites.
class ApiClient {
  ApiClient({required this.config, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final AppConfig config;
  final http.Client _http;
  String? _accessToken;
  String? _discoveredBaseUrl;
  Future<String>? _discoveryInProgress;

  String get baseUrl => _discoveredBaseUrl ?? config.apiBaseUrl;

  void close() => _http.close();

  /// Adds or removes the account's bearer token without exposing it to widgets.
  void setAccessToken(String? value) => _accessToken = value;

  /// Reads a JSON object, optionally with a different timeout.
  ///
  /// The override exists for slow, composed backends (the car catalogue reaches
  /// a provider that fetches several upstream pages per call) without making
  /// every other call wait that long.
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
    Duration? timeout,
  }) => _send(
    () async => _http.get(await _uri(path, query), headers: _headers),
    timeout: timeout,
  );

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) => _send(
    () async => _http.post(
      await _uri(path, null),
      headers: _headers,
      body: _encode(body),
    ),
    timeout: timeout,
  );

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? body,
    Duration? timeout,
  }) => _send(
    () async => _http.put(
      await _uri(path, null),
      headers: _headers,
      body: _encode(body),
    ),
    timeout: timeout,
  );

  Future<Map<String, dynamic>> deleteJson(String path) => _send(
    () async => _http.delete(await _uri(path, null), headers: _headers),
  );

  // ---------------------------------------------------------------------------

  Map<String, String> get _headers => <String, String>{
    'accept': 'application/json',
    'content-type': 'application/json',
    if (_accessToken != null) 'authorization': 'Bearer $_accessToken',
  };

  String? _encode(Map<String, dynamic>? body) =>
      body == null ? null : jsonEncode(body);

  Future<Uri> _uri(String path, Map<String, String>? query) async {
    final Uri base = Uri.parse(await _resolveBaseUrl());
    // Join without hardcoding a leading slash so a base URL with or without a
    // trailing path both behave.
    final String basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    final String subPath = path.startsWith('/') ? path : '/$path';

    return base.replace(
      path: '$basePath$subPath',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }

  Future<String> _resolveBaseUrl() async {
    if (!config.autoDiscoverBackend) return config.apiBaseUrl;
    final String? discovered = _discoveredBaseUrl;
    if (discovered != null) return discovered;

    final Future<String>? pending = _discoveryInProgress;
    if (pending != null) return pending;

    final Future<String> discovery = BackendDiscovery.discover(
      timeout: config.backendDiscoveryTimeout,
    );
    _discoveryInProgress = discovery;
    try {
      final String resolved = await discovery;
      _discoveredBaseUrl = resolved;
      return resolved;
    } finally {
      if (identical(_discoveryInProgress, discovery)) {
        _discoveryInProgress = null;
      }
    }
  }

  Future<http.Response> _requestWithRecovery(
    Future<http.Response> Function() request,
    Duration budget,
  ) async {
    try {
      return await request().timeout(budget);
    } on SocketException {
      if (!config.autoDiscoverBackend || _discoveredBaseUrl == null) rethrow;
      // The PC may have received a different hotspot address since the last
      // call. Rediscover once and retry this request.
      _discoveredBaseUrl = null;
      return request().timeout(budget + config.backendDiscoveryTimeout);
    }
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration? timeout,
  }) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Duration budget = timeout ?? config.requestTimeout;

    try {
      final http.Response response = await _requestWithRecovery(
        request,
        budget,
      );
      stopwatch.stop();
      _log(response, stopwatch.elapsedMilliseconds);
      return _decode(response);
    } on TimeoutException catch (error) {
      _logTimeout(stopwatch.elapsedMilliseconds);
      throw AppFailure.network(
        message: 'The server took too long to respond.',
        debugDetail: 'Timeout after ${budget.inSeconds}s: $error',
      );
    } on BackendDiscoveryException catch (error) {
      _logTimeout(stopwatch.elapsedMilliseconds);
      throw AppFailure.network(
        message: 'Could not find the Carvexa backend on this network. Start the backend on your PC and connect both devices to the same hotspot.',
        debugDetail: error.toString(),
      );
    } on SocketException catch (error) {
      _logTimeout(stopwatch.elapsedMilliseconds);
      throw AppFailure.network(
        message: config.autoDiscoverBackend
            ? 'The backend was found, but its API could not be reached. Check that it is running and that port 4000 is allowed through the PC firewall.'
            : 'Could not reach the server.',
        debugDetail: 'SocketException: $error',
      );
    } on http.ClientException catch (error) {
      _logTimeout(stopwatch.elapsedMilliseconds);
      throw AppFailure.network(debugDetail: 'ClientException: $error');
    } on AppFailure {
      rethrow;
    } catch (error) {
      _logTimeout(stopwatch.elapsedMilliseconds);
      throw AppFailure.unknown(debugDetail: 'Unexpected error: $error');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final int status = response.statusCode;

    if (status >= 200 && status < 300) {
      // 204 and empty bodies are legitimate (e.g. DELETE).
      if (response.bodyBytes.isEmpty) return <String, dynamic>{};

      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException catch (error) {
        throw AppFailure.unknown(
          message: 'The server sent a response the app could not read.',
          debugDetail: 'FormatException on HTTP $status: $error',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw AppFailure.unknown(
          message: 'The server sent a response the app could not read.',
          debugDetail: 'Expected a JSON object, got ${decoded.runtimeType}',
        );
      }
      return decoded;
    }

    throw _failureFromErrorResponse(response, status);
  }

  AppFailure _failureFromErrorResponse(http.Response response, int status) {
    String? code;
    String? serverMessage;

    try {
      final Object? decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic> &&
          decoded['error'] is Map<String, dynamic>) {
        final Map<String, dynamic> error =
            decoded['error'] as Map<String, dynamic>;
        code = error['code'] as String?;
        serverMessage = error['message'] as String?;
      }
    } catch (_) {
      // Non-JSON error body: keep the generic message, log the status only.
    }

    if (status >= 500) {
      return AppFailure.server(
        message: 'The service is temporarily unavailable. Please try again.',
        code: code,
        debugDetail: 'HTTP $status: ${serverMessage ?? response.reasonPhrase}',
      );
    }

    if (status == 404) {
      return AppFailure(
        kind: FailureKind.server,
        message: serverMessage ?? 'That item could not be found.',
        retryable: false,
        code: code,
        debugDetail: 'HTTP 404',
      );
    }

    if (status == 401 || status == 403) {
      return AppFailure(
        kind: FailureKind.server,
        message: serverMessage ?? 'You do not have access to that.',
        retryable: false,
        code: code,
        debugDetail: 'HTTP $status',
      );
    }

    if (status == 429) {
      return const AppFailure(
        kind: FailureKind.server,
        message: 'Too many requests. Wait a moment and try again.',
        retryable: true,
      );
    }

    return AppFailure(
      kind: FailureKind.validation,
      message: serverMessage ?? 'That request was not valid.',
      retryable: false,
      code: code,
      debugDetail: 'HTTP $status',
    );
  }

  // Metadata-only logging. Bodies, headers and query values are never logged
  // because they can carry customer data.
  void _log(http.Response response, int elapsedMs) {
    if (!config.enableVerboseNetworkLogs) return;
    debugPrint(
      '[api] ${response.request?.method ?? 'GET'} '
      '${response.request?.url.path ?? '?'} -> ${response.statusCode} (${elapsedMs}ms)',
    );
  }

  void _logTimeout(int elapsedMs) {
    if (!config.enableVerboseNetworkLogs) return;
    debugPrint('[api] request failed after ${elapsedMs}ms');
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';

abstract interface class SessionStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

class SecureSessionStore implements SessionStore {
  const SecureSessionStore({this._storage = const FlutterSecureStorage()});

  final FlutterSecureStorage _storage;
  static const String _key = 'carvexa_access_token';

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String token) =>
      _storage.write(key: _key, value: token);

  @override
  Future<void> clearToken() => _storage.delete(key: _key);
}

/// In-memory session storage for widget tests and previews.
class MemorySessionStore implements SessionStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}

class AccountController extends ChangeNotifier {
  AccountController({required this.apiClient, required this.sessionStore});

  final ApiClient apiClient;
  final SessionStore sessionStore;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? get profile =>
      _profile == null ? null : Map.unmodifiable(_profile!);
  bool get isAuthenticated => _profile != null;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _restored = false;
  bool get isRestored => _restored;
  int _sessionGeneration = 0;
  Future<void>? _restoreRequest;

  Future<void> restoreSession() {
    if (_restored) return Future<void>.value();
    final Future<void>? active = _restoreRequest;
    if (active != null) return active;

    final int generation = _sessionGeneration;
    late final Future<void> request;
    request = _restoreSession(generation).whenComplete(() {
      if (identical(_restoreRequest, request)) _restoreRequest = null;
    });
    _restoreRequest = request;
    return request;
  }

  Future<void> _restoreSession(int generation) async {
    String? token;
    try {
      token = await sessionStore.readToken();
      if (generation != _sessionGeneration) return;
      if (token != null && token.isNotEmpty) {
        apiClient.setAccessToken(token);
        final Map<String, dynamic> envelope = await apiClient.getJson(
          '/users/me',
        );
        if (generation != _sessionGeneration) return;
        final Object? data = envelope['data'];
        if (data is Map<String, dynamic>) _profile = data;
      }
    } on AppFailure catch (failure) {
      if (generation != _sessionGeneration) return;
      if (failure.code == 'unauthorized') {
        apiClient.setAccessToken(null);
        try {
          await sessionStore.clearToken();
        } catch (_) {
          // A stale credential must not prevent the app from starting.
        }
      } else if (token != null) {
        apiClient.setAccessToken(token);
        _errorMessage = 'We could not reconnect your account. Check your connection and try again.';
      }
    } catch (_) {
      if (generation != _sessionGeneration) return;
      apiClient.setAccessToken(null);
      try {
        await sessionStore.clearToken();
      } catch (_) {
        // A storage failure is recoverable; leave the account signed out.
      }
    } finally {
      if (generation == _sessionGeneration) {
        _restored = true;
        notifyListeners();
      }
    }
  }

  Future<bool> signIn({required String email, required String password}) =>
      _authenticate('/auth/login', <String, dynamic>{
        'email': email.trim(),
        'password': password,
      });

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
  }) => _authenticate('/auth/register', <String, dynamic>{
    'fullName': fullName.trim(),
    'email': email.trim(),
    'password': password,
  });

  Future<bool> _authenticate(String path, Map<String, dynamic> body) async {
    if (_isBusy) return false;
    final Future<void>? interruptedRestore = _restoreRequest;
    final int generation = ++_sessionGeneration;
    _setBusy(true);
    try {
      final Map<String, dynamic> envelope = await apiClient.postJson(
        path,
        body: body,
      );
      if (generation != _sessionGeneration) return false;
      final Object? data = envelope['data'];
      if (data is! Map<String, dynamic> ||
          data['token'] is! String ||
          data['user'] is! Map<String, dynamic>) {
        throw const AppFailure.unknown(
          message: 'The sign-in response was incomplete. Try again.',
        );
      }
      final String token = data['token'] as String;
      await sessionStore.writeToken(token);
      if (generation != _sessionGeneration) return false;
      apiClient.setAccessToken(token);
      _profile = data['user'] as Map<String, dynamic>;
      _restored = true;
      _errorMessage = null;
      return true;
    } on AppFailure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } catch (_) {
      _errorMessage = 'We could not save your session securely. Try again.';
      return false;
    } finally {
      _setBusy(false);
      if (interruptedRestore != null && !_restored) {
        unawaited(
          interruptedRestore.then((_) {
            if (!_restored) return restoreSession();
          }),
        );
      }
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> changes) async {
    if (!isAuthenticated || _isBusy) return false;
    _setBusy(true);
    try {
      final Map<String, dynamic> envelope = await apiClient.putJson(
        '/users/me',
        body: changes,
      );
      final Object? data = envelope['data'];
      if (data is! Map<String, dynamic>) throw const AppFailure.unknown();
      _profile = data;
      _errorMessage = null;
      return true;
    } on AppFailure catch (failure) {
      _errorMessage = failure.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    if (_isBusy) return;
    _sessionGeneration++;
    _setBusy(true);
    try {
      if (isAuthenticated) await apiClient.postJson('/auth/logout');
    } catch (_) {
      // Local sign-out still removes the credential from this device.
    } finally {
      apiClient.setAccessToken(null);
      try {
        await sessionStore.clearToken();
      } catch (_) {
        // The in-memory client is still cleared even if device storage fails.
      }
      _profile = null;
      _errorMessage = null;
      _restored = true;
      _setBusy(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_car_project/core/config/app_config.dart';
import 'package:flutter_car_project/core/network/api_client.dart';
import 'package:flutter_car_project/presentation/state/account_controller.dart';

const AppConfig _config = AppConfig(
  apiBaseUrl: 'http://localhost:4000/api',
  requestTimeout: Duration(seconds: 2),
  enableVerboseNetworkLogs: false,
);

http.Response _json(Object body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: const <String, String>{'content-type': 'application/json'},
);

Map<String, dynamic> _session(String token) => <String, dynamic>{
  'data': <String, dynamic>{
    'token': token,
    'user': <String, dynamic>{
      'id': 'user-1',
      'fullName': 'Ada Lovelace',
      'email': 'ada@example.com',
    },
  },
};

void main() {
  test('register saves the returned session and sign-out clears it', () async {
    final List<http.Request> requests = <http.Request>[];
    final ApiClient client = ApiClient(
      config: _config,
      httpClient: MockClient((http.Request request) async {
        requests.add(request);
        if (request.url.path.endsWith('/auth/register')) {
          return _json(_session('register-token'));
        }
        if (request.url.path.endsWith('/auth/logout')) {
          return _json({
            'data': {'loggedOut': true},
          });
        }
        return _json({
          'error': {'code': 'unexpected'},
        }, status: 404);
      }),
    );
    final MemorySessionStore store = MemorySessionStore();
    final AccountController account = AccountController(
      apiClient: client,
      sessionStore: store,
    );
    addTearDown(account.dispose);
    addTearDown(client.close);

    expect(
      await account.register(
        fullName: ' Ada Lovelace ',
        email: ' ada@example.com ',
        password: 'secret-password',
      ),
      isTrue,
    );
    expect(account.isAuthenticated, isTrue);
    expect(await store.readToken(), 'register-token');
    expect(jsonDecode(requests.first.body), <String, dynamic>{
      'fullName': 'Ada Lovelace',
      'email': 'ada@example.com',
      'password': 'secret-password',
    });

    await account.signOut();
    expect(account.isAuthenticated, isFalse);
    expect(await store.readToken(), isNull);
    expect(requests.last.headers['authorization'], 'Bearer register-token');
  });

  test(
    'a late session restore cannot clear a successful login session',
    () async {
      final Completer<void> releaseRestore = Completer<void>();
      final Completer<void> restoreStarted = Completer<void>();
      final MemorySessionStore store = MemorySessionStore();
      await store.writeToken('old-token');
      final ApiClient client = ApiClient(
        config: _config,
        httpClient: MockClient((http.Request request) async {
          if (request.url.path.endsWith('/users/me')) {
            if (!restoreStarted.isCompleted) restoreStarted.complete();
            await releaseRestore.future;
            return _json({
              'error': {'code': 'unauthorized'},
            }, status: 401);
          }
          if (request.url.path.endsWith('/auth/login')) {
            return _json(_session('fresh-token'));
          }
          return _json({
            'error': {'code': 'unexpected'},
          }, status: 404);
        }),
      );
      final AccountController account = AccountController(
        apiClient: client,
        sessionStore: store,
      );
      addTearDown(account.dispose);
      addTearDown(client.close);

      final Future<void> restore = account.restoreSession();
      await restoreStarted.future.timeout(const Duration(seconds: 1));
      expect(
        await account.signIn(
          email: 'ada@example.com',
          password: 'secret-password',
        ),
        isTrue,
      );

      releaseRestore.complete();
      await restore;

      expect(account.isAuthenticated, isTrue);
      expect(account.profile?['id'], 'user-1');
      expect(await store.readToken(), 'fresh-token');
    },
  );
}

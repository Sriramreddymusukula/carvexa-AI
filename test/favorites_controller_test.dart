import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_car_project/core/config/app_config.dart';
import 'package:flutter_car_project/core/network/api_client.dart';
import 'package:flutter_car_project/presentation/state/favorites_controller.dart';

import 'support/fake_car_catalog_repository.dart';

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

Map<String, dynamic> _favorite() => <String, dynamic>{
  'data': <String, dynamic>{
    'id': 'favorite-new-nexon',
    'externalCarId': kNewNexon.id,
    'vehicleType': 'new',
    'snapshot': <String, dynamic>{'title': 'Tata Nexon', 'model': 'Nexon'},
  },
};

void main() {
  test('waits for the saved list before add/remove so a late read cannot undo a change', () async {
    final Completer<void> releaseList = Completer<void>();
    final Completer<void> listStarted = Completer<void>();
    final List<http.Request> requests = <http.Request>[];
    final ApiClient client = ApiClient(
      config: _config,
      httpClient: MockClient((http.Request request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path.endsWith('/favorites')) {
          if (!listStarted.isCompleted) listStarted.complete();
          await releaseList.future;
          return _json({'data': <dynamic>[]});
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/favorites')) {
          return _json(_favorite());
        }
        if (request.method == 'DELETE' &&
            request.url.path.endsWith('/favorites/favorite-new-nexon')) {
          return http.Response('', 204);
        }
        return _json({
          'error': {'code': 'unexpected'},
        }, status: 404);
      }),
    );
    final FavoritesController favorites = FavoritesController(
      apiClient: client,
    );
    addTearDown(favorites.dispose);
    addTearDown(client.close);

    final Future<void> loading = favorites.load();
    await listStarted.future.timeout(const Duration(seconds: 1));
    final Future<bool> adding = favorites.toggle(kNewNexon);
    await Future<void>.delayed(Duration.zero);
    expect(
      requests.where((http.Request request) => request.method == 'POST'),
      isEmpty,
    );

    releaseList.complete();
    await loading;
    expect(await adding, isTrue);
    expect(favorites.contains(kNewNexon.id), isTrue);

    expect(await favorites.toggle(kNewNexon), isTrue);
    expect(favorites.contains(kNewNexon.id), isFalse);
    expect(requests.last.method, 'DELETE');
  });
}

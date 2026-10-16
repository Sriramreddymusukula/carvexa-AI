import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_car_project/core/config/app_config.dart';
import 'package:flutter_car_project/core/error/app_failure.dart';
import 'package:flutter_car_project/core/network/api_client.dart';
import 'package:flutter_car_project/core/utils/view_state.dart';
import 'package:flutter_car_project/data/models/car_catalog_page.dart';
import 'package:flutter_car_project/data/models/car_detail.dart';
import 'package:flutter_car_project/data/models/car_preview.dart';
import 'package:flutter_car_project/data/repositories/car_catalog_repository.dart';
import 'package:flutter_car_project/data/services/car_catalog_dto.dart';
import 'package:flutter_car_project/presentation/state/catalog_controller.dart';

import 'support/fake_car_catalog_repository.dart';

const AppConfig _config = AppConfig(
  apiBaseUrl: 'http://localhost:4000/api',
  requestTimeout: Duration(seconds: 5),
  enableVerboseNetworkLogs: false,
);

/// Builds an API client whose transport is a scripted fake, so the repository
/// can be tested without a backend.
ApiClient _clientReturning(
  Map<String, dynamic> body, {
  int status = 200,
  void Function(http.BaseRequest request)? onRequest,
}) {
  return ApiClient(
    config: _config,
    httpClient: MockClient((http.Request request) async {
      onRequest?.call(request);
      return http.Response(
        jsonEncode(body),
        status,
        headers: const <String, String>{'content-type': 'application/json'},
      );
    }),
  );
}

void main() {
  group('DTO mapping', () {
    test('maps a used listing, keeping the provider title as-is', () {
      final CarPreview? car = CarCatalogDto.car(<String, dynamic>{
        'id': 'abc',
        'title': 'Volvo XC90 B5 AWD',
        'model': 'Volvo XC90',
        'variant': 'B5 AWD',
        'source': 'used',
        'year': 2026,
        'price': 6500000,
        'formattedPrice': '₹65 Lakh',
        'mileageKm': 21500,
        'city': 'Gurgaon',
        'imageUrl': 'https://images.example/car.jpg',
        'detailAvailable': true,
      });

      expect(car, isNotNull);
      expect(car!.title, 'Volvo XC90 B5 AWD');
      // The source publishes no brand for used listings, so none is invented.
      expect(car.make, isNull);
      expect(car.mileageLabel, '21,500 km');
      expect(car.priceAvailable, isTrue);
      expect(car.detailAvailable, isTrue);
    });

    test('treats an unpublished price as unavailable, not as zero', () {
      final CarPreview? car = CarCatalogDto.car(<String, dynamic>{
        'id': 'abc',
        'title': 'Tata Nexon',
        'model': 'Nexon',
        'source': 'new',
        'price': null,
        'formattedPrice': null,
      });

      expect(car!.priceAvailable, isFalse);
      expect(car.formattedPrice, 'On-road estimate unavailable');
      expect(car.price, isNull);
    });

    test(
      'rejects a non-http image URL rather than passing it to the image widget',
      () {
        final CarPreview? car = CarCatalogDto.car(<String, dynamic>{
          'id': 'abc',
          'title': 'Tata Nexon',
          'model': 'Nexon',
          'source': 'new',
          'imageUrl': 'javascript:alert(1)',
        });

        expect(car!.imageUrl, isNull);
      },
    );

    test('drops a card that has no usable id, because it cannot be opened', () {
      expect(CarCatalogDto.car(<String, dynamic>{'title': 'No id'}), isNull);
    });

    test('survives wrong field types instead of throwing', () {
      final CarPreview? car = CarCatalogDto.car(<String, dynamic>{
        'id': 'abc',
        'title': 42,
        'model': null,
        'source': 'used',
        'year': 'not a year',
        'mileageKm': <String>[],
      });

      expect(car, isNotNull);
      expect(car!.title, '42');
      expect(car.year, isNull);
      expect(car.mileageKm, isNull);
    });
  });

  group('DTO page and detail', () {
    test('maps a page with its paging and capability metadata', () {
      final CarCatalogPage? page = CarCatalogDto.page(<String, dynamic>{
        'data': <String, dynamic>{
          'cars': <dynamic>[
            <String, dynamic>{
              'id': 'a',
              'title': 'A',
              'model': 'A',
              'source': 'used',
            },
          ],
          'source': 'used',
          'page': 1,
          'pageSize': 20,
          'hasMore': true,
          'totalKnown': false,
          'appliedFilters': <String, dynamic>{'city': 'new-delhi'},
          'capabilities': <String, dynamic>{
            'provider': 'parse-cardekho',
            'ready': true,
            'defaultSource': 'used',
            'sources': <dynamic>[
              <String, dynamic>{
                'id': 'used',
                'label': 'Used cars',
                'search': false,
                'pagination': true,
                'filters': <dynamic>[
                  <String, dynamic>{
                    'id': 'city',
                    'label': 'City',
                    'placeholder': 'new-delhi',
                    'examples': <dynamic>['new-delhi', 'mumbai'],
                  },
                ],
              },
            ],
          },
        },
      });

      expect(page, isNotNull);
      expect(page!.cars, hasLength(1));
      expect(page.hasMore, isTrue);
      expect(page.totalKnown, isFalse);
      expect(page.appliedFilters['city'], 'new-delhi');
      expect(page.capabilities.ready, isTrue);
      expect(page.capabilities.byId('used')!.pagination, isTrue);
      expect(
        page.capabilities.byId('used')!.filters.single.examples,
        contains('mumbai'),
      );
    });

    test('returns null for a malformed envelope so the repository can fail clearly', () {
      expect(
        CarCatalogDto.page(<String, dynamic>{'data': 'not an object'}),
        isNull,
      );
      expect(
        CarCatalogDto.detail(<String, dynamic>{'unexpected': true}),
        isNull,
      );
    });

    test('maps a detail, keeping unpublished sections absent', () {
      final detail = CarCatalogDto.detail(<String, dynamic>{
        'data': <String, dynamic>{
          'id': 'x',
          'source': 'new',
          'title': 'Tata Nexon',
          'model': 'Nexon',
          'priceRange': '7.40 - 14.52 Lakh',
          'images': <dynamic>[
            <String, dynamic>{'url': 'https://img/1.jpg', 'category': 'front'},
            <String, dynamic>{'url': 'not-a-url'},
          ],
          'spinImages': <dynamic>[
            <String, dynamic>{'url': 'https://img/spin-1.jpg'},
            <String, dynamic>{'url': 'https://img/spin-2.jpg'},
          ],
          'variants': <dynamic>[
            <String, dynamic>{'name': 'Nexon Smart', 'priceLabel': '7.40 Lakh'},
            <String, dynamic>{'priceLabel': 'orphan'},
          ],
          'variantCount': 18,
          'engineSpecs': <dynamic>[
            <String, dynamic>{'label': 'Engine', 'value': '1199 cc'},
            <String, dynamic>{'label': 'Empty', 'value': ''},
          ],
          'features': <dynamic>['Alloy wheels'],
        },
      });

      expect(detail, isNotNull);
      // The malformed image URL and the nameless variant are dropped.
      expect(detail!.images, hasLength(1));
      expect(detail.spinImages.map((CarImage image) => image.url), <String>[
        'https://img/spin-1.jpg',
        'https://img/spin-2.jpg',
      ]);
      expect(detail.variants, hasLength(1));
      expect(detail.engineSpecs, hasLength(1));
      // Unpublished sections stay empty rather than being filled in.
      expect(detail.specificationSections, isEmpty);
      expect(detail.hasTechnicalSpecs, isTrue);
      // The total is preserved so the UI can say it is showing a subset.
      expect(detail.variantCount, 18);
    });
  });

  group('repository over a scripted transport', () {
    test(
      'shares and retains catalog capabilities instead of refetching them',
      () async {
        final Completer<void> release = Completer<void>();
        int requestCount = 0;
        final RemoteCarCatalogRepository repository =
            RemoteCarCatalogRepository(
              apiClient: ApiClient(
                config: _config,
                httpClient: MockClient((http.Request request) async {
                  requestCount += 1;
                  await release.future;
                  return http.Response(
                    jsonEncode(<String, dynamic>{
                      'data': <String, dynamic>{
                        'provider': 'fixture',
                        'sources': <dynamic>[],
                      },
                    }),
                    200,
                    headers: const <String, String>{
                      'content-type': 'application/json',
                    },
                  );
                }),
              ),
            );

        final Future<CatalogCapabilities> first = repository
            .fetchCapabilities();
        final Future<CatalogCapabilities> duplicate = repository
            .fetchCapabilities();
        await Future<void>.delayed(Duration.zero);
        expect(requestCount, 1);
        release.complete();
        await Future.wait(<Future<CatalogCapabilities>>[first, duplicate]);
        await repository.fetchCapabilities();

        expect(requestCount, 1);
      },
    );

    test('sends only the filters that are set', () async {
      final List<Uri> seen = <Uri>[];
      final RemoteCarCatalogRepository repository = RemoteCarCatalogRepository(
        apiClient: _clientReturning(<String, dynamic>{
          'data': <String, dynamic>{'cars': <dynamic>[]},
        }, onRequest: (http.BaseRequest request) => seen.add(request.url)),
      );

      await repository.fetchCatalog(
        const CarCatalogQuery(source: 'used', city: 'new-delhi'),
      );
      await repository.fetchCatalog(
        const CarCatalogQuery(source: 'new', search: 'nexon'),
      );

      // An unset filter is omitted, not sent empty: the API rejects empty and
      // unknown query values.
      expect(seen[0].queryParameters, <String, String>{
        'source': 'used',
        'city': 'new-delhi',
      });
      expect(seen[1].queryParameters, <String, String>{
        'source': 'new',
        'q': 'nexon',
      });
    });

    test(
      'turns an unreadable body into an actionable parsing failure',
      () async {
        final RemoteCarCatalogRepository repository =
            RemoteCarCatalogRepository(
              apiClient: _clientReturning(<String, dynamic>{'nonsense': true}),
            );

        await expectLater(
          repository.fetchCatalog(const CarCatalogQuery()),
          throwsA(
            isA<AppFailure>().having(
              (AppFailure failure) => failure.kind,
              'kind',
              FailureKind.parsing,
            ),
          ),
        );
      },
    );

    test(
      'surfaces a server failure unchanged so the UI can offer a retry',
      () async {
        final RemoteCarCatalogRepository repository =
            RemoteCarCatalogRepository(
              apiClient: _clientReturning(<String, dynamic>{
                'error': <String, dynamic>{'code': 'service_unavailable'},
              }, status: 503),
            );

        await expectLater(
          repository.fetchCatalog(const CarCatalogQuery()),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  });

  group('catalog controller', () {
    test(
      'notifies the screen when the first load leaves its skeleton state',
      () async {
        final FakeCarCatalogRepository repository = FakeCarCatalogRepository();
        final CatalogController controller = CatalogController(
          repository: repository,
          debounce: const Duration(milliseconds: 10),
        );
        addTearDown(controller.dispose);
        final List<ViewState> observedStates = <ViewState>[];
        controller.addListener(
          () => observedStates.add(controller.snapshot.state),
        );

        await controller.start();

        expect(observedStates, contains(ViewState.data));
        expect(controller.snapshot.state, ViewState.data);
      },
    );

    test(
      'coalesces overlapping refreshes for the same catalog selection',
      () async {
        final FakeCarCatalogRepository repository = FakeCarCatalogRepository(
          latency: const Duration(milliseconds: 40),
        );
        final CatalogController controller = CatalogController(
          repository: repository,
        );
        addTearDown(controller.dispose);

        await controller.start();
        final Future<void> first = controller.refresh();
        final Future<void> duplicate = controller.refresh();
        await Future.wait(<Future<void>>[first, duplicate]);

        expect(repository.calls, hasLength(2));
      },
    );

    test('loads the default source and exposes data', () async {
      final FakeCarCatalogRepository repository = FakeCarCatalogRepository();
      final CatalogController controller = CatalogController(
        repository: repository,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      await controller.start();

      expect(controller.snapshot.state, ViewState.data);
      expect(controller.snapshot.data!.cars, isNotEmpty);
      expect(controller.capabilities.ready, isTrue);
      expect(controller.activeSource.id, 'used');
      // Used listings cannot be searched, so no search box is offered.
      expect(controller.supportsSearch, isFalse);
      expect(controller.supportsPagination, isTrue);
    });

    test('debounces typing into a single request', () async {
      final FakeCarCatalogRepository repository = FakeCarCatalogRepository();
      final CatalogController controller = CatalogController(
        repository: repository,
        debounce: const Duration(milliseconds: 40),
      );
      addTearDown(controller.dispose);

      await controller.start();
      controller.setSource('new');
      await Future<void>.delayed(Duration.zero);
      final int baseline = repository.calls.length;

      // Four keystrokes in quick succession.
      controller.search('n');
      controller.search('ne');
      controller.search('nex');
      controller.search('nexon');
      expect(
        controller.query.search,
        'nexon',
        reason: 'text updates immediately',
      );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      // One request, not four.
      expect(repository.calls.length - baseline, 1);
      expect(repository.calls.last.search, 'nexon');
    });

    test(
      'reaches the empty state and recovers when the search is cleared',
      () async {
        final FakeCarCatalogRepository repository = FakeCarCatalogRepository();
        final CatalogController controller = CatalogController(
          repository: repository,
          debounce: Duration.zero,
        );
        addTearDown(controller.dispose);

        await controller.start();
        controller.setSource('new');
        controller.search('zzzz-nothing');
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(controller.snapshot.state, ViewState.empty);
        expect(controller.isSearchActive, isTrue);

        controller.clearSearch();
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(controller.snapshot.state, ViewState.data);
      },
    );

    test('applies and clears a supported filter', () async {
      final FakeCarCatalogRepository repository = FakeCarCatalogRepository();
      final CatalogController controller = CatalogController(
        repository: repository,
        debounce: Duration.zero,
      );
      addTearDown(controller.dispose);

      await controller.start();
      controller.applyFilter('city', 'mumbai');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.hasActiveFilters, isTrue);
      expect(repository.calls.last.city, 'mumbai');
      expect(
        controller.snapshot.data!.cars.every(
          (CarPreview car) => car.city?.toLowerCase() == 'mumbai',
        ),
        isTrue,
      );

      controller.clearAllFilters();
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(controller.hasActiveFilters, isFalse);
      expect(repository.calls.last.city, isNull);
    });
  });
}

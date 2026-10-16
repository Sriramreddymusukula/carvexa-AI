// Live end-to-end verification of the Flutter data layer against the real
// backend and the real car catalogue.
//
// Deliberately OUTSIDE `test/`, so `flutter test` stays hermetic and offline.
// Run it explicitly, with the backend already serving:
//
//   cd backend && npm start
//   flutter test integration/live_catalog_test.dart
//
// It prints what the app would actually show, which is how Phase 4 verified the
// real catalogue end to end.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_car_project/core/config/app_config.dart';
import 'package:flutter_car_project/core/network/api_client.dart';
import 'package:flutter_car_project/data/models/car_catalog_page.dart';
import 'package:flutter_car_project/data/models/car_preview.dart';
import 'package:flutter_car_project/data/repositories/car_catalog_repository.dart';

void main() {
  test('reads the real catalogue through the real backend', () async {
    final AppConfig config = AppConfig.fromEnvironment();
    // ignore: avoid_print - this file exists to print what it observes
    print('backend: ${config.apiBaseUrl}');

    final ApiClient api = ApiClient(config: config);
    addTearDown(api.close);
    final RemoteCarCatalogRepository repository = RemoteCarCatalogRepository(
      apiClient: api,
    );

    final CatalogCapabilities capabilities = await repository.fetchCapabilities();
    // ignore: avoid_print
    print('capabilities ready : ${capabilities.ready}');
    // ignore: avoid_print
    print('provider           : ${capabilities.provider} (${capabilities.sourceName})');
    // ignore: avoid_print
    print('default source     : ${capabilities.defaultSource}');
    for (final CatalogSourceSpec source in capabilities.sources) {
      // ignore: avoid_print
      print(
        '  - ${source.id}: search=${source.search} pagination=${source.pagination} '
        'filters=${source.filters.map((CatalogFilterSpec f) => f.id).toList()}',
      );
    }

    expect(capabilities.ready, isTrue, reason: 'the catalogue must be configured');

    final CarCatalogPage used = await repository.fetchCatalog(const CarCatalogQuery());
    // ignore: avoid_print
    print('\nUSED cars=${used.cars.length} hasMore=${used.hasMore}');
    for (final CarPreview car in used.cars.take(4)) {
      // ignore: avoid_print
      print(
        '  ${car.title} | ${car.formattedPrice} | ${car.city ?? '-'} | '
        '${car.mileageLabel ?? '-'} | image=${car.imageUrl != null} | '
        'openable=${car.detailAvailable}',
      );
    }
    expect(used.cars, isNotEmpty, reason: 'the catalogue must return vehicles');

    final CarCatalogPage search = await repository.fetchCatalog(
      const CarCatalogQuery(source: 'new', search: 'tata nexon'),
    );
    // ignore: avoid_print
    print('\nSEARCH "tata nexon" -> ${search.cars.length} result(s)');
    for (final CarPreview car in search.cars.take(5)) {
      // ignore: avoid_print
      print('  ${car.title} | ${car.formattedPrice}');
    }
    expect(search.cars, isNotEmpty, reason: 'search must find a real vehicle');

    final detail = await repository.fetchCar(used.cars.first.id);
    // ignore: avoid_print
    print('\nLISTING DETAIL ${detail.title}');
    // ignore: avoid_print
    print('  price        : ${detail.formattedPrice}');
    // ignore: avoid_print
    print('  images       : ${detail.images.length}');
    // ignore: avoid_print
    print('  key facts    : ${detail.keyFacts.map((f) => '${f.label}=${f.value}').join(', ')}');
    // ignore: avoid_print
    print('  overview rows: ${detail.overview.length}');

    final CarCatalogPage newCars = await repository.fetchCatalog(
      const CarCatalogQuery(source: 'new'),
    );
    if (newCars.cars.isNotEmpty) {
      final model = await repository.fetchCar(newCars.cars.first.id);
      // ignore: avoid_print
      print('\nMODEL DETAIL ${model.title}');
      // ignore: avoid_print
      print('  price range  : ${model.priceRange}');
      // ignore: avoid_print
      print('  body / fuel  : ${model.bodyType} / ${model.fuelTypes.join(', ')}');
      // ignore: avoid_print
      print('  safety       : ${model.safetyRating}');
      // ignore: avoid_print
      print('  images       : ${model.images.length}');
      // ignore: avoid_print
      print('  variants     : ${model.variants.length} of ${model.variantCount}');
      // ignore: avoid_print
      print('  engine specs : ${model.engineSpecs.length}');
      // ignore: avoid_print
      print('  dimensions   : ${model.dimensions.length}');
      // ignore: avoid_print
      print('  spec sections: ${model.specificationSections.length}');
    }

    // ignore: avoid_print
    print('\nlive check completed');
  });
}

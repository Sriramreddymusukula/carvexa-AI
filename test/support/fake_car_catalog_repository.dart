import 'package:flutter_car_project/core/error/app_failure.dart';
import 'package:flutter_car_project/data/models/car_catalog_page.dart';
import 'package:flutter_car_project/data/models/car_detail.dart';
import 'package:flutter_car_project/data/models/car_preview.dart';
import 'package:flutter_car_project/data/repositories/car_catalog_repository.dart';

/// Fixture data for the double above.
///
/// Shapes match what the backend really returns, including the awkward cases:
/// a model with no published price, a listing with no photograph, and a vehicle
/// that has no brand field at all.
const CatalogCapabilities kFakeCapabilities = CatalogCapabilities(
  provider: 'fake',
  ready: true,
  sourceName: 'Test catalogue',
  defaultSource: 'used',
  sources: <CatalogSourceSpec>[
    CatalogSourceSpec(
      id: 'used',
      label: 'Used cars',
      description: 'Live used-car listings with real prices and photographs.',
      search: false,
      pagination: true,
      filters: <CatalogFilterSpec>[
        CatalogFilterSpec(
          id: 'city',
          label: 'City',
          placeholder: 'new-delhi',
          examples: <String>['new-delhi', 'mumbai'],
        ),
      ],
    ),
    CatalogSourceSpec(
      id: 'new',
      label: 'New cars',
      description: 'Current new-car models with published specifications.',
      search: true,
      pagination: false,
      filters: <CatalogFilterSpec>[
        CatalogFilterSpec(
          id: 'brand',
          label: 'Brand',
          placeholder: 'tata',
          examples: <String>['tata', 'hyundai'],
        ),
      ],
    ),
  ],
  notes: <String>['Fixture catalogue used by tests.'],
);

const CarPreview kUsedVolvo = CarPreview(
  id: 'used-volvo',
  title: 'Volvo XC90 B5 AWD',
  model: 'Volvo XC90',
  variant: 'B5 AWD',
  source: 'used',
  year: 2026,
  price: 6500000,
  priceLabel: '₹65 Lakh',
  mileageKm: 21500,
  fuelType: 'Petrol',
  transmission: 'Automatic',
  city: 'Gurgaon',
  owner: 'First owner',
  // A deliberately broken URL: the card must degrade to the placeholder rather
  // than showing a broken frame.
  imageUrl: 'https://example.invalid/missing.jpg',
  detailAvailable: true,
);

const CarPreview kUsedMini = CarPreview(
  id: 'used-mini',
  title: 'Mini Cooper S',
  model: 'Mini Cooper S',
  source: 'used',
  year: 2024,
  price: 2450000,
  priceLabel: '₹24.5 Lakh',
  mileageKm: 9100,
  fuelType: 'Petrol',
  transmission: 'Manual',
  city: 'Mumbai',
  owner: 'First owner',
  // No photograph at all: the image component must draw its placeholder.
  detailAvailable: true,
);

const CarPreview kNewNexon = CarPreview(
  id: 'new-nexon',
  title: 'Tata Nexon',
  model: 'Nexon',
  make: 'Tata',
  source: 'new',
  bodyType: 'SUV',
  // No published price: no Hyderabad estimate can be calculated.
  imageUrl: 'https://example.invalid/nexon.jpg',
  detailAvailable: true,
);

const CarPreview kNewCreta = CarPreview(
  id: 'new-creta',
  title: 'Hyundai Creta',
  model: 'Creta',
  make: 'Hyundai',
  source: 'new',
  bodyType: 'SUV',
  detailAvailable: true,
);

const List<CarPreviewRecord> kFakeCars = <CarPreviewRecord>[
  CarPreviewRecord(kUsedVolvo, bodyType: 'SUV'),
  CarPreviewRecord(kUsedMini),
  // Enough used cards to exercise "load more" (page size 2 in the tests).
  CarPreviewRecord(
    CarPreview(
      id: 'used-tata',
      title: 'Tata Harrier XZ',
      model: 'Tata Harrier',
      variant: 'XZ',
      source: 'used',
      year: 2023,
      price: 1800000,
      priceLabel: '₹18 Lakh',
      city: 'Gurgaon',
    ),
  ),
  CarPreviewRecord(
    CarPreview(
      id: 'used-hyundai',
      title: 'Hyundai i20 Sportz',
      model: 'Hyundai i20',
      variant: 'Sportz',
      source: 'used',
      year: 2022,
      price: 900000,
      priceLabel: '₹9 Lakh',
      city: 'Mumbai',
    ),
  ),
  CarPreviewRecord(kNewNexon, brand: 'tata'),
  CarPreviewRecord(kNewCreta, brand: 'hyundai'),
];

const CarDetail kFakeDetail = CarDetail(
  id: 'new-nexon',
  source: 'new',
  title: 'Tata Nexon',
  model: 'Nexon',
  make: 'Tata',
  priceRange: '7.40 - 14.52 Lakh',
  priceLabel: '7.40 - 14.52 Lakh',
  bodyType: 'SUV',
  fuelTypes: <String>['CNG', 'Diesel', 'Petrol'],
  mileage: '17.44 - 20.15 kmpl',
  safetyRating: '5 Star',
  seatingCapacity: '5',
  images: <CarImage>[
    CarImage(
      url: 'https://example.invalid/nexon-1.jpg',
      alt: 'Tata Nexon Front Left Side',
      category: 'front left side',
    ),
    CarImage(url: 'https://example.invalid/nexon-2.jpg', category: 'rear view'),
  ],
  variants: <CarVariant>[
    CarVariant(name: 'Nexon Smart', priceLabel: '7.40 Lakh', summary: '1199 cc, Manual, Petrol'),
    CarVariant(name: 'Nexon Fearless', priceLabel: '9.25 Lakh', summary: '1199 cc, Automatic'),
  ],
  variantCount: 2,
  features: <String>['All-adjustable Headrests', 'Rear AC vents'],
  featureCount: 2,
  engineSpecs: <CarSpecRow>[
    CarSpecRow(label: 'Engine', value: '1199 cc - 1497 cc'),
    CarSpecRow(label: 'Max power', value: '99 - 118.27 bhp'),
  ],
  dimensions: <CarSpecRow>[
    CarSpecRow(label: 'Length', value: '3995 mm'),
    CarSpecRow(label: 'Boot space', value: '382 Litres'),
  ],
  specificationSections: <CarSpecSection>[
    CarSpecSection(
      title: 'Engine & Transmission',
      items: <CarSpecRow>[CarSpecRow(label: 'Engine Type', value: '1.2L T-GDi')],
    ),
  ],
);

/// A failure a test can inject to exercise the error and retry paths.
const AppFailure kFakeFailure = AppFailure(
  kind: FailureKind.network,
  message: 'No connection. Check your network and try again.',
);


/// In-memory test double for the real car catalogue.
///
/// Lives in `test/`, never in `lib/`, so the application ships with **no**
/// sample cars. Its records mirror the shapes the backend really returns —
/// including a card with no published price and a card with no photograph —
/// because those are the cases the UI has to survive.
class FakeCarCatalogRepository implements CarCatalogRepository {
  FakeCarCatalogRepository({
    this.cars = kFakeCars,
    this.pageSize = 4,
    this.failure,
    this.detail,
    this.detailFailure,
    this.latency = Duration.zero,
  });

  /// Every call made against the double, so a test can assert on paging,
  /// debouncing and filter forwarding without a network.
  final List<CarCatalogQuery> calls = <CarCatalogQuery>[];

  final List<CarPreviewRecord> cars;
  final int pageSize;

  /// When set, every list call fails with this — drives the error/retry tests.
  final AppFailure? failure;

  /// Overrides the detail returned, for gallery/empty cases.
  final CarDetail? detail;
  final AppFailure? detailFailure;

  /// Artificial delay before any list call resolves.
  ///
  /// This is how the tests reproduce the bug that made the catalogue look
  /// inverted: the source switch and the request land at different times, so a
  /// test can hold the *old* source's results on screen and assert they are not
  /// left there once the selection has moved on.
  final Duration latency;

  @override
  Future<CatalogCapabilities> fetchCapabilities() async => kFakeCapabilities;

  @override
  Future<CarCatalogPage> fetchCatalog(CarCatalogQuery query) async {
    calls.add(query);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (failure != null) throw failure!;

    final List<CarPreview> matched = cars
        .where((CarPreviewRecord record) => record.matches(query))
        .map((CarPreviewRecord record) => record.car)
        .toList(growable: false);

    final int start = (query.page - 1) * pageSize;
    if (start >= matched.length) {
      return _page(const <CarPreview>[], query, hasMore: false, total: matched.length);
    }

    final List<CarPreview> slice = matched.sublist(
      start,
      (start + pageSize) > matched.length ? matched.length : (start + pageSize),
    );

    return _page(slice, query, hasMore: start + pageSize < matched.length, total: matched.length);
  }

  @override
  Future<CarDetail> fetchCar(String id) async {
    if (detailFailure != null) throw detailFailure!;
    if (detail != null) return detail!;
    return kFakeDetail;
  }

  CarCatalogPage _page(
    List<CarPreview> slice,
    CarCatalogQuery query, {
    required bool hasMore,
    required int total,
  }) {
    return CarCatalogPage(
      cars: slice,
      source: query.source,
      page: query.page,
      pageSize: pageSize,
      hasMore: hasMore,
      totalKnown: true,
      appliedFilters: <String, String>{
        if (query.city != null) 'city': query.city!,
        if (query.brand != null) 'brand': query.brand!,
      },
      capabilities: kFakeCapabilities,
    );
  }
}

/// A record plus the matching rules the double applies, so the fake supports
/// search and filtering the way the real API does.
class CarPreviewRecord {
  const CarPreviewRecord(this.car, {this.brand = '', this.bodyType = ''});

  final CarPreview car;
  final String brand;
  final String bodyType;

  bool matches(CarCatalogQuery query) {
    if (car.source != query.source) return false;
    // The catalogue reports a display name ("Mumbai") while the filter is a slug
    // ("mumbai"), so the comparison is case-insensitive.
    if (query.city != null &&
        car.city?.toLowerCase() != query.city!.toLowerCase()) {
      return false;
    }
    if (query.brand != null && brand != query.brand) return false;

    final String needle = query.search.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return '${car.title} ${car.make ?? ''} ${car.model}'.toLowerCase().contains(needle);
  }
}

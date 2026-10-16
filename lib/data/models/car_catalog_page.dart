import 'package:flutter/foundation.dart';

import 'car_preview.dart';

/// One page of catalogue cards plus everything the UI needs to render itself.
///
/// [capabilities] is not decoration: the screen builds its search box, its
/// filters and its load-more affordance from it, which is what guarantees a
/// control never appears unless it would really change the result set.
@immutable
class CarCatalogPage {
  const CarCatalogPage({
    required this.cars,
    required this.source,
    required this.page,
    required this.pageSize,
    required this.hasMore,
    required this.totalKnown,
    required this.appliedFilters,
    required this.capabilities,
  });

  final List<CarPreview> cars;
  final String source;
  final int page;
  final int pageSize;
  final bool hasMore;

  /// False when the catalogue reports a total that cannot be trusted, in which
  /// case the UI shows "load more" instead of a result count.
  final bool totalKnown;

  final Map<String, String> appliedFilters;
  final CatalogCapabilities capabilities;

  bool get isEmpty => cars.isEmpty;

  /// Concatenates two pages for load-more, de-duplicated by id.
  CarCatalogPage append(CarCatalogPage next) => CarCatalogPage(
    cars: <CarPreview>[...cars, ...next.cars],
    source: source,
    page: next.page,
    pageSize: pageSize,
    hasMore: next.hasMore,
    totalKnown: totalKnown,
    appliedFilters: appliedFilters,
    capabilities: capabilities,
  );
}

/// A filter the catalogue can genuinely apply, with the example values its own
/// published specification documents.
@immutable
class CatalogFilterSpec {
  const CatalogFilterSpec({
    required this.id,
    required this.label,
    required this.placeholder,
    required this.examples,
  });

  final String id;
  final String label;
  final String placeholder;
  final List<String> examples;
}

/// One browsable catalogue and what it supports.
@immutable
class CatalogSourceSpec {
  const CatalogSourceSpec({
    required this.id,
    required this.label,
    required this.description,
    required this.search,
    required this.pagination,
    required this.filters,
  });

  final String id;
  final String label;
  final String description;

  /// True only where the catalogue really supports free-text search.
  final bool search;

  /// True only where the catalogue really pages.
  final bool pagination;

  final List<CatalogFilterSpec> filters;
}

/// Everything the app is allowed to offer, straight from the backend.
@immutable
class CatalogCapabilities {
  const CatalogCapabilities({
    required this.provider,
    required this.ready,
    required this.sources,
    this.sourceName,
    this.defaultSource,
    this.notes = const <String>[],
  });

  final String provider;
  final String? sourceName;

  /// False when no provider is configured server-side.
  final bool ready;

  final String? defaultSource;
  final List<CatalogSourceSpec> sources;
  final List<String> notes;

  CatalogSourceSpec? byId(String id) {
    for (final CatalogSourceSpec source in sources) {
      if (source.id == id) return source;
    }
    return null;
  }

  CatalogSourceSpec get fallback => sources.isEmpty
      ? const CatalogSourceSpec(
          id: 'used',
          label: 'Vehicles',
          description: '',
          search: false,
          pagination: false,
          filters: <CatalogFilterSpec>[],
        )
      : byId(defaultSource ?? sources.first.id) ?? sources.first;
}

/// The user's current selection of source, search text, filters and page.
///
/// Immutable and comparable by value, so the controller can tell a genuine
/// filter change (which must reset the list and refetch) from a re-render (which
/// must not).
@immutable
class CarCatalogQuery {
  const CarCatalogQuery({
    this.source = 'used',
    this.search = '',
    this.city,
    this.brand,
    this.page = 1,
  });

  final String source;
  final String search;
  final String? city;
  final String? brand;
  final int page;

  bool get isSearching => search.trim().isNotEmpty;
  bool get hasFilters => city != null || brand != null;

  CarCatalogQuery copyWith({
    String? source,
    String? search,
    String? city,
    String? brand,
    int? page,
    bool clearCity = false,
    bool clearBrand = false,
  }) {
    return CarCatalogQuery(
      source: source ?? this.source,
      search: search ?? this.search,
      city: clearCity ? null : (city ?? this.city),
      brand: clearBrand ? null : (brand ?? this.brand),
      page: page ?? this.page,
    );
  }

  /// Clears the text query and resets to the first page.
  CarCatalogQuery cleared() => CarCatalogQuery(source: source, city: city, brand: brand);

  /// True when the two selections would produce the same request, ignoring page.
  bool sameSelection(CarCatalogQuery other) =>
      source == other.source &&
      search.trim() == other.search.trim() &&
      city == other.city &&
      brand == other.brand;

  /// Query string for our backend. Empty values are omitted rather than sent,
  /// because the API rejects unknown and empty filters.
  Map<String, String> toParameters({int? pageOverride}) => <String, String>{
    'source': source,
    if (isSearching) 'q': search.trim(),
    if (city != null && city!.isNotEmpty) 'city': city!,
    if (brand != null && brand!.isNotEmpty) 'brand': brand!,
    if ((pageOverride ?? page) > 1) 'page': '${pageOverride ?? page}',
  };

  @override
  bool operator ==(Object other) =>
      other is CarCatalogQuery &&
      other.source == source &&
      other.search == search &&
      other.city == city &&
      other.brand == brand &&
      other.page == page;

  @override
  int get hashCode => Object.hash(source, search, city, brand, page);
}

import '../models/car_catalog_page.dart';
import '../models/car_detail.dart';
import '../models/car_preview.dart';

/// Maps our backend's JSON envelope onto application models.
///
/// This is the adapter layer the architecture requires: a widget never sees a
/// JSON key, and swapping the catalogue provider is a backend change plus
/// nothing here.
///
/// Every reader is defensive on purpose. A catalogue is live data — a field can
/// be missing, null, or occasionally the wrong type — and the correct response
/// to that is "treat it as not published", never an exception and never a
/// fabricated default.
abstract final class CarCatalogDto {
  // ------------------------------------------------------------- primitives --

  static String? _text(Object? value) {
    if (value == null) return null;
    final String text = value is String ? value : value.toString();
    final String trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _integer(Object? value) {
    if (value is int) return value;
    if (value is double && value.isFinite) return value.round();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static bool _flag(Object? value) => value == true;

  /// Only http(s) URLs reach an image widget, so a malformed or relative value
  /// is treated as "no photograph" rather than passed to `Image.network`.
  static String? _url(Object? value) {
    final String? text = _text(value);
    if (text == null || !text.startsWith('http')) return null;
    return text;
  }

  static List<String> _textList(Object? value) {
    if (value is! List) return const <String>[];
    return value.map(_text).whereType<String>().toList(growable: false);
  }

  static List<CarSpecRow> _rows(Object? value) {
    if (value is! List) return const <CarSpecRow>[];
    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (Map<String, dynamic> row) => CarSpecRow(
            label: _text(row['label']) ?? '',
            value: _text(row['value']) ?? '',
          ),
        )
        .where((CarSpecRow row) => row.label.isNotEmpty && row.value.isNotEmpty)
        .toList(growable: false);
  }

  /// Unwraps the `{ data, meta }` envelope, or null for a malformed body.
  static Map<String, dynamic>? _data(Map<String, dynamic> envelope) {
    final Object? data = envelope['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  // ------------------------------------------------------------------- cars --

  /// A catalogue card. Returns null when there is no usable id, because a card
  /// the user cannot open must not be rendered as though it worked.
  static CarPreview? car(Map<String, dynamic> json) {
    final String? id = _text(json['id']);
    final String title =
        _text(json['title']) ?? _text(json['model']) ?? 'Vehicle';
    final String? source = _text(json['source']);
    if (id == null || (source != 'new' && source != 'used')) return null;

    return CarPreview(
      id: id,
      title: title,
      model: _text(json['model']) ?? title,
      source: source!,
      make: _text(json['make']),
      variant: _text(json['variant']),
      year: _integer(json['year']),
      price: _integer(json['price']),
      priceLabel: _text(json['formattedPrice']),
      currency: _text(json['currency']) ?? 'INR',
      mileageKm: _integer(json['mileageKm']),
      fuelType: _text(json['fuelType']),
      transmission: _text(json['transmission']),
      bodyType: _text(json['bodyType']),
      city: _text(json['city']),
      owner: _text(json['owner']),
      imageUrl: _url(json['imageUrl']),
      detailAvailable: _flag(json['detailAvailable']),
    );
  }

  static CarCatalogPage? page(Map<String, dynamic> envelope) {
    final Map<String, dynamic>? data = _data(envelope);
    if (data == null) return null;

    final Object? rawCars = data['cars'];
    final List<CarPreview> cars = rawCars is List
        ? rawCars
              .whereType<Map<String, dynamic>>()
              .map(car)
              .whereType<CarPreview>()
              .toList(growable: false)
        : const <CarPreview>[];

    final Map<String, String> appliedFilters = <String, String>{};
    final Object? rawFilters = data['appliedFilters'];
    if (rawFilters is Map<String, dynamic>) {
      rawFilters.forEach((String key, Object? value) {
        final String? text = _text(value);
        if (text != null) appliedFilters[key] = text;
      });
    }

    return CarCatalogPage(
      cars: cars,
      source: _text(data['source']) ?? 'used',
      page: _integer(data['page']) ?? 1,
      pageSize: _integer(data['pageSize']) ?? cars.length,
      hasMore: _flag(data['hasMore']),
      totalKnown: _flag(data['totalKnown']),
      appliedFilters: appliedFilters,
      capabilities: capabilitiesOf(data['capabilities']),
    );
  }

  // ------------------------------------------------------------------ detail --

  static CarDetail? detail(Map<String, dynamic> envelope) {
    final Map<String, dynamic>? data = _data(envelope);
    if (data == null) return null;

    final String? id = _text(data['id']);
    final String? source = _text(data['source']);
    if (id == null || (source != 'new' && source != 'used')) return null;

    List<CarImage> parseImages(Object? raw) => raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> image) => CarImage(
                  url: _url(image['url']) ?? '',
                  alt: _text(image['alt']),
                  category: _text(image['category']),
                ),
              )
              .where((CarImage image) => image.url.isNotEmpty)
              .toList(growable: false)
        : const <CarImage>[];

    final List<CarImage> images = parseImages(data['images']);
    final List<CarImage> spinImages = parseImages(data['spinImages']);

    final List<CarVariant> variants = data['variants'] is List
        ? (data['variants'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> variant) => CarVariant(
                  name: _text(variant['name']) ?? '',
                  priceLabel: _text(variant['priceLabel']),
                  price: _integer(variant['price']),
                  fuelType: _text(variant['fuelType']),
                  summary: _text(variant['summary']),
                ),
              )
              .where((CarVariant variant) => variant.name.isNotEmpty)
              .toList(growable: false)
        : const <CarVariant>[];

    final List<CarSpecSection> sections = data['specificationSections'] is List
        ? (data['specificationSections'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> section) => CarSpecSection(
                  title: _text(section['title']) ?? 'Specifications',
                  items: _rows(section['items']),
                ),
              )
              .where((CarSpecSection section) => section.items.isNotEmpty)
              .toList(growable: false)
        : const <CarSpecSection>[];

    return CarDetail(
      id: id,
      source: source!,
      title: _text(data['title']) ?? 'Vehicle',
      model: _text(data['model']) ?? '',
      make: _text(data['make']),
      variant: _text(data['variant']),
      year: _integer(data['year']),
      price: _integer(data['price']),
      priceLabel: _text(data['formattedPrice']),
      priceRange: _text(data['priceRange']),
      currency: _text(data['currency']) ?? 'INR',
      bodyType: _text(data['bodyType']),
      fuelType: _text(data['fuelType']),
      fuelTypes: _textList(data['fuelTypes']),
      transmission: _text(data['transmission']),
      mileage: _text(data['mileage']),
      safetyRating: _text(data['safetyRating']),
      seatingCapacity: _text(data['seatingCapacity']),
      mileageKm: _integer(data['mileageKm']),
      city: _text(data['city']),
      owner: _text(data['owner']),
      images: images,
      spinImages: spinImages,
      variants: variants,
      variantCount: _integer(data['variantCount']) ?? variants.length,
      features: _textList(data['features']),
      featureCount: _integer(data['featureCount']) ?? 0,
      engineSpecs: _rows(data['engineSpecs']),
      dimensions: _rows(data['dimensions']),
      specificationSections: sections,
      overview: _rows(data['overview']),
      moreInfoUrl: _url(data['moreInfoUrl']),
      catalogOrigin: _text(data['catalogOrigin']),
    );
  }

  // ------------------------------------------------------------ capabilities --

  /// Never throws: an unreadable descriptor must still let the screen render its
  /// loading, empty and error states.
  static CatalogCapabilities capabilitiesOf(Object? value) {
    if (value is! Map<String, dynamic>) {
      return const CatalogCapabilities(
        provider: 'unknown',
        ready: false,
        sources: <CatalogSourceSpec>[],
      );
    }

    final List<CatalogSourceSpec> sources = value['sources'] is List
        ? (value['sources'] as List)
              .whereType<Map<String, dynamic>>()
              .map(
                (Map<String, dynamic> source) => CatalogSourceSpec(
                  id: _text(source['id']) ?? '',
                  label: _text(source['label']) ?? 'Vehicles',
                  description: _text(source['description']) ?? '',
                  search: _flag(source['search']),
                  pagination: _flag(source['pagination']),
                  filters: source['filters'] is List
                      ? (source['filters'] as List)
                            .whereType<Map<String, dynamic>>()
                            .map(
                              (Map<String, dynamic> filter) =>
                                  CatalogFilterSpec(
                                    id: _text(filter['id']) ?? '',
                                    label: _text(filter['label']) ?? 'Filter',
                                    placeholder:
                                        _text(filter['placeholder']) ?? '',
                                    examples: _textList(filter['examples']),
                                  ),
                            )
                            .where(
                              (CatalogFilterSpec filter) =>
                                  filter.id.isNotEmpty,
                            )
                            .toList(growable: false)
                      : const <CatalogFilterSpec>[],
                ),
              )
              .where((CatalogSourceSpec source) => source.id.isNotEmpty)
              .toList(growable: false)
        : const <CatalogSourceSpec>[];

    return CatalogCapabilities(
      provider: _text(value['provider']) ?? 'unknown',
      ready: _flag(value['ready']) && sources.isNotEmpty,
      sourceName: _text(value['sourceName']),
      defaultSource: _text(value['defaultSource']),
      sources: sources,
      notes: _textList(value['notes']),
    );
  }

  /// Capabilities from a full `GET /api/cars/capabilities` response.
  static CatalogCapabilities capabilities(Map<String, dynamic> envelope) =>
      capabilitiesOf(_data(envelope));
}

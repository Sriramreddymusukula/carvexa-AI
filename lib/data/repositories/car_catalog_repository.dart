import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../models/car_catalog_page.dart';
import '../models/car_detail.dart';
import '../services/car_catalog_dto.dart';

/// Source of the car catalogue.
///
/// The production [RemoteCarCatalogRepository] talks to our Express API. Screens
/// depend on this interface so catalog transport details stay in the data layer.
///
/// The repository deliberately exposes *our* vocabulary — a query, a page, a
/// detail — so the external catalogue is invisible above this line.
abstract interface class CarCatalogRepository {
  /// What the catalogue can do. Cheap, and safe to call on start-up.
  Future<CatalogCapabilities> fetchCapabilities();

  /// One page of catalogue cards for [query].
  Future<CarCatalogPage> fetchCatalog(CarCatalogQuery query);

  /// Full detail for one item, addressed by the opaque id we minted.
  Future<CarDetail> fetchCar(String id);
}

/// The real implementation, over our backend.
///
/// The provider key never appears here or anywhere above it: this class only
/// ever sends our own opaque ids and receives our own normalised shapes.
class RemoteCarCatalogRepository implements CarCatalogRepository {
  RemoteCarCatalogRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;
  CatalogCapabilities? _cachedCapabilities;
  Future<CatalogCapabilities>? _capabilitiesRequest;

  @override
  Future<CatalogCapabilities> fetchCapabilities() async {
    final CatalogCapabilities? cached = _cachedCapabilities;
    if (cached != null) return cached;

    final Future<CatalogCapabilities> request = _capabilitiesRequest ??=
        _fetchCapabilities();
    try {
      final CatalogCapabilities capabilities = await request;
      _cachedCapabilities ??= capabilities;
      return _cachedCapabilities!;
    } finally {
      if (identical(_capabilitiesRequest, request)) _capabilitiesRequest = null;
    }
  }

  Future<CatalogCapabilities> _fetchCapabilities() async {
    final Map<String, dynamic> envelope = await _api.getJson(
      '/cars/capabilities',
      timeout: _api.config.catalogRequestTimeout,
    );
    return CarCatalogDto.capabilities(envelope);
  }

  @override
  Future<CarCatalogPage> fetchCatalog(CarCatalogQuery query) async {
    final Map<String, dynamic> envelope = await _api.getJson(
      '/cars',
      // Empty values are omitted by the query object, which the API requires.
      query: query.toParameters(),
      timeout: _api.config.catalogRequestTimeout,
    );

    final CarCatalogPage? page = CarCatalogDto.page(envelope);
    if (page == null) throw _malformed();
    return page;
  }

  @override
  Future<CarDetail> fetchCar(String id) async {
    // The id is opaque and already URL-safe, but encoding keeps a future change
    // of id format from silently breaking the path.
    final Map<String, dynamic> envelope = await _api.getJson(
      '/cars/${Uri.encodeComponent(id)}',
      timeout: _api.config.catalogRequestTimeout,
    );

    final CarDetail? detail = CarCatalogDto.detail(envelope);
    if (detail == null) throw _malformed();
    return detail;
  }

  /// A body the app cannot read is a version mismatch worth naming, not a
  /// silently empty screen.
  AppFailure _malformed() => AppFailure(
    kind: FailureKind.parsing,
    message: 'The catalogue sent something the app could not read.',
    retryable: true,
    code: 'catalog_malformed',
  );
}

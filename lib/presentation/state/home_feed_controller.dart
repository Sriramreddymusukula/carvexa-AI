import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../core/utils/view_state.dart';
import '../../data/models/car_catalog_page.dart';
import '../../data/models/car_preview.dart';
import '../../data/repositories/car_catalog_repository.dart';

/// Home feed state.
///
/// A plain [ChangeNotifier] holding an immutable [ViewSnapshot]. That single
/// pattern covers every screen in the app, so loading, empty and error states
/// are handled identically everywhere — see `ViewSnapshot`.
///
/// The home screen shows the first page of the live new-car catalog and promotes its first car to the hero showcase. Nothing shown here is invented.
class HomeFeedController extends ChangeNotifier {
  HomeFeedController({required this.repository});

  final CarCatalogRepository repository;

  ViewSnapshot<List<CarPreview>> _snapshot = const ViewSnapshot<List<CarPreview>>.initial();
  ViewSnapshot<List<CarPreview>> get snapshot => _snapshot;

  CarPreview? _showcase;
  CarPreview? get showcase => _showcase;

  /// The catalogue the feed was rendered from, so the screen can label it.
  String _sourceLabel = 'Cars';
  String get sourceLabel => _sourceLabel;

  CatalogCapabilities _capabilities = const CatalogCapabilities(
    provider: 'unknown',
    ready: false,
    sources: <CatalogSourceSpec>[],
  );
  CatalogCapabilities get capabilities => _capabilities;

  /// Guards against a second request racing the first (fast taps, a retry
  /// while the original call is still in flight).
  bool _inFlight = false;
  bool _disposed = false;

  /// The catalogue home leads with.
  ///
  /// Home is the shop window, and a shopper opening a car app wants to see
  /// what they can buy new, not a page of second-hand listings. The backend's
  /// own default is the used catalogue, so asking for the default would put
  /// used cars on the front page.
  ///
  /// Home has a strict contract: if the provider does not expose a `new`
  /// source, show the unavailable/empty state rather than falling back to used
  /// listings.
  bool _hasNewSource(CatalogCapabilities capabilities) =>
      capabilities.sources.any((CatalogSourceSpec source) => source.id == 'new');

  Future<void> load({bool force = false}) async {
    if (_inFlight) return;
    if (!force && _snapshot.state == ViewState.data) return;

    _inFlight = true;
    _snapshot = _snapshot.hasData
        ? ViewSnapshot<List<CarPreview>>.refreshing(_snapshot.data!)
        : const ViewSnapshot<List<CarPreview>>.loading();
    notifyListeners();

    try {
      // Capabilities are free (the backend spends no provider credit on them)
      // and they are what says which source is the model index.
      if (!_capabilities.ready) {
        _capabilities = await repository.fetchCapabilities();
        if (_disposed) return;
      }

      if (!_hasNewSource(_capabilities)) {
        _sourceLabel = 'New cars';
        _showcase = null;
        _snapshot = const ViewSnapshot<List<CarPreview>>.empty();
        return;
      }

      final CarCatalogPage page = await repository.fetchCatalog(
        const CarCatalogQuery(source: 'new'),
      );
      if (_disposed) return;

      if (page.capabilities.ready) _capabilities = page.capabilities;
      _sourceLabel = 'New cars';

      // Treat the API's classification as an explicit contract, and keep the
      // Home boundary defensive if a provider ever returns a mixed response.
      final List<CarPreview> newCars = page.cars
          .where((CarPreview car) => car.source == 'new')
          .toList(growable: false);

      // One page, one hero: the first vehicle becomes the showcase and the rest
      // fill the grid.
      _showcase = newCars.isEmpty ? null : newCars.first;
      final List<CarPreview> rest = newCars.skip(1).toList(growable: false);

      _snapshot = newCars.isEmpty
          ? const ViewSnapshot<List<CarPreview>>.empty()
          : ViewSnapshot<List<CarPreview>>.data(rest.isEmpty ? newCars : rest);
    } on AppFailure catch (failure) {
      if (_disposed) return;
      _snapshot = ViewSnapshot<List<CarPreview>>.error(failure);
    } catch (error, stackTrace) {
      // An unexpected error must still reach the user as something actionable
      // rather than an infinite spinner.
      debugPrint('HomeFeedController.load failed: $error\n$stackTrace');
      _snapshot = ViewSnapshot<List<CarPreview>>.error(
        AppFailure.unknown(debugDetail: error.toString()),
      );
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Pull-to-refresh: always re-fetches.
  Future<void> refresh() => load(force: true);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

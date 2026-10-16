import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../core/utils/view_state.dart';
import '../../data/models/car_detail.dart';
import '../../data/repositories/car_catalog_repository.dart';

/// State for one vehicle's details page.
///
/// Identical shape to every other screen: an immutable [ViewSnapshot] covering
/// loading, data, empty, error, with retry. Created per detail page and
/// disposed with it, so leaving a vehicle and coming back always re-reads the
/// catalogue rather than showing a stale snapshot.
class CarDetailsController extends ChangeNotifier {
  CarDetailsController({required this.repository, required this.carId});

  final CarCatalogRepository repository;

  /// The opaque id from the card that was tapped.
  final String carId;

  ViewSnapshot<CarDetail> _snapshot = const ViewSnapshot<CarDetail>.initial();
  ViewSnapshot<CarDetail> get snapshot => _snapshot;

  bool _inFlight = false;
  bool _disposed = false;

  Future<void> load({bool force = false}) async {
    if (_inFlight) return;
    if (!force && _snapshot.state == ViewState.data) return;

    _inFlight = true;
    if (!_snapshot.hasData) {
      _snapshot = const ViewSnapshot<CarDetail>.loading();
    }
    notifyListeners();

    try {
      final CarDetail car = await repository.fetchCar(carId);
      if (_disposed) return;
      // A detail page always has content, so there is no empty case here.
      _snapshot = ViewSnapshot<CarDetail>.data(car);
    } on AppFailure catch (failure) {
      if (_disposed) return;
      _snapshot = ViewSnapshot<CarDetail>.error(failure);
    } catch (error, stackTrace) {
      if (_disposed) return;
      debugPrint('CarDetailsController.load failed: $error\n$stackTrace');
      _snapshot = ViewSnapshot<CarDetail>.error(
        AppFailure.unknown(debugDetail: error.toString()),
      );
    } finally {
      _inFlight = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> retry() => load(force: true);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

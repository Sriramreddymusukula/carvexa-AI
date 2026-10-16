import 'package:flutter/foundation.dart';

import '../../data/models/car_preview.dart';

/// The user's comparison shortlist.
///
/// A vehicle only means anything next to another vehicle, so the app keeps a
/// small shortlist of what the user is weighing up and compares them side by
/// side. It is deliberately a [ChangeNotifier] holding plain [CarPreview]s:
/// everything shown in the comparison is a value the catalogue actually
/// published, and nothing is derived, estimated or filled in.
///
/// Three is the ceiling because a fourth column stops being readable on a
/// phone, and a comparison nobody can read is not a comparison.
class CompareController extends ChangeNotifier {
  /// How many vehicles can be compared at once.
  static const int maxVehicles = 3;

  final List<CarPreview> _selected = <CarPreview>[];

  /// The vehicles currently being weighed up, in the order they were added.
  List<CarPreview> get selected => List<CarPreview>.unmodifiable(_selected);

  bool get isEmpty => _selected.isEmpty;

  /// True once there are enough vehicles for a side-by-side to mean anything.
  bool get canCompare => _selected.length >= 2;

  /// True when [car] is already on the shortlist.
  bool contains(String id) => _selected.any((CarPreview car) => car.id == id);

  /// Adds or removes [car]. Returns false when the shortlist is already full
  /// and the vehicle was not on it, so the caller can explain the refusal
  /// rather than silently ignoring the tap.
  bool toggle(CarPreview car) {
    if (contains(car.id)) {
      _selected.removeWhere((CarPreview item) => item.id == car.id);
      notifyListeners();
      return true;
    }

    if (_selected.length >= maxVehicles) return false;

    _selected.add(car);
    notifyListeners();
    return true;
  }

  void remove(String id) {
    final int before = _selected.length;
    _selected.removeWhere((CarPreview car) => car.id == id);
    if (_selected.length != before) notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }
}
import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../core/network/api_client.dart';
import '../../data/models/car_preview.dart';
import 'account_controller.dart';

@immutable
class FavoriteEntry {
  const FavoriteEntry({required this.id, required this.car});

  final String id;
  final CarPreview car;

  static FavoriteEntry? fromJson(Map<String, dynamic> json) {
    final Object? id = json['id'];
    final Object? rawSnapshot = json['snapshot'];
    final String? type = json['vehicleType'] as String?;
    if (id is! String ||
        rawSnapshot is! Map<String, dynamic> ||
        (type != 'new' && type != 'used')) {
      return null;
    }
    final Map<String, dynamic> snapshot = rawSnapshot;
    final String? title = snapshot['title'] as String?;
    final String? model = snapshot['model'] as String?;
    if (title == null || model == null) return null;

    return FavoriteEntry(
      id: id,
      car: CarPreview(
        id: json['externalCarId'] as String? ?? '',
        title: title,
        model: model,
        source: type!,
        make: snapshot['make'] as String?,
        variant: snapshot['trim'] as String?,
        owner: snapshot['owner'] as String?,
        year: _int(snapshot['year']),
        price: _int(snapshot['price']),
        priceLabel: snapshot['formattedPrice'] as String?,
        currency: snapshot['currency'] as String? ?? 'INR',
        mileageKm: _int(snapshot['mileage']),
        fuelType: snapshot['fuelType'] as String?,
        transmission: snapshot['transmission'] as String?,
        bodyType: snapshot['bodyType'] as String?,
        city: snapshot['location'] as String?,
        imageUrl: snapshot['imageUrl'] as String?,
        detailAvailable: true,
      ),
    );
  }

  static int? _int(Object? value) => value is num ? value.round() : null;
}

class FavoritesController extends ChangeNotifier {
  FavoritesController({required this.apiClient});

  final ApiClient apiClient;
  List<FavoriteEntry> _items = const <FavoriteEntry>[];
  List<FavoriteEntry> get items => List.unmodifiable(_items);

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _loaded = false;
  Future<void>? _activeLoad;
  AppFailure? _failure;
  AppFailure? get failure => _failure;
  final Set<String> _mutating = <String>{};
  String? _activeUserId;
  int _generation = 0;

  void syncAuthentication(AccountController account) {
    final Map<String, dynamic>? profile = account.profile;
    final String? userId = account.isAuthenticated && profile != null
        ? profile['id'] as String?
        : null;
    if (userId != _activeUserId) {
      _activeUserId = userId;
      _generation++;
      _items = const <FavoriteEntry>[];
      _loaded = false;
      _isLoading = false;
      _activeLoad = null;
      _failure = null;
      notifyListeners();
    }
    if (userId == null) {
      return;
    }
    if (!_loaded && !_isLoading) load();
  }

  bool contains(String carId) =>
      _items.any((FavoriteEntry item) => item.car.id == carId);
  bool isMutating(String carId) => _mutating.contains(carId);

  Future<void> load({bool retry = false}) {
    final Future<void>? active = _activeLoad;
    if (active != null) return active;
    if (_loaded && !retry) return Future<void>.value();

    final int generation = _generation;
    final Future<void> request = _load(generation);
    _activeLoad = request;
    return request;
  }

  Future<void> _load(int generation) async {
    _isLoading = true;
    _failure = null;
    notifyListeners();
    try {
      final Map<String, dynamic> response = await apiClient.getJson(
        '/favorites',
        query: const <String, String>{'limit': '100', 'page': '1'},
      );
      if (generation != _generation) return;
      final Object? data = response['data'];
      _items = data is List
          ? data
                .whereType<Map<String, dynamic>>()
                .map(FavoriteEntry.fromJson)
                .whereType<FavoriteEntry>()
                .toList(growable: false)
          : const <FavoriteEntry>[];
      _loaded = true;
    } on AppFailure catch (failure) {
      if (generation == _generation) _failure = failure;
    } catch (error, stackTrace) {
      if (generation == _generation) {
        debugPrint('FavoritesController.load failed: $error\n$stackTrace');
        _failure = AppFailure.unknown(debugDetail: error.toString());
      }
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        _activeLoad = null;
        notifyListeners();
      }
    }
  }

  Future<bool> toggle(CarPreview car) async {
    if (_mutating.contains(car.id)) return false;
    _mutating.add(car.id);
    final int generation = _generation;
    notifyListeners();
    try {
      // A saved-list read may already be running from authentication restore.
      // Wait for it before deciding whether this tap is an add or a remove,
      // otherwise a late GET could overwrite a successful POST in memory.
      if (_isLoading) {
        await _activeLoad;
      } else if (!_loaded) {
        await load(retry: true);
      }
      if (generation != _generation || !_loaded) return false;

      FavoriteEntry? existing;
      for (final FavoriteEntry item in _items) {
        if (item.car.id == car.id) {
          existing = item;
          break;
        }
      }
      if (existing != null) {
        final String favoriteId = existing.id;
        await apiClient.deleteJson(
          '/favorites/${Uri.encodeComponent(favoriteId)}',
        );
        if (generation != _generation) return false;
        _items = _items
            .where((FavoriteEntry item) => item.id != favoriteId)
            .toList(growable: false);
      } else {
        final Map<String, dynamic> response = await apiClient.postJson(
          '/favorites',
          body: <String, dynamic>{
            'externalCarId': car.id,
            'vehicleType': car.source,
            'source': 'external_catalog',
            'snapshot': <String, dynamic>{
              'title': car.title,
              'make': car.make,
              'model': car.model,
              'trim': car.variant,
              'owner': car.owner,
              'year': car.year,
              'price': car.price,
              'currency': car.currency,
              'formattedPrice': car.priceLabel,
              'bodyType': car.bodyType,
              'fuelType': car.fuelType,
              'transmission': car.transmission,
              'imageUrl': car.imageUrl,
              'mileage': car.mileageKm,
              'location': car.city,
            }..removeWhere((String key, Object? value) => value == null),
          },
        );
        if (generation != _generation) return false;
        final Object? data = response['data'];
        if (data is! Map<String, dynamic>) return false;
        final FavoriteEntry? entry = FavoriteEntry.fromJson(data);
        if (entry == null) return false;
        _items = <FavoriteEntry>[entry, ..._items];
        _loaded = true;
      }
      _failure = null;
      return true;
    } on AppFailure catch (failure) {
      if (generation == _generation) _failure = failure;
      return false;
    } finally {
      _mutating.remove(car.id);
      if (generation == _generation) notifyListeners();
    }
  }
}

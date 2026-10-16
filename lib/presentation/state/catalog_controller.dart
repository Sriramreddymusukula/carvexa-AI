import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/error/app_failure.dart';
import '../../core/utils/view_state.dart';
import '../../data/models/car_catalog_page.dart';
import '../../data/repositories/car_catalog_repository.dart';

/// The catalogue screen's state.
///
/// One [ChangeNotifier] holding one immutable [ViewSnapshot], the same pattern
/// every screen in this app uses, so loading, empty, error and retry behave
/// identically everywhere.
///
/// Two rules shape the implementation:
///
///  * **Never show a control the catalogue cannot honour.** Whether there is a
///    search box, a filter chip or a load-more button is read from
///    [capabilities], which the backend derives from the provider's real
///    contract. A control that would do nothing is simply never rendered.
///  * **Never let a slow request overwrite a newer one.** Every load stamps
///    itself with a generation number and discards its own result if a later
///    load has started, which is what makes debounced typing safe.
class CatalogController extends ChangeNotifier {
  CatalogController({
    required this.repository,
    this.debounce = const Duration(milliseconds: 350),
  });

  final CarCatalogRepository repository;

  /// Long enough to avoid a request per keystroke, short enough to feel live.
  final Duration debounce;

  CarCatalogQuery _query = const CarCatalogQuery(city: 'hyderabad');
  CarCatalogQuery get query => _query;

  /// The selection that produced the results currently on screen.
  ///
  /// This is what tells a *refresh* (the same question asked again, so the old
  /// answers may stay up) from a *different question* (another catalogue,
  /// filter or search term, where the old answers must be dropped).
  ///
  /// Without it, switching the catalogue keeps the previous catalogue's cars
  /// on screen for as long as the request takes — which reads as "new cars are
  /// showing used cars", because the header and the tabs have already moved on
  /// to the new selection while the list has not.
  CarCatalogQuery? _loadedQuery;

  CatalogCapabilities _capabilities = const CatalogCapabilities(
    provider: 'unknown',
    ready: false,
    sources: <CatalogSourceSpec>[],
  );

  /// What the current catalogue can do. Drives every control on the screen.
  CatalogCapabilities get capabilities => _capabilities;

  ViewSnapshot<CarCatalogPage> _snapshot =
      const ViewSnapshot<CarCatalogPage>.initial();
  ViewSnapshot<CarCatalogPage> get snapshot => _snapshot;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool get isSearchActive => _query.isSearching;
  bool get hasActiveFilters => _query.hasFilters;

  /// The source the user is browsing, falling back until capabilities arrive.
  CatalogSourceSpec get activeSource =>
      _capabilities.byId(_query.source) ?? _capabilities.fallback;

  bool get supportsSearch => activeSource.search;
  bool get supportsPagination => activeSource.pagination;

  /// True when "more results" is meaningful: a paged source that actually
  /// reported another page.
  bool get canLoadMore =>
      supportsPagination && (_snapshot.data?.hasMore ?? false);

  /// Set when load-more fails, so the button can offer an inline retry.
  AppFailure? _loadMoreFailure;
  AppFailure? get loadMoreFailure => _loadMoreFailure;

  bool _focusSearchRequested = false;

  /// True when the screen was opened *to be searched* (for example from the
  /// home screen's search field). The search box autofocuses once, and the
  /// controller moves to a source that can actually search.
  bool get shouldFocusSearch => _focusSearchRequested;

  /// Asks the catalogue to open ready to search. Safe to call before [start].
  void requestSearchFocus() {
    _focusSearchRequested = true;
    notifyListeners();
  }

  Timer? _searchTimer;
  int _generation = 0;
  bool _disposed = false;
  CarCatalogQuery? _loadingQuery;
  Future<void>? _capabilitiesRequest;

  // ------------------------------------------------------------------ start --

  /// Loads capabilities (free) and the first page. Safe to call more than once.
  Future<void> start({bool force = false}) async {
    if (_snapshot.state == ViewState.initial || force) {
      await _loadCapabilities();
    }
    await load();
  }

  Future<void> _loadCapabilities() {
    final Future<void>? activeRequest = _capabilitiesRequest;
    if (activeRequest != null) return activeRequest;

    final Future<void> request = _fetchCapabilities();
    _capabilitiesRequest = request;
    return request;
  }

  Future<void> _fetchCapabilities() async {
    try {
      final CatalogCapabilities capabilities = await repository
          .fetchCapabilities();
      if (_disposed) return;

      _capabilities = capabilities;
      // Adopt the catalogue's own default source the first time we learn it.
      if (capabilities.defaultSource != null) {
        _query = _query.copyWith(source: capabilities.defaultSource!);
      }

      // Opened to be searched: make sure we are on a source that can search,
      // rather than dropping the user on a catalogue with no search box.
      if (_focusSearchRequested) {
        final CatalogSourceSpec? current = _capabilities.byId(_query.source);
        if (current == null || !current.search) {
          for (final CatalogSourceSpec source in _capabilities.sources) {
            if (source.search) {
              _query = CarCatalogQuery(source: source.id);
              break;
            }
          }
        }
      }
      notifyListeners();
    } on AppFailure {
      // Not fatal: every catalogue page carries its own capabilities block, and
      // the screen can still render its error state without them.
    } finally {
      _capabilitiesRequest = null;
    }
  }

  // ------------------------------------------------------------------- load --

  /// Loads the current selection, replacing the list.
  Future<void> load({bool force = false}) async {
    if (!force && _snapshot.state == ViewState.data) return;

    // Captured up front: the selection must not be re-read after the await,
    // because the user may have moved on again while this request was in
    // flight. The result is attributed to what was actually asked for.
    final CarCatalogQuery requested = _query;
    // Repeated taps, a duplicate start(), or overlapping refresh gestures must
    // not send the same provider-backed request twice.
    if (_loadingQuery?.sameSelection(requested) ?? false) return;
    final int generation = ++_generation;
    _loadingQuery = requested;

    // Only a re-ask of the *same* question may keep the previous cars on
    // screen. Changing the catalogue, a filter or the search term means the
    // cars already loaded are an answer to a different question, and showing
    // them under the new header states something untrue about the catalogue.
    final bool sameQuestion = _loadedQuery?.sameSelection(requested) ?? false;

    _snapshot = sameQuestion && _snapshot.hasData
        ? ViewSnapshot<CarCatalogPage>.refreshing(_snapshot.data!)
        : const ViewSnapshot<CarCatalogPage>.loading();
    notifyListeners();

    try {
      final CarCatalogPage page = await repository.fetchCatalog(requested);
      if (_disposed || generation != _generation) return;

      if (page.capabilities.ready) _capabilities = page.capabilities;
      _loadMoreFailure = null;
      _loadedQuery = requested;
      _snapshot = page.isEmpty
          ? const ViewSnapshot<CarCatalogPage>.empty()
          : ViewSnapshot<CarCatalogPage>.data(page);
    } on AppFailure catch (failure) {
      if (_disposed || generation != _generation) return;
      _snapshot = ViewSnapshot<CarCatalogPage>.error(failure);
    } catch (error, stackTrace) {
      if (_disposed || generation != _generation) return;
      debugPrint('CatalogController.load failed: $error\n$stackTrace');
      _snapshot = ViewSnapshot<CarCatalogPage>.error(
        AppFailure.unknown(debugDetail: error.toString()),
      );
    } finally {
      // The screen was notified when loading began. Notify again after either
      // outcome so the skeleton can resolve to content or an error state.
      if (!_disposed && generation == _generation) {
        _loadingQuery = null;
        notifyListeners();
      }
    }
  }

  /// Retry for the whole screen.
  Future<void> retry() => load(force: true);

  /// Pull-to-refresh.
  Future<void> refresh() => load(force: true);

  // --------------------------------------------------------------- load more --

  /// Appends the next page. Ignored unless the source really pages.
  Future<void> loadMore() async {
    if (!canLoadMore || _isLoadingMore) return;

    final CarCatalogPage? current = _snapshot.data;
    if (current == null) return;

    final CarCatalogQuery requested = _query;
    _isLoadingMore = true;
    _loadMoreFailure = null;
    notifyListeners();

    try {
      final CarCatalogPage next = await repository.fetchCatalog(
        requested.copyWith(page: current.page + 1),
      );
      if (_disposed) return;

      // If the selection changed while this page was in flight, appending would
      // mix two different result sets together.
      if (!requested.sameSelection(_query) || next.source != _query.source) {
        return;
      }

      final CarCatalogPage merged = current.append(next);
      _query = _query.copyWith(page: merged.page);
      // The page grew, but the question did not change, so what is on screen is
      // still the answer to the current selection.
      _loadedQuery = _query;
      _snapshot = ViewSnapshot<CarCatalogPage>.data(merged);
    } on AppFailure catch (failure) {
      if (_disposed) return;
      // Keep the results the user already has; offer an inline retry instead of
      // replacing a good list with an error screen.
      _loadMoreFailure = failure;
    } catch (error) {
      if (_disposed) return;
      debugPrint('CatalogController.loadMore failed: $error');
      _loadMoreFailure = AppFailure.unknown(debugDetail: error.toString());
    } finally {
      if (!_disposed) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  // ----------------------------------------------------------------- search --

  /// Called on every keystroke. The text appears immediately, the request is
  /// debounced, and clearing the box restores the unfiltered list.
  void search(String text) {
    if (!supportsSearch) return;

    final CarCatalogQuery next = _query.copyWith(search: text, page: 1);
    if (next == _query) return;

    _query = next;
    notifyListeners();

    _searchTimer?.cancel();
    _searchTimer = Timer(debounce, () => load(force: true));
  }

  void clearSearch() {
    _searchTimer?.cancel();
    if (!_query.isSearching) return;
    _query = _query.cleared();
    notifyListeners();
    if (supportsSearch) load(force: true);
  }

  // ---------------------------------------------------------------- filters --

  /// Switches between catalogues (used / new), dropping anything the incoming
  /// catalogue cannot honour — a city does not exist for new models, and a
  /// search term is meaningless where the provider cannot search.
  void setSource(String source) {
    if (_query.source == source) return;

    _searchTimer?.cancel();
    final CatalogSourceSpec? spec = _capabilities.byId(source);
    final bool hasCity =
        spec?.filters.any((CatalogFilterSpec f) => f.id == 'city') ?? false;
    final bool hasBrand =
        spec?.filters.any((CatalogFilterSpec f) => f.id == 'brand') ?? false;

    _query = CarCatalogQuery(
      source: source,
      city: hasCity ? _query.city : null,
      brand: hasBrand ? _query.brand : null,
    );
    load(force: true);
  }

  /// Applies a supported filter, or clears it when [value] is null or empty.
  void applyFilter(String id, String? value) {
    final String? normalised = (value == null || value.trim().isEmpty)
        ? null
        : value.trim();

    _searchTimer?.cancel();
    _query = switch (id) {
      'city' => _query.copyWith(
        city: normalised,
        page: 1,
        clearCity: normalised == null,
      ),
      'brand' => _query.copyWith(
        brand: normalised,
        page: 1,
        clearBrand: normalised == null,
      ),
      _ => _query,
    };
    load(force: true);
  }

  void clearAllFilters() {
    if (!_query.hasFilters) return;
    _searchTimer?.cancel();
    _query = _query.copyWith(clearCity: true, clearBrand: true, page: 1);
    load(force: true);
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    super.dispose();
  }
}


import '../error/app_failure.dart';

/// The state of asynchronous content.
///
/// Every screen that shows remote data renders the same four cases, so the
/// loading/empty/error experience is consistent across the app and each screen
/// only has to say *what* to show.
enum ViewState {
  /// Nothing requested yet.
  initial,

  /// Request in flight â€” show a skeleton, not a blank screen.
  loading,

  /// Loaded with content.
  data,

  /// Loaded successfully but there is nothing to show.
  empty,

  /// Request failed; [ViewSnapshot.failure] carries the reason.
  error,
}

/// Immutable snapshot pairing a [ViewState] with its payload.
class ViewSnapshot<T> {
  const ViewSnapshot._(this.state, {this.data, this.failure, this.isRefreshing = false});

  const ViewSnapshot.initial() : this._(ViewState.initial);

  const ViewSnapshot.loading() : this._(ViewState.loading);

  const ViewSnapshot.data(T value) : this._(ViewState.data, data: value);

  const ViewSnapshot.empty() : this._(ViewState.empty);

  const ViewSnapshot.error(AppFailure value) : this._(ViewState.error, failure: value);

  const ViewSnapshot.refreshing(T value)
    : this._(ViewState.data, data: value, isRefreshing: true);

  final ViewState state;
  final T? data;
  final AppFailure? failure;

  /// True while existing content is being re-fetched (pull-to-refresh), so the
  /// UI can keep showing content instead of dropping to a skeleton.
  final bool isRefreshing;

  bool get isLoading => state == ViewState.loading;
  bool get hasData => data != null;
}

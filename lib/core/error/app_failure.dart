import 'package:flutter/foundation.dart';

/// User-facing failure categories.
///
/// The UI reacts to the *category*, never to an exception type, so screens do
/// not need to know about sockets, timeouts or status codes. This is what lets
/// an [ErrorState] offer the right recovery action with one click.
enum FailureKind {
  /// No usable connection, DNS failure, or the request timed out.
  network,

  /// The server answered, but with an error status.
  server,

  /// The request was rejected as invalid. Should not normally be reachable —
  /// it means the client sent something the API refused.
  validation,

  /// The response could not be understood. Usually a backend/frontend version
  /// mismatch, so it is worth surfacing to developers.
  parsing,

  /// Anything not yet classified.
  unknown,
}

/// A safe, presentable description of a failure.
///
/// [debugDetail] may contain technical information; it is shown only in debug
/// builds. [message] is written for a user and never contains stack traces,
/// URLs with credentials, or raw driver errors.
@immutable
class AppFailure implements Exception {
  const AppFailure({
    required this.kind,
    required this.message,
    this.retryable = true,
    this.code,
    this.debugDetail,
  });

  const AppFailure.network({
    String message = 'No connection. Check your network and try again.',
    String? debugDetail,
  }) : this(
         kind: FailureKind.network,
         message: message,
         retryable: true,
         debugDetail: debugDetail,
       );

  const AppFailure.server({
    String message = 'The service is temporarily unavailable.',
    int? statusCode,
    String? code,
    String? debugDetail,
  }) : this(
         kind: FailureKind.server,
         message: message,
         retryable: true,
         code: code,
         debugDetail: debugDetail,
       );

  const AppFailure.unknown({
    String message = 'Something went wrong.',
    String? debugDetail,
  }) : this(
         kind: FailureKind.unknown,
         message: message,
         retryable: true,
         debugDetail: debugDetail,
       );

  final FailureKind kind;

  /// User-facing, actionable text.
  final String message;

  /// Whether offering a "Try again" action makes sense.
  final bool retryable;

  /// Machine-readable code from the API (`error.code`), when present.
  final String? code;

  /// Technical context, debug builds only.
  final String? debugDetail;

  @override
  String toString() =>
      'AppFailure($kind, $code, $message${debugDetail == null ? '' : ', debug: $debugDetail'})';
}

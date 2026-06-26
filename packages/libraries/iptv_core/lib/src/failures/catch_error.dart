import "dart:async";
import "dart:developer" as developer;
import "dart:io";

import "failures.dart";

/// Shared funnel that maps any thrown error/stackTrace into a [Failures].
///
/// Repositories wrap I/O in try/catch and delegate the `catch` branch here so
/// error mapping stays in one place. Every funneled error is logged with its
/// stack trace (TODO: also forward to crash reporting).
Failures catchError(Object error, StackTrace stackTrace) {
  final Failures failure = switch (error) {
    SocketException() => const Failures.network(),
    HttpException() => const Failures.network(),
    TimeoutException() => const Failures.network(),
    FormatException() => const Failures.invalidPlaylist(),
    final HttpStatusException e => Failures.server(e.statusCode),
    _ => const Failures.unexpected(),
  };
  developer.log(
    "catchError → $failure  (${error.runtimeType}: $error)",
    name: "iptv.error",
    error: error,
    stackTrace: stackTrace,
  );
  return failure;
}

/// Lightweight transport error carrying an HTTP status code, so [catchError]
/// can produce a precise [Failures.server]. Thrown by the http layer.
class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode, [this.message]);

  final int statusCode;
  final String? message;

  @override
  String toString() => "HttpStatusException($statusCode): ${message ?? ''}";
}

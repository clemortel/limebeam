import "package:flutter/foundation.dart";

/// Runs a pure parsing function off the UI isolate (spec §6). Use for M3U /
/// XMLTV / large JSON payloads inside repositories — never parse thousands of
/// entries on the main isolate.
///
/// [parser] MUST be a top-level or static function (compute requirement).
Future<R> runParse<M, R>(ComputeCallback<M, R> parser, M message) {
  return compute(parser, message);
}

// TEMPORARY perf instrumentation to diagnose the Search-tab first-open stall.
// Remove this file and its call sites once the cause is found.
//
// Uses print() (not debugPrint/assert) so output is visible in `flutter run
// --profile`. A monotonic clock timestamps every event so gaps between lines
// reveal where the main isolate blocks.

// ignore_for_file: avoid_print

/// Monotonic clock started at app launch.
final Stopwatch perfClock = Stopwatch()..start();

/// Logs [message] with the elapsed time since launch.
void perfLog(String message) {
  print("[PERF +${perfClock.elapsedMilliseconds}ms] $message");
}

/// Runs [body] and logs how long it took.
T perfSpan<T>(String label, T Function() body) {
  final int start = perfClock.elapsedMilliseconds;
  final T result = body();
  final int took = perfClock.elapsedMilliseconds - start;
  print("[PERF +${perfClock.elapsedMilliseconds}ms] $label took ${took}ms");
  return result;
}

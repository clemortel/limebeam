import "dart:convert";

import "package:hive/hive.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/usage_metrics.dart";

/// Hive box holding the single usage-metrics blob.
const String kUsageBoxName = "iptv_usage";
const String _kUsageKey = "usage_metrics";

/// Reads/writes [UsageMetrics] (Hive). The box is opened by `registerSettings`
/// before anything reads it.
abstract interface class IUsageMetricsRepository {
  /// Synchronous load from the already-open box; defaults when absent.
  UsageMetrics load();

  /// Records that the Tip Jar prompt was shown (first call flips "once", a
  /// later call flips "twice").
  Future<void> markTipPromptShown();
}

/// Persists [UsageMetrics] and implements [WatchTimeSink] so the player can
/// accumulate watch time without importing this library.
class UsageMetricsRepository implements IUsageMetricsRepository, WatchTimeSink {
  UsageMetricsRepository(this._box);

  final Box<String> _box;

  @override
  UsageMetrics load() {
    final String? raw = _box.get(_kUsageKey);
    if (raw == null || raw.isEmpty) return const UsageMetrics();
    try {
      return UsageMetrics.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const UsageMetrics();
    }
  }

  Future<void> _save(UsageMetrics metrics) =>
      _box.put(_kUsageKey, jsonEncode(metrics.toJson()));

  @override
  Future<void> addWatchSeconds(int seconds) {
    if (seconds <= 0) return Future<void>.value();
    final UsageMetrics metrics = load();
    return _save(
      metrics.copyWith(
        watchTimeTotalSeconds: metrics.watchTimeTotalSeconds + seconds,
      ),
    );
  }

  @override
  Future<void> markTipPromptShown() {
    final UsageMetrics metrics = load();
    return _save(
      metrics.tipPromptShownOnce
          ? metrics.copyWith(tipPromptShownTwice: true)
          : metrics.copyWith(tipPromptShownOnce: true),
    );
  }
}

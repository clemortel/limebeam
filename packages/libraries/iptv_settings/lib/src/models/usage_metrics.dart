import "package:freezed_annotation/freezed_annotation.dart";

part "usage_metrics.freezed.dart";
part "usage_metrics.g.dart";

/// Lightweight, persisted signals used only to time the rare, ignorable Tip Jar
/// prompt — never to gate a feature or unlock content.
///
/// Kept in its own store (not [AppPreferences]) so the player's watch-time
/// writes can never clobber user-set preferences.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class UsageMetrics with _$UsageMetrics {
  const UsageMetrics._();

  const factory UsageMetrics({
    @Default(0) int watchTimeTotalSeconds,
    @Default(false) bool tipPromptShownOnce,
    @Default(false) bool tipPromptShownTwice,
  }) = _UsageMetrics;

  factory UsageMetrics.fromJson(Map<String, dynamic> json) =>
      _$UsageMetricsFromJson(json);
}

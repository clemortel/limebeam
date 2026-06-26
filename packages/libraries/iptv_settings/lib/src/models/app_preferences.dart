import "package:freezed_annotation/freezed_annotation.dart";

part "app_preferences.freezed.dart";
part "app_preferences.g.dart";

/// Theme selection. [system] follows the OS setting.
enum AppThemeMode { system, light, dark }

/// Text size preset. The multiplier is applied app-wide via `textScaler`.
enum FontScaleOption { normal, large }

extension FontScaleOptionX on FontScaleOption {
  double get multiplier => switch (this) {
        FontScaleOption.normal => 1,
        FontScaleOption.large => 1.15,
      };
}

/// User-tunable app preferences (spec §4.6). Persisted as JSON; the parental
/// PIN lives in secure storage, not here.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class AppPreferences with _$AppPreferences {
  const AppPreferences._();

  const factory AppPreferences({
    @Default(AppThemeMode.dark) AppThemeMode themeMode,
    @Default(FontScaleOption.normal) FontScaleOption fontScale,
    @Default(true) bool autoplayNext,
    @Default(true) bool playerGestures,
    @Default(false) bool parentalEnabled,
    @Default(0) int launchCount,
    @Default(false) bool supporter,
    @Default(true) bool donationReminders,
  }) = _AppPreferences;

  factory AppPreferences.fromJson(Map<String, dynamic> json) =>
      _$AppPreferencesFromJson(json);

  /// Launches before the gentle "support the dev" banner may appear.
  static const int donationReminderThreshold = 10;

  /// Whether to show the non-intrusive donation banner: reminders on, not yet a
  /// supporter, and the app has been opened enough times to have proven useful.
  bool get shouldSuggestDonation =>
      donationReminders &&
      !supporter &&
      launchCount >= donationReminderThreshold;
}

/// iptv_settings — app preferences (theme, font scale, playback, parental).
///
/// Public surface only. Implementation stays private under `src/`.
library iptv_settings;

export "src/di.dart";
export "src/infrastructure/preferences_repository.dart"
    show IPreferencesRepository;
export "src/infrastructure/usage_metrics_repository.dart"
    show IUsageMetricsRepository;
export "src/models/app_preferences.dart";
export "src/models/usage_metrics.dart";
export "src/riverpods/app_preferences_notifier.dart";
export "src/riverpods/parental_session.dart";
export "src/riverpods/providers.dart";
export "src/ui/settings_view.dart";

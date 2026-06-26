import "package:get_it/get_it.dart";
import "package:iptv_settings/src/infrastructure/preferences_repository.dart";
import "package:iptv_settings/src/infrastructure/usage_metrics_repository.dart";
import "package:iptv_settings/src/riverpods/app_preferences_notifier.dart";
import "package:iptv_settings/src/riverpods/parental_session.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
IPreferencesRepository preferencesRepository(PreferencesRepositoryRef ref) =>
    GetIt.instance<IPreferencesRepository>();

/// Bridges the GetIt-registered usage-metrics repository into Riverpod.
@Riverpod(keepAlive: true)
IUsageMetricsRepository usageMetricsRepository(UsageMetricsRepositoryRef ref) =>
    GetIt.instance<IUsageMetricsRepository>();

/// Whether adult content must be hidden right now: parental control is on and
/// the session has not been unlocked with the PIN. Views watch this.
@riverpod
bool adultHidden(AdultHiddenRef ref) =>
    ref.watch(appPreferencesNotifierProvider).parentalEnabled &&
    !ref.watch(parentalSessionProvider);

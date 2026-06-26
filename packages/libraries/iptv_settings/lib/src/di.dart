import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:get_it/get_it.dart";
import "package:hive/hive.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/preferences_repository.dart";
import "infrastructure/usage_metrics_repository.dart";

/// Opens the preferences + usage boxes and registers the repositories. Call
/// after `Hive.initFlutter()` (await it — it opens boxes).
Future<void> registerSettings(GetIt getIt) async {
  final Box<String> box = await Hive.openBox<String>(kPrefsBoxName);
  getIt.registerLazySingleton<IPreferencesRepository>(
    () => PreferencesRepository(box, const FlutterSecureStorage()),
  );

  final Box<String> usageBox = await Hive.openBox<String>(kUsageBoxName);
  getIt.registerLazySingleton<IUsageMetricsRepository>(
    () => UsageMetricsRepository(usageBox),
  );
  // The same instance also satisfies the player's watch-time seam.
  getIt.registerLazySingleton<WatchTimeSink>(
    () => getIt<IUsageMetricsRepository>() as WatchTimeSink,
  );
}

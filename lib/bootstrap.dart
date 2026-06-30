import "package:flutter/scheduler.dart" show FrameTiming;
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:hive_flutter/hive_flutter.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_player/iptv_player.dart";
import "package:iptv_settings/iptv_settings.dart";

import "app.dart";
import "flavors/flavor.dart";
import "injection.dart";
import "perf_log.dart";
import "platform/form_factor_detector.dart";
import "router/router.dart";

/// Shared startup path for every flavor entrypoint.
Future<void> bootstrap(Flavor flavor) async {
  perfLog("bootstrap start"); // starts the clock deterministically at launch
  WidgetsFlutterBinding.ensureInitialized();

  // TEMP: log any frame slower than 100ms with its build/raster split so we can
  // tell UI-thread compute (build) from GPU (raster) from a blocking gap.
  WidgetsBinding.instance.addTimingsCallback((List<FrameTiming> timings) {
    for (final FrameTiming t in timings) {
      final int total = t.totalSpan.inMilliseconds;
      if (total > 100) {
        perfLog(
          "SLOW FRAME total=${total}ms "
          "build=${t.buildDuration.inMilliseconds}ms "
          "raster=${t.rasterDuration.inMilliseconds}ms",
        );
      }
    }
  });

  await ensurePlayerInitialized();

  await Hive.initFlutter();
  await configureDependencies();

  // Load the persisted active source so the splash can route correctly.
  await getIt<ISourceRepository>().hydrateOnLaunch();

  // Count this launch for the gentle "support the dev" heuristic.
  final IPreferencesRepository prefs = getIt<IPreferencesRepository>();
  await prefs.save(prefs.load().copyWith(launchCount: prefs.load().launchCount + 1));

  // Probe the device class once, before the first frame, so the UI can adopt
  // the TV layout (side rail, solid surfaces, focus nav) from launch.
  final bool isTelevision = await detectIsTelevision();

  runApp(
    ProviderScope(
      overrides: [
        televisionDetectedProvider.overrideWithValue(isTelevision),
      ],
      child: IptvApp(appRouter: AppRouter()),
    ),
  );
}

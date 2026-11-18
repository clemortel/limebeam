import "dart:async" show unawaited;

import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_riverpod/misc.dart" show Override;
import "package:hive_flutter/hive_flutter.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart" show CacheStore;
import "package:iptv_player/iptv_player.dart";
import "package:iptv_settings/iptv_settings.dart";

import "app.dart";
import "flavors/flavor.dart";
import "injection.dart";
import "platform/form_factor_detector.dart";
import "router/router.dart";
import "source_scope.dart";

/// Painted immediately at launch, before any async init, so the window has a
/// real first frame within ~1s. This both removes the blank launch screen and
/// lets the platform answer queued input events during startup — on slow TV
/// hardware the old init-then-runApp order left the window frameless for many
/// seconds, and one remote key press during that gap triggered an
/// "Input dispatching timed out" ANR.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  /// Matches `AppColors.bgBase` (dark) without depending on iptv_ui.
  static const Color _kBackground = Color(0xFF0B0C0E);

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: _kBackground, child: SizedBox.expand()),
    );
  }
}

/// Shared startup path for every flavor entrypoint.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();

  // First frame before any heavy init (see [_BootSplash]).
  runApp(const _BootSplash());

  await Hive.initFlutter();
  await configureDependencies();

  // Load the persisted active source so the splash can route correctly.
  await getIt<ISourceRepository>().hydrateOnLaunch();

  // Probe the device class once, before the real app builds, so the UI can
  // adopt the TV layout (side rail, solid surfaces, focus nav) from launch.
  final bool isTelevision = await detectIsTelevision();
  // Let the player pick the SurfaceView ExoPlayer engine on TV.
  setPlayerTelevision(isTelevision: isTelevision);

  runApp(
    ProviderScope(
      overrides: <Override>[
        televisionDetectedProvider.overrideWithValue(isTelevision),
        sourceScopedProvidersOverride(),
        beforeSourceSwitchHooksOverride(),
      ],
      child: IptvApp(appRouter: AppRouter()),
    ),
  );

  // Deferred off the startup path, after the app's first frame:
  // - media_kit's native library load (multi-second dlopen on weak TV
  //   hardware) — playback starts long after launch, so lazy is safe.
  // - the launch counter write (pure bookkeeping).
  // - reclaiming stale multi-MB catalog copies from the append-only cache file
  //   (a bloated file slows every launch's index scan and every lazy read).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(ensurePlayerInitialized());
    final IPreferencesRepository prefs = getIt<IPreferencesRepository>();
    unawaited(
      prefs.save(prefs.load().copyWith(launchCount: prefs.load().launchCount + 1)),
    );
    unawaited(getIt<CacheStore>().compact());
  });
}

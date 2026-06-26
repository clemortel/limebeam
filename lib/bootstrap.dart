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
import "router/router.dart";

/// Shared startup path for every flavor entrypoint.
Future<void> bootstrap(Flavor flavor) async {
  WidgetsFlutterBinding.ensureInitialized();
  await ensurePlayerInitialized();

  await Hive.initFlutter();
  await configureDependencies();

  // Load the persisted active source so the splash can route correctly.
  await getIt<ISourceRepository>().hydrateOnLaunch();

  // Count this launch for the gentle "support the dev" heuristic.
  final IPreferencesRepository prefs = getIt<IPreferencesRepository>();
  await prefs.save(prefs.load().copyWith(launchCount: prefs.load().launchCount + 1));

  runApp(
    ProviderScope(
      child: IptvApp(appRouter: AppRouter()),
    ),
  );
}

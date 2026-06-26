import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";

import "player/floating_player.dart";
import "router/router.dart";
import "router/router.gr.dart";

/// Root application widget. Thin: composition of theme + router + the user's
/// theme-mode / font-scale preferences.
class IptvApp extends ConsumerWidget {
  const IptvApp({required this.appRouter, super.key});

  final AppRouter appRouter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppPreferences prefs = ref.watch(appPreferencesNotifierProvider);
    final ThemeMode themeMode = switch (prefs.themeMode) {
      AppThemeMode.system => ThemeMode.system,
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
    };
    final TextScaler textScaler =
        TextScaler.linear(prefs.fontScale.multiplier);

    return MaterialApp.router(
      title: "LimeBeam",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(brightness: Brightness.light),
      darkTheme: AppTheme.themeData(brightness: Brightness.dark),
      themeMode: themeMode,
      routerConfig: appRouter.config(),
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        // The floating PiP window lives above the navigator so it persists
        // across tabs/routes while the user browses.
        child: Stack(
          children: <Widget>[
            Positioned.fill(child: child ?? const SizedBox.shrink()),
            FloatingPlayer(
              onExpand: () => appRouter.push(const PlayerRoute()),
            ),
          ],
        ),
      ),
    );
  }
}

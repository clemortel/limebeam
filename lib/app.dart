import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";

import "platform/form_factor_detector.dart";
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
    final bool isTelevision = ref.watch(televisionDetectedProvider);
    // Magnify design tokens for the 10-foot TV layout (no effect otherwise).
    final double tokenScale = isTelevision ? AppTheme.tvTokenScale : 1.0;

    return MaterialApp.router(
      title: "LimeBeam",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData(
        brightness: Brightness.light,
        tokenScale: tokenScale,
      ),
      darkTheme: AppTheme.themeData(
        brightness: Brightness.dark,
        tokenScale: tokenScale,
      ),
      themeMode: themeMode,
      routerConfig: appRouter.config(),
      builder: (BuildContext context, Widget? child) {
        // TV is decided by the platform probe; phone vs tablet by viewport.
        final FormFactor formFactor = isTelevision
            ? FormFactor.tv
            : formFactorFromSize(MediaQuery.sizeOf(context));
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          // The active device class flows to every widget through this scope
          // (nav shell, grids, player) without prop-drilling.
          child: FormFactorScope(
            formFactor: formFactor,
            // The "Reduce transparency" preference flows to every GlassSurface
            // (tab bar, player chrome, sheets) through this single scope. Glass
            // is also force-disabled on TV — BackdropFilter is too costly on
            // low-power TV/Firestick GPUs.
            child: GlassScope(
              enabled: !prefs.reduceTransparency && !formFactor.isTv,
              // The floating PiP window lives above the navigator so it
              // persists across tabs/routes while the user browses.
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: child ?? const SizedBox.shrink()),
                  FloatingPlayer(
                    onExpand: () => appRouter.push(const PlayerRoute()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../../injection.dart";
import "../router.gr.dart";

/// Decides the landing destination from the persisted active source.
@RoutePage()
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bool hasActive = getIt<ActiveSourceStore>().hasActive;
      context.router.replaceAll(<PageRouteInfo<dynamic>>[
        if (hasActive) const MainShellRoute() else const WelcomeRoute(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const LimeBeamMark(),
            SizedBox(height: t.space.x6),
            CircularProgressIndicator(color: t.colors.accent),
          ],
        ),
      ),
    );
  }
}

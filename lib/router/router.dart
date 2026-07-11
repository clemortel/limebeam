import "package:auto_route/auto_route.dart";

import "router.gr.dart";

/// Declarative app router. The splash decides onboarding-vs-main from the
/// persisted active source; onboarding is a linear stack; the main shell hosts
/// the 5 tabs (spec §3).
///
/// Run `melos run build_runner` after editing to regenerate `router.gr.dart`.
@AutoRouterConfig(replaceInRouteName: "Screen|Page,Route")
class AppRouter extends RootStackRouter {
  AppRouter();

  @override
  List<AutoRoute> get routes => <AutoRoute>[
        AutoRoute(page: SplashRoute.page, initial: true, path: "/"),
        AutoRoute(page: WelcomeRoute.page, path: "/welcome"),
        AutoRoute(page: SourceTypeRoute.page, path: "/onboarding/type"),
        AutoRoute(page: XtreamFormRoute.page, path: "/onboarding/xtream"),
        AutoRoute(page: M3uFormRoute.page, path: "/onboarding/m3u"),
        AutoRoute(page: SourceSummaryRoute.page, path: "/onboarding/summary"),
        AutoRoute(page: ConnectingRoute.page, path: "/onboarding/connecting"),
        AutoRoute(page: SourceSuccessRoute.page, path: "/onboarding/success"),
        AutoRoute(
          page: MainShellRoute.page,
          path: "/main",
          children: <AutoRoute>[
            AutoRoute(page: HomeTabRoute.page, path: "home"),
            AutoRoute(page: LiveTabRoute.page, path: "live"),
            AutoRoute(page: FilmsTabRoute.page, path: "films"),
            AutoRoute(page: SeriesTabRoute.page, path: "series"),
            AutoRoute(page: SearchTabRoute.page, path: "search"),
            AutoRoute(page: SettingsTabRoute.page, path: "settings"),
          ],
        ),
        AutoRoute(page: SourcesRoute.page, path: "/sources"),
        AutoRoute(page: DonationsRoute.page, path: "/donations"),
        AutoRoute(page: AboutRoute.page, path: "/about"),
        // Detail screens push over the shell (cover the tab bar).
        AutoRoute(page: MovieDetailRoute.page, path: "/movie"),
        AutoRoute(page: SeriesDetailRoute.page, path: "/series"),
        AutoRoute(page: PlayerRoute.page, path: "/player"),
      ];
}

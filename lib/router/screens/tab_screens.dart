import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_donations/iptv_donations.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

import "../../donations/tip_prompt.dart";
import "../../home/home_view.dart";
import "../../perf_log.dart";
import "../../player_launch.dart";
import "../../search/search_view.dart";
import "../../settings/about_view.dart";
import "../router.gr.dart";

// TEMP: marks which tab is building so a SLOW FRAME can be attributed.
/// Accueil — dashboard (§4.2).
@RoutePage()
class HomeTabScreen extends ConsumerStatefulWidget {
  const HomeTabScreen({super.key});

  @override
  ConsumerState<HomeTabScreen> createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends ConsumerState<HomeTabScreen> {
  @override
  void initState() {
    super.initState();
    // A source is already active to be on the shell; this is a positive moment
    // to (rarely) surface the Tip Jar prompt. The service self-gates.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) const TipPromptService().maybeShow(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) {
    perfLog("HomeTabScreen.build");
    return HomeView(
      onOpenChannel: (Channel c) => ref.openChannel(context, c),
      onOpenMovie: (Movie m) =>
          context.router.root.push(MovieDetailRoute(movie: m)),
      onOpenSeries: (Series s) =>
          context.router.root.push(SeriesDetailRoute(series: s)),
      onOpenSession: (WatchSession s) => ref.openSession(context, s),
    );
  }
}

/// TV — live channels (§4.3.1).
@RoutePage()
class LiveTabScreen extends ConsumerWidget {
  const LiveTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    perfLog("LiveTabScreen.build");
    return LiveChannelsView(
      onOpenChannel: (Channel channel) => ref.openChannel(context, channel),
      hideAdult: ref.watch(adultHiddenProvider),
    );
  }
}

/// Films & Séries (§4.4): inner Films/Séries segmented toggle.
@RoutePage()
class BrowseTabScreen extends ConsumerStatefulWidget {
  const BrowseTabScreen({super.key});

  @override
  ConsumerState<BrowseTabScreen> createState() => _BrowseTabScreenState();
}

class _BrowseTabScreenState extends ConsumerState<BrowseTabScreen> {
  int _segment = 0; // 0 = Films, 1 = Séries

  @override
  Widget build(BuildContext context) {
    perfLog("BrowseTabScreen.build");
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool hideAdult = ref.watch(adultHiddenProvider);
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.tabBrowse, style: t.typography.h1),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.x4,
              vertical: t.space.x2,
            ),
            child: Row(
              children: <Widget>[
                FilterChipX(
                  label: l.browseMovies,
                  selected: _segment == 0,
                  onTap: () => setState(() => _segment = 0),
                ),
                SizedBox(width: t.space.x2),
                FilterChipX(
                  label: l.browseSeries,
                  selected: _segment == 1,
                  onTap: () => setState(() => _segment = 1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _segment == 0
          ? VodGridView(
              hideAdult: hideAdult,
              onOpenMovie: (Movie m) =>
                  context.router.root.push(MovieDetailRoute(movie: m)),
            )
          : SeriesGridView(
              hideAdult: hideAdult,
              onOpenSeries: (Series s) =>
                  context.router.root.push(SeriesDetailRoute(series: s)),
            ),
    );
  }
}

/// Recherche — unified search across live / VOD / series (§4).
@RoutePage()
class SearchTabScreen extends ConsumerWidget {
  const SearchTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    perfLog("SearchTabScreen.build");
    return SearchView(
      onOpenChannel: (Channel c) => ref.openChannel(context, c),
      onOpenMovie: (Movie m) =>
          context.router.root.push(MovieDetailRoute(movie: m)),
      onOpenSeries: (Series s) =>
          context.router.root.push(SeriesDetailRoute(series: s)),
    );
  }
}

/// Réglages (§4.6): Sources entry + Interface / Lecture / Parental sections.
@RoutePage()
class SettingsTabScreen extends StatelessWidget {
  const SettingsTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.tabSettings, style: t.typography.h1),
      ),
      body: ListView(
        // Clear the floating glass nav bar (bottom inset set by the shell).
        padding: EdgeInsets.only(
          top: t.space.x4,
          bottom: t.space.x4 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          _SettingsNavTile(
            icon: Icons.cloud_outlined,
            label: l.settingsSources,
            onTap: () => context.router.root.push(const SourcesRoute()),
          ),
          SizedBox(height: t.space.x4),
          const SettingsView(),
          SizedBox(height: t.space.x4),
          _SettingsNavTile(
            icon: Icons.favorite_outline,
            label: l.settingsSupport,
            onTap: () => context.router.root.push(const DonationsRoute()),
          ),
          SizedBox(height: t.space.x4),
          _SettingsNavTile(
            icon: Icons.info_outline,
            label: l.settingsAbout,
            onTap: () => context.router.root.push(const AboutRoute()),
          ),
        ],
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: t.space.x4),
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        borderRadius: t.radius.lgAll,
        border: Border.all(color: t.colors.borderSubtle),
      ),
      // Transparent Material so the ListTile's tap ripple stays visible over
      // the colored container.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(icon, color: t.colors.textSecondary),
          title: Text(
            label,
            style: t.typography.body.copyWith(color: t.colors.textPrimary),
          ),
          trailing: Icon(Icons.chevron_right, color: t.colors.textTertiary),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Standalone Sources management, reached from Réglages.
@RoutePage()
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SourcesSettingsView(
      onAddSource: () => context.router.root.push(const SourceTypeRoute()),
    );
  }
}

/// À propos — legal, privacy, licenses, version.
@RoutePage()
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => const AboutView();
}

/// Tip Jar — reached from Réglages or the gentle Home banner.
@RoutePage()
class DonationsScreen extends ConsumerWidget {
  const DonationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SupportDeveloperView(
      onTipped: () =>
          ref.read(appPreferencesNotifierProvider.notifier).markSupporter(),
    );
  }
}

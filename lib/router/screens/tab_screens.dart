import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_api/iptv_api.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_donations/iptv_donations.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_player/iptv_player.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

import "../../browse/genre_browse_view.dart";
import "../../donations/tip_prompt.dart";
import "../../home/home_view.dart";
import "../../player_launch.dart";
import "../../search/search_view.dart";
import "../../settings/about_view.dart";
import "../router.gr.dart";

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

/// TV — live channels (§4.3.1). On TV, drives the dwell video preview: the
/// focused channel's stream is fed to a persistent [LivePreview] after a short
/// dwell, and the preview is stopped when a channel is opened full-screen.
@RoutePage()
class LiveTabScreen extends ConsumerStatefulWidget {
  const LiveTabScreen({super.key});

  @override
  ConsumerState<LiveTabScreen> createState() => _LiveTabScreenState();
}

class _LiveTabScreenState extends ConsumerState<LiveTabScreen> {
  String? _previewUrl;

  /// Builds the live URL for the dwelled channel (null clears the preview).
  void _onDwell(Channel? channel) {
    final IPlaylistSource? source = ref.read(activePlaylistSourceProvider);
    final String? url = (channel == null || source == null)
        ? null
        : source.buildLiveUrl(channel.streamId);
    if (url != _previewUrl) setState(() => _previewUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    final bool isTv = FormFactorScope.isTv(context);
    return LiveChannelsView(
      onOpenChannel: (Channel channel) {
        // Stop the preview before the full-screen player takes over so two
        // decoders don't run at once on the weak TV hardware.
        if (_previewUrl != null) setState(() => _previewUrl = null);
        ref.openChannel(context, channel);
      },
      hideAdult: ref.watch(adultHiddenProvider),
      preview: isTv ? LivePreview(url: _previewUrl) : null,
      onChannelDwell: isTv ? _onDwell : null,
    );
  }
}

/// Films (§4.4). TV browses by genre rows (Netflix-style); phone/tablet keep
/// the category-chip grid.
@RoutePage()
class FilmsTabScreen extends ConsumerWidget {
  const FilmsTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool hideAdult = ref.watch(adultHiddenProvider);
    if (FormFactorScope.isTv(context)) {
      return GenreBrowseView(
        kind: BrowseKind.films,
        hideAdult: hideAdult,
        onOpenMovie: (Movie m) =>
            context.router.root.push(MovieDetailRoute(movie: m)),
      );
    }
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.browseMovies, style: t.typography.h1),
      ),
      body: VodGridView(
        hideAdult: hideAdult,
        onOpenMovie: (Movie m) =>
            context.router.root.push(MovieDetailRoute(movie: m)),
      ),
    );
  }
}

/// Séries (§4.4) — its own destination. TV browses by genre rows; phone/tablet
/// keep the category-chip grid.
@RoutePage()
class SeriesTabScreen extends ConsumerWidget {
  const SeriesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool hideAdult = ref.watch(adultHiddenProvider);
    if (FormFactorScope.isTv(context)) {
      return GenreBrowseView(
        kind: BrowseKind.series,
        hideAdult: hideAdult,
        onOpenSeries: (Series s) =>
            context.router.root.push(SeriesDetailRoute(series: s)),
      );
    }
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.browseSeries, style: t.typography.h1),
      ),
      body: SeriesGridView(
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
      // TV: the rail labels the section; skip the redundant big title.
      appBar: FormFactorScope.isTv(context)
          ? null
          : AppBar(
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
    final bool isTv = FormFactorScope.isTv(context);
    final Widget tile = Container(
      margin: EdgeInsets.symmetric(horizontal: t.space.x4),
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        borderRadius: t.radius.lgAll,
        border: Border.all(color: t.colors.borderSubtle),
      ),
      // Transparent Material so the ListTile's tap ripple stays visible over
      // the colored container (touch). On TV the tap is owned by IptvFocusable
      // below so the accent glass ring shows instead of the Material ink.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(icon, color: t.colors.textSecondary),
          title: Text(
            label,
            style: t.typography.body.copyWith(color: t.colors.textPrimary),
          ),
          trailing: Icon(Icons.chevron_right, color: t.colors.textTertiary),
          onTap: isTv ? null : onTap,
        ),
      ),
    );
    if (!isTv) return tile;
    return IptvFocusable(
      onTap: onTap,
      focusBorderRadius: t.radius.lgAll,
      child: tile,
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
      // No source left: back to the first-launch flow, nothing to browse.
      onNoSourceLeft: () => context.router.root.replaceAll(
        <PageRouteInfo<dynamic>>[const WelcomeRoute()],
      ),
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
          ref.read(appPreferencesProvider.notifier).markSupporter(),
    );
  }
}

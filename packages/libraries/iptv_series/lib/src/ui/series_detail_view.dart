import "package:cached_network_image/cached_network_image.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/episode.dart";
import "../models/season.dart";
import "../models/series.dart";
import "../models/series_detail.dart";
import "../riverpods/providers.dart";

const double _kBackdropAspect = 16 / 9;
const int _kSynopsisCollapsedLines = 3;

const double _kSeasonSkeletonHeight = 120;
const double _kSeasonChipsHeight = 34;
const double _kEpisodePlayIconSize = 28;

/// TV cinematic hero: fraction of viewport height, and content-column width
/// fraction (lower-left), so episodes peek below and text stays readable.
const double _kTvHeroFraction = 0.56;
const double _kTvContentWidthFraction = 0.52;
const int _kTvBackdropCacheWidth = 1280;

/// Series detail (§4.4.1). Mobile: stacked hero + synopsis + seasons/episodes.
/// TV: a cinematic full-bleed hero with Play (first/next episode) autofocused,
/// then season chips + episode list below the fold.
class SeriesDetailView extends ConsumerWidget {
  const SeriesDetailView({
    required this.series,
    this.onPlayEpisode,
    this.actions,
    this.episodeTrailing,
    this.seasonAction,
    super.key,
  });

  final Series series;
  final void Function(Season season, Episode episode)? onPlayEpisode;

  /// Phone only: trailing control of each episode row (e.g. download).
  final Widget Function(Season season, Episode episode)? episodeTrailing;

  /// Phone only: control beside the season chips (e.g. download season).
  final Widget Function(Season season)? seasonAction;

  /// App-layer actions (e.g. a favorite toggle). App bar on mobile; beside
  /// Play on TV.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<SeriesDetail> detail =
        ref.watch(seriesDetailProvider(series.id));

    if (FormFactorScope.isTv(context)) {
      return _CinematicSeriesDetail(
        series: series,
        detail: detail,
        onPlayEpisode: onPlayEpisode,
        actions: actions,
      );
    }

    // Mobile / tablet: unchanged stacked layout.
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(backgroundColor: t.colors.bgBase, actions: actions),
      body: ListView(
        padding: EdgeInsets.only(bottom: t.space.x8),
        children: <Widget>[
          _Hero(coverUrl: series.coverUrl),
          Padding(
            padding: EdgeInsets.all(t.space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  series.name,
                  style: t.typography.h2.copyWith(color: t.colors.textPrimary),
                ),
                SizedBox(height: t.space.x2),
                _Meta(series: series),
                SizedBox(height: t.space.x4),
                _Synopsis(plot: series.plot ?? ""),
                SizedBox(height: t.space.x6),
                _SeasonsSection(
                  detail: detail,
                  onPlayEpisode: onPlayEpisode,
                  episodeTrailing: episodeTrailing,
                  seasonAction: seasonAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// TV-only cinematic series detail.
class _CinematicSeriesDetail extends StatelessWidget {
  const _CinematicSeriesDetail({
    required this.series,
    required this.detail,
    this.onPlayEpisode,
    this.actions,
  });

  final Series series;
  final AsyncState<SeriesDetail> detail;
  final void Function(Season season, Episode episode)? onPlayEpisode;
  final List<Widget>? actions;

  /// First playable (season, episode) across all seasons, or null while the
  /// detail is still loading / empty.
  (Season, Episode)? _firstEpisode() {
    final SeriesDetail? data = switch (detail) {
      AsyncSuccess<SeriesDetail>(:final SeriesDetail data) => data,
      _ => null,
    };
    if (data == null) return null;
    for (final Season s in data.seasons) {
      if (s.episodes.isNotEmpty) return (s, s.episodes.first);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Size size = MediaQuery.sizeOf(context);
    final (Season, Episode)? first = _firstEpisode();
    final String? url = series.coverUrl;

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: SizedBox(
              height: size.height * _kTvHeroFraction,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (url != null && url.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      memCacheWidth: _kTvBackdropCacheWidth,
                      placeholder: (BuildContext c, String _) =>
                          ColoredBox(color: t.colors.bgElevated),
                      errorWidget: (BuildContext c, String _, Object __) =>
                          ColoredBox(color: t.colors.bgElevated),
                    )
                  else
                    ColoredBox(color: t.colors.bgElevated),
                  const _ScrimGradient(),
                  Padding(
                    padding: tvOverscan(context),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: size.width * _kTvContentWidthFraction,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              series.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: t.typography.h1
                                  .copyWith(color: t.colors.textPrimary),
                            ),
                            SizedBox(height: t.space.x2),
                            _Meta(series: series),
                            SizedBox(height: t.space.x4),
                            _Synopsis(plot: series.plot ?? ""),
                            SizedBox(height: t.space.x4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                PrimaryButton(
                                  label: AppLocalizations.of(context).commonPlay,
                                  expand: false,
                                  autofocus: true,
                                  onPressed: first == null
                                      ? null
                                      : () => onPlayEpisode?.call(
                                            first.$1,
                                            first.$2,
                                          ),
                                ),
                                if (actions != null) ...<Widget>[
                                  SizedBox(width: t.space.x3),
                                  ...actions!,
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: tvOverscan(context),
              child: _SeasonsSection(
                detail: detail,
                onPlayEpisode: onPlayEpisode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left→right + bottom→up dark scrims tinted with bgBase — legibility without
/// blur (cheap on Fire TV GPUs).
class _ScrimGradient extends StatelessWidget {
  const _ScrimGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Color(0xE60B0C0E), Color(0x990B0C0E), Color(0x000B0C0E)],
          stops: <double>[0.0, 0.45, 0.85],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xE60B0C0E), Color(0x000B0C0E)],
            stops: <double>[0.0, 0.6],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.series});

  final Series series;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final List<String> parts = <String>[
      if (series.year != null && series.year!.isNotEmpty) series.year!,
      if (series.rating != null && series.rating!.isNotEmpty)
        "★ ${series.rating}",
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(" · "),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.typography.caption.copyWith(color: t.colors.textSecondary),
    );
  }
}

class _Synopsis extends StatefulWidget {
  const _Synopsis({required this.plot});

  final String plot;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    if (widget.plot.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.plot,
          maxLines: _expanded ? null : _kSynopsisCollapsedLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: t.typography.body.copyWith(color: t.colors.textSecondary),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IptvFocusable(
            onTap: () => setState(() => _expanded = !_expanded),
            focusBorderRadius: t.radius.smAll,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: t.space.x1),
              child: Text(
                _expanded
                    ? AppLocalizations.of(context).commonLess
                    : AppLocalizations.of(context).commonMore,
                style: t.typography.bodyStrong
                    .copyWith(color: t.colors.accentTextOnDark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SeasonsSection extends StatelessWidget {
  const _SeasonsSection({
    required this.detail,
    required this.onPlayEpisode,
    this.episodeTrailing,
    this.seasonAction,
  });

  final AsyncState<SeriesDetail> detail;
  final void Function(Season season, Episode episode)? onPlayEpisode;
  final Widget Function(Season season, Episode episode)? episodeTrailing;
  final Widget Function(Season season)? seasonAction;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return switch (detail) {
      AsyncIdle<SeriesDetail>() => SkeletonBox(
          height: _kSeasonSkeletonHeight,
          borderRadius: t.radius.smAll,
        ),
      AsyncLoading<SeriesDetail>() => SkeletonBox(
          height: _kSeasonSkeletonHeight,
          borderRadius: t.radius.smAll,
        ),
      AsyncError<SeriesDetail>(:final Failures failure) => Text(
          failure.localized(AppLocalizations.of(context)),
          style: t.typography.caption.copyWith(color: t.colors.textSecondary),
        ),
      AsyncSuccess<SeriesDetail>(:final SeriesDetail data) => _Seasons(
          seasons: data.seasons,
          onPlayEpisode: onPlayEpisode,
          episodeTrailing: episodeTrailing,
          seasonAction: seasonAction,
        ),
    };
  }
}

class _Seasons extends StatefulWidget {
  const _Seasons({
    required this.seasons,
    required this.onPlayEpisode,
    this.episodeTrailing,
    this.seasonAction,
  });

  final IList<Season> seasons;
  final void Function(Season season, Episode episode)? onPlayEpisode;
  final Widget Function(Season season, Episode episode)? episodeTrailing;
  final Widget Function(Season season)? seasonAction;

  @override
  State<_Seasons> createState() => _SeasonsState();
}

class _SeasonsState extends State<_Seasons> {
  int _seasonIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool isTv = FormFactorScope.isTv(context);
    final IList<Season> seasons = widget.seasons;
    if (seasons.isEmpty) {
      return Text(
        AppLocalizations.of(context).seriesNoEpisodes,
        style: t.typography.caption.copyWith(color: t.colors.textTertiary),
      );
    }
    final int index = _seasonIndex.clamp(0, seasons.length - 1);
    final Season season = seasons[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: SizedBox(
                height: _kSeasonChipsHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: seasons.length,
                  separatorBuilder: (BuildContext c, int i) =>
                      SizedBox(width: t.space.x2),
                  itemBuilder: (BuildContext c, int i) => FilterChipX(
                    label: seasons[i].name,
                    selected: i == index,
                    onTap: () => setState(() => _seasonIndex = i),
                  ),
                ),
              ),
            ),
            if (!isTv && widget.seasonAction != null)
              widget.seasonAction!(season),
          ],
        ),
        SizedBox(height: t.space.x3),
        for (int i = 0; i < season.episodes.length; i++)
          _EpisodeRow(
            episode: season.episodes[i],
            // On TV the hero Play owns initial focus; here the list is reached
            // by pressing Down, so don't steal focus. On mobile, no autofocus.
            autofocus: false,
            onPlay: () =>
                widget.onPlayEpisode?.call(season, season.episodes[i]),
            trailing: !isTv && widget.episodeTrailing != null
                ? widget.episodeTrailing!(season, season.episodes[i])
                : null,
          ),
        if (isTv) SizedBox(height: t.space.x6),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.coverUrl});

  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Widget image = coverUrl == null || coverUrl!.isEmpty
        ? ColoredBox(color: t.colors.bgElevated)
        : CachedNetworkImage(
            imageUrl: coverUrl!,
            fit: BoxFit.cover,
            placeholder: (BuildContext c, String _) => const SkeletonBox(),
            errorWidget: (BuildContext c, String _, Object __) =>
                ColoredBox(color: t.colors.bgElevated),
          );
    return AspectRatio(aspectRatio: _kBackdropAspect, child: image);
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.onPlay,
    this.autofocus = false,
    this.trailing,
  });

  final Episode episode;
  final VoidCallback onPlay;
  final bool autofocus;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final String subtitle = episode.duration.isEmpty
        ? AppLocalizations.of(context).episodeLabel(episode.episodeNum)
        : episode.duration;
    return PressableScale(
      onTap: onPlay,
      autofocus: autofocus,
      focusBorderRadius: t.radius.mdAll,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space.x2, horizontal: t.space.x2),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.play_circle_outline,
              color: t.colors.accent,
              size: _kEpisodePlayIconSize,
            ),
            SizedBox(width: t.space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "${episode.episodeNum}. ${episode.title}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.textPrimary),
                  ),
                  Text(
                    subtitle,
                    style: t.typography.caption
                        .copyWith(color: t.colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

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

/// On TV the hero is capped to this fraction of the viewport height so the
/// synopsis + episodes stay above the fold (a full-width 16:9 image would
/// otherwise fill the whole landscape screen).
const double _kTvHeroHeightFraction = 0.4;
const double _kSeasonSkeletonHeight = 120;
const double _kSeasonChipsHeight = 34;
const double _kEpisodePlayIconSize = 28;

/// Series detail (§4.4.1): hero, synopsis, season picker, episode list.
class SeriesDetailView extends ConsumerWidget {
  const SeriesDetailView({
    required this.series,
    this.onPlayEpisode,
    this.actions,
    super.key,
  });

  final Series series;
  final void Function(Season season, Episode episode)? onPlayEpisode;

  /// App-layer actions (e.g. a favorite toggle) shown in the app bar.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<SeriesDetail> detail =
        ref.watch(seriesDetailProvider(series.id));

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(backgroundColor: t.colors.bgBase, actions: actions),
      body: ListView(
        padding: EdgeInsets.only(bottom: t.space.x8) + tvOverscan(context),
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
                _SeasonsSection(detail: detail, onPlayEpisode: onPlayEpisode),
              ],
            ),
          ),
        ],
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
                _expanded ? AppLocalizations.of(context).commonLess : AppLocalizations.of(context).commonMore,
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
  const _SeasonsSection({required this.detail, required this.onPlayEpisode});

  final AsyncState<SeriesDetail> detail;
  final void Function(Season season, Episode episode)? onPlayEpisode;

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
        ),
    };
  }
}

class _Seasons extends StatefulWidget {
  const _Seasons({required this.seasons, required this.onPlayEpisode});

  final IList<Season> seasons;
  final void Function(Season season, Episode episode)? onPlayEpisode;

  @override
  State<_Seasons> createState() => _SeasonsState();
}

class _SeasonsState extends State<_Seasons> {
  int _seasonIndex = 0;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
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
        SizedBox(
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
        SizedBox(height: t.space.x3),
        for (int i = 0; i < season.episodes.length; i++)
          _EpisodeRow(
            episode: season.episodes[i],
            // Anchor the TV remote on the first episode so play is one click.
            autofocus: i == 0 && FormFactorScope.isTv(context),
            onPlay: () =>
                widget.onPlayEpisode?.call(season, season.episodes[i]),
          ),
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
    // TV: cap the height so episodes stay above the fold. Touch: full-width
    // 16:9 (only ~⅓ of a portrait phone screen).
    if (FormFactorScope.isTv(context)) {
      return SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * _kTvHeroHeightFraction,
        child: image,
      );
    }
    return AspectRatio(aspectRatio: _kBackdropAspect, child: image);
  }
}

class _EpisodeRow extends StatelessWidget {
  const _EpisodeRow({
    required this.episode,
    required this.onPlay,
    this.autofocus = false,
  });

  final Episode episode;
  final VoidCallback onPlay;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final String subtitle = episode.duration.isEmpty
        ? AppLocalizations.of(context).episodeLabel(episode.episodeNum)
        : episode.duration;
    return PressableScale(
      onTap: onPlay,
      autofocus: autofocus,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: t.space.x2),
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
          ],
        ),
      ),
    );
  }
}

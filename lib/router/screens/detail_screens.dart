import "package:auto_route/auto_route.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_vod/iptv_vod.dart";

import "../../download_launch.dart";
import "../../favorites/favorite_button.dart";
import "../../player_launch.dart";

/// Fiche film (§4.4.1).
@RoutePage()
class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({required this.movie, super.key});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MovieDetailView(
      movie: movie,
      onPlay: () => ref.openMovie(context, movie),
      actions: <Widget>[
        FavoriteButton(
          favorite: Favorite(
            id: movie.streamId,
            kind: ContentKind.movie,
            title: movie.name,
            subtitle: movie.year,
            posterUrl: movie.posterUrl,
            addedAtMillis: 0,
          ),
        ),
      ],
    );
  }
}

/// Fiche série (§4.4.1) with seasons + episodes.
@RoutePage()
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({required this.series, super.key});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.toastDownloadFailures(context);
    return SeriesDetailView(
      series: series,
      onPlayEpisode: (Season season, Episode episode) =>
          ref.openEpisode(context, series.id, season, episode),
      episodeTrailing: (Season season, Episode episode) => _EpisodeDownloadSlot(
        series: series,
        season: season,
        episode: episode,
      ),
      seasonAction: (Season season) =>
          _SeasonDownloadSlot(series: series, season: season),
      actions: <Widget>[
        FavoriteButton(
          favorite: Favorite(
            id: series.id,
            kind: ContentKind.series,
            title: series.name,
            subtitle: series.year,
            posterUrl: series.coverUrl,
            addedAtMillis: 0,
          ),
        ),
      ],
    );
  }
}

/// Records for [ids], keyed by episode id. Empty until the store has loaded.
IMap<String, DownloadRecord> _recordsFor(
  AsyncState<IList<DownloadRecord>> state,
) =>
    switch (state) {
      AsyncSuccess<IList<DownloadRecord>>(
        :final IList<DownloadRecord> data,
      ) =>
        IMap<String, DownloadRecord>.fromEntries(
          data.map(
            (DownloadRecord r) =>
                MapEntry<String, DownloadRecord>(r.contentId, r),
          ),
        ),
      AsyncIdle<IList<DownloadRecord>>() => IMap<String, DownloadRecord>(),
      AsyncLoading<IList<DownloadRecord>>() => IMap<String, DownloadRecord>(),
      AsyncError<IList<DownloadRecord>>() => IMap<String, DownloadRecord>(),
    };

class _EpisodeDownloadSlot extends ConsumerWidget {
  const _EpisodeDownloadSlot({
    required this.series,
    required this.season,
    required this.episode,
  });

  final Series series;
  final Season season;
  final Episode episode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IMap<String, DownloadRecord> records =
        _recordsFor(ref.watch(downloadsProvider));
    return EpisodeDownloadButton(
      record: records[episode.id],
      onDownload: () => ref.downloadEpisodes(
        series,
        season,
        <Episode>[episode].toIList(),
      ),
      onRemove: () => ref.read(downloadsProvider.notifier).remove(episode.id),
    );
  }
}

class _SeasonDownloadSlot extends ConsumerWidget {
  const _SeasonDownloadSlot({required this.series, required this.season});

  final Series series;
  final Season season;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final IMap<String, DownloadRecord> records =
        _recordsFor(ref.watch(downloadsProvider));
    final IList<DownloadRecord> mine = season.episodes
        .map((Episode e) => records[e.id])
        .whereType<DownloadRecord>()
        .toIList();
    final int completed =
        mine.where((DownloadRecord r) => r.phase is DownloadCompleted).length;
    return SeasonDownloadButton(
      totalCount: season.episodes.length,
      completedCount: completed,
      startedCount: mine.length,
      // Skips queued/running/done; failed ones are retried.
      onDownload: () => ref.downloadEpisodes(
        series,
        season,
        season.episodes
            .where(
              (Episode e) => switch (records[e.id]?.phase) {
                null => true,
                DownloadFailed() => true,
                DownloadQueued() => false,
                DownloadRunning() => false,
                DownloadPaused() => false,
                DownloadCompleted() => false,
              },
            )
            .toIList(),
      ),
    );
  }
}

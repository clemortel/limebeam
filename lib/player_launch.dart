import "package:auto_route/auto_route.dart";
import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_api/iptv_api.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_player/iptv_player.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

import "router/router.gr.dart";

/// When a resume point is within this many seconds of the end, resuming an
/// episode starts the *next* episode instead (the current one is effectively
/// watched).
const int _kResumeNextThresholdSeconds = 120;

/// Builds playback queues from the active source and pushes the player.
///
/// The player itself is feature-agnostic (it only knows [PlaybackRequest]s);
/// translating a Channel/Movie/Episode into a queue + stream URL happens here,
/// including resuming from a saved [WatchSession].
extension PlayerLaunch on WidgetRef {
  /// Plays a downloaded episode with no network.
  Future<void> openDownloadedEpisode(
    BuildContext context,
    DownloadRecord record,
  ) async {}

  /// Plays the tapped channel; the queue is the visible category so the
  /// in-player mini-list can zap between channels.
  void openChannel(BuildContext context, Channel channel) {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
    final IList<Channel> scope = _scopedChannels(channel);
    final IList<PlaybackRequest> items = scope
        .map(
          (Channel c) => PlaybackRequest(
            contentId: c.id,
            kind: PlaybackKind.live,
            title: c.name,
            posterUrl: c.logoUrl,
            url: source.buildLiveUrl(c.streamId),
            // HLS variant for the iOS AVPlayer (AirPlay) path, which cannot
            // decode the default MPEG-TS live stream.
            externalUrl: source.buildLiveUrl(c.streamId, hls: true),
          ),
        )
        .toIList();
    final int index = scope.indexWhere((Channel c) => c.id == channel.id);
    final AppPreferences prefs = read(appPreferencesProvider);
    _push(
      context,
      PlaybackQueue(
        items: items,
        index: index < 0 ? 0 : index,
        gesturesEnabled: prefs.playerGestures,
      ),
    );
  }

  void openMovie(BuildContext context, Movie movie) {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
    final PlaybackRequest request = PlaybackRequest(
      contentId: movie.streamId,
      kind: PlaybackKind.movie,
      title: movie.name,
      subtitle: movie.year,
      posterUrl: movie.posterUrl,
      containerExtension: movie.containerExtension,
      url: source.buildMovieUrl(movie.streamId, movie.containerExtension),
      startAt: _resumeFor(ContentKind.movie, movie.streamId),
    );
    final AppPreferences prefs = read(appPreferencesProvider);
    _pushVod(
      context,
      PlaybackQueue.single(request, gesturesEnabled: prefs.playerGestures),
    );
  }

  /// Plays the tapped episode; the queue is the whole season so the in-player
  /// mini-list can move to the next/previous episode.
  void openEpisode(
    BuildContext context,
    String seriesId,
    Season season,
    Episode episode,
  ) {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
    final int index =
        season.episodes.indexWhere((Episode e) => e.id == episode.id);
    final AppPreferences prefs = read(appPreferencesProvider);
    _pushVod(
      context,
      PlaybackQueue(
        items: _seasonQueue(source, seriesId, season),
        index: index < 0 ? 0 : index,
        autoplayNext: prefs.autoplayNext,
        gesturesEnabled: prefs.playerGestures,
      ),
    );
  }

  /// Resumes a continue-watching entry. For an episode this rebuilds the whole
  /// season queue (so next/previous work in the player) and, when the saved
  /// point is within [_kResumeNextThresholdSeconds] of the end, starts the
  /// *next* episode instead. Falls back to a single-item resume when the season
  /// can't be fetched (or the entry is a movie / a legacy session with no
  /// seriesId).
  Future<void> openSession(BuildContext context, WatchSession session) async {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
    final AppPreferences prefs = read(appPreferencesProvider);

    if (session.kind == ContentKind.episode && session.seriesId != null) {
      final Either<Failures, SeriesDetail> result =
          await read(seriesRepositoryProvider).getSeriesInfo(session.seriesId!);
      if (!context.mounted) return;
      final SeriesDetail? detail =
          result.fold((Failures _) => null, (SeriesDetail d) => d);
      Season? season;
      for (final Season s
          in detail?.seasons ?? const IListConst<Season>(<Season>[])) {
        if (s.episodes.any((Episode e) => e.id == session.id)) {
          season = s;
          break;
        }
      }
      if (season != null) {
        final int current =
            season.episodes.indexWhere((Episode e) => e.id == session.id);
        // Near the end → start the next episode (if any) fresh.
        final bool nearEnd = session.durationSeconds > 0 &&
            session.positionSeconds >=
                session.durationSeconds - _kResumeNextThresholdSeconds;
        final bool hasNext = current >= 0 &&
            current < season.episodes.length - 1;
        final int index =
            (nearEnd && hasNext) ? current + 1 : (current < 0 ? 0 : current);
        _pushVod(
          context,
          PlaybackQueue(
            items: _seasonQueue(source, session.seriesId!, season),
            index: index,
            autoplayNext: prefs.autoplayNext,
            gesturesEnabled: prefs.playerGestures,
          ),
        );
        return;
      }
    }

    // Movie, or episode whose season couldn't be resolved: single-item resume.
    final String url = switch (session.kind) {
      ContentKind.episode =>
        source.buildSeriesUrl(session.id, session.containerExtension),
      _ => source.buildMovieUrl(session.id, session.containerExtension),
    };
    final PlaybackRequest request = PlaybackRequest(
      contentId: session.id,
      kind: session.kind == ContentKind.episode
          ? PlaybackKind.episode
          : PlaybackKind.movie,
      title: session.title,
      subtitle: session.subtitle,
      posterUrl: session.posterUrl,
      containerExtension: session.containerExtension,
      seriesId: session.seriesId,
      url: url,
      startAt: Duration(seconds: session.positionSeconds),
    );
    if (!context.mounted) return;
    _pushVod(
      context,
      PlaybackQueue.single(request, gesturesEnabled: prefs.playerGestures),
    );
  }

  /// Builds the playable queue for a whole [season], each item carrying its own
  /// saved resume offset and the parent [seriesId].
  IList<PlaybackRequest> _seasonQueue(
    IPlaylistSource source,
    String seriesId,
    Season season,
  ) {
    return season.episodes
        .map(
          (Episode e) => PlaybackRequest(
            contentId: e.id,
            kind: PlaybackKind.episode,
            title: e.title,
            subtitle: "S${e.season} · E${e.episodeNum}",
            containerExtension: e.containerExtension,
            seriesId: seriesId,
            url: source.buildSeriesUrl(e.id, e.containerExtension),
            startAt: _resumeFor(ContentKind.episode, e.id),
          ),
        )
        .toIList();
  }

  /// The channels currently visible in the TV tab (selected category, or all).
  IList<Channel> _scopedChannels(Channel fallback) {
    final AsyncState<IList<Channel>> channelsState =
        read(liveChannelsProvider);
    final IList<Channel> all = switch (channelsState) {
      AsyncSuccess<IList<Channel>>(:final IList<Channel> data) => data,
      _ => const IListConst<Channel>(<Channel>[]),
    };
    if (all.isEmpty) {
      return IList<Channel>(<Channel>[fallback]);
    }
    final String category = read(selectedLiveCategoryProvider);
    if (category.isEmpty) return all;
    return all.where((Channel c) => c.categoryId == category).toIList();
  }

  /// Saved resume offset for a VOD item, or zero when none exists.
  Duration _resumeFor(ContentKind kind, String id) {
    final AsyncState<IList<WatchSession>> state =
        read(watchSessionsProvider);
    final IList<WatchSession> sessions = switch (state) {
      AsyncSuccess<IList<WatchSession>>(:final IList<WatchSession> data) =>
        data,
      _ => const IListConst<WatchSession>(<WatchSession>[]),
    };
    final String key = "${kind.name}_$id";
    for (final WatchSession s in sessions) {
      if (s.key == key) return Duration(seconds: s.positionSeconds);
    }
    return Duration.zero;
  }

  /// Starts playback and opens the full-screen player.
  void _push(BuildContext context, PlaybackQueue queue) {
    if (queue.items.isEmpty) {
      _toastUnavailable(context);
      return;
    }
    read(playbackControllerProvider.notifier).start(queue);
    context.router.root.push(const PlayerRoute());
  }

  /// Like [_push] but refreshes continue-watching when the player closes.
  void _pushVod(BuildContext context, PlaybackQueue queue) {
    if (queue.items.isEmpty) {
      _toastUnavailable(context);
      return;
    }
    read(playbackControllerProvider.notifier).start(queue);
    context.router.root.push(const PlayerRoute()).then(
          (_) => read(watchSessionsProvider.notifier).refresh(),
        );
  }
}

void _toastUnavailable(BuildContext context) {
  AppToast.show(
    context,
    message: "Source indisponible",
    kind: ToastKind.error,
  );
}

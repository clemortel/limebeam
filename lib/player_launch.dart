import "package:auto_route/auto_route.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_api/iptv_api.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_player/iptv_player.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

import "router/router.gr.dart";

/// Builds playback queues from the active source and pushes the player.
///
/// The player itself is feature-agnostic (it only knows [PlaybackRequest]s);
/// translating a Channel/Movie/Episode into a queue + stream URL happens here,
/// including resuming from a saved [WatchSession].
extension PlayerLaunch on WidgetRef {
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
          ),
        )
        .toIList();
    final int index = scope.indexWhere((Channel c) => c.id == channel.id);
    final AppPreferences prefs = read(appPreferencesNotifierProvider);
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
    final AppPreferences prefs = read(appPreferencesNotifierProvider);
    _pushVod(
      context,
      PlaybackQueue.single(request, gesturesEnabled: prefs.playerGestures),
    );
  }

  /// Plays the tapped episode; the queue is the whole season so the in-player
  /// mini-list can move to the next/previous episode.
  void openEpisode(BuildContext context, Season season, Episode episode) {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
    final IList<PlaybackRequest> items = season.episodes
        .map(
          (Episode e) => PlaybackRequest(
            contentId: e.id,
            kind: PlaybackKind.episode,
            title: e.title,
            subtitle: "S${e.season} · E${e.episodeNum}",
            containerExtension: e.containerExtension,
            url: source.buildSeriesUrl(e.id, e.containerExtension),
            startAt: _resumeFor(ContentKind.episode, e.id),
          ),
        )
        .toIList();
    final int index =
        season.episodes.indexWhere((Episode e) => e.id == episode.id);
    final int start = index < 0 ? 0 : index;
    final AppPreferences prefs = read(appPreferencesNotifierProvider);
    _pushVod(
      context,
      PlaybackQueue(
        items: items,
        index: start,
        autoplayNext: prefs.autoplayNext,
        gesturesEnabled: prefs.playerGestures,
      ),
    );
  }

  /// Resumes a continue-watching entry: rebuilds the URL + start offset.
  void openSession(BuildContext context, WatchSession session) {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
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
      url: url,
      startAt: Duration(seconds: session.positionSeconds),
    );
    final AppPreferences prefs = read(appPreferencesNotifierProvider);
    _pushVod(
      context,
      PlaybackQueue.single(request, gesturesEnabled: prefs.playerGestures),
    );
  }

  /// The channels currently visible in the TV tab (selected category, or all).
  IList<Channel> _scopedChannels(Channel fallback) {
    final AsyncState<IList<Channel>> channelsState =
        read(liveChannelsNotifierProvider);
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
        read(watchSessionsNotifierProvider);
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
          (_) => read(watchSessionsNotifierProvider.notifier).refresh(),
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

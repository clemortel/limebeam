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
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_player/iptv_player.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

import "offline_queue.dart";
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
  /// Toasts every download failure once. Call from a screen's build:
  /// `ref.listen` is auto-disposed with the widget.
  void toastDownloadFailures(BuildContext context) {
    listen<DownloadFailure?>(downloadFailuresProvider, (
      DownloadFailure? _,
      DownloadFailure? next,
    ) {
      if (next == null || !context.mounted) return;
      final AppLocalizations l = AppLocalizations.of(context);
      AppToast.show(
        context,
        message: switch (next.kind) {
          DownloadFailureKind.enqueue => l.downloadsEnqueueFailed,
          DownloadFailureKind.remove => l.downloadsRemoveFailed,
        },
        kind: ToastKind.error,
      );
    });
  }

  /// Plays a downloaded episode with no network. The queue is the downloaded
  /// part of its season, so next/previous and autoplay work offline.
  Future<void> openDownloadedEpisode(
    BuildContext context,
    DownloadRecord record, {
    bool fromStart = false,
  }) async {
    final IDownloadsRepository repository = read(downloadsRepositoryProvider);
    final IList<DownloadRecord> season =
        offlineSeasonRecords(await _downloadRecords(), record);
    // Resolved per launch, never cached: the iOS container path changes.
    final List<Either<Failures, String>> urls = await Future.wait(
      season.map(repository.localUrlFor),
    );
    if (!context.mounted) return;
    final List<PlaybackRequest> items = <PlaybackRequest>[];
    int index = 0;
    for (int i = 0; i < season.length; i++) {
      final DownloadRecord r = season[i];
      final String? url = urls[i].fold((Failures _) => null, (String u) => u);
      if (url == null) continue;
      if (r.contentId == record.contentId) index = items.length;
      final PlaybackRequest item = _downloadedRequest(r, url);
      items.add(
        fromStart && r.contentId == record.contentId
            ? item.copyWith(startAt: Duration.zero)
            : item,
      );
    }
    final bool tappedPlayable =
        items.any((PlaybackRequest i) => i.contentId == record.contentId);
    if (!tappedPlayable) {
      _toastDownloadUnavailable(context);
      return;
    }
    final AppPreferences prefs = read(appPreferencesProvider);
    _pushVod(
      context,
      PlaybackQueue(
        items: items.toIList(),
        index: index,
        autoplayNext: prefs.autoplayNext,
        gesturesEnabled: prefs.playerGestures,
      ),
    );
  }

  PlaybackRequest _downloadedRequest(DownloadRecord r, String url) {
    return PlaybackRequest(
      contentId: r.contentId,
      kind: PlaybackKind.episode,
      title: r.title,
      subtitle: "S${r.seasonNumber} · E${r.episodeNumber}",
      posterUrl: r.seriesCoverUrl.isEmpty ? null : r.seriesCoverUrl,
      containerExtension: r.containerExtension,
      seriesId: r.seriesId,
      url: url,
      startAt: _resumeFor(ContentKind.episode, r.contentId),
    );
  }

  /// The active source's downloads. Trap: read from the repository, because
  /// [downloadsProvider] is still loading on a cold start and "Continue
  /// watching" would then go to the network in airplane mode. Trap: only
  /// the active source's, episode ids repeat across panels.
  Future<IList<DownloadRecord>> _downloadRecords() async => recordsOfSource(
        await read(downloadsRepositoryProvider).watch().first,
        _activeSourceId,
      );

  String? get _activeSourceId => read(activeSourceStoreProvider).sourceId;

  /// [items] with the item at [index] pointing at its downloaded file, when
  /// there is one. A bad local path never blocks playback: the online URL
  /// stays.
  Future<IList<PlaybackRequest>> _withLocalUrl(
    IList<PlaybackRequest> items,
    int index,
  ) async {
    if (index < 0 || index >= items.length) return items;
    final DownloadRecord? local = completedDownloadFor(
      await _downloadRecords(),
      _activeSourceId,
      items[index].contentId,
    );
    if (local == null) return items;
    final Either<Failures, String> localUrl =
        await read(downloadsRepositoryProvider).localUrlFor(local);
    final String? url = localUrl.fold((Failures _) => null, (String u) => u);
    return url == null
        ? items
        : items.replace(index, items[index].copyWith(url: url));
  }

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
  Future<void> openEpisode(
    BuildContext context,
    String seriesId,
    Season season,
    Episode episode,
  ) async {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) {
      _toastUnavailable(context);
      return;
    }
    // Offline (cached sheet on screen): the queue is the downloaded part of
    // the season, as in openDownloadedEpisode. Not downloaded: fall through.
    if (isServedFromCache(read(seriesDetailProvider(seriesId)))) {
      final DownloadRecord? local = completedDownloadFor(
        await _downloadRecords(),
        _activeSourceId,
        episode.id,
      );
      if (!context.mounted) return;
      if (local != null) {
        await openDownloadedEpisode(context, local);
        return;
      }
    }
    final int index =
        season.episodes.indexWhere((Episode e) => e.id == episode.id);
    final AppPreferences prefs = read(appPreferencesProvider);
    final IList<PlaybackRequest> items = await _withLocalUrl(
      _seasonQueue(source, seriesId, season),
      index,
    );
    if (!context.mounted) return;
    _pushVod(
      context,
      PlaybackQueue(
        items: items,
        index: index < 0 ? 0 : index,
        autoplayNext: prefs.autoplayNext,
        gesturesEnabled: prefs.playerGestures,
      ),
    );
  }

  /// Resumes a continue-watching entry. For an episode this rebuilds the whole
  /// season queue (so next/previous work in the player) and, when the saved
  /// point is within [_kResumeNextThresholdSeconds] of the end, starts the
  /// *next* episode instead. Falls back to a downloaded copy when the source
  /// or the season can't be reached, then to a single-item resume (also for a
  /// movie or a legacy session with no seriesId).
  ///
  /// Trap: the online path comes first even for a downloaded episode, so a
  /// connected device keeps the full season queue and the same near-the-end
  /// rule; the offline queue only holds what was downloaded.
  Future<void> openSession(BuildContext context, WatchSession session) async {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    final bool isEpisode = session.kind == ContentKind.episode;
    if (source == null) {
      if (isEpisode && await _resumeOffline(context, session)) return;
      if (!context.mounted) return;
      _toastUnavailable(context);
      return;
    }
    final AppPreferences prefs = read(appPreferencesProvider);

    if (isEpisode && session.seriesId != null) {
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
      // Cached sheet = offline: resume from the downloads (local queue and
      // offlineResumeTarget's near-end rule). None downloaded: online path.
      if (detail != null && detail.fromCache) {
        if (await _resumeOffline(context, session)) return;
        if (!context.mounted) return;
      }
      if (season != null) {
        final int current =
            season.episodes.indexWhere((Episode e) => e.id == session.id);
        // Near the end → start the next episode (if any) fresh.
        final bool nearEnd = session.durationSeconds > 0 &&
            session.positionSeconds >=
                session.durationSeconds - _kResumeNextThresholdSeconds;
        final bool hasNext =
            current >= 0 && current < season.episodes.length - 1;
        final int index =
            (nearEnd && hasNext) ? current + 1 : (current < 0 ? 0 : current);
        final IList<PlaybackRequest> items = await _withLocalUrl(
          _seasonQueue(source, session.seriesId!, season),
          index,
        );
        if (!context.mounted) return;
        _pushVod(
          context,
          PlaybackQueue(
            items: items,
            index: index,
            autoplayNext: prefs.autoplayNext,
            gesturesEnabled: prefs.playerGestures,
          ),
        );
        return;
      }
      // The season could not be fetched: the device may be offline.
      if (await _resumeOffline(context, session)) return;
      if (!context.mounted) return;
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

  /// Resumes [session] from its downloaded copy. False when there is none.
  /// Same near-the-end rule as the online path, see [offlineResumeTarget].
  Future<bool> _resumeOffline(
    BuildContext context,
    WatchSession session,
  ) async {
    final IList<DownloadRecord> records = await _downloadRecords();
    final DownloadRecord? local =
        completedDownloadFor(records, _activeSourceId, session.id);
    if (local == null) return false;
    if (!context.mounted) return true;
    final ({DownloadRecord record, bool fromStart}) target =
        offlineResumeTarget(
      season: offlineSeasonRecords(records, local),
      current: local,
      positionSeconds: session.positionSeconds,
      durationSeconds: session.durationSeconds,
      thresholdSeconds: _kResumeNextThresholdSeconds,
    );
    await openDownloadedEpisode(
      context,
      target.record,
      fromStart: target.fromStart,
    );
    return true;
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
    final AsyncState<IList<Channel>> channelsState = read(liveChannelsProvider);
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
    final AsyncState<IList<WatchSession>> state = read(watchSessionsProvider);
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

void _toastDownloadUnavailable(BuildContext context) {
  AppToast.show(
    context,
    message: AppLocalizations.of(context).downloadsUnavailable,
    kind: ToastKind.error,
  );
}

void _toastUnavailable(BuildContext context) {
  AppToast.show(
    context,
    message: AppLocalizations.of(context).sourceUnavailable,
    kind: ToastKind.error,
  );
}

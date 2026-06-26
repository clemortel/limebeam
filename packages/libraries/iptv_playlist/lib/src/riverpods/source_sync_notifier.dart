import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_epg/iptv_epg.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_vod/iptv_vod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "sync_progress.dart";

part "source_sync_notifier.g.dart";

/// Orchestrates the eager post-connect sync: live → vod → series → epg,
/// reporting [SyncProgress] for the connecting screen. Live is fatal on
/// failure; VOD/series surface their failure; EPG is best-effort.
///
/// keepAlive so the counts survive the connecting → success navigation.
@Riverpod(keepAlive: true)
class SourceSyncNotifier extends _$SourceSyncNotifier {
  @override
  SyncProgress build() => const SyncProgress();

  Future<void> run() async {
    state = const SyncProgress(step: SyncStep.live);
    final Either<Failures, int> live =
        await ref.read(liveRepositoryProvider).sync();
    final int? channels = live.fold((Failures f) => null, (int n) => n);
    if (channels == null) {
      state = state.copyWith(
        step: SyncStep.failed,
        failure: live.swap().getOrElse(() => const Failures.unexpected()),
      );
      return;
    }
    state = state.copyWith(step: SyncStep.vod, channels: channels);

    final Either<Failures, int> vod =
        await ref.read(vodRepositoryProvider).sync();
    state = state.copyWith(
      step: SyncStep.series,
      movies: vod.getOrElse(() => 0),
    );

    final Either<Failures, int> series =
        await ref.read(seriesRepositoryProvider).sync();
    state = state.copyWith(
      step: SyncStep.epg,
      series: series.getOrElse(() => 0),
    );

    // EPG is best-effort — its absence must not block onboarding.
    final Either<Failures, int> epg =
        await ref.read(epgRepositoryProvider).sync();
    state = state.copyWith(
      step: SyncStep.done,
      epgLoaded: epg.isRight(),
    );

    _refreshCaches();
  }

  /// Forces the feature notifiers to re-read the freshly-written cache.
  void _refreshCaches() {
    ref.invalidate(liveChannelsNotifierProvider);
    ref.invalidate(liveCategoriesNotifierProvider);
    ref.invalidate(vodNotifierProvider);
    ref.invalidate(vodCategoriesNotifierProvider);
    ref.invalidate(seriesNotifierProvider);
    ref.invalidate(seriesCategoriesNotifierProvider);
    ref.invalidate(epgNotifierProvider);
  }
}

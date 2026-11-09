import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter/foundation.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_epg/iptv_epg.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_vod/iptv_vod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "sync_gate_outcome.dart";
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

  /// The one sync gate: non-null from the first synchronous step of a sync or
  /// source change until it ends. Checked and set with no `await` between,
  /// so exactly one caller can win.
  Future<SyncProgress>? _inFlight;

  /// Runs one sync, or joins the one already in flight: two interleaved runs
  /// would write one source's channels under the other's keys. The returned
  /// future completes with the final progress, so callers always learn how
  /// it ended (never a silent no-op).
  Future<SyncProgress> run() {
    final Future<SyncProgress>? running = _inFlight;
    if (running != null) return running;
    final Completer<SyncProgress> done = Completer<SyncProgress>();
    _inFlight = done.future;
    return _syncAndFinish(done);
  }

  /// The only way to change the active source: [change] runs under the same
  /// gate as [run], so a switch can never land mid-sync (the repositories
  /// read the active store after their network await). Refused when a sync
  /// or another change is in flight. On success, when [shouldSync] agrees
  /// (default: yes), the sync starts inside the same claim, with no window.
  Future<SyncGateOutcome<T>> changeSource<T>(
    Future<Either<Failures, T>> Function() change, {
    bool Function(T value)? shouldSync,
  }) async {
    if (_inFlight != null) return SyncGateRefused<T>();
    final Completer<SyncProgress> done = Completer<SyncProgress>();
    _inFlight = done.future;
    final SyncProgress before = state;
    state = const SyncProgress(step: SyncStep.connecting);

    Either<Failures, T> result;
    try {
      result = await change();
    } on Object catch (error, stackTrace) {
      result = left(catchError(error, stackTrace));
    }
    final bool sync = result.fold(
      (Failures _) => false,
      (T value) => shouldSync?.call(value) ?? true,
    );
    if (!sync) {
      state = before;
      _inFlight = null;
      done.complete(before);
      return SyncGateRan<T>(result);
    }
    return SyncGateRan<T>(result, sync: _syncAndFinish(done));
  }

  Future<SyncProgress> _syncAndFinish(Completer<SyncProgress> done) async {
    try {
      await syncCatalog();
    } on Object catch (error, stackTrace) {
      // A throwing sync must still free the gate: otherwise `isRunning`
      // stays true and every add/switch/refresh is refused until restart.
      state = SyncProgress(
        step: SyncStep.failed,
        failure: catchError(error, stackTrace),
      );
    } finally {
      _inFlight = null;
      done.complete(state);
    }
    return state;
  }

  /// The sync steps themselves. Only [run] and [changeSource] call it, under
  /// the gate; overridable so tests can stand in for the repositories.
  @protected
  @visibleForOverriding
  Future<void> syncCatalog() async {
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

    invalidateCatalogCaches();
  }

  /// Forces the feature notifiers to re-read the cache. Also called on a
  /// source switch, so the previous source's catalog never lingers on
  /// screen when the new source's sync fails.
  void invalidateCatalogCaches() {
    ref.invalidate(liveChannelsProvider);
    ref.invalidate(liveCategoriesProvider);
    ref.invalidate(vodProvider);
    ref.invalidate(vodCategoriesProvider);
    ref.invalidate(seriesProvider);
    ref.invalidate(seriesCategoriesProvider);
    ref.invalidate(epgProvider);
  }
}

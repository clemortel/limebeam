import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:riverpod_annotation/riverpod_annotation.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;

import "../infrastructure/source_repository.dart" show ISourceRepository;
import "../models/source.dart";
import "../models/source_action_failure.dart";
import "providers.dart";

part "sources_notifier.g.dart";

/// Id of the active source, observable. The underlying [ActiveSourceStore]
/// is a plain holder, so this mirrors it for the UI.
@Riverpod(keepAlive: true)
class ActiveSourceId extends _$ActiveSourceId {
  @override
  String? build() => ref.read(activeSourceStoreProvider).sourceId;

  /// Re-reads the store after any change to it (switch, delete, add).
  ///
  /// A new id resets everything scoped to the previous source right away,
  /// before any sync and whatever its outcome: otherwise source A's
  /// favorites, sessions and catalog stay visible (and playable, with A's
  /// ids sent to B's portal) under source B.
  void sync() {
    final String? next = ref.read(activeSourceStoreProvider).sourceId;
    if (next == state) return;
    state = next;
    ref.read(sourceSyncProvider.notifier).invalidateCatalogCaches();
    for (final ProviderOrFamily scoped
        in ref.read(sourceScopedProvidersProvider)) {
      ref.invalidate(scoped);
    }
  }
}

/// Saved-source list for Réglages (§4.6). Long-lived cache.
@Riverpod(keepAlive: true)
class SourcesNotifier extends _$SourcesNotifier {
  @override
  AsyncState<IList<Source>> build() {
    _load();
    return const AsyncState<IList<Source>>.loading();
  }

  Future<void> _load() async {
    final IList<Source> sources =
        await ref.read(sourceRepositoryProvider).getSources();
    state = AsyncState<IList<Source>>.success(sources);
    ref.read(activeSourceIdProvider.notifier).sync();
  }

  Future<void> refresh() => _load();

  SourceSyncNotifier get _gate => ref.read(sourceSyncProvider.notifier);

  /// Makes [id] the active source and re-syncs the catalog from it. A no-op
  /// when it already is the active one.
  ///
  /// Goes through the sync gate: refused ([SyncInProgress]) while a sync is
  /// in flight, because a switch mid-sync would write the running source's
  /// channels under the new source's keys. The request is dropped, not
  /// queued; the UI disables the rows meanwhile. A failed sync is reported.
  Future<Either<SourceActionFailure, Unit>> activate(String id) async {
    if (ref.read(activeSourceIdProvider) == id) return right(unit);
    final SyncGateOutcome<Unit> outcome = await _gate.changeSource<Unit>(
      () => _setActive(id),
    );
    return _settle<Unit>(outcome);
  }

  Future<Either<Failures, Unit>> _setActive(String id) async {
    final Either<Failures, Unit> result =
        await ref.read(sourceRepositoryProvider).setActive(id);
    if (result.isRight()) ref.read(activeSourceIdProvider.notifier).sync();
    return result;
  }

  /// Turns a gate outcome into the action result: refusal, change failure,
  /// or the sync's own failure once it has ended.
  Future<Either<SourceActionFailure, T>> _settle<T>(
    SyncGateOutcome<T> outcome,
  ) async {
    switch (outcome) {
      case SyncGateRefused<T>():
        return left(const SourceActionFailure.syncInProgress());
      case SyncGateRan<T>(
          :final Either<Failures, T> result,
          :final Future<SyncProgress>? sync
        ):
        if (result.isLeft()) {
          return result.leftMap(SourceActionFailure.failed);
        }
        final SyncProgress? progress = await sync;
        final Failures? syncFailure = progress?.failure;
        if (progress != null && progress.isFailed && syncFailure != null) {
          return left(SourceActionFailure.failed(syncFailure));
        }
        return result.leftMap(SourceActionFailure.failed);
    }
  }

  /// Re-downloads the active source's catalog. Joins a sync already running.
  Future<SyncProgress> refreshCatalog() => _gate.run();

  /// Renames [id]. A blank name is refused, not silently accepted.
  Future<Either<SourceActionFailure, Unit>> rename(
    String id,
    String name,
  ) async {
    if (name.trim().isEmpty) return left(const SourceActionFailure.blankName());
    final Either<Failures, Unit> result =
        await ref.read(sourceRepositoryProvider).renameSource(id, name);
    await _load();
    return result.leftMap(SourceActionFailure.failed);
  }

  /// Deletes [id]. When it was the active source, the first remaining one
  /// takes over (and syncs), so the app never keeps pointing at a dead id.
  /// Deleting the active source goes through the sync gate, like [activate].
  ///
  /// The [DeleteOutcome] carries everything the caller needs afterwards, so
  /// the view reads no provider after the await (its element may be gone).
  Future<Either<SourceActionFailure, DeleteOutcome>> delete(String id) async {
    final bool wasActive = ref.read(activeSourceIdProvider) == id;
    if (!wasActive) {
      final Either<Failures, Unit> result =
          await ref.read(sourceRepositoryProvider).deleteSource(id);
      await _load();
      return result.map((Unit _) => DeleteOutcome.deleted).leftMap(
            SourceActionFailure.failed,
          );
    }
    final SyncGateOutcome<DeleteOutcome> outcome =
        await _gate.changeSource<DeleteOutcome>(
      _deleteActive(id),
      shouldSync: (DeleteOutcome o) => o == DeleteOutcome.deleted,
    );
    final Either<SourceActionFailure, DeleteOutcome> settled =
        await _settle<DeleteOutcome>(outcome);
    await _load();
    return settled;
  }

  Future<Either<Failures, DeleteOutcome>> Function() _deleteActive(
    String id,
  ) =>
      () async {
        final ISourceRepository repository = ref.read(sourceRepositoryProvider);
        final Either<Failures, Unit> deleted =
            await repository.deleteSource(id);
        if (deleted.isLeft()) {
          return deleted.map((Unit _) => DeleteOutcome.deleted);
        }
        final IList<Source> remaining = await repository.getSources();
        if (remaining.isEmpty) {
          ref.read(activeSourceIdProvider.notifier).sync();
          return right(DeleteOutcome.noSourceLeft);
        }
        final Either<Failures, Unit> next =
            await repository.setActive(remaining.first.id);
        ref.read(activeSourceIdProvider.notifier).sync();
        return next.map((Unit _) => DeleteOutcome.deleted);
      };
}

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:riverpod_annotation/riverpod_annotation.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;

import "../models/source.dart";
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

  bool get _isSyncing => ref.read(sourceSyncProvider).isRunning;

  /// Makes [id] the active source and re-syncs the catalog from it. A no-op
  /// when it already is the active one.
  ///
  /// Refused (left) while a sync is in flight: a switch mid-sync would write
  /// the running source's channels under the new source's keys. The latest
  /// request is dropped, not queued; the UI disables the rows meanwhile.
  Future<Either<Failures, Unit>> activate(String id) async {
    if (ref.read(activeSourceIdProvider) == id) return right(unit);
    if (_isSyncing) return left(const Failures.unexpected());
    final Either<Failures, Unit> result =
        await ref.read(sourceRepositoryProvider).setActive(id);
    if (result.isLeft()) return result;
    ref.read(activeSourceIdProvider.notifier).sync();
    await ref.read(sourceSyncProvider.notifier).run();
    return result;
  }

  /// Re-downloads the active source's catalog. Ignored while a sync runs.
  Future<void> refreshCatalog() => ref.read(sourceSyncProvider.notifier).run();

  Future<Either<Failures, Unit>> rename(String id, String name) async {
    if (name.trim().isEmpty) return right(unit);
    final Either<Failures, Unit> result =
        await ref.read(sourceRepositoryProvider).renameSource(id, name);
    await _load();
    return result;
  }

  /// Deletes [id]. When it was the active source, the first remaining one
  /// takes over (and syncs), so the app never keeps pointing at a dead id.
  /// Deleting the active source mid-sync is refused, like [activate].
  ///
  /// When nothing remains, [activeSourceIdProvider] ends up null: the caller
  /// sends the user back to the first-launch flow.
  Future<Either<Failures, Unit>> delete(String id) async {
    final bool wasActive = ref.read(activeSourceIdProvider) == id;
    if (wasActive && _isSyncing) return left(const Failures.unexpected());
    final Either<Failures, Unit> result =
        await ref.read(sourceRepositoryProvider).deleteSource(id);
    await _load();
    if (result.isLeft() || !wasActive) return result;
    final IList<Source> remaining = switch (state) {
      AsyncSuccess<IList<Source>>(:final IList<Source> data) => data,
      AsyncIdle<IList<Source>>() => IList<Source>(),
      AsyncLoading<IList<Source>>() => IList<Source>(),
      AsyncError<IList<Source>>() => IList<Source>(),
    };
    if (remaining.isEmpty) return result;
    await activate(remaining.first.id);
    return result;
  }
}

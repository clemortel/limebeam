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

  /// Re-reads the store after a switch or a delete.
  void sync() => state = ref.read(activeSourceStoreProvider).sourceId;
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

  /// Makes [id] the active source and re-syncs the catalog from it. A no-op
  /// when it already is the active one.
  Future<Either<Failures, Unit>> activate(String id) async {
    if (ref.read(activeSourceIdProvider) == id) return right(unit);
    final Either<Failures, Unit> result =
        await ref.read(sourceRepositoryProvider).setActive(id);
    if (result.isLeft()) return result;
    ref.read(activeSourceIdProvider.notifier).sync();
    await ref.read(sourceSyncProvider.notifier).run();
    return result;
  }

  /// Re-downloads the active source's catalog.
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
  Future<void> delete(String id) async {
    final bool wasActive = ref.read(activeSourceIdProvider) == id;
    await ref.read(sourceRepositoryProvider).deleteSource(id);
    await _load();
    if (!wasActive) return;
    final IList<Source> remaining = switch (state) {
      AsyncSuccess<IList<Source>>(:final IList<Source> data) => data,
      AsyncIdle<IList<Source>>() => IList<Source>(),
      AsyncLoading<IList<Source>>() => IList<Source>(),
      AsyncError<IList<Source>>() => IList<Source>(),
    };
    if (remaining.isNotEmpty) await activate(remaining.first.id);
  }
}

import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_riverpod/misc.dart" show ProviderOrFamily;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:riverpod/src/framework.dart" show Override;

Source _source(String id) => Source(
      id: id,
      name: "Source $id",
      type: SourceType.m3u,
      createdAtEpochMs: 0,
    );

/// In-memory repository that mirrors the real one's active-source rules.
class _FakeRepository implements ISourceRepository {
  _FakeRepository(this._store, List<Source> sources) : _sources = sources;

  final ActiveSourceStore _store;
  final List<Source> _sources;

  @override
  Future<IList<Source>> getSources() async => _sources.toIList();

  @override
  Future<Either<Failures, Unit>> setActive(String id) async {
    if (!_sources.any((Source s) => s.id == id)) {
      return left(const Failures.notFound());
    }
    _store.set(sourceId: id, config: const SourceConfig.demo());
    return right(unit);
  }

  bool failDelete = false;

  @override
  Future<Either<Failures, Unit>> deleteSource(String id) async {
    if (failDelete) return left(const Failures.network());
    _sources.removeWhere((Source s) => s.id == id);
    if (_store.sourceId == id) _store.clear();
    return right(unit);
  }

  @override
  Future<Either<Failures, Unit>> renameSource(String id, String name) async {
    final int i = _sources.indexWhere((Source s) => s.id == id);
    if (i < 0) return left(const Failures.notFound());
    _sources[i] = _sources[i].copyWith(name: name.trim());
    return right(unit);
  }

  @override
  Future<Either<Failures, Source>> addXtreamSource({
    required String name,
    required String host,
    required String username,
    required String password,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failures, Source>> addM3uSource({
    required String name,
    required String url,
    String? epgUrl,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failures, Source>> addDemoSource() =>
      throw UnimplementedError();

  @override
  Future<void> hydrateOnLaunch() async {}
}

class _FakeSync extends SourceSyncNotifier {
  int runs = 0;
  int cacheResets = 0;

  /// When set, a sync stays "in flight" until it completes.
  Completer<void>? gate;

  /// Final step the next sync ends on.
  SyncStep endsOn = SyncStep.done;

  @override
  Future<void> syncCatalog() async {
    runs++;
    state = const SyncProgress(step: SyncStep.live);
    if (gate != null) await gate!.future;
    state = endsOn == SyncStep.failed
        ? const SyncProgress(
            step: SyncStep.failed,
            failure: Failures.network(),
          )
        : SyncProgress(step: endsOn);
  }

  @override
  void invalidateCatalogCaches() => cacheResets++;
}

int _scopedBuilds = 0;

/// Stands in for a per-source provider such as favorites.
final Provider<int> _scoped = Provider<int>((Ref ref) => ++_scopedBuilds);

void main() {
  late ActiveSourceStore store;
  late _FakeSync sync;
  late _FakeRepository repository;
  late ProviderContainer container;

  setUp(() {
    _scopedBuilds = 0;
    store = ActiveSourceStore()
      ..set(sourceId: "a", config: const SourceConfig.demo());
    sync = _FakeSync();
    repository = _FakeRepository(
      store,
      <Source>[_source("a"), _source("b"), _source("c")],
    );
    container = ProviderContainer(
      overrides: <Override>[
        activeSourceStoreProvider.overrideWithValue(store),
        sourceRepositoryProvider.overrideWithValue(repository),
        sourceScopedProvidersProvider.overrideWithValue(
          IList<ProviderOrFamily>(<ProviderOrFamily>[_scoped]),
        ),
        sourceSyncProvider.overrideWith(() => sync),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<SourcesNotifier> loaded() async {
    container.read(sourcesProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(sourcesProvider.notifier);
  }

  IList<Source> sources() => switch (container.read(sourcesProvider)) {
        AsyncSuccess<IList<Source>>(:final IList<Source> data) => data,
        _ => IList<Source>(),
      };

  test("activate switches the active source and re-syncs the catalog",
      () async {
    final SourcesNotifier notifier = await loaded();

    final Either<SourceActionFailure, Unit> result =
        await notifier.activate("b");

    expect(result.isRight(), isTrue);
    expect(container.read(activeSourceIdProvider), "b");
    expect(sync.runs, 1);
  });

  test("activate on the already active source does nothing", () async {
    final SourcesNotifier notifier = await loaded();

    await notifier.activate("a");

    expect(sync.runs, 0);
  });

  test("activate keeps the current source when the switch fails", () async {
    final SourcesNotifier notifier = await loaded();

    final Either<SourceActionFailure, Unit> result =
        await notifier.activate("zzz");

    expect(result.isLeft(), isTrue);
    expect(container.read(activeSourceIdProvider), "a");
    expect(sync.runs, 0);
  });

  test("deleting the active source hands over to the next one", () async {
    final SourcesNotifier notifier = await loaded();

    await notifier.delete("a");

    expect(sources().map((Source s) => s.id).toList(), <String>["b", "c"]);
    expect(container.read(activeSourceIdProvider), "b");
    expect(sync.runs, 1);
  });

  test("deleting an inactive source leaves the active one alone", () async {
    final SourcesNotifier notifier = await loaded();

    await notifier.delete("b");

    expect(container.read(activeSourceIdProvider), "a");
    expect(sync.runs, 0);
  });

  test("should trim a rename and refuse a blank name", () async {
    final SourcesNotifier notifier = await loaded();

    final Either<SourceActionFailure, Unit> blank =
        await notifier.rename("b", "   ");
    await notifier.rename("a", "  Salon  ");

    expect(blank, left<SourceActionFailure, Unit>(const BlankName()));
    expect(
      sources().map((Source s) => s.name).toList(),
      <String>["Salon", "Source b", "Source c"],
    );
  });

  test("should refuse to switch while a sync is in flight", () async {
    final SourcesNotifier notifier = await loaded();
    sync.gate = Completer<void>();
    final Future<Either<SourceActionFailure, Unit>> first =
        notifier.activate("b");
    await Future<void>.delayed(Duration.zero);

    final Either<SourceActionFailure, Unit> second =
        await notifier.activate("c");

    expect(second, left<SourceActionFailure, Unit>(const SyncInProgress()));
    expect(container.read(activeSourceIdProvider), "b");
    expect(store.sourceId, "b");
    sync.gate!.complete();
    await first;
  });

  test("should tell a refresh requested mid-sync how that sync ended",
      () async {
    final SourcesNotifier notifier = await loaded();
    sync.gate = Completer<void>();
    final Future<Either<SourceActionFailure, Unit>> first =
        notifier.activate("b");
    await Future<void>.delayed(Duration.zero);

    final Future<SyncProgress> refresh = notifier.refreshCatalog();
    sync.gate!.complete();

    expect((await refresh).isDone, isTrue);
    expect(sync.runs, 1);
    await first;
  });

  test("should let one of two racing activations win, refuse the other",
      () async {
    final SourcesNotifier notifier = await loaded();

    final Future<Either<SourceActionFailure, Unit>> toB =
        notifier.activate("b");
    final Future<Either<SourceActionFailure, Unit>> toC =
        notifier.activate("c");

    expect((await toB).isRight(), isTrue);
    expect(await toC, left<SourceActionFailure, Unit>(const SyncInProgress()));
    expect(store.sourceId, "b");
    expect(sync.runs, 1);
  });

  test("should report a failed sync after a switch", () async {
    final SourcesNotifier notifier = await loaded();
    sync.endsOn = SyncStep.failed;

    final Either<SourceActionFailure, Unit> result =
        await notifier.activate("b");

    expect(
      result,
      left<SourceActionFailure, Unit>(
        const SourceActionFailure.failed(Failures.network()),
      ),
    );
  });

  test("should refuse to delete the active source mid-sync", () async {
    final SourcesNotifier notifier = await loaded();
    sync.gate = Completer<void>();
    final Future<Either<SourceActionFailure, Unit>> first =
        notifier.activate("b");
    await Future<void>.delayed(Duration.zero);

    final Either<SourceActionFailure, DeleteOutcome> result =
        await notifier.delete("b");

    expect(
      result,
      left<SourceActionFailure, DeleteOutcome>(const SyncInProgress()),
    );
    expect(sources().map((Source s) => s.id), contains("b"));
    sync.gate!.complete();
    await first;
  });

  test("should return the outcome of deleting the active source", () async {
    final SourcesNotifier notifier = await loaded();

    final Either<SourceActionFailure, DeleteOutcome> result =
        await notifier.delete("a");

    expect(
      result,
      right<SourceActionFailure, DeleteOutcome>(DeleteOutcome.deleted),
    );
    expect(container.read(activeSourceIdProvider), "b");
  });

  test("should reset source-scoped providers and caches on a switch", () async {
    final SourcesNotifier notifier = await loaded();
    container.read(_scoped);
    expect(_scopedBuilds, 1);

    await notifier.activate("b");

    container.read(_scoped);
    expect(_scopedBuilds, 2);
    expect(sync.cacheResets, 1);
  });

  test("should follow the store when a source is added elsewhere", () async {
    await loaded();
    container.read(_scoped);

    store.set(sourceId: "c", config: const SourceConfig.demo());
    container.read(activeSourceIdProvider.notifier).sync();

    expect(container.read(activeSourceIdProvider), "c");
    container.read(_scoped);
    expect(_scopedBuilds, 2);
  });

  test("should not reset the scope when the id did not change", () async {
    await loaded();
    container.read(_scoped);

    container.read(activeSourceIdProvider.notifier).sync();

    expect(_scopedBuilds, 1);
    expect(sync.cacheResets, 0);
  });

  test("should surface a failed delete and keep the active source", () async {
    final SourcesNotifier notifier = await loaded();
    repository.failDelete = true;

    final Either<SourceActionFailure, DeleteOutcome> result =
        await notifier.delete("a");

    expect(result.isLeft(), isTrue);
    expect(container.read(activeSourceIdProvider), "a");
    expect(sync.runs, 0);
  });

  test("should leave no active source after deleting the last one", () async {
    final SourcesNotifier notifier = await loaded();
    await notifier.delete("c");
    await notifier.delete("b");

    final Either<SourceActionFailure, DeleteOutcome> result =
        await notifier.delete("a");

    expect(
      result,
      right<SourceActionFailure, DeleteOutcome>(DeleteOutcome.noSourceLeft),
    );
    expect(sources(), isEmpty);
    expect(container.read(activeSourceIdProvider), isNull);
    expect(sync.runs, 0);
  });
}

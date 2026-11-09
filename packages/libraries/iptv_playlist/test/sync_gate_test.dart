import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_riverpod/misc.dart" show Override;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";

class _GatedSync extends SourceSyncNotifier {
  int syncs = 0;
  bool throws = false;
  Completer<void> release = Completer<void>();

  @override
  Future<void> syncCatalog() async {
    syncs++;
    state = const SyncProgress(step: SyncStep.live);
    await release.future;
    if (throws) throw StateError("boom");
    state = const SyncProgress(step: SyncStep.done);
  }
}

void main() {
  late _GatedSync sync;
  late ProviderContainer container;

  setUp(() {
    sync = _GatedSync();
    container = ProviderContainer(
      overrides: <Override>[sourceSyncProvider.overrideWith(() => sync)],
    );
    addTearDown(container.dispose);
    container.read(sourceSyncProvider);
  });

  SourceSyncNotifier gate() => container.read(sourceSyncProvider.notifier);

  test("should hand the caller the in-flight sync instead of a no-op",
      () async {
    final Future<SyncProgress> first = gate().run();
    final Future<SyncProgress> second = gate().run();

    sync.release.complete();

    expect((await second).isDone, isTrue);
    expect((await first).isDone, isTrue);
    expect(sync.syncs, 1);
  });

  test("should refuse a source change while a sync runs", () async {
    final Future<SyncProgress> running = gate().run();
    bool changed = false;

    final SyncGateOutcome<Unit> outcome =
        await gate().changeSource<Unit>(() async {
      changed = true;
      return right(unit);
    });

    expect(outcome, isA<SyncGateRefused<Unit>>());
    expect(changed, isFalse);
    sync.release.complete();
    await running;
  });

  test("should let only one of two racing changes through", () async {
    int changes = 0;
    Future<Either<Failures, Unit>> change() async {
      changes++;
      await Future<void>.delayed(Duration.zero);
      return right(unit);
    }

    final Future<SyncGateOutcome<Unit>> a = gate().changeSource<Unit>(change);
    final Future<SyncGateOutcome<Unit>> b = gate().changeSource<Unit>(change);
    sync.release.complete();

    expect(await a, isA<SyncGateRan<Unit>>());
    expect(await b, isA<SyncGateRefused<Unit>>());
    expect(changes, 1);
  });

  test("should join the sync when run() lands during a change", () async {
    final Completer<void> slowChange = Completer<void>();
    final Future<SyncGateOutcome<Unit>> change =
        gate().changeSource<Unit>(() async {
      await slowChange.future;
      return right(unit);
    });
    final Future<SyncProgress> joined = gate().run();

    slowChange.complete();
    sync.release.complete();

    expect((await joined).isDone, isTrue);
    expect(await change, isA<SyncGateRan<Unit>>());
    expect(sync.syncs, 1);
  });

  test("should not sync, and free the gate, when the change fails", () async {
    final SyncGateOutcome<Unit> outcome = await gate()
        .changeSource<Unit>(() async => left(const Failures.notFound()));

    expect(outcome, isA<SyncGateRan<Unit>>());
    expect((outcome as SyncGateRan<Unit>).sync, isNull);
    expect(sync.syncs, 0);
    expect(container.read(sourceSyncProvider).isRunning, isFalse);
    sync.release.complete();
    expect((await gate().run()).isDone, isTrue);
  });

  test("should free the gate and report failure when the sync throws",
      () async {
    sync.throws = true;
    final Future<SyncProgress> running = gate().run();
    sync.release.complete();

    final SyncProgress ended = await running;

    expect(ended.isFailed, isTrue);
    expect(container.read(sourceSyncProvider).isRunning, isFalse);
    sync.throws = false;
    sync.release = Completer<void>()..complete();
    expect((await gate().run()).isDone, isTrue);
  });

  test("should run the before-switch hooks first, in order, then change",
      () async {
    final List<String> order = <String>[];
    final _GatedSync local = _GatedSync();
    final ProviderContainer hooked = ProviderContainer(
      overrides: <Override>[
        sourceSyncProvider.overrideWith(() => local),
        beforeSourceSwitchHooksProvider.overrideWithValue(
          IList<BeforeSourceSwitchHook>(<BeforeSourceSwitchHook>[
            (Ref ref) async => order.add("hook1"),
            (Ref ref) async => throw StateError("a failing hook"),
            (Ref ref) async => order.add("hook2"),
          ]),
        ),
      ],
    );
    addTearDown(hooked.dispose);

    final Future<SyncGateOutcome<Unit>> outcome =
        hooked.read(sourceSyncProvider.notifier).changeSource<Unit>(() async {
      order.add("change");
      return right(unit);
    });
    local.release.complete();
    await outcome;

    expect(order, <String>["hook1", "hook2", "change"]);
  });

  test("should run no hook for a change refused mid-sync", () async {
    int hooks = 0;
    final _GatedSync local = _GatedSync();
    final ProviderContainer hooked = ProviderContainer(
      overrides: <Override>[
        sourceSyncProvider.overrideWith(() => local),
        beforeSourceSwitchHooksProvider.overrideWithValue(
          IList<BeforeSourceSwitchHook>(<BeforeSourceSwitchHook>[
            (Ref ref) async => hooks++,
          ]),
        ),
      ],
    );
    addTearDown(hooked.dispose);
    final SourceSyncNotifier gate2 = hooked.read(sourceSyncProvider.notifier);
    final Future<SyncProgress> running = gate2.run();

    final SyncGateOutcome<Unit> outcome =
        await gate2.changeSource<Unit>(() async => right(unit));
    local.release.complete();
    await running;

    expect(outcome, isA<SyncGateRefused<Unit>>());
    expect(hooks, 0);
  });
}

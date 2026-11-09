import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";
import "package:riverpod/src/framework.dart";

import "add_xtream_source_notifier_test.mocks.dart";

/// Stands in for the catalog sync: ends at once, or when [gate] completes.
class _FakeSync extends SourceSyncNotifier {
  Completer<void>? gate;
  int syncs = 0;
  bool fails = false;

  @override
  Future<void> syncCatalog() async {
    syncs++;
    state = const SyncProgress(step: SyncStep.live);
    if (gate != null) await gate!.future;
    state = fails
        ? const SyncProgress(
            step: SyncStep.failed,
            failure: Failures.network(),
          )
        : const SyncProgress(step: SyncStep.done);
  }
}

// Run `melos run build_runner` to generate the mocks.
@GenerateMocks(<Type>[ISourceRepository])
void main() {
  late MockISourceRepository repository;

  const Source source = Source(
    id: "1",
    name: "Test",
    type: SourceType.xtream,
    createdAtEpochMs: 0,
    status: ConnectionStatus.ok,
  );

  setUpAll(() {
    provideDummy<Either<Failures, Source>>(right(source));
  });

  setUp(() => repository = MockISourceRepository());

  late _FakeSync sync;

  ProviderContainer makeContainer() {
    sync = _FakeSync();
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        sourceSyncProvider.overrideWith(() => sync),
        sourceRepositoryProvider.overrideWithValue(repository),
        activeSourceStoreProvider.overrideWithValue(ActiveSourceStore()),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void fillValidForm(AddXtreamSourceNotifier n) {
    n.setName("Test");
    n.setHost("http://portal.tv:8080");
    n.setUsername("user");
    n.setPassword("pass");
  }

  test("should not submit while the form is invalid", () async {
    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);

    await notifier.submit();

    verifyNever(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    );
  });

  test("should expose success submission when repository connects", () async {
    when(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).thenAnswer((_) async => right(source));

    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);
    fillValidForm(notifier);

    await notifier.submit();

    expect(
      container.read(addXtreamSourceProvider).submission,
      const AsyncState<Source>.success(source),
    );
  });

  test("should expose portalAuth error when credentials are invalid", () async {
    when(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).thenAnswer((_) async => left(const Failures.portalAuth()));

    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);
    fillValidForm(notifier);

    await notifier.submit();

    expect(
      container.read(addXtreamSourceProvider).submission,
      const AsyncState<Source>.error(Failures.portalAuth()),
    );
  });

  test("should refuse to add a source while a sync runs", () async {
    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);
    fillValidForm(notifier);
    sync.gate = Completer<void>();
    final Future<SyncProgress> running =
        container.read(sourceSyncProvider.notifier).run();

    final SyncProgress? progress = await notifier.submit();

    expect(progress, isNull);
    expect(container.read(addXtreamSourceProvider).syncBusy, isTrue);
    expect(
      container.read(addXtreamSourceProvider).submission,
      const AsyncState<Source>.idle(),
    );
    verifyNever(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    );
    sync.gate!.complete();
    await running;
  });

  test("should complete submit with the sync the add started", () async {
    when(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).thenAnswer((_) async => right(source));
    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);
    fillValidForm(notifier);

    final SyncProgress? progress = await notifier.submit();

    expect(progress?.isDone, isTrue);
  });

  test("should re-run only the sync when retrying after a failed sync",
      () async {
    when(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).thenAnswer((_) async => right(source));
    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);
    fillValidForm(notifier);
    sync.fails = true;
    final SyncProgress? failed = await notifier.submit();
    expect(failed?.isFailed, isTrue);

    sync.fails = false;
    final SyncProgress? retried = await notifier.retry();

    expect(retried?.isDone, isTrue);
    expect(sync.syncs, 2);
    verify(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).called(1);
  });

  test("should re-submit when retrying after a failed add", () async {
    when(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).thenAnswer((_) async => left(const Failures.network()));
    final ProviderContainer container = makeContainer();
    final AddXtreamSourceNotifier notifier =
        container.read(addXtreamSourceProvider.notifier);
    fillValidForm(notifier);
    await notifier.submit();

    await notifier.retry();

    verify(
      repository.addXtreamSource(
        name: anyNamed("name"),
        host: anyNamed("host"),
        username: anyNamed("username"),
        password: anyNamed("password"),
      ),
    ).called(2);
  });
}

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";
import "package:riverpod/src/framework.dart";

import "add_xtream_source_notifier_test.mocks.dart";

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

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
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
}

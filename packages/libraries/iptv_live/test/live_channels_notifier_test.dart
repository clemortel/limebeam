import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_live/iptv_live.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "live_channels_notifier_test.mocks.dart";

// Run `melos run build_runner` to generate the mocks.
@GenerateMocks(<Type>[ILiveRepository])
void main() {
  late MockILiveRepository repository;

  setUpAll(() {
    provideDummy<Either<Failures, IList<Channel>>>(
      right(const IListConst<Channel>(<Channel>[])),
    );
    provideDummy<Either<Failures, int>>(right(0));
  });

  setUp(() => repository = MockILiveRepository());

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        liveRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test("should emit success with channels when repository returns data",
      () async {
    final IList<Channel> channels = IList<Channel>(const <Channel>[
      Channel(
        id: "1",
        name: "BBC One",
        streamId: "1",
        categoryId: "c1",
      ),
    ]);
    when(repository.getChannels()).thenAnswer((_) async => right(channels));

    final ProviderContainer container = makeContainer();
    // build() triggers the first fetch; await a microtask turn.
    await container.read(liveChannelsNotifierProvider.notifier).silentRefresh();

    expect(
      container.read(liveChannelsNotifierProvider),
      AsyncState<IList<Channel>>.success(channels),
    );
  });

  test("should emit error when repository returns a failure", () async {
    when(repository.getChannels())
        .thenAnswer((_) async => left(const Failures.network()));

    final ProviderContainer container = makeContainer();
    await container.read(liveChannelsNotifierProvider.notifier).silentRefresh();

    expect(
      container.read(liveChannelsNotifierProvider),
      const AsyncState<IList<Channel>>.error(Failures.network()),
    );
  });
}

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "cast_devices_notifier_test.mocks.dart";

// Run `melos run build_runner` to generate the mocks.
@GenerateMocks(<Type>[ICastRepository])
void main() {
  late MockICastRepository repository;

  setUp(() {
    repository = MockICastRepository();
    when(repository.initialize()).thenAnswer((_) async {});
    when(repository.startDiscovery()).thenReturn(null);
    when(repository.stopDiscovery()).thenReturn(null);
  });

  ProviderContainer makeContainer() {
    final ProviderContainer container = ProviderContainer(
      overrides: [
        castRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  const CastDevice device = CastDevice(id: "abc", name: "Living Room TV");

  test("should start idle before discovery begins", () {
    final ProviderContainer container = makeContainer();

    expect(
      container.read(castDevicesProvider),
      const AsyncState<IList<CastDevice>>.idle(),
    );
  });

  test("should emit success with discovered devices after startDiscovery",
      () async {
    final IList<CastDevice> devices =
        IList<CastDevice>(const <CastDevice>[device]);
    when(repository.devices()).thenAnswer(
      (_) => Stream<IList<CastDevice>>.value(devices),
    );

    final ProviderContainer container = makeContainer();
    await container
        .read(castDevicesProvider.notifier)
        .startDiscovery();
    // Let the stream emission propagate.
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(castDevicesProvider),
      AsyncState<IList<CastDevice>>.success(devices),
    );
    verify(repository.initialize()).called(1);
    verify(repository.startDiscovery()).called(1);
  });

  test("should stop discovery and reset to idle", () async {
    when(repository.devices()).thenAnswer(
      (_) => const Stream<IList<CastDevice>>.empty(),
    );

    final ProviderContainer container = makeContainer();
    final CastDevicesNotifier notifier =
        container.read(castDevicesProvider.notifier);
    await notifier.startDiscovery();
    notifier.stopDiscovery();

    expect(
      container.read(castDevicesProvider),
      const AsyncState<IList<CastDevice>>.idle(),
    );
    verify(repository.stopDiscovery()).called(1);
  });
}

import "dart:async";

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../infrastructure/cast_repository.dart";
import "../models/cast_device.dart";
import "providers.dart";

part "cast_devices_notifier.g.dart";

/// Drives the cast device picker: starts Chromecast discovery and streams the
/// discovered receivers as the custom [AsyncState]. The active remote session
/// itself is owned by `PlaybackController` (it coordinates the local↔remote
/// handoff), so this notifier is purely the picker's data source.
@Riverpod(keepAlive: true)
class CastDevicesNotifier extends _$CastDevicesNotifier {
  StreamSubscription<IList<CastDevice>>? _subscription;

  /// Cached so [_stop] can run during `onDispose` without `ref.read` (which
  /// throws once the container is being torn down).
  ICastRepository? _repository;

  @override
  AsyncState<IList<CastDevice>> build() {
    ref.onDispose(_stop);
    return const AsyncState<IList<CastDevice>>.idle();
  }

  /// Initializes the Cast context, begins discovery, and pipes results into
  /// state. Call when the picker opens.
  Future<void> startDiscovery() async {
    final ICastRepository repository = ref.read(castRepositoryProvider);
    _repository = repository;
    await repository.initialize();
    state = const AsyncState<IList<CastDevice>>.loading();
    repository.startDiscovery();
    await _subscription?.cancel();
    _subscription = repository.devices().listen(
      (IList<CastDevice> devices) =>
          state = AsyncState<IList<CastDevice>>.success(devices),
    );
  }

  /// Stops discovery and clears the list. Call when the picker closes.
  void stopDiscovery() {
    _stop();
    state = const AsyncState<IList<CastDevice>>.idle();
  }

  void _stop() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _repository?.stopDiscovery();
  }
}

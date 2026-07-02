import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../infrastructure/pairing_server.dart";
import "../models/pairing.dart";

part "pairing_controller.g.dart";

/// Drives a "type on your phone" pairing session as the custom [AsyncState]:
/// loading while the server binds, success([PairingSession]) once the QR URL is
/// ready (re-emitted as the phone connects and submits), error on bind failure.
/// autoDispose: closing the sheet tears the server down via [ref.onDispose].
@riverpod
class PairingController extends _$PairingController {
  PairingServer? _server;
  StreamSubscription<PhoneCredentials>? _sub;

  @override
  AsyncState<PairingSession> build() {
    ref.onDispose(_teardown);
    return const AsyncState<PairingSession>.idle();
  }

  /// Binds the on-device server and starts advertising the QR URL.
  Future<void> start() async {
    state = const AsyncState<PairingSession>.loading();
    final Either<Failures, PairingServer> result = await PairingServer.start();
    state = result.fold(
      (Failures failure) => AsyncState<PairingSession>.error(failure),
      (PairingServer server) {
        _server = server;
        server.onConnected = _onPhoneConnected;
        _sub = server.credentials.listen(_onCredentials);
        return AsyncState<PairingSession>.success(
          PairingSession(url: server.url),
        );
      },
    );
  }

  void _onPhoneConnected() {
    final AsyncState<PairingSession> current = state;
    if (current is AsyncSuccess<PairingSession>) {
      state = AsyncState<PairingSession>.success(
        current.data.copyWith(phoneConnected: true),
      );
    }
  }

  void _onCredentials(PhoneCredentials creds) {
    final AsyncState<PairingSession> current = state;
    if (current is AsyncSuccess<PairingSession>) {
      state = AsyncState<PairingSession>.success(
        current.data.copyWith(received: creds),
      );
    }
  }

  /// Stops advertising and releases the port.
  Future<void> stop() async {
    await _teardown();
    state = const AsyncState<PairingSession>.idle();
  }

  Future<void> _teardown() async {
    await _sub?.cancel();
    _sub = null;
    await _server?.dispose();
    _server = null;
  }
}

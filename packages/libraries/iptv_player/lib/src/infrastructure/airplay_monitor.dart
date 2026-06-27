import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Event channel streaming the current iOS audio-output route (native → Dart).
const EventChannel _kRouteEvents = EventChannel("limebeam/route/events");

/// Reports whether the iOS output route is currently AirPlay, so the controller
/// can swap to the AVPlayer engine (which streams video over AirPlay) and back
/// to libmpv for local playback. iOS-only; returns an empty stream elsewhere.
class AirPlayMonitor {
  const AirPlayMonitor();

  /// Emits `true` while an AirPlay route is active, `false` otherwise. Emits the
  /// current state immediately on subscribe.
  Stream<bool> get airPlayActive {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const Stream<bool>.empty();
    }
    return _kRouteEvents.receiveBroadcastStream().map(
      (dynamic event) => event is Map && event["airplay"] == true,
    );
  }
}

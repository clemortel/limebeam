import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Thin bridge to the native Android MediaSession.
///
/// The MediaSession tells Fire OS (and any CEC-connected device) the *intended*
/// playback state, so Fire TV does not inject a spurious "play" command a few
/// seconds after the user intentionally pauses.
///
/// All calls are best-effort and no-op off Android.
class MediaSessionService {
  const MediaSessionService();

  static const MethodChannel _channel = MethodChannel("limebeam/player");

  /// Registers [onCommand] to receive play (true) / pause (false) intents
  /// that originate from the native MediaSession (e.g. voice commands, HDMI-CEC,
  /// lock-screen media controls). Call once when the engine is set up.
  void setCommandHandler(void Function(bool play) onCommand) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == "onPlay") onCommand(true);
      if (call.method == "onPause") onCommand(false);
    });
  }

  /// Pushes the current playing state to the native MediaSession so the OS
  /// always reflects the true intent (paused vs playing).
  Future<void> setPlaying({required bool playing}) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>("setPlaying", playing);
    } catch (_) {
      // Best-effort: a missing native side must never crash playback.
    }
  }
}

import "package:flutter/foundation.dart";
import "package:flutter/services.dart";

/// Thin bridge to native OS Picture-in-Picture. Android only — media_kit's
/// libmpv texture has no AVPlayerLayer, so iOS has no native PiP. All calls are
/// best-effort and no-op off Android.
class PipService {
  const PipService();

  static const MethodChannel _channel = MethodChannel("limebeam/pip");

  Future<bool> isSupported() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      return await _channel.invokeMethod<bool>("isSupported") ?? false;
    } catch (_) {
      return false; // PiP unavailable → hide the affordance.
    }
  }

  Future<void> enter() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>("enter");
    } catch (_) {
      // Best-effort: failing to enter PiP must never crash playback.
    }
  }
}

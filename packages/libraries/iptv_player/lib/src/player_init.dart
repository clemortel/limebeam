import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:media_kit/media_kit.dart";

bool _softwareRenderingOnly = false;

/// True on Android emulators, where libmpv's hardware GL context fails
/// (`eglCreateContext → EGL_BAD_ATTRIBUTE`, black video). The player then
/// disables hardware acceleration; real devices keep it.
bool get playerSoftwareRenderingOnly => _softwareRenderingOnly;

bool _isTelevision = false;

/// True on Android TV / Fire TV. Set once at startup via
/// [setPlayerTelevision]. Selects the SurfaceView-backed ExoPlayer engine for
/// LIVE playback (see `PlaybackController._createEngine`), whose hardware
/// overlay avoids the video-frame drops the libmpv texture path suffers on
/// weak TV GPUs. Off TV (phones/tablets) the value stays false and media_kit
/// is used for everything.
bool get playerIsTelevision => _isTelevision;

/// Records whether the current device is a TV. Call once from bootstrap after
/// the device class is known, before any [PlayerView] is shown.
void setPlayerTelevision({required bool isTelevision}) {
  _isTelevision = isTelevision;
}

bool _playerInitialized = false;

/// Initializes the media_kit engine + detects emulators. Idempotent. Called
/// from bootstrap AFTER the first frame (the native library load can take
/// seconds on weak TV hardware and must stay off the startup critical path),
/// and long before any [PlayerView] is shown. Keeps the engine import behind
/// the package boundary.
Future<void> ensurePlayerInitialized() async {
  if (_playerInitialized) return;
  _playerInitialized = true;
  MediaKit.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      _softwareRenderingOnly = !info.isPhysicalDevice;
    } catch (_) {
      // If detection fails, keep hardware acceleration (real-device default).
    }
  }
}

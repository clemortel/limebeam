import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:media_kit/media_kit.dart";

bool _softwareRenderingOnly = false;

/// True on Android emulators, where libmpv's hardware GL context fails
/// (`eglCreateContext → EGL_BAD_ATTRIBUTE`, black video). The player then
/// disables hardware acceleration; real devices keep it.
bool get playerSoftwareRenderingOnly => _softwareRenderingOnly;

/// Initializes the media_kit engine + detects emulators. Call once at startup
/// (bootstrap, awaited) before any [PlayerView] is shown. Keeps the engine
/// import behind the package boundary.
Future<void> ensurePlayerInitialized() async {
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

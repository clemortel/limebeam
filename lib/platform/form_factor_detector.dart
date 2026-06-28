import "package:device_info_plus/device_info_plus.dart";
import "package:flutter/foundation.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;

/// Android system features that mark a device as a television. Covers Android
/// TV (leanback / television hardware) and Amazon Fire TV.
const List<String> _kTvSystemFeatures = <String>[
  "android.software.leanback",
  "android.hardware.type.television",
  "amazon.hardware.fire_tv",
];

/// Detects whether the host is a television, using the platform's declared
/// system features. Pure read, safe to call once at startup.
///
/// Returns `false` on non-TV / unknown platforms; the size-based fallback in
/// [FormFactorScope] then distinguishes phone vs tablet. webOS reports TV
/// through its own signal once the LG Flutter SDK is wired in.
Future<bool> detectIsTelevision() async {
  if (defaultTargetPlatform != TargetPlatform.android) return false;
  try {
    final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
    return info.systemFeatures
        .any((String feature) => _kTvSystemFeatures.contains(feature));
  } catch (_) {
    // Detection failures default to non-TV; size heuristics still apply.
    return false;
  }
}

/// Holds the resolved "is a television" flag. Defaults to `false` and is
/// overridden in `bootstrap` with the value from [detectIsTelevision] so the
/// async probe runs exactly once, before the first frame.
final Provider<bool> televisionDetectedProvider =
    Provider<bool>((Ref ref) => false);

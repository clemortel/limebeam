import "dart:io";

import "package:flutter/services.dart";

const String _kChannel = "limebeam/download_storage";
const String _kDirectory = "downloads";

/// Device storage seam: free space and iCloud backup exclusion.
abstract interface class DownloadStorage {
  /// Free bytes available for user data, null when unknown.
  Future<int?> freeBytes();

  /// Creates the downloads folder if needed and keeps it out of the backup.
  /// Never throws.
  Future<void> excludeFromBackup();
}

/// Native-channel implementation. Android has no counterpart yet: it degrades
/// to "unknown" so the feature stays neutral there.
class ChannelDownloadStorage implements DownloadStorage {
  static const MethodChannel _channel = MethodChannel(_kChannel);

  @override
  Future<int?> freeBytes() async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<int>("freeBytes");
    } catch (_) {
      return null;
    }
  }

  /// Trap: applied on every launch, iOS may reset the flag after a restore.
  /// Trap: never relocate under Library/Caches, iOS purges it mid-download.
  @override
  Future<void> excludeFromBackup() async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>(
        "excludeFromBackup",
        <String, String>{"directory": _kDirectory},
      );
    } catch (_) {
      // Best effort: a failure only costs backup size.
    }
  }
}

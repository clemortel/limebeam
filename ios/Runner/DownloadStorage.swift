import Flutter
import Foundation

/// Native side of `iptv_downloads` storage: free space and iCloud backup
/// exclusion of `Documents/downloads`.
///
/// Trap: the folder must stay in Documents, never Library/Caches. iOS purges
/// Caches under disk pressure, which would delete an episode mid-download.
/// Trap: the exclusion flag can be reset by a restore, so Dart re-applies it
/// on every launch.
enum DownloadStorage {
  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "limebeam/download_storage",
      binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "freeBytes":
        result(freeBytes())
      case "excludeFromBackup":
        let args = call.arguments as? [String: String]
        result(excludeFromBackup(directory: args?["directory"] ?? "downloads"))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Space iOS is willing to give to user-initiated data (accounts for
  /// purgeable storage), nil when the system cannot say.
  private static func freeBytes() -> NSNumber? {
    let home = URL(fileURLWithPath: NSHomeDirectory())
    guard
      let values = try? home.resourceValues(forKeys: [
        .volumeAvailableCapacityForImportantUsageKey
      ]),
      let bytes = values.volumeAvailableCapacityForImportantUsage
    else { return nil }
    return NSNumber(value: bytes)
  }

  private static func excludeFromBackup(directory: String) -> Bool {
    guard
      let documents = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
      ).first
    else { return false }
    var url = documents.appendingPathComponent(directory, isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try url.setResourceValues(values)
      return true
    } catch {
      return false
    }
  }
}

import "package:freezed_annotation/freezed_annotation.dart";

part "download_storage_info.freezed.dart";

/// Disk figures for the Downloads header.
@freezed
sealed class DownloadStorageInfo with _$DownloadStorageInfo {
  const factory DownloadStorageInfo({
    /// Bytes taken by completed episodes.
    required int usedBytes,

    /// Free bytes on the device, null when the platform cannot tell.
    int? freeBytes,
  }) = _DownloadStorageInfo;
}

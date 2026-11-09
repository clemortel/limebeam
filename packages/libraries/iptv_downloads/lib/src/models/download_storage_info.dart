import "package:freezed_annotation/freezed_annotation.dart";

part "download_storage_info.freezed.dart";

/// Disk figures for the Downloads header.
@freezed
sealed class DownloadStorageInfo with _$DownloadStorageInfo {
  const factory DownloadStorageInfo({
    /// Bytes taken by the completed episodes of the active source.
    required int usedBytes,

    /// Bytes taken by every source's completed episodes.
    required int totalUsedBytes,

    /// Free bytes on the device, null when the platform cannot tell.
    int? freeBytes,
  }) = _DownloadStorageInfo;
}

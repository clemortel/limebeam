import "package:freezed_annotation/freezed_annotation.dart";

import "download_record.dart";

part "download_request.freezed.dart";

/// What the app layer hands over to start one download. Deliberately not
/// serializable: [url] embeds the Xtream password. This package never stores
/// or logs it, but the native plugin does copy it into its own task storage
/// (WorkManager on Android, resume data on iOS): see
/// `BackgroundDownloaderGateway` for what is purged and what remains.
@freezed
sealed class DownloadRequest with _$DownloadRequest {
  const DownloadRequest._();

  const factory DownloadRequest({
    required String contentId,
    required String sourceId,
    required String seriesId,
    required String seriesTitle,
    required int seasonNumber,
    required int episodeNumber,
    required String title,
    required String containerExtension,
    required String url,
    @Default("") String seriesCoverUrl,
    @Default("") String duration,
  }) = _DownloadRequest;

  /// Trap: the generated toString prints every field, [url] included.
  @override
  String toString() =>
      "DownloadRequest(key: ${downloadKey(sourceId, contentId)}, "
      "url: <redacted>)";
}

extension DownloadRequestKey on DownloadRequest {
  String get key => downloadKey(sourceId, contentId);
}

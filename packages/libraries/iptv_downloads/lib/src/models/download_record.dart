import "package:freezed_annotation/freezed_annotation.dart";

import "download_phase.dart";

part "download_record.freezed.dart";
part "download_record.g.dart";

/// Persisted metadata of one offline episode: everything the library and the
/// player need with no network, since `getSeriesInfo` is online-only.
///
/// Trap: never add the stream URL here, it embeds the Xtream password.
/// Trap: [relativePath] stays relative because the iOS container path changes
/// across app updates.
@freezed
sealed class DownloadRecord with _$DownloadRecord {
  const factory DownloadRecord({
    /// Episode id. Same key as watch progress, so resume is shared.
    required String contentId,
    required String seriesId,
    required String seriesTitle,
    required int seasonNumber,
    required int episodeNumber,
    required String title,
    required String containerExtension,
    required String relativePath,
    required DownloadPhase phase,
    @Default("") String seriesCoverUrl,
    @Default("") String duration,
  }) = _DownloadRecord;

  factory DownloadRecord.fromJson(Map<String, dynamic> json) =>
      _$DownloadRecordFromJson(json);
}

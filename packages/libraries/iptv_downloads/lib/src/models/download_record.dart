import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

import "download_phase.dart";

part "download_record.freezed.dart";
part "download_record.g.dart";

/// Persisted metadata of one offline episode: everything the library and the
/// player need with no network, since `getSeriesInfo` is online-only.
///
/// Trap: never add the stream URL here, it embeds the Xtream password.
/// Records are scoped to the playlist source that produced them: Xtream
/// episode ids are panel-local, so two sources can reuse the same id.
/// Trap: [relativePath] stays relative because the iOS container path changes
/// across app updates.
@freezed
sealed class DownloadRecord with _$DownloadRecord {
  const factory DownloadRecord({
    /// Episode id. Same key as watch progress, so resume is shared.
    required String contentId,

    /// The playlist source the episode belongs to. Empty only on records
    /// written before downloads were scoped: the repository adopts them to
    /// the active source (see `adoptLegacy`) and they never match a source
    /// until then.
    @Default("") String sourceId,
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

    /// Native task id of the current attempt (`<key>#<nonce>`). Empty on
    /// records written before attempts got their own id: their task id is
    /// the key, see [DownloadRecordKey.nativeTaskId].
    @Default("") String taskId,
  }) = _DownloadRecord;

  factory DownloadRecord.fromJson(Map<String, dynamic> json) =>
      _$DownloadRecordFromJson(json);
}

/// Identity of one download across sources. Also the native task id and the
/// Hive key. A legacy record (no source) keeps its bare content id, which is
/// what its native task and box entry were stored under.
String downloadKey(String sourceId, String contentId) =>
    sourceId.isEmpty ? contentId : "$sourceId:$contentId";

/// Separates the record key from the per-attempt nonce in a native task id.
/// Safe: content ids are validated to `[A-Za-z0-9_-]` before they get here.
const String kTaskIdSeparator = "#";

/// Task id of one enqueue. Trap: the key alone is not enough, a late event
/// of a removed attempt would be taken for the re-download of the same key.
String downloadTaskId(String key, String nonce) =>
    "$key$kTaskIdSeparator$nonce";

/// The record key a native task id belongs to. A bare key (legacy task)
/// maps to itself.
String keyOfTaskId(String taskId) {
  final int cut = taskId.lastIndexOf(kTaskIdSeparator);
  return cut < 0 ? taskId : taskId.substring(0, cut);
}

extension DownloadRecordKey on DownloadRecord {
  String get key => downloadKey(sourceId, contentId);

  /// What the native layer knows this download as right now.
  String get nativeTaskId => taskId.isEmpty ? key : taskId;
}

/// The records of [sourceId] only; none when there is no active source.
IList<DownloadRecord> recordsOfSource(
  IList<DownloadRecord> all,
  String? sourceId,
) =>
    sourceId == null || sourceId.isEmpty
        ? const IListConst<DownloadRecord>(<DownloadRecord>[])
        : all.where((DownloadRecord r) => r.sourceId == sourceId).toIList();

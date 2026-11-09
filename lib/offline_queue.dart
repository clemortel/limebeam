import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_downloads/iptv_downloads.dart";

/// The completed downloads of [tapped]'s season (same source), in episode
/// order.
///
/// [tapped] is always included, so the queue never loses the episode the user
/// asked for even if the live downloads list has not loaded yet.
IList<DownloadRecord> offlineSeasonRecords(
  IList<DownloadRecord> all,
  DownloadRecord tapped,
) {
  final List<DownloadRecord> season = all
      .where(
        (DownloadRecord r) =>
            r.phase is DownloadCompleted &&
            r.sourceId == tapped.sourceId &&
            r.seriesId == tapped.seriesId &&
            r.seasonNumber == tapped.seasonNumber,
      )
      .toList();
  if (!season.any((DownloadRecord r) => r.contentId == tapped.contentId)) {
    season.add(tapped);
  }
  season.sort(
    (DownloadRecord a, DownloadRecord b) =>
        a.episodeNumber.compareTo(b.episodeNumber),
  );
  return season.toIList();
}

/// The completed download of [contentId] in [sourceId], or null. Trap:
/// episode ids are panel-local, so the source is part of the match.
DownloadRecord? completedDownloadFor(
  IList<DownloadRecord> all,
  String? sourceId,
  String contentId,
) {
  if (sourceId == null) return null;
  for (final DownloadRecord r in all) {
    if (r.sourceId == sourceId &&
        r.contentId == contentId &&
        r.phase is DownloadCompleted) {
      return r;
    }
  }
  return null;
}

/// Where an offline "Continue watching" tap on [current] should start.
///
/// Mirrors the online rule: within [thresholdSeconds] of the end the episode
/// counts as watched, so the *next* episode starts from zero, provided it is
/// downloaded. Trap: a later downloaded episode is not the next one (E4 to E6
/// missing must not jump to E7); then the current one resumes as is.
/// [season] is [offlineSeasonRecords] output (episode order).
({DownloadRecord record, bool fromStart}) offlineResumeTarget({
  required IList<DownloadRecord> season,
  required DownloadRecord current,
  required int positionSeconds,
  required int durationSeconds,
  required int thresholdSeconds,
}) {
  final bool nearEnd = durationSeconds > 0 &&
      positionSeconds >= durationSeconds - thresholdSeconds;
  if (nearEnd) {
    for (final DownloadRecord r in season) {
      if (r.episodeNumber == current.episodeNumber + 1) {
        return (record: r, fromStart: true);
      }
    }
  }
  return (record: current, fromStart: false);
}

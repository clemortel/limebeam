import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_downloads/iptv_downloads.dart";

/// The completed downloads of [tapped]'s season, in episode order.
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

/// The completed download for [contentId], or null.
DownloadRecord? completedDownloadFor(
  IList<DownloadRecord> all,
  String contentId,
) {
  for (final DownloadRecord r in all) {
    if (r.contentId == contentId && r.phase is DownloadCompleted) return r;
  }
  return null;
}

/// Where an offline "Continue watching" tap on [current] should start.
///
/// Mirrors the online rule: within [thresholdSeconds] of the end the episode
/// counts as watched, so the next downloaded episode of [season] starts from
/// zero. With no next downloaded episode the current one resumes as is.
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
      if (r.episodeNumber > current.episodeNumber) {
        return (record: r, fromStart: true);
      }
    }
  }
  return (record: current, fromStart: false);
}

import "package:fast_immutable_collections/fast_immutable_collections.dart";

import "../models/download_phase.dart";
import "../models/download_record.dart";

/// One season of one series, episodes sorted by number.
class DownloadSeasonGroup {
  const DownloadSeasonGroup({required this.number, required this.episodes});

  final int number;
  final IList<DownloadRecord> episodes;
}

/// One series with its seasons, sorted by number.
class DownloadSeriesGroup {
  const DownloadSeriesGroup({
    required this.seriesId,
    required this.title,
    required this.coverUrl,
    required this.seasons,
  });

  final String seriesId;
  final String title;
  final String coverUrl;
  final IList<DownloadSeasonGroup> seasons;
}

/// Groups records series > season > episode, series ordered by title.
IList<DownloadSeriesGroup> groupDownloads(IList<DownloadRecord> records) {
  final Map<String, List<DownloadRecord>> bySeries =
      <String, List<DownloadRecord>>{};
  for (final DownloadRecord r in records) {
    bySeries.putIfAbsent(r.seriesId, () => <DownloadRecord>[]).add(r);
  }
  final List<DownloadSeriesGroup> groups =
      bySeries.values.map((List<DownloadRecord> list) {
    final Map<int, List<DownloadRecord>> bySeason =
        <int, List<DownloadRecord>>{};
    for (final DownloadRecord r in list) {
      bySeason.putIfAbsent(r.seasonNumber, () => <DownloadRecord>[]).add(r);
    }
    final List<DownloadSeasonGroup> seasons = bySeason.entries
        .map(
          (MapEntry<int, List<DownloadRecord>> e) => DownloadSeasonGroup(
            number: e.key,
            episodes: (e.value
                  ..sort(
                    (DownloadRecord a, DownloadRecord b) =>
                        a.episodeNumber.compareTo(b.episodeNumber),
                  ))
                .toIList(),
          ),
        )
        .toList()
      ..sort(
        (DownloadSeasonGroup a, DownloadSeasonGroup b) =>
            a.number.compareTo(b.number),
      );
    final DownloadRecord first = list.first;
    // Cover: first non-empty among the records.
    final String cover = list
        .map((DownloadRecord r) => r.seriesCoverUrl)
        .firstWhere((String u) => u.isNotEmpty, orElse: () => "");
    return DownloadSeriesGroup(
      seriesId: first.seriesId,
      title: first.seriesTitle,
      coverUrl: cover,
      seasons: seasons.toIList(),
    );
  }).toList()
        ..sort(
          (DownloadSeriesGroup a, DownloadSeriesGroup b) =>
              a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
  return groups.toIList();
}

/// Only a finished download can be played with no network.
bool isPlayable(DownloadRecord record) => switch (record.phase) {
      DownloadCompleted() => true,
      DownloadQueued() => false,
      DownloadRunning() => false,
      DownloadPaused() => false,
      DownloadFailed() => false,
    };

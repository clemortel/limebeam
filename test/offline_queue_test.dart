import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:green_iptv/offline_queue.dart";

DownloadRecord _record(
  String id, {
  required int episode,
  int season = 1,
  String series = "s1",
  DownloadPhase phase = const DownloadPhase.completed(),
}) =>
    DownloadRecord(
      contentId: id,
      seriesId: series,
      seriesTitle: "Show",
      seasonNumber: season,
      episodeNumber: episode,
      title: "Ep $episode",
      containerExtension: "mkv",
      relativePath: "downloads/$id.mkv",
      phase: phase,
    );

void main() {
  test("keeps completed same-season records sorted by episode", () {
    final DownloadRecord tapped = _record("b", episode: 2);
    final IList<DownloadRecord> all = <DownloadRecord>[
      _record("c", episode: 3),
      tapped,
      _record("a", episode: 1),
      _record("x", episode: 4, phase: const DownloadPhase.queued()),
      _record("y", episode: 1, season: 2),
      _record("z", episode: 1, series: "other"),
    ].toIList();

    final List<String> ids = offlineSeasonRecords(all, tapped)
        .map((DownloadRecord r) => r.contentId)
        .toList();
    expect(ids, <String>["a", "b", "c"]);
  });

  test("always includes the tapped record", () {
    final DownloadRecord tapped = _record("b", episode: 2);
    expect(
      offlineSeasonRecords(
              const IListConst<DownloadRecord>(<DownloadRecord>[]), tapped)
          .length,
      1,
    );
  });
}

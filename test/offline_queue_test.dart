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

  group("offlineResumeTarget", () {
    final DownloadRecord e1 = _record("a", episode: 1);
    final DownloadRecord e2 = _record("b", episode: 2);
    final DownloadRecord e3 = _record("c", episode: 3);
    final IList<DownloadRecord> season = <DownloadRecord>[e1, e2, e3].toIList();

    ({DownloadRecord record, bool fromStart}) pick(
      DownloadRecord current, {
      required int position,
      int duration = 1000,
    }) =>
        offlineResumeTarget(
          season: season,
          current: current,
          positionSeconds: position,
          durationSeconds: duration,
          thresholdSeconds: 120,
        );

    test("should resume the same episode mid-way", () {
      final ({DownloadRecord record, bool fromStart}) t =
          pick(e2, position: 500);
      expect(t.record.contentId, "b");
      expect(t.fromStart, isFalse);
    });

    test("should start the next downloaded episode from zero near the end", () {
      final ({DownloadRecord record, bool fromStart}) t =
          pick(e2, position: 880);
      expect(t.record.contentId, "c");
      expect(t.fromStart, isTrue);
    });

    test("should skip a gap to the next downloaded episode", () {
      final IList<DownloadRecord> gap = <DownloadRecord>[e1, e3].toIList();
      final ({DownloadRecord record, bool fromStart}) t = offlineResumeTarget(
        season: gap,
        current: e1,
        positionSeconds: 990,
        durationSeconds: 1000,
        thresholdSeconds: 120,
      );
      expect(t.record.contentId, "c");
    });

    test("should resume the last episode when there is no next one", () {
      final ({DownloadRecord record, bool fromStart}) t =
          pick(e3, position: 990);
      expect(t.record.contentId, "c");
      expect(t.fromStart, isFalse);
    });

    test("should never treat an unknown duration as near the end", () {
      final ({DownloadRecord record, bool fromStart}) t =
          pick(e2, position: 5000, duration: 0);
      expect(t.record.contentId, "b");
      expect(t.fromStart, isFalse);
    });
  });
}

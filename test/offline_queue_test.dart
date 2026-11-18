import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:green_iptv/offline_queue.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:iptv_series/iptv_series.dart";

DownloadRecord _record(
  String id, {
  required int episode,
  int season = 1,
  String series = "s1",
  String source = "src",
  DownloadPhase phase = const DownloadPhase.completed(),
}) =>
    DownloadRecord(
      contentId: id,
      sourceId: source,
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
  group("isServedFromCache", () {
    const SeriesDetail live = SeriesDetail(seasons: IListConst<Season>(<Season>[]));

    test("is true only for a successful cached sheet", () {
      expect(
        isServedFromCache(
          AsyncState<SeriesDetail>.success(live.copyWith(fromCache: true)),
        ),
        isTrue,
      );
      expect(
        isServedFromCache(const AsyncState<SeriesDetail>.success(live)),
        isFalse,
      );
      expect(
        isServedFromCache(const AsyncState<SeriesDetail>.loading()),
        isFalse,
      );
    });
  });

  test("an offline queue holds only downloaded episodes, in order", () {
    final DownloadRecord e2 = _record("b", episode: 2);
    final IList<DownloadRecord> all = <DownloadRecord>[
      _record("d", episode: 4),
      e2,
      _record("c", episode: 3, phase: const DownloadPhase.queued()),
    ].toIList();

    final List<int> numbers = offlineSeasonRecords(all, e2)
        .map((DownloadRecord r) => r.episodeNumber)
        .toList();

    expect(numbers, <int>[2, 4]);
  });

  test("near the end with the next episode not downloaded resumes local", () {
    final DownloadRecord e2 = _record("b", episode: 2);
    final IList<DownloadRecord> season = offlineSeasonRecords(
      <DownloadRecord>[e2, _record("d", episode: 4)].toIList(),
      e2,
    );

    final ({DownloadRecord record, bool fromStart}) target =
        offlineResumeTarget(
      season: season,
      current: e2,
      positionSeconds: 995,
      durationSeconds: 1000,
      thresholdSeconds: 30,
    );

    expect(target.record.contentId, "b");
    expect(target.fromStart, isFalse);
  });

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
        const IListConst<DownloadRecord>(<DownloadRecord>[]),
        tapped,
      ).length,
      1,
    );
  });

  test("season queue never mixes sources", () {
    final DownloadRecord tapped = _record("b", episode: 2);
    final IList<DownloadRecord> all = <DownloadRecord>[
      tapped,
      _record("b", episode: 2, source: "other"),
      _record("c", episode: 3, source: "other"),
    ].toIList();
    expect(offlineSeasonRecords(all, tapped).length, 1);
  });

  group("completedDownloadFor", () {
    final IList<DownloadRecord> all = <DownloadRecord>[
      _record("7", episode: 1, source: "a"),
      _record(
        "8",
        episode: 2,
        source: "a",
        phase: const DownloadPhase.queued(),
      ),
    ].toIList();

    test("should match the same source and id", () {
      expect(completedDownloadFor(all, "a", "7")?.sourceId, "a");
    });

    test("should ignore an id colliding in another source", () {
      expect(completedDownloadFor(all, "b", "7"), isNull);
      expect(completedDownloadFor(all, null, "7"), isNull);
    });

    test("should ignore unfinished downloads", () {
      expect(completedDownloadFor(all, "a", "8"), isNull);
    });
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

    test("should not jump over a gap to a later downloaded episode", () {
      final IList<DownloadRecord> gap = <DownloadRecord>[e1, e3].toIList();
      final ({DownloadRecord record, bool fromStart}) t = offlineResumeTarget(
        season: gap,
        current: e1,
        positionSeconds: 990,
        durationSeconds: 1000,
        thresholdSeconds: 120,
      );
      // E2 is missing: the online path would play it, offline cannot.
      expect(t.record.contentId, "a");
      expect(t.fromStart, isFalse);
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

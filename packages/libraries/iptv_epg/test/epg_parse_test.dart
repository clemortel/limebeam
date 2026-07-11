import "package:flutter_test/flutter_test.dart";
import "package:iptv_epg/src/infrastructure/epg_repository.dart";
import "package:iptv_epg/src/models/epg_entry.dart";

/// XMLTV times for a programme running "now" so it survives the prune window.
String _time(DateTime t) =>
    "${t.year.toString().padLeft(4, "0")}"
    "${t.month.toString().padLeft(2, "0")}"
    "${t.day.toString().padLeft(2, "0")}"
    "${t.hour.toString().padLeft(2, "0")}"
    "${t.minute.toString().padLeft(2, "0")}"
    "${t.second.toString().padLeft(2, "0")} +0000";

void main() {
  group("parseXmltvToJson / decodeEpgJson", () {
    test("round-trips a current programme with title and description", () {
      final DateTime now = DateTime.now().toUtc();
      final DateTime start = now.subtract(const Duration(minutes: 30));
      final DateTime stop = now.add(const Duration(minutes: 30));
      final String xml = """
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <programme start="${_time(start)}" stop="${_time(stop)}" channel="ch.1">
    <title>News</title>
    <desc>Evening news.</desc>
  </programme>
</tv>
""";
      final List<EpgEntry> entries = decodeEpgJson(parseXmltvToJson(xml));
      expect(entries, hasLength(1));
      final EpgEntry e = entries.single;
      expect(e.channelId, "ch.1");
      expect(e.title, "News");
      expect(e.description, "Evening news.");
      expect(e.isLiveAt(now), isTrue);
    });

    test("prunes programmes far outside the window", () {
      final DateTime now = DateTime.now().toUtc();
      final DateTime oldStart = now.subtract(const Duration(days: 10));
      final DateTime oldStop = oldStart.add(const Duration(hours: 1));
      final DateTime farStart = now.add(const Duration(days: 10));
      final DateTime farStop = farStart.add(const Duration(hours: 1));
      final String xml = """
<tv>
  <programme start="${_time(oldStart)}" stop="${_time(oldStop)}" channel="ch.1">
    <title>Old</title>
  </programme>
  <programme start="${_time(farStart)}" stop="${_time(farStop)}" channel="ch.1">
    <title>Far future</title>
  </programme>
</tv>
""";
      expect(decodeEpgJson(parseXmltvToJson(xml)), isEmpty);
    });

    test("keeps first title, skips broken programmes, handles CDATA", () {
      final DateTime now = DateTime.now().toUtc();
      final DateTime start = now.subtract(const Duration(minutes: 5));
      final DateTime stop = now.add(const Duration(minutes: 55));
      final String xml = """
<tv>
  <programme start="${_time(start)}" stop="${_time(stop)}" channel="ch.2">
    <title>First</title>
    <title lang="fr">Premier</title>
    <desc><![CDATA[Cdata description]]></desc>
  </programme>
  <programme channel="ch.3">
    <title>No times</title>
  </programme>
</tv>
""";
      final List<EpgEntry> entries = decodeEpgJson(parseXmltvToJson(xml));
      expect(entries, hasLength(1));
      expect(entries.single.title, "First");
      expect(entries.single.description, "Cdata description");
    });
  });
}

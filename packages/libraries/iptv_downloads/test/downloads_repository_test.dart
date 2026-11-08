import "dart:async";
import "dart:convert";
import "dart:io";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:iptv_downloads/src/infrastructure/download_gateway.dart";
import "package:iptv_downloads/src/infrastructure/downloads_repository_impl.dart";

const String _kSecretUrl = "http://panel.example/series/user/s3cr3t/42.mkv";

class FakeGateway implements DownloadGateway {
  final StreamController<GatewayEvent> controller =
      StreamController<GatewayEvent>.broadcast();
  final List<String> enqueued = <String>[];
  final List<String> canceled = <String>[];
  Set<String> active = <String>{};
  bool accept = true;
  final Set<String> throwing = <String>{};
  final List<String> purged = <String>[];

  @override
  Stream<GatewayEvent> get events => controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> enqueue(DownloadRequest request, String filename) async {
    enqueued.add(request.contentId);
    if (throwing.contains(request.contentId)) {
      throw const DownloadGatewayException("enqueue");
    }
    return accept;
  }

  @override
  Future<void> cancel(String contentId) async => canceled.add(contentId);

  @override
  Future<ISet<String>> activeIds() async => active.toISet();

  @override
  Future<void> purgeStoredTask(String contentId) async => purged.add(contentId);
}

DownloadRequest _request(String id) => DownloadRequest(
      contentId: id,
      seriesId: "s1",
      seriesTitle: "Show",
      seasonNumber: 1,
      episodeNumber: 2,
      title: "Pilot",
      containerExtension: "mkv",
      url: _kSecretUrl,
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late Directory dir;
  late Box<String> box;
  late FakeGateway gateway;
  late DownloadsRepository repo;

  Future<DownloadsRepository> build() async {
    final DownloadsRepository r = DownloadsRepository(
      box: box,
      gateway: gateway,
      documentsPath: () async => dir.path,
    );
    await r.initialize();
    return r;
  }

  setUp(() async {
    dir = await Directory.systemTemp.createTemp("dl_test");
    Hive.init(dir.path);
    box = await Hive.openBox<String>("downloads");
    gateway = FakeGateway();
    repo = await build();
  });

  tearDown(() async {
    await repo.dispose();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  test("phase JSON round trip", () {
    for (final DownloadPhase p in <DownloadPhase>[
      const DownloadPhase.queued(),
      const DownloadPhase.running(0.5),
      const DownloadPhase.completed(),
      const DownloadPhase.failed(),
    ]) {
      final DownloadPhase back = DownloadPhase.fromJson(
        jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>,
      );
      expect(back, p);
    }
  });

  test("enqueue is idempotent", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    expect(gateway.enqueued, <String>["a"]);
    final IList<DownloadRecord> list = await repo.watch().first;
    expect(list.single.phase, const DownloadPhase.queued());
    expect(list.single.relativePath, "downloads/a.mkv");
  });

  test("failed record is restarted by a new enqueue", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.failed));
    await _settle();
    expect((await repo.watch().first).single.phase, isA<DownloadFailed>());
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    expect(gateway.enqueued, <String>["a", "a"]);
    expect((await repo.watch().first).single.phase, isA<DownloadQueued>());
  });

  test("should fail the throwing record and still queue the others", () async {
    gateway.throwing.add("a");
    final Either<Failures, Unit> result = await repo.enqueue(
      <DownloadRequest>[_request("a"), _request("b")].toIList(),
    );
    expect(result.isLeft(), isTrue);
    expect(gateway.enqueued, <String>["a", "b"]);
    final IList<DownloadRecord> all = await repo.watch().first;
    DownloadPhase phase(String id) =>
        all.firstWhere((DownloadRecord r) => r.contentId == id).phase;
    expect(phase("a"), isA<DownloadFailed>());
    expect(phase("b"), isA<DownloadQueued>());
  });

  test("should purge stored task data on remove, end and dead task", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.failed));
    await _settle();
    await _settle();
    expect(gateway.purged, contains("a"));
    gateway.purged.clear();
    await repo.remove("a");
    expect(gateway.purged, <String>["a"]);
    gateway.purged.clear();
    await repo.enqueue(<DownloadRequest>[_request("b")].toIList());
    await repo.dispose();
    repo = await build();
    expect(gateway.purged, <String>["b"]);
  });

  test("progress stays in memory, status is persisted", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.running, 0.4));
    await _settle();
    final DownloadRecord live = (await repo.watch().first).single;
    expect(live.phase, const DownloadPhase.running(0.4));
    final Map<String, dynamic> stored =
        jsonDecode(box.get("a")!) as Map<String, dynamic>;
    expect(
      DownloadRecord.fromJson(stored).phase,
      const DownloadPhase.running(0),
    );
  });

  test("remove cancels, deletes the file and forgets the record", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    final File file = File("${dir.path}/downloads/a.mkv")
      ..createSync(recursive: true);
    final Either<Failures, Unit> result = await repo.remove("a");
    expect(result.isRight(), isTrue);
    expect(gateway.canceled, <String>["a"]);
    expect(file.existsSync(), isFalse);
    expect(box.get("a"), isNull);
    expect(await repo.watch().first, isEmpty);
  });

  test("reconcile on launch", () async {
    await repo.enqueue(
      <DownloadRequest>[
        _request("lost"),
        _request("done"),
        _request("alive"),
      ].toIList(),
    );
    File("${dir.path}/downloads/done.mkv").createSync(recursive: true);
    await repo.dispose();

    gateway = FakeGateway()..active = <String>{"alive"};
    repo = await build();
    final Map<String, DownloadPhase> phases = <String, DownloadPhase>{
      for (final DownloadRecord r in await repo.watch().first)
        r.contentId: r.phase,
    };
    expect(phases["lost"], isA<DownloadFailed>());
    expect(phases["done"], isA<DownloadCompleted>());
    expect(phases["alive"], isA<DownloadQueued>());
  });

  test("localUrlFor needs the file", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    final DownloadRecord record = (await repo.watch().first).single;
    expect((await repo.localUrlFor(record)).isLeft(), isTrue);
    File("${dir.path}/downloads/a.mkv").createSync(recursive: true);
    final Either<Failures, String> ok = await repo.localUrlFor(record);
    expect(ok.getOrElse(() => ""), startsWith("file://"));
  });

  test("a late tick never reopens a finished record", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller
      ..add(const GatewayEvent("a", GatewayStatus.completed))
      ..add(const GatewayEvent("a", GatewayStatus.running, 1));
    await _settle();
    final IList<DownloadRecord> list = await repo.watch().first;
    expect(list.single.phase, const DownloadPhase.completed());
  });

  test("no stored record contains the URL", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.completed));
    await _settle();
    for (final dynamic key in box.keys) {
      expect(box.get(key), isNot(contains("s3cr3t")));
      expect(box.get(key), isNot(contains("panel.example")));
    }
  });
}

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
import "package:iptv_downloads/src/infrastructure/download_storage.dart";
import "package:iptv_downloads/src/infrastructure/downloads_repository_impl.dart";

const String _kSecretUrl = "http://panel.example/series/user/s3cr3t/42.mkv";

class FakeGateway implements DownloadGateway {
  final StreamController<GatewayEvent> controller =
      StreamController<GatewayEvent>.broadcast();
  final List<String> enqueued = <String>[];
  final List<String> canceled = <String>[];
  Set<String> active = <String>{};
  bool accept = true;
  final List<String> paused = <String>[];
  final List<String> resumed = <String>[];
  bool canResume = true;
  int? size;
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
  Future<bool> pause(String contentId) async {
    paused.add(contentId);
    return true;
  }

  @override
  Future<bool> resume(String contentId) async {
    resumed.add(contentId);
    return canResume;
  }

  @override
  Future<int?> expectedSize(DownloadRequest request) async => size;

  @override
  Future<ISet<String>> activeIds() async => active.toISet();

  @override
  Future<void> purgeStoredTask(String contentId) async => purged.add(contentId);
}

class FakeStorage implements DownloadStorage {
  int? free;
  int excludeCalls = 0;

  @override
  Future<int?> freeBytes() async => free;

  @override
  Future<void> excludeFromBackup() async => excludeCalls++;
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
  late FakeStorage storage;
  late DownloadsRepository repo;

  Future<DownloadsRepository> build() async {
    final DownloadsRepository r = DownloadsRepository(
      box: box,
      gateway: gateway,
      storage: storage,
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
    storage = FakeStorage();
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
      const DownloadPhase.paused(),
      const DownloadPhase.failed(),
      const DownloadPhase.failed(reason: DownloadFailureReason.storage),
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

  test("backup exclusion is applied on every launch", () async {
    expect(storage.excludeCalls, 1);
    await repo.dispose();
    repo = await build();
    expect(storage.excludeCalls, 2);
  });

  test("an episode that does not fit is refused with a storage reason",
      () async {
    gateway.size = 900 * 1024 * 1024;
    storage.free = 1000 * 1024 * 1024;
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    expect(gateway.enqueued, isEmpty);
    expect(
      (await repo.watch().first).single.phase,
      const DownloadPhase.failed(reason: DownloadFailureReason.storage),
    );
  });

  test("a batch counts the episodes already accepted", () async {
    gateway.size = 400 * 1024 * 1024;
    storage.free = 1000 * 1024 * 1024;
    await repo.enqueue(
      <DownloadRequest>[_request("a"), _request("b")].toIList(),
    );
    expect(gateway.enqueued, <String>["a"]);
  });

  test("unknown size or unknown free space is accepted", () async {
    storage.free = 1;
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.size = 10 * 1024 * 1024 * 1024;
    storage.free = null;
    await repo.enqueue(<DownloadRequest>[_request("b")].toIList());
    expect(gateway.enqueued, <String>["a", "b"]);
  });

  test("pause waits for the native status, resume re-queues", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.running, 0.3));
    await _settle();
    await repo.pause("a");
    expect(gateway.paused, <String>["a"]);
    expect((await repo.watch().first).single.phase, isA<DownloadRunning>());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.paused));
    await _settle();
    expect((await repo.watch().first).single.phase, isA<DownloadPaused>());
    // A stale tick and a stale queued status do not undo the pause.
    gateway.controller
      ..add(const GatewayEvent("a", GatewayStatus.running, 0.31))
      ..add(const GatewayEvent("a", GatewayStatus.queued));
    await _settle();
    expect((await repo.watch().first).single.phase, isA<DownloadPaused>());
    await repo.resume("a");
    expect(gateway.resumed, <String>["a"]);
    expect((await repo.watch().first).single.phase, isA<DownloadQueued>());
  });

  test("resume of a lost transfer fails with a server reason", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.paused));
    await _settle();
    gateway.canResume = false;
    await repo.resume("a");
    expect(
      (await repo.watch().first).single.phase,
      const DownloadPhase.failed(reason: DownloadFailureReason.server),
    );
  });

  test("a native failure keeps its typed reason", () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(
      const GatewayEvent(
        "a",
        GatewayStatus.failed,
        0,
        DownloadFailureReason.network,
      ),
    );
    await _settle();
    expect(
      (await repo.watch().first).single.phase,
      const DownloadPhase.failed(reason: DownloadFailureReason.network),
    );
  });

  test("storageInfo sums completed files and reports free space", () async {
    await repo.enqueue(
      <DownloadRequest>[_request("a"), _request("b")].toIList(),
    );
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.completed));
    await _settle();
    File("${dir.path}/downloads/a.mkv")
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(1000, 0));
    File("${dir.path}/downloads/b.mkv").writeAsBytesSync(List<int>.filled(5, 0));
    storage.free = 42;
    final DownloadStorageInfo info =
        (await repo.storageInfo()).getOrElse(() => throw StateError("x"));
    expect(info.usedBytes, 1000);
    expect(info.freeBytes, 42);
  });
}

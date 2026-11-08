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

  /// When set, [activeIds] waits on it (boot reconcile window).
  Completer<void>? activeGate;

  /// Each purge call takes the next gate, if any, and waits on it.
  final List<Completer<void>> purgeGates = <Completer<void>>[];

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
  Future<ISet<String>> activeIds() async {
    await activeGate?.future;
    return active.toISet();
  }

  @override
  Future<void> purgeStoredTask(String contentId) async {
    purged.add(contentId);
    if (purgeGates.isNotEmpty) await purgeGates.removeAt(0).future;
  }
}

class FakeStorage implements DownloadStorage {
  int? free;
  int excludeCalls = 0;

  @override
  Future<int?> freeBytes() async => free;

  @override
  Future<void> excludeFromBackup() async => excludeCalls++;
}

/// An empty [source] is the legacy, pre-scoping shape: key == content id.
DownloadRequest _request(String id, [String source = ""]) => DownloadRequest(
      contentId: id,
      sourceId: source,
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
        (await repo.storageInfo(null)).getOrElse(() => throw StateError("x"));
    expect(info.totalUsedBytes, 1000);
    expect(info.freeBytes, 42);
  });

  group("source scoping", () {
    test("same episode id in two sources stays apart", () async {
      await repo.enqueue(
        <DownloadRequest>[_request("7", "s1"), _request("7", "s2")].toIList(),
      );
      final IList<DownloadRecord> all = await repo.watch().first;
      expect(all.length, 2);
      expect(
        all.map((DownloadRecord r) => r.relativePath).toSet().length,
        2,
      );
      expect(recordsOfSource(all, "s1").single.sourceId, "s1");
      expect(recordsOfSource(all, null), isEmpty);
      await repo.remove(recordsOfSource(all, "s1").single.key);
      expect(
        (await repo.watch().first).single.sourceId,
        "s2",
      );
      expect(gateway.canceled, <String>["s1:7"]);
    });

    test("removeSource cancels, purges, deletes files and records", () async {
      await repo.enqueue(
        <DownloadRequest>[_request("1", "s1"), _request("2", "s2")].toIList(),
      );
      final File gone = File("${dir.path}/downloads/s1_1.mkv")
        ..createSync(recursive: true);
      final File kept = File("${dir.path}/downloads/s2_2.mkv")
        ..createSync(recursive: true);
      // A native task whose record is already gone.
      gateway.active = <String>{"s1:ghost", "s2:2"};
      gateway.purged.clear();
      final Either<Failures, Unit> result = await repo.removeSource("s1");
      expect(result.isRight(), isTrue);
      expect(gateway.canceled, containsAll(<String>["s1:1", "s1:ghost"]));
      expect(gateway.canceled, isNot(contains("s2:2")));
      expect(gateway.purged, containsAll(<String>["s1:1", "s1:ghost"]));
      expect(gone.existsSync(), isFalse);
      expect(kept.existsSync(), isTrue);
      expect(box.keys, <String>["s2:2"]);
    });

    test("retainSources sweeps orphans and spares legacy records", () async {
      await repo.enqueue(
        <DownloadRequest>[
          _request("1", "gone"),
          _request("2", "live"),
          _request("3"),
        ].toIList(),
      );
      await repo.retainSources(<String>{"live"}.toISet());
      final Set<String> keys =
          (await repo.watch().first).map((DownloadRecord r) => r.key).toSet();
      expect(keys, <String>{"live:2", "3"});
    });

    test("adoptLegacy moves finished records to the source", () async {
      await repo.enqueue(
        <DownloadRequest>[_request("done"), _request("busy")].toIList(),
      );
      gateway.controller
          .add(const GatewayEvent("done", GatewayStatus.completed));
      await _settle();
      await _settle();
      final Either<Failures, Unit> result = await repo.adoptLegacy("s9");
      expect(result.isRight(), isTrue);
      final IList<DownloadRecord> all = await repo.watch().first;
      final DownloadRecord done =
          all.firstWhere((DownloadRecord r) => r.contentId == "done");
      final DownloadRecord busy =
          all.firstWhere((DownloadRecord r) => r.contentId == "busy");
      expect(done.sourceId, "s9");
      expect(done.phase, isA<DownloadCompleted>());
      // The old file name is kept: the path stays valid and unique.
      expect(done.relativePath, "downloads/done.mkv");
      // A bare-id task would never report under the new key.
      expect(busy.phase, isA<DownloadFailed>());
      expect(gateway.canceled, contains("busy"));
      expect(box.keys.toSet(), <String>{"s9:done", "s9:busy"});
      // Persisted: a relaunch sees them under the source.
      await repo.dispose();
      repo = await build();
      expect(recordsOfSource(await repo.watch().first, "s9").length, 2);
    });
  });

  group("races", () {
    test("a late cancel never overwrites a finished record", () async {
      await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      final Completer<void> slowPurge = Completer<void>();
      gateway.purgeGates.add(slowPurge);
      // The cancel event reads "queued" then waits on its purge...
      gateway.controller.add(const GatewayEvent("a", GatewayStatus.canceled));
      await _settle();
      // ...the completion lands meanwhile...
      gateway.controller.add(const GatewayEvent("a", GatewayStatus.completed));
      await _settle();
      await _settle();
      expect((await repo.watch().first).single.phase, isA<DownloadCompleted>());
      // ...and the cancel resumes with its stale view.
      slowPurge.complete();
      await _settle();
      await _settle();
      expect((await repo.watch().first).single.phase, isA<DownloadCompleted>());
    });

    test("reconcile ignores an enqueue made during boot", () async {
      await repo.dispose();
      gateway = FakeGateway()..activeGate = Completer<void>();
      final DownloadsRepository booting = DownloadsRepository(
        box: box,
        gateway: gateway,
        storage: storage,
        documentsPath: () async => dir.path,
      );
      repo = booting;
      final Future<void> init = booting.initialize();
      final Future<Either<Failures, Unit>> enqueued =
          booting.enqueue(<DownloadRequest>[_request("late", "s1")].toIList());
      await _settle();
      // Held back until the reconcile is over.
      expect(gateway.enqueued, isEmpty);
      gateway.activeGate!.complete();
      await init;
      expect((await enqueued).isRight(), isTrue);
      expect(gateway.enqueued, <String>["late"]);
      expect(gateway.purged, isNot(contains("s1:late")));
      expect((await booting.watch().first).single.phase, isA<DownloadQueued>());
    });
  });

  test("storageInfo counts the active source, and the total", () async {
    await repo.enqueue(
      <DownloadRequest>[_request("1", "s1"), _request("2", "s2")].toIList(),
    );
    gateway.controller
      ..add(const GatewayEvent("s1:1", GatewayStatus.completed))
      ..add(const GatewayEvent("s2:2", GatewayStatus.completed));
    await _settle();
    await _settle();
    File("${dir.path}/downloads/s1_1.mkv")
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.filled(100, 0));
    File("${dir.path}/downloads/s2_2.mkv")
        .writeAsBytesSync(List<int>.filled(30, 0));
    final DownloadStorageInfo info = (await repo.storageInfo("s1"))
        .getOrElse(() => throw StateError("storageInfo"));
    expect(info.usedBytes, 100);
    expect(info.totalUsedBytes, 130);
  });

  test("pause and resume address the source-scoped task id", () async {
    await repo.enqueue(<DownloadRequest>[_request("7", "s1")].toIList());
    gateway.controller.add(const GatewayEvent("s1:7", GatewayStatus.running));
    await _settle();
    await repo.pause("s1:7");
    gateway.controller.add(const GatewayEvent("s1:7", GatewayStatus.paused));
    await _settle();
    await repo.resume("s1:7");
    expect(gateway.paused, <String>["s1:7"]);
    expect(gateway.resumed, <String>["s1:7"]);
  });
}

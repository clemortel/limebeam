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
  final Set<String> cancelThrowing = <String>{};
  final List<String> purged = <String>[];

  /// When set, [activeIds] waits on it (boot reconcile window).
  Completer<void>? activeGate;

  /// When set, [enqueue] waits on it after recording the call.
  Completer<void>? enqueueGate;

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
    await enqueueGate?.future;
    return accept;
  }

  @override
  Future<void> cancel(String contentId) async {
    canceled.add(contentId);
    if (cancelThrowing.contains(contentId)) {
      throw const DownloadGatewayException("cancel");
    }
  }

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
      // ...the completion lands meanwhile and queues behind it (per-key
      // lock), so the cancel never acts on a stale view...
      gateway.controller.add(const GatewayEvent("a", GatewayStatus.completed));
      await _settle();
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

    test("remove during the gateway enqueue cancels the new task", () async {
      gateway.enqueueGate = Completer<void>();
      final Future<Either<Failures, Unit>> enqueued =
          repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      await _settle();
      await _settle();
      expect(gateway.enqueued, <String>["a"]);
      // The remove waits for the in-flight enqueue, then tears it down.
      final Future<Either<Failures, Unit>> removing = repo.remove("a");
      await _settle();
      expect(gateway.canceled, isEmpty);
      gateway.enqueueGate!.complete();
      expect((await enqueued).isRight(), isTrue);
      expect((await removing).isRight(), isTrue);
      // The task created before the removal is torn down, not orphaned.
      expect(gateway.canceled, <String>["a"]);
      expect(gateway.purged, <String>["a"]);
      expect(await repo.watch().first, isEmpty);
      expect(box.get("a"), isNull);
    });
  });

  group("per-key serialisation", () {
    test("remove then immediate re-enqueue keeps the new record", () async {
      await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      final Future<Either<Failures, Unit>> removing = repo.remove("a");
      final Future<Either<Failures, Unit>> enqueuing =
          repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      await removing;
      await enqueuing;
      expect(gateway.enqueued, <String>["a", "a"]);
      // The old purge must not hit the new task: cancel precedes enqueue.
      expect(gateway.canceled, <String>["a"]);
      expect(box.get("a"), isNotNull);
      final IList<DownloadRecord> list = await repo.watch().first;
      expect(list.single.phase, const DownloadPhase.queued());
    });

    test("failing remove does not overwrite a new enqueue", () async {
      await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      gateway.cancelThrowing.add("a");
      final Future<Either<Failures, Unit>> removing = repo.remove("a");
      gateway.enqueueGate = Completer<void>();
      final Future<Either<Failures, Unit>> enqueuing =
          repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      await _settle();
      // The enqueue is parked behind the remove, not racing it.
      expect(gateway.enqueued, <String>["a"]);
      expect((await removing).isLeft(), isTrue);
      gateway.enqueueGate!.complete();
      await enqueuing;
      expect(box.get("a"), isNotNull);
      final IList<DownloadRecord> list = await repo.watch().first;
      expect(list.single.phase, const DownloadPhase.queued());
    });

    test("remove waits for an enqueue in flight", () async {
      gateway.enqueueGate = Completer<void>();
      final Future<Either<Failures, Unit>> enqueuing =
          repo.enqueue(<DownloadRequest>[_request("a")].toIList());
      await _settle();
      final Future<Either<Failures, Unit>> removing = repo.remove("a");
      await _settle();
      expect(gateway.canceled, isEmpty);
      gateway.enqueueGate!.complete();
      await enqueuing;
      await removing;
      expect(gateway.canceled, <String>["a"]);
      expect(box.get("a"), isNull);
      expect((await repo.watch().first), isEmpty);
    });
  });

  test("reconcile fails a restored completed record without its file",
      () async {
    await repo.enqueue(<DownloadRequest>[_request("a")].toIList());
    gateway.controller.add(const GatewayEvent("a", GatewayStatus.completed));
    await _settle();
    await repo.dispose();
    repo = await build();
    expect((await repo.watch().first).single.phase, isA<DownloadFailed>());
  });
}

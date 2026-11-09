import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:io";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/download_phase.dart";
import "../models/download_record.dart";
import "../models/download_request.dart";
import "download_gateway.dart";
import "downloads_repository.dart";

/// Progress ticks arrive many times a second; the UI needs one per second.
const Duration _kProgressThrottle = Duration(seconds: 1);

/// Hive-backed store. Hive is the source of truth; the native layer only
/// moves bytes. Trap: records never hold the URL (see [DownloadRecord]).
class DownloadsRepository implements IDownloadsRepository {
  DownloadsRepository({
    required Box<String> box,
    required DownloadGateway gateway,
    required Future<String> Function() documentsPath,
    DateTime Function() now = DateTime.now,
  })  : _box = box,
        _gateway = gateway,
        _documentsPath = documentsPath,
        _now = now {
    for (final dynamic key in _box.keys) {
      final String? raw = _box.get(key);
      if (raw == null) continue;
      try {
        final DownloadRecord record = DownloadRecord.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _records[record.key] = record;
      } catch (_) {
        // A corrupt record must not take the whole library down.
        developer.log("skipped unreadable record", name: "iptv.downloads");
      }
    }
  }

  final Box<String> _box;
  final DownloadGateway _gateway;
  final Future<String> Function() _documentsPath;
  final DateTime Function() _now;

  final Map<String, DownloadRecord> _records = <String, DownloadRecord>{};
  final Map<String, double> _progress = <String, double>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<GatewayEvent>? _subscription;
  DateTime? _lastProgressEmit;

  /// Tail of the per-key mutation chain, see [_locked].
  final Map<String, Future<void>> _tails = <String, Future<void>>{};

  /// Completes once [initialize] is over, whatever its outcome. Trap:
  /// [enqueue] waits for it, otherwise a record created while the boot
  /// reconcile runs has no native task yet and is wrongly marked failed.
  final Completer<void> _ready = Completer<void>();

  /// Runs [body] after every earlier mutation of [key] has finished.
  ///
  /// Trap: enqueue, remove, removeSource, adoptLegacy, native events and the
  /// boot reconcile all await between reading and writing a record. Without
  /// one lock per key, remove() then enqueue() on the same key interleave:
  /// remove's late `_box.delete` wipes the new record, or its rollback puts
  /// the old one back over it. [body] must never call another locked method
  /// on the same key (the chain would wait on itself).
  Future<T> _locked<T>(String key, Future<T> Function() body) {
    final Future<void> previous = _tails[key] ?? Future<void>.value();
    final Completer<T> result = Completer<T>();
    final Future<void> tail = previous.then((_) async {
      try {
        result.complete(await body());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    _tails[key] = tail;
    // `tail` never fails: errors travel through `result`.
    unawaited(
      tail.whenComplete(() {
        if (identical(_tails[key], tail)) _tails.remove(key);
      }),
    );
    return result.future;
  }

  /// Subscribes to the native events, then reconciles. Never throws: the app
  /// must boot in airplane mode.
  Future<void> initialize() async {
    try {
      _subscription ??= _gateway.events.listen(_onEvent);
      await _gateway.initialize();
      await _reconcile();
    } catch (error, stackTrace) {
      developer.log(
        "initialize failed (${error.runtimeType})",
        name: "iptv.downloads",
        stackTrace: stackTrace,
      );
    } finally {
      if (!_ready.isCompleted) _ready.complete();
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _changes.close();
  }

  /// A record still queued or running with no native task was killed with
  /// the app: completed if its file landed, failed otherwise.
  Future<void> _reconcile() async {
    final ISet<String> active = await _gateway.activeIds();
    final String root = await _documentsPath();
    for (final DownloadRecord snapshot in _records.values.toList()) {
      final String key = snapshot.key;
      await _locked<void>(key, () => _reconcileOne(key, active, root));
    }
  }

  Future<void> _reconcileOne(
    String key,
    ISet<String> active,
    String root,
  ) async {
    // Judge the live record: earlier mutations ran before this turn.
    DownloadRecord? record = _records[key];
    if (record == null) return;
    final bool landed = File("$root/${record.relativePath}").existsSync();
    // A restored backup can bring a completed record without its file.
    if (record.phase is DownloadCompleted && !landed) {
      await _setPhase(key, const DownloadPhase.failed());
      return;
    }
    if (active.contains(key)) return;
    // Dead task: whatever resume data it left holds the URL.
    await _gateway.purgeStoredTask(key);
    record = _records[key];
    if (record == null) return;
    final bool pending =
        record.phase is DownloadQueued || record.phase is DownloadRunning;
    if (!pending) return;
    await _setPhase(
      key,
      landed ? const DownloadPhase.completed() : const DownloadPhase.failed(),
    );
  }

  void _onEvent(GatewayEvent event) {
    unawaited(
      _locked<void>(event.taskId, () => _handle(event))
          .catchError((Object error, StackTrace st) {
        developer.log(
          "event failed (${error.runtimeType})",
          name: "iptv.downloads",
          stackTrace: st,
        );
      }),
    );
  }

  /// Trap: events overlap (each runs unawaited), so the record is read
  /// again after every await instead of trusting the first read.
  Future<void> _handle(GatewayEvent event) async {
    final String key = event.taskId;
    final DownloadRecord? record = _records[key];
    // Late events of a removed download.
    if (record == null) return;
    switch (event.status) {
      case GatewayStatus.running:
        // A late tick never reopens a finished record: a restart goes
        // through enqueue, which resets the phase first.
        if (record.phase is DownloadCompleted ||
            record.phase is DownloadFailed) {
          return;
        }
        if (record.phase is! DownloadRunning) {
          await _setPhase(
            key,
            const DownloadPhase.running(0),
            progress: event.progress,
          );
          return;
        }
        _progress[key] = event.progress;
        final DateTime now = _now();
        final DateTime? last = _lastProgressEmit;
        if (last == null || now.difference(last) >= _kProgressThrottle) {
          _lastProgressEmit = now;
          _emit();
        }
      case GatewayStatus.queued:
        // A retry wait must not rewrite what is already queued.
        if (record.phase is DownloadQueued) return;
        await _setPhase(key, const DownloadPhase.queued());
      case GatewayStatus.completed:
        await _gateway.purgeStoredTask(key);
        await _setPhase(key, const DownloadPhase.completed());
      case GatewayStatus.failed:
      case GatewayStatus.canceled:
        await _gateway.purgeStoredTask(key);
        // Completed stays: a late cancel must not erase a finished file.
        final DownloadRecord? fresh = _records[key];
        if (fresh == null || fresh.phase is DownloadCompleted) return;
        await _setPhase(key, const DownloadPhase.failed());
    }
  }

  Future<void> _setPhase(
    String key,
    DownloadPhase phase, {
    double? progress,
  }) async {
    final DownloadRecord? record = _records[key];
    if (record == null) return;
    // Memory first: the stored phase carries no progress.
    if (progress == null) {
      _progress.remove(key);
    } else {
      _progress[key] = progress;
    }
    await _put(record.copyWith(phase: phase));
    _emit();
  }

  Future<void> _put(DownloadRecord record) async {
    _records[record.key] = record;
    await _box.put(record.key, jsonEncode(record.toJson()));
  }

  IList<DownloadRecord> _snapshot() => _records.values
      .map(
        (DownloadRecord r) => r.phase is DownloadRunning
            ? r.copyWith(
                phase: DownloadPhase.running(_progress[r.key] ?? 0),
              )
            : r,
      )
      .toIList();

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  @override
  Stream<IList<DownloadRecord>> watch() {
    late final StreamController<IList<DownloadRecord>> controller;
    StreamSubscription<void>? sub;
    controller = StreamController<IList<DownloadRecord>>(
      onListen: () {
        controller.add(_snapshot());
        sub = _changes.stream.listen((_) => controller.add(_snapshot()));
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// One file per source and episode: ids repeat across panels.
  String _fileName(DownloadRequest request) => request.sourceId.isEmpty
      ? "${request.contentId}.${request.containerExtension}"
      : "${request.sourceId}_${request.contentId}"
          ".${request.containerExtension}";

  @override
  Future<Either<Failures, Unit>> enqueue(
    IList<DownloadRequest> requests,
  ) async {
    // The first gateway failure; later requests are still attempted.
    Failures? firstFailure;
    try {
      await _ready.future;
      for (final DownloadRequest request in requests) {
        final String key = request.key;
        await _locked<void>(key, () async {
          final DownloadRecord? existing = _records[key];
          if (existing != null && existing.phase is! DownloadFailed) return;
          final String filename = _fileName(request);
          final DownloadRecord record = DownloadRecord(
            contentId: request.contentId,
            sourceId: request.sourceId,
            seriesId: request.seriesId,
            seriesTitle: request.seriesTitle,
            seasonNumber: request.seasonNumber,
            episodeNumber: request.episodeNumber,
            title: request.title,
            containerExtension: request.containerExtension,
            relativePath: "$kDownloadsDirectory/$filename",
            phase: const DownloadPhase.queued(),
            seriesCoverUrl: request.seriesCoverUrl,
            duration: request.duration,
          );
          _records[key] = record;
          _progress.remove(key);
          await _put(record);
          _emit();
          bool accepted = false;
          try {
            accepted = await _gateway.enqueue(request, filename);
          } catch (error, stackTrace) {
            // No native task exists, so no event will ever fix the phase.
            firstFailure ??= catchError(error, stackTrace);
          }
          if (!accepted) {
            await _setPhase(key, const DownloadPhase.failed());
          }
        });
      }
      final Failures? failure = firstFailure;
      return failure == null ? right(unit) : left(failure);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> remove(String key) =>
      _locked<Either<Failures, Unit>>(key, () => _removeLocked(key));

  Future<Either<Failures, Unit>> _removeLocked(String key) async {
    final DownloadRecord? record = _records.remove(key);
    _progress.remove(key);
    if (record == null) return right(unit);
    _emit();
    try {
      await _gateway.cancel(key);
      await _gateway.purgeStoredTask(key);
      final String root = await _documentsPath();
      final File file = File("$root/${record.relativePath}");
      if (file.existsSync()) await file.delete();
      await _box.delete(key);
      return right(unit);
    } catch (error, stackTrace) {
      // Hive still has it and the file may too: show what is really there.
      _records[key] = record;
      _emit();
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> removeSource(String sourceId) async {
    if (sourceId.isEmpty) return right(unit);
    Failures? firstFailure;
    try {
      final List<DownloadRecord> victims = _records.values
          .where((DownloadRecord r) => r.sourceId == sourceId)
          .toList();
      for (final DownloadRecord record in victims) {
        (await remove(record.key)).fold(
          (Failures f) => firstFailure ??= f,
          (Unit _) {},
        );
      }
      // Native tasks outliving their record still hold the old credentials.
      final String prefix = "$sourceId:";
      final ISet<String> tasks = await _gateway.activeIds();
      for (final String taskId
          in tasks.where((String id) => id.startsWith(prefix))) {
        await _locked<void>(taskId, () async {
          await _gateway.cancel(taskId);
          await _gateway.purgeStoredTask(taskId);
        });
      }
    } catch (error, stackTrace) {
      firstFailure ??= catchError(error, stackTrace);
    }
    final Failures? failure = firstFailure;
    return failure == null ? right(unit) : left(failure);
  }

  @override
  Future<Either<Failures, Unit>> retainSources(ISet<String> sourceIds) async {
    final Set<String> orphans = _records.values
        .map((DownloadRecord r) => r.sourceId)
        .where((String id) => id.isNotEmpty && !sourceIds.contains(id))
        .toSet();
    Failures? firstFailure;
    for (final String sourceId in orphans) {
      (await removeSource(sourceId)).fold(
        (Failures f) => firstFailure ??= f,
        (Unit _) {},
      );
    }
    final Failures? failure = firstFailure;
    return failure == null ? right(unit) : left(failure);
  }

  @override
  Future<Either<Failures, Unit>> adoptLegacy(String sourceId) async {
    if (sourceId.isEmpty) return right(unit);
    try {
      // After the boot reconcile, which judges legacy tasks by their id.
      await _ready.future;
      final List<DownloadRecord> legacy = _records.values
          .where((DownloadRecord r) => r.sourceId.isEmpty)
          .toList();
      for (final DownloadRecord snapshot in legacy) {
        final String oldKey = snapshot.key;
        await _locked<void>(oldKey, () => _adoptOne(oldKey, sourceId));
      }
      _emit();
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  Future<void> _adoptOne(String oldKey, String sourceId) async {
    // Re-read: an earlier mutation may have removed or replaced it.
    final DownloadRecord? old = _records[oldKey];
    if (old == null) return;
    final bool pending =
        old.phase is DownloadQueued || old.phase is DownloadRunning;
    // A task started under the bare id would report events nobody maps
    // to the new key: stop it and let the user restart it.
    if (pending) {
      await _gateway.cancel(oldKey);
      await _gateway.purgeStoredTask(oldKey);
    }
    final DownloadRecord adopted = old.copyWith(
      sourceId: sourceId,
      phase: pending ? const DownloadPhase.failed() : old.phase,
    );
    // Never overwrite a record the source already owns.
    if (_records.containsKey(adopted.key)) return;
    _records.remove(oldKey);
    _progress.remove(oldKey);
    await _put(adopted);
    await _box.delete(oldKey);
  }

  @override
  Future<Either<Failures, String>> localUrlFor(DownloadRecord record) async {
    try {
      final String path = "${await _documentsPath()}/${record.relativePath}";
      if (!File(path).existsSync()) return left(const Failures.notFound());
      return right(Uri.file(path).toString());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}

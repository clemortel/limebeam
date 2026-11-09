import "dart:async";
import "dart:convert";
import "dart:developer" as developer;
import "dart:io";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/download_failure_reason.dart";
import "../models/download_phase.dart";
import "../models/download_record.dart";
import "../models/download_request.dart";
import "../models/download_storage_info.dart";
import "download_gateway.dart";
import "download_storage.dart";
import "downloads_repository.dart";

/// Progress ticks arrive many times a second; the UI needs one per second.
const Duration _kProgressThrottle = Duration(seconds: 1);

const int _kBytesPerMegabyte = 1024 * 1024;

/// Headroom kept free on top of an episode: the OS and the player need room.
const int _kSpaceMarginBytes = 300 * _kBytesPerMegabyte;

/// Hive-backed store. Hive is the source of truth; the native layer only
/// moves bytes. Trap: records never hold the URL (see [DownloadRecord]).
class DownloadsRepository implements IDownloadsRepository {
  DownloadsRepository({
    required Box<String> box,
    required DownloadGateway gateway,
    required DownloadStorage storage,
    required Future<String> Function() documentsPath,
    DateTime Function() now = DateTime.now,
  })  : _box = box,
        _gateway = gateway,
        _storage = storage,
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
  final DownloadStorage _storage;
  final Future<String> Function() _documentsPath;
  final DateTime Function() _now;

  final Map<String, DownloadRecord> _records = <String, DownloadRecord>{};
  final Map<String, double> _progress = <String, double>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  StreamSubscription<GatewayEvent>? _subscription;
  DateTime? _lastProgressEmit;

  /// Completes once [initialize] is over, whatever its outcome. Trap:
  /// [enqueue] waits for it, otherwise a record created while the boot
  /// reconcile runs has no native task yet and is wrongly marked failed.
  final Completer<void> _ready = Completer<void>();

  /// Subscribes to the native events, then reconciles. Never throws: the app
  /// must boot in airplane mode.
  Future<void> initialize() async {
    try {
      _subscription ??= _gateway.events.listen(_onEvent);
      await _storage.excludeFromBackup();
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
      if (active.contains(key)) continue;
      // Dead task: whatever resume data it left holds the URL.
      await _gateway.purgeStoredTask(key);
      // Events and removals ran during the awaits: judge the live record.
      final DownloadRecord? record = _records[key];
      if (record == null) continue;
      final bool pending = record.phase is DownloadQueued ||
          record.phase is DownloadRunning ||
          record.phase is DownloadPaused;
      if (!pending) continue;
      final bool landed = File("$root/${record.relativePath}").existsSync();
      await _setPhase(
        key,
        landed ? const DownloadPhase.completed() : const DownloadPhase.failed(),
      );
    }
  }

  void _onEvent(GatewayEvent event) {
    unawaited(
      _handle(event).catchError((Object error, StackTrace st) {
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
        // Nor a paused one: a tick queued before the pause status is stale.
        if (record.phase is DownloadCompleted ||
            record.phase is DownloadFailed ||
            record.phase is DownloadPaused) {
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
        if (record.phase is DownloadQueued ||
            record.phase is DownloadPaused ||
            record.phase is DownloadCompleted ||
            record.phase is DownloadFailed) {
          return;
        }
        await _setPhase(key, const DownloadPhase.queued());
      case GatewayStatus.paused:
        if (record.phase is DownloadCompleted ||
            record.phase is DownloadFailed) {
          return;
        }
        await _setPhase(key, const DownloadPhase.paused());
      case GatewayStatus.completed:
        await _gateway.purgeStoredTask(key);
        await _setPhase(key, const DownloadPhase.completed());
      case GatewayStatus.failed:
      case GatewayStatus.canceled:
        await _gateway.purgeStoredTask(key);
        // Completed stays: a late cancel must not erase a finished file.
        final DownloadRecord? fresh = _records[key];
        if (fresh == null || fresh.phase is DownloadCompleted) return;
        await _setPhase(key, DownloadPhase.failed(reason: event.reason));
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
      // Episodes accepted in this batch are not on disk yet: count them.
      int reservedBytes = 0;
      for (final DownloadRequest request in requests) {
        final String key = request.key;
        final DownloadRecord? existing = _records[key];
        if (existing != null && existing.phase is! DownloadFailed) continue;
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
        // Stored before any await so a concurrent enqueue sees it.
        _records[key] = record;
        _progress.remove(key);
        await _put(record);
        _emit();
        final int? size = await _gateway.expectedSize(request);
        final int? free = await _storage.freeBytes();
        // Trap: remove()/removeSource() during an await above deletes the
        // record; a native task created afterwards would be an orphan whose
        // events are all dropped and whose URL is never purged.
        if (!identical(_records[key], record)) continue;
        // Unknown size or unknown free space: accept, the native layer
        // reports a write failure if the disk really is full.
        if (size != null &&
            free != null &&
            reservedBytes + size + _kSpaceMarginBytes > free) {
          await _setPhase(
            key,
            const DownloadPhase.failed(reason: DownloadFailureReason.storage),
          );
          continue;
        }
        reservedBytes += size ?? 0;
        bool accepted = false;
        try {
          accepted = await _gateway.enqueue(request, filename);
        } catch (error, stackTrace) {
          // No native task exists, so no event will ever fix the phase.
          firstFailure ??= catchError(error, stackTrace);
        }
        if (!identical(_records[key], record)) {
          // Removed while the gateway was working: undo the task it made.
          if (accepted) {
            try {
              await _gateway.cancel(key);
            } catch (_) {
              // Best effort; the purge below still runs.
            }
            await _gateway.purgeStoredTask(key);
          }
          continue;
        }
        if (!accepted) {
          await _setPhase(key, const DownloadPhase.failed());
        }
      }
      final Failures? failure = firstFailure;
      return failure == null ? right(unit) : left(failure);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> pause(String key) async {
    try {
      final DownloadRecord? record = _records[key];
      // Running only: a queued task is still in the plugin's holding queue
      // and the native pause refuses it.
      final bool pausable = record != null && record.phase is DownloadRunning;
      // The paused status event flips the phase, not this call.
      if (pausable) await _gateway.pause(key);
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> resume(String key) async {
    try {
      final DownloadRecord? record = _records[key];
      if (record == null || record.phase is! DownloadPaused) {
        return right(unit);
      }
      // Queued first: the native layer re-enters the holding queue.
      await _setPhase(key, const DownloadPhase.queued());
      bool resumed = false;
      try {
        resumed = await _gateway.resume(key);
      } catch (_) {
        // Nothing was restarted: show the row as it really is.
        await _setPhase(key, const DownloadPhase.paused());
        rethrow;
      }
      if (!resumed) {
        // The paused task and its resume data embed the URL: do not leave
        // them behind a record that is now failed.
        await _gateway.purgeStoredTask(key);
        await _setPhase(
          key,
          const DownloadPhase.failed(reason: DownloadFailureReason.server),
        );
      }
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, DownloadStorageInfo>> storageInfo(
    String? sourceId,
  ) async {
    try {
      final String root = await _documentsPath();
      int total = 0;
      int mine = 0;
      for (final DownloadRecord record in _records.values) {
        if (record.phase is! DownloadCompleted) continue;
        final File file = File("$root/${record.relativePath}");
        if (!file.existsSync()) continue;
        final int length = file.lengthSync();
        total += length;
        if (sourceId != null && record.sourceId == sourceId) mine += length;
      }
      return right(
        DownloadStorageInfo(
          usedBytes: mine,
          totalUsedBytes: total,
          freeBytes: await _storage.freeBytes(),
        ),
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> remove(String key) async {
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
        await _gateway.cancel(taskId);
        await _gateway.purgeStoredTask(taskId);
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
      for (final DownloadRecord old in legacy) {
        final String oldKey = old.key;
        final bool pending = old.phase is DownloadQueued ||
            old.phase is DownloadRunning ||
            old.phase is DownloadPaused;
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
        if (_records.containsKey(adopted.key)) continue;
        _records.remove(oldKey);
        _progress.remove(oldKey);
        await _put(adopted);
        await _box.delete(oldKey);
      }
      _emit();
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
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

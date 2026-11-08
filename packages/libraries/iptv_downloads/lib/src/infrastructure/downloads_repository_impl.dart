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
        _records[record.contentId] = record;
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
    for (final DownloadRecord record in _records.values.toList()) {
      if (active.contains(record.contentId)) continue;
      // Dead task: whatever resume data it left holds the URL.
      await _gateway.purgeStoredTask(record.contentId);
      final bool pending =
          record.phase is DownloadQueued || record.phase is DownloadRunning;
      if (!pending) continue;
      final bool landed = File("$root/${record.relativePath}").existsSync();
      await _setPhase(
        record.contentId,
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

  Future<void> _handle(GatewayEvent event) async {
    final DownloadRecord? record = _records[event.contentId];
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
            event.contentId,
            const DownloadPhase.running(0),
            progress: event.progress,
          );
          return;
        }
        _progress[event.contentId] = event.progress;
        final DateTime now = _now();
        final DateTime? last = _lastProgressEmit;
        if (last == null || now.difference(last) >= _kProgressThrottle) {
          _lastProgressEmit = now;
          _emit();
        }
      case GatewayStatus.queued:
        // A retry wait must not rewrite what is already queued.
        if (record.phase is DownloadQueued) return;
        await _setPhase(event.contentId, const DownloadPhase.queued());
      case GatewayStatus.completed:
        await _gateway.purgeStoredTask(event.contentId);
        await _setPhase(event.contentId, const DownloadPhase.completed());
      case GatewayStatus.failed:
      case GatewayStatus.canceled:
        await _gateway.purgeStoredTask(event.contentId);
        // Completed stays: a late cancel must not erase a finished file.
        if (record.phase is DownloadCompleted) return;
        await _setPhase(event.contentId, const DownloadPhase.failed());
    }
  }

  Future<void> _setPhase(
    String contentId,
    DownloadPhase phase, {
    double? progress,
  }) async {
    final DownloadRecord? record = _records[contentId];
    if (record == null) return;
    // Memory first: the stored phase carries no progress.
    if (progress == null) {
      _progress.remove(contentId);
    } else {
      _progress[contentId] = progress;
    }
    await _put(record.copyWith(phase: phase));
    _emit();
  }

  Future<void> _put(DownloadRecord record) async {
    _records[record.contentId] = record;
    await _box.put(record.contentId, jsonEncode(record.toJson()));
  }

  IList<DownloadRecord> _snapshot() => _records.values
      .map(
        (DownloadRecord r) => r.phase is DownloadRunning
            ? r.copyWith(
                phase: DownloadPhase.running(_progress[r.contentId] ?? 0),
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

  @override
  Future<Either<Failures, Unit>> enqueue(
    IList<DownloadRequest> requests,
  ) async {
    // The first gateway failure; later requests are still attempted.
    Failures? firstFailure;
    try {
      for (final DownloadRequest request in requests) {
        final DownloadRecord? existing = _records[request.contentId];
        if (existing != null && existing.phase is! DownloadFailed) continue;
        final String ext = request.containerExtension;
        final DownloadRecord record = DownloadRecord(
          contentId: request.contentId,
          seriesId: request.seriesId,
          seriesTitle: request.seriesTitle,
          seasonNumber: request.seasonNumber,
          episodeNumber: request.episodeNumber,
          title: request.title,
          containerExtension: ext,
          relativePath: "$kDownloadsDirectory/${request.contentId}.$ext",
          phase: const DownloadPhase.queued(),
          seriesCoverUrl: request.seriesCoverUrl,
          duration: request.duration,
        );
        // Stored before any await so a concurrent enqueue sees it.
        _records[record.contentId] = record;
        _progress.remove(record.contentId);
        await _put(record);
        _emit();
        bool accepted = false;
        try {
          accepted =
              await _gateway.enqueue(request, "${request.contentId}.$ext");
        } catch (error, stackTrace) {
          // No native task exists, so no event will ever fix the phase.
          firstFailure ??= catchError(error, stackTrace);
        }
        if (!accepted) {
          await _setPhase(record.contentId, const DownloadPhase.failed());
        }
      }
      final Failures? failure = firstFailure;
      return failure == null ? right(unit) : left(failure);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> remove(String contentId) async {
    final DownloadRecord? record = _records.remove(contentId);
    _progress.remove(contentId);
    if (record == null) return right(unit);
    _emit();
    try {
      await _gateway.cancel(contentId);
      await _gateway.purgeStoredTask(contentId);
      final String root = await _documentsPath();
      final File file = File("$root/${record.relativePath}");
      if (file.existsSync()) await file.delete();
      await _box.delete(contentId);
      return right(unit);
    } catch (error, stackTrace) {
      // Hive still has it and the file may too: show what is really there.
      _records[contentId] = record;
      _emit();
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

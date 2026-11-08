import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/download_record.dart";
import "../models/download_request.dart";

/// Offline episode store. Works with no network, except [enqueue].
abstract interface class IDownloadsRepository {
  /// Emits the full list on every change, starting with the current one.
  Stream<IList<DownloadRecord>> watch();

  /// Idempotent: a request whose content is already queued, running, or
  /// completed is skipped; a failed one is restarted.
  Future<Either<Failures, Unit>> enqueue(IList<DownloadRequest> requests);

  /// Cancels a running task, deletes the file, and forgets the record.
  /// [key] is `DownloadRecord.key`: content ids repeat across sources.
  Future<Either<Failures, Unit>> remove(String key);

  /// Cancels every task of [sourceId], purges the plugin's stored copy of
  /// them, and deletes their files and records. For a deleted source.
  Future<Either<Failures, Unit>> removeSource(String sourceId);

  /// [removeSource] for every source id with records that is not in
  /// [sourceIds]: sweeps what a deletion left behind.
  Future<Either<Failures, Unit>> retainSources(ISet<String> sourceIds);

  /// Gives the records written before downloads were scoped (no source id)
  /// to [sourceId]. A queued or running one is stopped and marked failed.
  Future<Either<Failures, Unit>> adoptLegacy(String sourceId);

  /// The `file://` URL of a completed download, resolved at call time.
  Future<Either<Failures, String>> localUrlFor(DownloadRecord record);
}

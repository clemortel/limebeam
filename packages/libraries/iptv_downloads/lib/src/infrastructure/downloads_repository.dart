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
  Future<Either<Failures, Unit>> remove(String contentId);

  /// The `file://` URL of a completed download, resolved at call time.
  Future<Either<Failures, String>> localUrlFor(DownloadRecord record);
}

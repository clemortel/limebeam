import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/download_record.dart";
import "../models/download_request.dart";
import "../models/download_storage_info.dart";

/// Offline episode store. Works with no network, except [enqueue].
abstract interface class IDownloadsRepository {
  /// Emits the full list on every change, starting with the current one.
  Stream<IList<DownloadRecord>> watch();

  /// Idempotent: a request whose content is already queued, running, or
  /// completed is skipped; a failed one is restarted.
  Future<Either<Failures, Unit>> enqueue(IList<DownloadRequest> requests);

  /// Stops a running or queued transfer. The record turns paused when the
  /// native layer confirms; a transfer it cannot pause is left untouched.
  Future<Either<Failures, Unit>> pause(String contentId);

  /// Restarts a paused transfer where it stopped. When the native layer lost
  /// it (app relaunched), the record fails and a retry restarts from zero.
  Future<Either<Failures, Unit>> resume(String contentId);

  /// Space taken by finished episodes and free space on the device.
  Future<Either<Failures, DownloadStorageInfo>> storageInfo();

  /// Cancels a running task, deletes the file, and forgets the record.
  Future<Either<Failures, Unit>> remove(String contentId);

  /// The `file://` URL of a completed download, resolved at call time.
  Future<Either<Failures, String>> localUrlFor(DownloadRecord record);
}

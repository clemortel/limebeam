import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:get_it/get_it.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../infrastructure/downloads_repository.dart";
import "../models/download_record.dart";
import "../models/download_request.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
IDownloadsRepository downloadsRepository(Ref ref) =>
    GetIt.instance<IDownloadsRepository>();

/// Every download, live. keepAlive so progress survives leaving the screen.
@Riverpod(keepAlive: true)
class DownloadsNotifier extends _$DownloadsNotifier {
  @override
  AsyncState<IList<DownloadRecord>> build() {
    final StreamSubscription<IList<DownloadRecord>> subscription =
        ref.read(downloadsRepositoryProvider).watch().listen(
              (IList<DownloadRecord> records) =>
                  state = AsyncState<IList<DownloadRecord>>.success(records),
            );
    ref.onDispose(subscription.cancel);
    return const AsyncState<IList<DownloadRecord>>.loading();
  }

  /// A failure never replaces the live list: the last success stays and the
  /// failure goes out through [downloadFailuresProvider] instead.
  Future<void> enqueue(IList<DownloadRequest> requests) async {
    final Either<Failures, Unit> result =
        await ref.read(downloadsRepositoryProvider).enqueue(requests);
    result.fold(
      (Failures _) => ref
          .read(downloadFailuresProvider.notifier)
          .report(DownloadFailureKind.enqueue),
      (Unit _) {},
    );
  }

  /// [key] is `DownloadRecord.key`.
  Future<void> remove(String key) async {
    final Either<Failures, Unit> result =
        await ref.read(downloadsRepositoryProvider).remove(key);
    result.fold(
      (Failures _) => ref
          .read(downloadFailuresProvider.notifier)
          .report(DownloadFailureKind.remove),
      (Unit _) {},
    );
  }
}

/// What the user tried to do when a download operation failed.
enum DownloadFailureKind { enqueue, remove }

/// One failure to tell the user about, once.
///
/// Trap: deliberately not Freezed. Value equality would make two identical
/// failures equal, and `ref.listen` would swallow the second toast.
@immutable
class DownloadFailure {
  const DownloadFailure(this.kind);

  final DownloadFailureKind kind;
}

/// One-shot channel for download failures. Listen with `ref.listen` and show
/// a toast; the state is null until the first failure.
@Riverpod(keepAlive: true)
class DownloadFailures extends _$DownloadFailures {
  @override
  DownloadFailure? build() => null;

  void report(DownloadFailureKind kind) => state = DownloadFailure(kind);
}

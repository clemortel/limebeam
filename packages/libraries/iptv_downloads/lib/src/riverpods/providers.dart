import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
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
    final StreamSubscription<IList<DownloadRecord>> subscription = ref
        .read(downloadsRepositoryProvider)
        .watch()
        .listen(
          (IList<DownloadRecord> records) =>
              state = AsyncState<IList<DownloadRecord>>.success(records),
        );
    ref.onDispose(subscription.cancel);
    return const AsyncState<IList<DownloadRecord>>.loading();
  }

  Future<void> enqueue(IList<DownloadRequest> requests) async {
    final Either<Failures, Unit> result =
        await ref.read(downloadsRepositoryProvider).enqueue(requests);
    result.fold(
      (Failures failure) =>
          state = AsyncState<IList<DownloadRecord>>.error(failure),
      (Unit _) {},
    );
  }

  Future<void> remove(String contentId) async {
    final Either<Failures, Unit> result =
        await ref.read(downloadsRepositoryProvider).remove(contentId);
    result.fold(
      (Failures failure) =>
          state = AsyncState<IList<DownloadRecord>>.error(failure),
      (Unit _) {},
    );
  }
}

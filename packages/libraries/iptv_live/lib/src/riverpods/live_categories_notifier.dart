import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/live_category.dart";
import "providers.dart";

part "live_categories_notifier.g.dart";

/// Live categories for the chip row (§4.3.1). Long-lived cache.
@Riverpod(keepAlive: true)
class LiveCategoriesNotifier extends _$LiveCategoriesNotifier {
  @override
  AsyncState<IList<LiveCategory>> build() {
    _fetch();
    return const AsyncState<IList<LiveCategory>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<LiveCategory>> result =
        await ref.read(liveRepositoryProvider).getCategories();
    state = result.fold(
      (Failures failure) => AsyncState<IList<LiveCategory>>.error(failure),
      (IList<LiveCategory> categories) =>
          AsyncState<IList<LiveCategory>>.success(categories),
    );
  }

  Future<void> refresh() => _fetch();
}

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:get_it/get_it.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_series/src/infrastructure/series_repository.dart";
import "package:iptv_series/src/models/series.dart";
import "package:iptv_series/src/models/series_category.dart";
import "package:iptv_series/src/models/series_detail.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
ISeriesRepository seriesRepository(Ref ref) =>
    GetIt.instance<ISeriesRepository>();

/// Selected series category ("" = all).
@riverpod
class SelectedSeriesCategory extends _$SelectedSeriesCategory {
  @override
  String build() => "";

  void select(String id) => state = id;
}

/// Seasons + episodes for one series, for the detail screen.
///
/// Cache first: a cached detail is shown at once (so offline never waits for
/// the 30 s network timeout), then the network result replaces it.
@riverpod
class SeriesDetailNotifier extends _$SeriesDetailNotifier {
  @override
  AsyncState<SeriesDetail> build(String seriesId) {
    _load(seriesId);
    return const AsyncState<SeriesDetail>.loading();
  }

  Future<void> _load(String seriesId) async {
    final ISeriesRepository repository = ref.read(seriesRepositoryProvider);

    final Either<Failures, Option<SeriesDetail>> cached =
        await repository.getCachedSeriesInfo(seriesId);
    if (!ref.mounted) return;
    final SeriesDetail? shown = cached.fold(
      (Failures _) => null,
      (Option<SeriesDetail> detail) => detail.toNullable(),
    );
    if (shown != null) state = AsyncState<SeriesDetail>.success(shown);

    final Either<Failures, SeriesDetail> result =
        await repository.getSeriesInfo(seriesId);
    if (!ref.mounted) return;
    state = result.fold(
      // A failed refresh must not wipe a detail the user is already reading.
      // The offline rule (fromCache) lives in the repository only: a Left
      // here is a 5xx/auth failure (or no cache) and keeps the sheet as is.
      (Failures failure) => shown != null
          ? AsyncState<SeriesDetail>.success(shown)
          : AsyncState<SeriesDetail>.error(failure),
      (SeriesDetail detail) => AsyncState<SeriesDetail>.success(detail),
    );
  }
}

/// Series for the grid (§4.4). keepAlive cache.
@Riverpod(keepAlive: true)
class SeriesNotifier extends _$SeriesNotifier {
  @override
  AsyncState<IList<Series>> build() {
    _fetch();
    return const AsyncState<IList<Series>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<Series>> result =
        await ref.read(seriesRepositoryProvider).getSeries();
    state = result.fold(
      (Failures failure) => AsyncState<IList<Series>>.error(failure),
      (IList<Series> series) => AsyncState<IList<Series>>.success(series),
    );
  }

  Future<void> refresh() => _fetch();
}

/// Series categories for the filter chips. keepAlive cache.
@Riverpod(keepAlive: true)
class SeriesCategoriesNotifier extends _$SeriesCategoriesNotifier {
  @override
  AsyncState<IList<SeriesCategory>> build() {
    _fetch();
    return const AsyncState<IList<SeriesCategory>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<SeriesCategory>> result =
        await ref.read(seriesRepositoryProvider).getCategories();
    state = result.fold(
      (Failures failure) =>
          AsyncState<IList<SeriesCategory>>.error(failure),
      (IList<SeriesCategory> categories) =>
          AsyncState<IList<SeriesCategory>>.success(categories),
    );
  }

  Future<void> refresh() => _fetch();
}

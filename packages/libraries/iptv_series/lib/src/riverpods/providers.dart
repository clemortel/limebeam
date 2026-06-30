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

/// Seasons + episodes for one series, fetched on demand for the detail screen.
@riverpod
class SeriesDetailNotifier extends _$SeriesDetailNotifier {
  @override
  AsyncState<SeriesDetail> build(String seriesId) {
    _fetch(seriesId);
    return const AsyncState<SeriesDetail>.loading();
  }

  Future<void> _fetch(String seriesId) async {
    final Either<Failures, SeriesDetail> result =
        await ref.read(seriesRepositoryProvider).getSeriesInfo(seriesId);
    state = result.fold(
      (Failures failure) => AsyncState<SeriesDetail>.error(failure),
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

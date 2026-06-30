import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:get_it/get_it.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_vod/src/infrastructure/vod_repository.dart";
import "package:iptv_vod/src/models/movie.dart";
import "package:iptv_vod/src/models/movie_info.dart";
import "package:iptv_vod/src/models/vod_category.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
IVodRepository vodRepository(Ref ref) =>
    GetIt.instance<IVodRepository>();

/// Selected VOD category ("" = all).
@riverpod
class SelectedVodCategory extends _$SelectedVodCategory {
  @override
  String build() => "";

  void select(String id) => state = id;
}

/// Extended details for one movie, fetched on demand for the detail screen.
@riverpod
class MovieInfoNotifier extends _$MovieInfoNotifier {
  @override
  AsyncState<MovieInfo> build(String streamId) {
    _fetch(streamId);
    return const AsyncState<MovieInfo>.loading();
  }

  Future<void> _fetch(String streamId) async {
    final Either<Failures, MovieInfo> result =
        await ref.read(vodRepositoryProvider).getMovieInfo(streamId);
    state = result.fold(
      (Failures failure) => AsyncState<MovieInfo>.error(failure),
      (MovieInfo info) => AsyncState<MovieInfo>.success(info),
    );
  }
}

/// Movies for the grid (§4.4). keepAlive cache.
@Riverpod(keepAlive: true)
class VodNotifier extends _$VodNotifier {
  @override
  AsyncState<IList<Movie>> build() {
    _fetch();
    return const AsyncState<IList<Movie>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<Movie>> result =
        await ref.read(vodRepositoryProvider).getMovies();
    state = result.fold(
      (Failures failure) => AsyncState<IList<Movie>>.error(failure),
      (IList<Movie> movies) => AsyncState<IList<Movie>>.success(movies),
    );
  }

  Future<void> refresh() => _fetch();
}

/// VOD categories for the filter chips. keepAlive cache.
@Riverpod(keepAlive: true)
class VodCategoriesNotifier extends _$VodCategoriesNotifier {
  @override
  AsyncState<IList<VodCategory>> build() {
    _fetch();
    return const AsyncState<IList<VodCategory>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<VodCategory>> result =
        await ref.read(vodRepositoryProvider).getCategories();
    state = result.fold(
      (Failures failure) => AsyncState<IList<VodCategory>>.error(failure),
      (IList<VodCategory> categories) =>
          AsyncState<IList<VodCategory>>.success(categories),
    );
  }

  Future<void> refresh() => _fetch();
}

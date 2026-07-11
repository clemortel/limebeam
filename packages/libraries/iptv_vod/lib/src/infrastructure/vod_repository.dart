import "dart:convert";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/movie.dart";
import "../models/movie_info.dart";
import "../models/vod_category.dart";

/// Data layer for movies (VOD). `Either<Failures, T>`, never throws.
abstract interface class IVodRepository {
  Future<Either<Failures, int>> sync();

  Future<Either<Failures, IList<Movie>>> getMovies();

  Future<Either<Failures, IList<VodCategory>>> getCategories();

  /// Extended details for one movie (fetched on demand, not cached).
  Future<Either<Failures, MovieInfo>> getMovieInfo(String streamId);
}

@LazySingleton(as: IVodRepository)
class VodRepository implements IVodRepository {
  VodRepository(this._factory, this._activeStore, this._cache);

  final PlaylistSourceFactory _factory;
  final ActiveSourceStore _activeStore;
  final CacheStore _cache;

  String get _sid => _activeStore.sourceId ?? "none";
  String get _streamsKey => "vod_streams_$_sid";
  String get _categoriesKey => "vod_categories_$_sid";

  @override
  Future<Either<Failures, int>> sync() async {
    try {
      final SourceConfig? config = _activeStore.config;
      if (config == null) return left(const Failures.unexpected());

      final Either<Failures, Map<String, dynamic>> result =
          await _factory.create(config).fetchVod();

      return await result.fold(
        (Failures failure) async => left(failure),
        (Map<String, dynamic> payload) async {
          await _cache.write(
            _streamsKey,
            jsonEncode(payload["streams"] ?? <dynamic>[]),
          );
          await _cache.write(
            _categoriesKey,
            jsonEncode(payload["categories"] ?? <dynamic>[]),
          );
          final List<dynamic> streams =
              (payload["streams"] as List<dynamic>?) ?? <dynamic>[];
          return right(streams.length);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<Movie>>> getMovies() async {
    try {
      final String? raw = await _cache.read(_streamsKey);
      if (raw == null) return right(const IListConst<Movie>(<Movie>[]));
      final List<Movie> movies = await runParse(parseMovies, raw);
      return right(movies.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<VodCategory>>> getCategories() async {
    try {
      final String? raw = await _cache.read(_categoriesKey);
      if (raw == null) return right(const IListConst<VodCategory>(<VodCategory>[]));
      final List<VodCategory> categories =
          await runParse(parseVodCategories, raw);
      return right(categories.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, MovieInfo>> getMovieInfo(String streamId) async {
    try {
      final SourceConfig? config = _activeStore.config;
      if (config == null) return left(const Failures.unexpected());

      final Either<Failures, Map<String, dynamic>> result =
          await _factory.create(config).fetchVodInfo(streamId);

      return result.map(MovieInfo.fromVodInfo);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}

// --- Top-level parsers (run via compute) -----------------------------------

List<Movie> parseMovies(String rawJson) {
  final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
  return list.map((dynamic e) {
    final Map<String, dynamic> m = e as Map<String, dynamic>;
    final String icon = "${m["stream_icon"] ?? ""}";
    return Movie(
      id: "${m["stream_id"]}",
      name: "${m["name"] ?? ""}",
      streamId: "${m["stream_id"]}",
      categoryId: "${m["category_id"] ?? ""}",
      posterUrl: icon.isEmpty ? null : icon,
      rating: _nullableString(m["rating"]),
      year: _nullableString(m["year"]),
      containerExtension: "${m["container_extension"] ?? "mp4"}",
    );
  }).toList(growable: false);
}

List<VodCategory> parseVodCategories(String rawJson) {
  final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
  return list.map((dynamic e) {
    final Map<String, dynamic> m = e as Map<String, dynamic>;
    final String name = "${m["category_name"] ?? ""}";
    return VodCategory(
      id: "${m["category_id"]}",
      name: name,
      isAdult: isAdultCategoryName(name),
    );
  }).toList(growable: false);
}

String? _nullableString(dynamic value) {
  if (value == null) return null;
  final String s = "$value";
  return s.isEmpty ? null : s;
}

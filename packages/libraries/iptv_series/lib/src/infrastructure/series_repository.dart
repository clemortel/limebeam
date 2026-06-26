import "dart:convert";
import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/season.dart";
import "../models/series.dart";
import "../models/series_category.dart";
import "../models/series_detail.dart";

/// Data layer for series. `Either<Failures, T>`, never throws.
abstract interface class ISeriesRepository {
  Future<Either<Failures, int>> sync();

  Future<Either<Failures, IList<Series>>> getSeries();

  Future<Either<Failures, IList<SeriesCategory>>> getCategories();

  /// Seasons + episodes for one series (fetched on demand, not cached).
  Future<Either<Failures, SeriesDetail>> getSeriesInfo(String seriesId);
}

@LazySingleton(as: ISeriesRepository)
class SeriesRepository implements ISeriesRepository {
  SeriesRepository(this._factory, this._activeStore, this._cache);

  final PlaylistSourceFactory _factory;
  final ActiveSourceStore _activeStore;
  final CacheStore _cache;

  String get _sid => _activeStore.sourceId ?? "none";
  String get _seriesKey => "series_$_sid";
  String get _categoriesKey => "series_categories_$_sid";

  @override
  Future<Either<Failures, int>> sync() async {
    try {
      final SourceConfig? config = _activeStore.config;
      if (config == null) return left(const Failures.unexpected());

      final Either<Failures, Map<String, dynamic>> result =
          await _factory.create(config).fetchSeries();

      return await result.fold(
        (Failures failure) async => left(failure),
        (Map<String, dynamic> payload) async {
          await _cache.write(
            _seriesKey,
            jsonEncode(payload["series"] ?? <dynamic>[]),
          );
          await _cache.write(
            _categoriesKey,
            jsonEncode(payload["categories"] ?? <dynamic>[]),
          );
          final List<dynamic> series =
              (payload["series"] as List<dynamic>?) ?? <dynamic>[];
          return right(series.length);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<Series>>> getSeries() async {
    try {
      final String? raw = _cache.read(_seriesKey);
      if (raw == null) return right(const IListConst<Series>(<Series>[]));
      final List<Series> series = await runParse(parseSeries, raw);
      return right(series.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<SeriesCategory>>> getCategories() async {
    try {
      final String? raw = _cache.read(_categoriesKey);
      if (raw == null) return right(const IListConst<SeriesCategory>(<SeriesCategory>[]));
      final List<SeriesCategory> categories =
          await runParse(parseSeriesCategories, raw);
      return right(categories.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, SeriesDetail>> getSeriesInfo(
    String seriesId,
  ) async {
    try {
      final SourceConfig? config = _activeStore.config;
      if (config == null) return left(const Failures.unexpected());

      final Either<Failures, Map<String, dynamic>> result =
          await _factory.create(config).fetchSeriesInfo(seriesId);

      return result.fold(
        (Failures failure) {
          developer.log("getSeriesInfo failed → $failure", name: "iptv.series");
          return left(failure);
        },
        (Map<String, dynamic> map) {
          final SeriesDetail detail = SeriesDetail.fromSeriesInfo(map);
          final int episodes = detail.seasons
              .fold<int>(0, (int a, Season s) => a + s.episodes.length);
          developer.log(
            "getSeriesInfo id=$seriesId seasons=${detail.seasons.length} "
            "episodes=$episodes episodesType=${map["episodes"].runtimeType}",
            name: "iptv.series",
          );
          return right(detail);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}

// --- Top-level parsers (run via compute) -----------------------------------

List<Series> parseSeries(String rawJson) {
  final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
  return list.map((dynamic e) {
    final Map<String, dynamic> m = e as Map<String, dynamic>;
    final String cover = "${m["cover"] ?? ""}";
    return Series(
      id: "${m["series_id"]}",
      name: "${m["name"] ?? ""}",
      categoryId: "${m["category_id"] ?? ""}",
      coverUrl: cover.isEmpty ? null : cover,
      plot: _nullableString(m["plot"]),
      year: _nullableString(m["releaseDate"] ?? m["year"]),
      rating: _nullableString(m["rating"]),
    );
  }).toList(growable: false);
}

List<SeriesCategory> parseSeriesCategories(String rawJson) {
  final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
  return list.map((dynamic e) {
    final Map<String, dynamic> m = e as Map<String, dynamic>;
    final String name = "${m["category_name"] ?? ""}";
    return SeriesCategory(
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

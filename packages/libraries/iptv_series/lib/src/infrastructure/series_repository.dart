import "dart:convert";
import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/episode.dart";
import "../models/season.dart";
import "../models/series.dart";
import "../models/series_category.dart";
import "../models/series_detail.dart";

/// Data layer for series. `Either<Failures, T>`, never throws.
abstract interface class ISeriesRepository {
  Future<Either<Failures, int>> sync();

  Future<Either<Failures, IList<Series>>> getSeries();

  Future<Either<Failures, IList<SeriesCategory>>> getCategories();

  /// Seasons + episodes for one series. A success with seasons is written
  /// to the cache. A network failure, or a success without seasons
  /// (captive portal, auth:0), serves the cached copy (`fromCache: true`)
  /// when one exists; otherwise the failure, or the empty detail.
  Future<Either<Failures, SeriesDetail>> getSeriesInfo(String seriesId);

  /// The cached detail without touching the network, or `none()`.
  Future<Either<Failures, Option<SeriesDetail>>> getCachedSeriesInfo(
    String seriesId,
  );
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

  /// One small entry per opened series, scoped to the active source.
  String _infoKey(String seriesId) => "series_info_${_sid}_$seriesId";

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
      final String? raw = await _cache.read(_seriesKey);
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
      final String? raw = await _cache.read(_categoriesKey);
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
      // Pinned before the await: a source switch mid-request must neither
      // write nor serve another account's sheet.
      final String key = _infoKey(seriesId);

      final Either<Failures, Map<String, dynamic>> result =
          await _factory.create(config).fetchSeriesInfo(seriesId);

      return await result.fold(
        (Failures failure) async {
          developer.log("getSeriesInfo failed → $failure", name: "iptv.series");
          if (failure is! NetworkError) return left(failure);
          final SeriesDetail? cached = await _readCached(key);
          if (cached == null) return left(failure);
          return right(cached.copyWith(fromCache: true));
        },
        (Map<String, dynamic> map) async {
          final SeriesDetail detail = SeriesDetail.fromSeriesInfo(map);
          final int episodes = detail.seasons
              .fold<int>(0, (int a, Season s) => a + s.episodes.length);
          developer.log(
            "getSeriesInfo id=$seriesId seasons=${detail.seasons.length} "
            "episodes=$episodes episodesType=${map["episodes"].runtimeType}",
            name: "iptv.series",
          );
          if (detail.seasons.isEmpty) {
            // An empty sheet must neither replace nor hide a good cached one.
            final SeriesDetail? cached = await _readCached(key);
            if (cached != null) return right(cached.copyWith(fromCache: true));
            return right(detail);
          }
          await _writeCached(key, detail);
          return right(detail);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Option<SeriesDetail>>> getCachedSeriesInfo(
    String seriesId,
  ) async {
    try {
      return right(optionOf(await _readCached(_infoKey(seriesId))));
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  Future<SeriesDetail?> _readCached(String key) async {
    try {
      final String? raw = await _cache.read(key);
      if (raw == null) return null;
      return seriesDetailFromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object {
      // A stale/corrupt/unreadable entry must never block a live fetch.
      return null;
    }
  }

  /// Best-effort: a Hive/disk error must not fail a successful fetch.
  Future<void> _writeCached(String key, SeriesDetail detail) async {
    try {
      final String encoded = jsonEncode(seriesDetailToJson(detail));
      // The box compacts after a handful of overwrites, and a compaction
      // rewrites the multi-MB catalogs too - skip the write when unchanged.
      if (await _cache.read(key) == encoded) return;
      await _cache.write(key, encoded);
    } on Object catch (error) {
      developer.log(
        "series info cache write failed: $error",
        name: "iptv.series",
      );
    }
  }
}

// --- Cache (de)serialisation: only content fields, no portal data ----------

Map<String, dynamic> seriesDetailToJson(SeriesDetail d) => <String, dynamic>{
      "plot": d.plot,
      "cover": d.coverUrl,
      "seasons": d.seasons
          .map((Season s) => <String, dynamic>{
                "number": s.number,
                "name": s.name,
                "episodes": s.episodes
                    .map((Episode e) => <String, dynamic>{
                          "id": e.id,
                          "title": e.title,
                          "num": e.episodeNum,
                          "season": e.season,
                          "ext": e.containerExtension,
                          "plot": e.plot,
                          "duration": e.duration,
                          "poster": e.posterUrl,
                        },)
                    .toList(growable: false),
              },)
          .toList(growable: false),
    };

SeriesDetail seriesDetailFromJson(Map<String, dynamic> m) => SeriesDetail(
      plot: m["plot"] as String,
      coverUrl: m["cover"] as String?,
      seasons: (m["seasons"] as List<dynamic>)
          .map((dynamic raw) {
            final Map<String, dynamic> s = raw as Map<String, dynamic>;
            return Season(
              number: s["number"] as int,
              name: s["name"] as String,
              episodes: (s["episodes"] as List<dynamic>)
                  .map((dynamic rawEp) {
                    final Map<String, dynamic> e =
                        rawEp as Map<String, dynamic>;
                    return Episode(
                      id: e["id"] as String,
                      title: e["title"] as String,
                      episodeNum: e["num"] as int,
                      season: e["season"] as int,
                      containerExtension: e["ext"] as String,
                      plot: e["plot"] as String,
                      duration: e["duration"] as String,
                      posterUrl: SeriesDetail.safeHttpUrl(e["poster"]),
                    );
                  })
                  .toIList(),
            );
          })
          .toIList(),
    );

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

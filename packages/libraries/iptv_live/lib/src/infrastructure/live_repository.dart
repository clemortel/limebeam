import "dart:convert";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/channel.dart";
import "../models/live_category.dart";

/// Data-layer contract for live channels. Returns `Either<Failures, T>` and
/// never throws. Large payloads are parsed off the UI isolate.
abstract interface class ILiveRepository {
  /// Fetches from the active source and writes the cache.
  Future<Either<Failures, int>> sync();

  Future<Either<Failures, IList<Channel>>> getChannels();

  Future<Either<Failures, IList<LiveCategory>>> getCategories();
}

@LazySingleton(as: ILiveRepository)
class LiveRepository implements ILiveRepository {
  LiveRepository(this._factory, this._activeStore, this._cache);

  final PlaylistSourceFactory _factory;
  final ActiveSourceStore _activeStore;
  final CacheStore _cache;

  String get _sid => _activeStore.sourceId ?? "none";
  String get _streamsKey => "live_streams_$_sid";
  String get _categoriesKey => "live_categories_$_sid";

  @override
  Future<Either<Failures, int>> sync() async {
    try {
      final SourceConfig? config = _activeStore.config;
      if (config == null) return left(const Failures.unexpected());

      final Either<Failures, Map<String, dynamic>> result =
          await _factory.create(config).fetchLiveStreams();

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
  Future<Either<Failures, IList<Channel>>> getChannels() async {
    try {
      final String? raw = await _cache.read(_streamsKey);
      if (raw == null) return right(const IListConst<Channel>(<Channel>[]));
      final List<Channel> channels = await runParse(parseChannels, raw);
      return right(channels.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<LiveCategory>>> getCategories() async {
    try {
      final String? raw = await _cache.read(_categoriesKey);
      if (raw == null) return right(const IListConst<LiveCategory>(<LiveCategory>[]));
      final List<LiveCategory> categories =
          await runParse(parseLiveCategories, raw);
      return right(categories.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}

// --- Top-level parsers (run via compute, off the UI isolate) ---------------

List<Channel> parseChannels(String rawJson) {
  final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
  return list.map((dynamic e) {
    final Map<String, dynamic> m = e as Map<String, dynamic>;
    return Channel(
      id: "${m["stream_id"]}",
      name: "${m["name"] ?? ""}",
      streamId: "${m["stream_id"]}",
      categoryId: "${m["category_id"] ?? ""}",
      logoUrl: _emptyToNull("${m["stream_icon"] ?? ""}"),
      epgChannelId: _emptyToNull("${m["epg_channel_id"] ?? ""}"),
      number: int.tryParse("${m["num"] ?? 0}") ?? 0,
    );
  }).toList(growable: false);
}

List<LiveCategory> parseLiveCategories(String rawJson) {
  final List<dynamic> list = jsonDecode(rawJson) as List<dynamic>;
  return list.map((dynamic e) {
    final Map<String, dynamic> m = e as Map<String, dynamic>;
    final String name = "${m["category_name"] ?? ""}";
    return LiveCategory(
      id: "${m["category_id"]}",
      name: name,
      isAdult: isAdultCategoryName(name),
    );
  }).toList(growable: false);
}

String? _emptyToNull(String value) => value.isEmpty ? null : value;

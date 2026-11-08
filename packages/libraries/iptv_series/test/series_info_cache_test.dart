import "dart:io";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_series/src/infrastructure/series_repository.dart";
import "package:iptv_series/src/models/series_detail.dart";
import "package:iptv_series/src/riverpods/providers.dart";

class _MemoryCache implements CacheStore {
  final Map<String, String> data = <String, String>{};
  int writes = 0;

  @override
  Future<void> write(String key, String value) async {
    writes++;
    data[key] = value;
  }

  @override
  Future<String?> read(String key) async => data[key];

  @override
  Future<void> delete(String key) async => data.remove(key);

  @override
  Future<void> clear() async => data.clear();

  @override
  Future<void> compact() async {}
}

class _FakeHttp implements HttpService {
  Object? error;
  dynamic payload;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    if (error != null) throw error!;
    return payload;
  }

  @override
  Future<String> getRaw(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();
}

const Map<String, dynamic> _payload = <String, dynamic>{
  "info": <String, dynamic>{"plot": "A plot", "cover": "https://i/c.jpg"},
  "episodes": <String, dynamic>{
    "1": <dynamic>[
      <String, dynamic>{
        "id": "10",
        "title": "Pilot",
        "episode_num": 1,
        "season": 1,
        "container_extension": "mkv",
        "info": <String, dynamic>{
          "plot": "ep plot",
          "duration": "00:42:00",
          "movie_image": "https://i/e1.jpg",
        },
      },
      <String, dynamic>{
        "id": "11",
        "title": "Two",
        "episode_num": 2,
        "info": <String, dynamic>{"movie_image": ""},
      },
    ],
  },
};

void main() {
  late _MemoryCache cache;
  late _FakeHttp http;
  late ActiveSourceStore store;
  late SeriesRepository repository;

  setUp(() {
    cache = _MemoryCache();
    http = _FakeHttp()..payload = _payload;
    store = ActiveSourceStore()
      ..set(
        sourceId: "src1",
        config: const SourceConfig.xtream(
          host: "http://example.invalid",
          username: "user",
          password: "secret",
        ),
      );
    repository = SeriesRepository(PlaylistSourceFactory(http), store, cache);
  });

  group("fromSeriesInfo", () {
    test("should read episode poster from info.movie_image", () {
      final SeriesDetail detail = SeriesDetail.fromSeriesInfo(_payload);
      expect(
        detail.seasons.first.episodes[0].posterUrl,
        "https://i/e1.jpg",
      );
      expect(detail.seasons.first.episodes[1].posterUrl, isNull);
    });
  });

  group("getSeriesInfo", () {
    test("should write the detail to the cache on success", () async {
      final Either<Failures, SeriesDetail> result =
          await repository.getSeriesInfo("42");

      expect(result.isRight(), isTrue);
      expect(cache.data.keys, <String>["series_info_src1_42"]);
      final String stored = cache.data.values.single;
      expect(stored.contains("example.invalid"), isFalse);
      expect(stored.contains("secret"), isFalse);
    });

    test("should not rewrite an unchanged detail", () async {
      await repository.getSeriesInfo("42");
      await repository.getSeriesInfo("42");
      expect(cache.writes, 1);
    });

    test("should serve the cache on network failure", () async {
      await repository.getSeriesInfo("42");
      http.error = const SocketException("offline");

      final SeriesDetail detail =
          (await repository.getSeriesInfo("42")).getOrElse(
        () => throw StateError("expected cached detail"),
      );

      expect(detail.fromCache, isTrue);
      expect(detail.plot, "A plot");
      expect(detail.seasons.first.episodes.first.posterUrl, "https://i/e1.jpg");
      expect(detail.seasons.first.episodes.first.containerExtension, "mkv");
    });

    test("should fail with the network error when nothing is cached",
        () async {
      http.error = const SocketException("offline");

      final Either<Failures, SeriesDetail> result =
          await repository.getSeriesInfo("42");

      expect(result, left<Failures, SeriesDetail>(const Failures.network()));
    });

    test("should not mask a server error with the cache", () async {
      await repository.getSeriesInfo("42");
      http.error = const HttpStatusException(500);

      final Either<Failures, SeriesDetail> result =
          await repository.getSeriesInfo("42");

      expect(result, left<Failures, SeriesDetail>(const Failures.server(500)));
    });

    test("should treat a corrupt cache entry as a miss", () async {
      cache.data["series_info_src1_42"] = "{not json";
      http.error = const SocketException("offline");

      final Either<Failures, SeriesDetail> result =
          await repository.getSeriesInfo("42");

      expect(result.isLeft(), isTrue);
    });
  });

  group("SeriesDetailNotifier", () {
    ProviderContainer makeContainer() {
      final ProviderContainer container = ProviderContainer(
        // Riverpod 3 does not export `Override` from the public barrel.
        // ignore: always_specify_types
        overrides: [
          seriesRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test("should flag offline data when the network is down", () async {
      await repository.getSeriesInfo("42");
      http.error = const SocketException("offline");

      final ProviderContainer container = makeContainer();
      container.listen(seriesDetailProvider("42"), (_, __) {});
      await settle();
      await settle();

      final AsyncState<SeriesDetail> state =
          container.read(seriesDetailProvider("42"));
      expect(state, isA<AsyncSuccess<SeriesDetail>>());
      expect((state as AsyncSuccess<SeriesDetail>).data.fromCache, isTrue);
    });

    test("should not flag offline data when online", () async {
      await repository.getSeriesInfo("42");

      final ProviderContainer container = makeContainer();
      container.listen(seriesDetailProvider("42"), (_, __) {});
      await settle();
      await settle();

      final AsyncState<SeriesDetail> state =
          container.read(seriesDetailProvider("42"));
      expect((state as AsyncSuccess<SeriesDetail>).data.fromCache, isFalse);
    });

    test("should emit the error when offline with no cache", () async {
      http.error = const SocketException("offline");

      final ProviderContainer container = makeContainer();
      container.listen(seriesDetailProvider("42"), (_, __) {});
      await settle();
      await settle();

      expect(
        container.read(seriesDetailProvider("42")),
        const AsyncState<SeriesDetail>.error(Failures.network()),
      );
    });

    test("should keep the cached detail when a refresh hits a server error",
        () async {
      await repository.getSeriesInfo("42");
      http.error = const HttpStatusException(503);

      final ProviderContainer container = makeContainer();
      container.listen(seriesDetailProvider("42"), (_, __) {});
      await settle();
      await settle();

      expect(
        container.read(seriesDetailProvider("42")),
        isA<AsyncSuccess<SeriesDetail>>(),
      );
    });
  });
}

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_api/src/clients/xtream_codes_client.dart";
import "package:iptv_core/iptv_core.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "xtream_codes_client_test.mocks.dart";

// Run `melos run build_runner` to generate the mocks.
@GenerateMocks(<Type>[HttpService])
void main() {
  late MockHttpService http;
  late XtreamCodesClient client;

  const XtreamConfig config = XtreamConfig(
    host: "http://portal.tv:8080/",
    username: "user",
    password: "pass",
  );

  setUp(() {
    http = MockHttpService();
    client = XtreamCodesClient(config: config, http: http);
  });

  group("stream URL building", () {
    test("should build live URL with normalized host (trailing slash dropped)",
        () {
      expect(
        client.buildLiveUrl("123"),
        "http://portal.tv:8080/live/user/pass/123.ts",
      );
    });

    test("should build live HLS URL (.m3u8) when hls is requested", () {
      expect(
        client.buildLiveUrl("123", hls: true),
        "http://portal.tv:8080/live/user/pass/123.m3u8",
      );
    });

    test("should build movie URL with its container extension", () {
      expect(
        client.buildMovieUrl("55", "mkv"),
        "http://portal.tv:8080/movie/user/pass/55.mkv",
      );
    });

    test("should build series episode URL with its container extension", () {
      expect(
        client.buildSeriesUrl("9", "mp4"),
        "http://portal.tv:8080/series/user/pass/9.mp4",
      );
    });
  });

  group("authenticate", () {
    test("should return right when auth=1 and status Active", () async {
      when(http.get(any, queryParameters: anyNamed("queryParameters")))
          .thenAnswer((_) async => <String, dynamic>{
                "user_info": <String, dynamic>{"auth": 1, "status": "Active"},
              },);

      final Either<Failures, Map<String, dynamic>> result =
          await client.authenticate();

      expect(result.isRight(), isTrue);
    });

    test("should return portalAuth failure when auth=0", () async {
      when(http.get(any, queryParameters: anyNamed("queryParameters")))
          .thenAnswer((_) async => <String, dynamic>{
                "user_info": <String, dynamic>{"auth": 0, "status": "Active"},
              },);

      final Either<Failures, Map<String, dynamic>> result =
          await client.authenticate();

      expect(
        result,
        left<Failures, Map<String, dynamic>>(const Failures.portalAuth()),
      );
    });

    test("should map thrown errors through catchError", () async {
      when(http.get(any, queryParameters: anyNamed("queryParameters")))
          .thenThrow(const HttpStatusException(500));

      final Either<Failures, Map<String, dynamic>> result =
          await client.authenticate();

      expect(
        result,
        left<Failures, Map<String, dynamic>>(const Failures.server(500)),
      );
    });
  });
}

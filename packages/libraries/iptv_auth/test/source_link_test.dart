import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";

void main() {
  group("SourceLink.parse", () {
    test("reads Xtream credentials out of a get.php link", () {
      final SourceLink? link = SourceLink.parse(
        "http://portal.tv:8080/get.php?username=bob&password=s3cret"
        "&type=m3u_plus&output=ts",
      );

      expect(
        link,
        const SourceLink.xtream(
          host: "http://portal.tv:8080",
          username: "bob",
          password: "s3cret",
        ),
      );
    });

    test("reads Xtream credentials out of a player_api link", () {
      final SourceLink? link = SourceLink.parse(
        " https://p.example/player_api.php?username=a&password=b ",
      );

      expect(
        link,
        const SourceLink.xtream(
          host: "https://p.example",
          username: "a",
          password: "b",
        ),
      );
    });

    test("treats any other http link as a playlist URL", () {
      expect(
        SourceLink.parse("http://example.com/list.m3u"),
        const SourceLink.m3u(url: "http://example.com/list.m3u"),
      );
    });

    test("rejects text that is not an http link", () {
      expect(SourceLink.parse(""), isNull);
      expect(SourceLink.parse("hello world"), isNull);
      expect(SourceLink.parse("ftp://example.com/list.m3u"), isNull);
      expect(SourceLink.parse("example.com/list.m3u"), isNull);
    });
  });
}

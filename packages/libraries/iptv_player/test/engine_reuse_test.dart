import "package:flutter_test/flutter_test.dart";
import "package:iptv_player/src/riverpods/player_controller.dart";

void main() {
  bool reuse({
    bool hasEngine = true,
    bool engineIsNative = false,
    bool wantsNative = false,
    bool airPlayMismatch = false,
  }) =>
      canReuseEngine(
        hasEngine: hasEngine,
        engineIsNative: engineIsNative,
        wantsNative: wantsNative,
        airPlayMismatch: airPlayMismatch,
      );

  group("canReuseEngine", () {
    test("keeps a matching engine", () {
      expect(reuse(), isTrue);
    });

    test("builds one when none is running", () {
      expect(reuse(hasEngine: false), isFalse);
    });

    test("replaces an engine of the wrong native kind", () {
      expect(reuse(engineIsNative: true), isFalse);
      expect(reuse(wantsNative: true), isFalse);
    });

    // A local file reached on AVPlayer, or an online item under AirPlay left
    // on libmpv: the engine must be rebuilt.
    test("replaces an engine on an AirPlay / local-file mismatch", () {
      expect(reuse(airPlayMismatch: true), isFalse);
    });
  });
}

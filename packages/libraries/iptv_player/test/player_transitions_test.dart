import "dart:async";

import "package:flutter_test/flutter_test.dart";
import "package:iptv_player/src/riverpods/player_transitions.dart";

void main() {
  group("decideNavigation", () {
    NavigationAction decide({
      bool casting = false,
      bool local = false,
      bool reusable = true,
    }) =>
        decideNavigation(
          casting: casting,
          itemIsLocal: local,
          engineReusable: reusable,
        );

    test("casting an online item reloads the open session", () {
      expect(decide(casting: true), NavigationAction.castLoad);
    });

    test("casting a local file leaves the session", () {
      expect(decide(casting: true, local: true), NavigationAction.leaveCast);
    });

    test("not casting: reuse the engine or rebuild it", () {
      expect(decide(), NavigationAction.openLocal);
      expect(decide(reusable: false), NavigationAction.swapEngine);
    });

    test("after leaving a cast the engine decides", () {
      expect(
        decideAfterLeavingCast(engineReusable: true),
        NavigationAction.openLocal,
      );
      expect(
        decideAfterLeavingCast(engineReusable: false),
        NavigationAction.swapEngine,
      );
    });
  });

  group("TransitionQueue", () {
    test("runs bodies one at a time, in call order", () async {
      final TransitionQueue queue = TransitionQueue();
      final List<String> log = <String>[];
      final Completer<void> gate = Completer<void>();
      final Future<void> first = queue.run(() async {
        log.add("a:start");
        await gate.future;
        log.add("a:end");
      });
      final Future<void> second = queue.run(() async => log.add("b"));
      await Future<void>.delayed(Duration.zero);
      // Two swaps never overlap: b waits for a to finish disposing.
      expect(log, <String>["a:start"]);
      gate.complete();
      await Future.wait(<Future<void>>[first, second]);
      expect(log, <String>["a:start", "a:end", "b"]);
    });

    test("a failing body does not block the next one", () async {
      final TransitionQueue queue = TransitionQueue();
      final List<Object> errors = <Object>[];
      bool ran = false;
      await queue.run(
        () async => throw StateError("boom"),
        onError: (Object e, StackTrace _) => errors.add(e),
      );
      await queue.run(() async => ran = true);
      expect(errors.single, isA<StateError>());
      expect(ran, isTrue);
    });

    test("bump supersedes earlier generations", () {
      final TransitionQueue queue = TransitionQueue();
      final int first = queue.bump();
      expect(queue.isCurrent(first), isTrue);
      final int second = queue.bump();
      expect(queue.isCurrent(first), isFalse);
      expect(queue.isCurrent(second), isTrue);
    });

    test("two rapid navigations: only the last one creates anything", () async {
      final TransitionQueue queue = TransitionQueue();
      int alive = 0;
      int peak = 0;
      Future<void> swap(int gen) async {
        if (!queue.isCurrent(gen)) return;
        // Dispose of the old engine, a gap in which a rival could run.
        await Future<void>.delayed(Duration.zero);
        if (!queue.isCurrent(gen)) return;
        alive++;
        if (alive > peak) peak = alive;
      }

      final int a = queue.bump();
      final Future<void> fa = queue.run(() => swap(a));
      final int b = queue.bump();
      final Future<void> fb = queue.run(() => swap(b));
      await Future.wait(<Future<void>>[fa, fb]);
      expect(alive, 1);
      expect(peak, 1);
    });
  });
}

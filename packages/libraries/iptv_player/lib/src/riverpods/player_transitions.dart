import "dart:async";

/// What a queue change must do, given the live cast and engine state.
enum NavigationAction {
  /// Casting and the item can travel: load it on the open session.
  castLoad,

  /// Casting but the item is a local file: end the session, play locally.
  leaveCast,

  /// Not casting and the engine is the wrong one (or missing): rebuild it.
  swapEngine,

  /// Not casting and the engine fits: open the item on it.
  openLocal,
}

/// Decides how to reach a queue item. Pure: the controller feeds it the
/// state read when the transition actually runs, never when it was asked.
NavigationAction decideNavigation({
  required bool casting,
  required bool itemIsLocal,
  required bool engineReusable,
}) {
  if (casting) {
    return itemIsLocal ? NavigationAction.leaveCast : NavigationAction.castLoad;
  }
  return engineReusable
      ? NavigationAction.openLocal
      : NavigationAction.swapEngine;
}

/// What remains to do once a cast session has been ended for a local item.
NavigationAction decideAfterLeavingCast({required bool engineReusable}) =>
    engineReusable ? NavigationAction.openLocal : NavigationAction.swapEngine;

/// Serial queue plus generation counter for everything that replaces the
/// engine or hands playback to a cast receiver.
///
/// Trap: those steps await (dispose, end session, load media). Run
/// concurrently, two swaps dispose the same engine and leave a second
/// player decoding, and a cast hand-off races the session it is closing.
/// Rules: [run] executes bodies one at a time in call order; a user-driven
/// change calls [bump] first, and a body holding an older generation (see
/// [isCurrent]) must stop before creating anything.
class TransitionQueue {
  int _generation = 0;
  Future<void> _tail = Future<void>.value();

  int get generation => _generation;

  /// Marks every transition requested so far as superseded.
  int bump() => ++_generation;

  bool isCurrent(int generation) => generation == _generation;

  /// Resolves once every transition requested so far has finished.
  Future<void> get idle => _tail;

  /// Queues [body]. A failing body never blocks the ones behind it; its
  /// error goes to [onError].
  Future<void> run(
    Future<void> Function() body, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) {
    final Future<void> next = _tail.then((_) async {
      try {
        await body();
      } catch (error, stackTrace) {
        onError?.call(error, stackTrace);
      }
    });
    _tail = next;
    return next;
  }
}

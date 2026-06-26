import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/content_kind.dart";
import "../models/watch_session.dart";
import "providers.dart";

part "watch_sessions_notifier.g.dart";

/// Continue-watching sessions, newest first. Long-lived; the player writes
/// through [WatchProgressSink], so call [refresh] after returning from a
/// player.
@Riverpod(keepAlive: true)
class WatchSessionsNotifier extends _$WatchSessionsNotifier {
  @override
  AsyncState<IList<WatchSession>> build() {
    _fetch();
    return const AsyncState<IList<WatchSession>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<WatchSession>> result =
        await ref.read(favoritesRepositoryProvider).getSessions();
    state = result.fold(
      (Failures failure) => AsyncState<IList<WatchSession>>.error(failure),
      (IList<WatchSession> sessions) =>
          AsyncState<IList<WatchSession>>.success(sessions),
    );
  }

  Future<void> refresh() => _fetch();

  Future<void> remove(ContentKind kind, String id) async {
    await ref.read(favoritesRepositoryProvider).removeSession(kind, id);
    await _fetch();
  }
}

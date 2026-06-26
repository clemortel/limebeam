import "dart:convert";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/content_kind.dart";
import "../models/favorite.dart";
import "../models/watch_session.dart";

/// At/above this elapsed fraction the item is treated as finished and dropped
/// from continue-watching.
const double _kFinishedFraction = 0.9;

/// Below this elapsed time we don't store a resume point (avoids cluttering the
/// rail with items barely started).
const int _kMinResumeSeconds = 15;

/// Favorites + continue-watching store. Persists small JSON lists in the shared
/// [CacheStore], namespaced per active source. Returns `Either<Failures, T>`
/// and never throws. Also implements [WatchProgressSink] so the player can
/// record progress without importing this library.
abstract interface class IFavoritesRepository {
  Future<Either<Failures, IList<WatchSession>>> getSessions();

  Future<Either<Failures, Unit>> removeSession(ContentKind kind, String id);

  Future<Either<Failures, IList<Favorite>>> getFavorites();

  /// Toggles membership; returns the new "is favorite" state.
  Future<Either<Failures, bool>> toggleFavorite(Favorite favorite);
}

class FavoritesRepository implements IFavoritesRepository, WatchProgressSink {
  FavoritesRepository(this._activeStore, this._cache);

  final ActiveSourceStore _activeStore;
  final CacheStore _cache;

  String get _sid => _activeStore.sourceId ?? "none";
  String get _sessionsKey => "watch_sessions_$_sid";
  String get _favoritesKey => "favorites_$_sid";

  @override
  Future<Either<Failures, IList<WatchSession>>> getSessions() async {
    try {
      final List<WatchSession> list = _readSessions()
        ..sort(
          (WatchSession a, WatchSession b) =>
              b.updatedAtMillis.compareTo(a.updatedAtMillis),
        );
      return right(list.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> removeSession(
    ContentKind kind,
    String id,
  ) async {
    try {
      final String key = "${kind.name}_$id";
      final List<WatchSession> list = _readSessions()
        ..removeWhere((WatchSession s) => s.key == key);
      await _writeSessions(list);
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<Favorite>>> getFavorites() async {
    try {
      final List<Favorite> list = _readFavorites()
        ..sort(
          (Favorite a, Favorite b) =>
              b.addedAtMillis.compareTo(a.addedAtMillis),
        );
      return right(list.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, bool>> toggleFavorite(Favorite favorite) async {
    try {
      final List<Favorite> list = _readFavorites();
      final bool wasFavorite = list.any((Favorite f) => f.key == favorite.key);
      list.removeWhere((Favorite f) => f.key == favorite.key);
      if (!wasFavorite) {
        list.add(
          favorite.copyWith(
            addedAtMillis: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      await _writeFavorites(list);
      return right(!wasFavorite);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<void> saveProgress({
    required String id,
    required String kind,
    required String containerExtension,
    required String title,
    required int positionSeconds,
    required int durationSeconds,
    String? subtitle,
    String? posterUrl,
  }) async {
    // Best-effort: a failed progress save must never break playback.
    try {
      final ContentKind kindEnum = ContentKind.values.firstWhere(
        (ContentKind k) => k.name == kind,
        orElse: () => ContentKind.movie,
      );
      final String key = "${kindEnum.name}_$id";
      final List<WatchSession> list = _readSessions()
        ..removeWhere((WatchSession s) => s.key == key);

      final double fraction =
          durationSeconds > 0 ? positionSeconds / durationSeconds : 0;
      final bool finished = fraction >= _kFinishedFraction;
      final bool trivial = positionSeconds < _kMinResumeSeconds;
      if (!finished && !trivial) {
        list.add(
          WatchSession(
            id: id,
            kind: kindEnum,
            title: title,
            containerExtension: containerExtension,
            positionSeconds: positionSeconds,
            durationSeconds: durationSeconds,
            updatedAtMillis: DateTime.now().millisecondsSinceEpoch,
            subtitle: subtitle,
            posterUrl: posterUrl,
          ),
        );
      }
      await _writeSessions(list);
    } catch (_) {
      // Swallowed on purpose — see above.
    }
  }

  List<WatchSession> _readSessions() {
    final String? raw = _cache.read(_sessionsKey);
    if (raw == null || raw.isEmpty) return <WatchSession>[];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (dynamic e) => WatchSession.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  Future<void> _writeSessions(List<WatchSession> list) => _cache.write(
        _sessionsKey,
        jsonEncode(
          list.map((WatchSession s) => s.toJson()).toList(growable: false),
        ),
      );

  List<Favorite> _readFavorites() {
    final String? raw = _cache.read(_favoritesKey);
    if (raw == null || raw.isEmpty) return <Favorite>[];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((dynamic e) => Favorite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _writeFavorites(List<Favorite> list) => _cache.write(
        _favoritesKey,
        jsonEncode(
          list.map((Favorite f) => f.toJson()).toList(growable: false),
        ),
      );
}

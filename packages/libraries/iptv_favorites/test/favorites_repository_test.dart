import "dart:convert";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_favorites/src/infrastructure/favorites_repository.dart";

/// In-memory [CacheStore] for deterministic repository tests.
class _FakeCache implements CacheStore {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> compact() async {}
}

void main() {
  late _FakeCache cache;
  late ActiveSourceStore active;
  late FavoritesRepository repo;

  setUp(() {
    cache = _FakeCache();
    active = ActiveSourceStore()
      ..set(
        sourceId: "s1",
        config: const SourceConfig.xtream(
          host: "h",
          username: "u",
          password: "p",
        ),
      );
    repo = FavoritesRepository(active, cache);
  });

  IList<T> rightOf<T>(Either<Failures, IList<T>> e) =>
      e.getOrElse(() => IList<T>(const <Never>[]));

  group("watch sessions", () {
    test("stores a resumable session for normal progress", () async {
      await repo.saveProgress(
        id: "1",
        kind: "movie",
        containerExtension: "mp4",
        title: "Film",
        positionSeconds: 120,
        durationSeconds: 6000,
      );
      final IList<WatchSession> sessions = rightOf(await repo.getSessions());
      expect(sessions.length, 1);
      expect(sessions.first.id, "1");
      expect(sessions.first.kind, ContentKind.movie);
    });

    test("ignores trivial progress below the minimum", () async {
      await repo.saveProgress(
        id: "1",
        kind: "movie",
        containerExtension: "mp4",
        title: "Film",
        positionSeconds: 10,
        durationSeconds: 6000,
      );
      expect(rightOf(await repo.getSessions()), isEmpty);
    });

    test("drops a finished session (>= 90%)", () async {
      await repo.saveProgress(
        id: "1",
        kind: "movie",
        containerExtension: "mp4",
        title: "Film",
        positionSeconds: 5500,
        durationSeconds: 6000,
      );
      expect(rightOf(await repo.getSessions()), isEmpty);
    });

    test("upsert keeps a single entry per content", () async {
      await repo.saveProgress(
        id: "1",
        kind: "movie",
        containerExtension: "mp4",
        title: "Film",
        positionSeconds: 100,
        durationSeconds: 6000,
      );
      await repo.saveProgress(
        id: "1",
        kind: "movie",
        containerExtension: "mp4",
        title: "Film",
        positionSeconds: 300,
        durationSeconds: 6000,
      );
      final IList<WatchSession> sessions = rightOf(await repo.getSessions());
      expect(sessions.length, 1);
      expect(sessions.first.positionSeconds, 300);
    });

    test("returns sessions newest-first", () async {
      // Seed the cache directly for deterministic timestamps.
      final List<Map<String, dynamic>> seeded = <Map<String, dynamic>>[
        const WatchSession(
          id: "old",
          kind: ContentKind.movie,
          title: "Old",
          containerExtension: "mp4",
          positionSeconds: 10,
          durationSeconds: 100,
          updatedAtMillis: 100,
        ).toJson(),
        const WatchSession(
          id: "new",
          kind: ContentKind.movie,
          title: "New",
          containerExtension: "mp4",
          positionSeconds: 10,
          durationSeconds: 100,
          updatedAtMillis: 200,
        ).toJson(),
      ];
      await cache.write("watch_sessions_s1", jsonEncode(seeded));
      final IList<WatchSession> sessions = rightOf(await repo.getSessions());
      expect(sessions.map((WatchSession s) => s.id).toList(), <String>[
        "new",
        "old",
      ]);
    });

    test("removeSession deletes the matching entry", () async {
      await repo.saveProgress(
        id: "1",
        kind: "episode",
        containerExtension: "mkv",
        title: "Ep",
        positionSeconds: 100,
        durationSeconds: 6000,
      );
      await repo.removeSession(ContentKind.episode, "1");
      expect(rightOf(await repo.getSessions()), isEmpty);
    });
  });

  group("favorites", () {
    Favorite favorite(String id) => Favorite(
          id: id,
          kind: ContentKind.movie,
          title: "Movie $id",
          addedAtMillis: 0,
        );

    test("toggle adds then removes", () async {
      final Either<Failures, bool> first =
          await repo.toggleFavorite(favorite("1"));
      expect(first.getOrElse(() => false), isTrue); // now favorite
      expect(rightOf(await repo.getFavorites()).length, 1);

      final Either<Failures, bool> second =
          await repo.toggleFavorite(favorite("1"));
      expect(second.getOrElse(() => true), isFalse); // no longer favorite
      expect(rightOf(await repo.getFavorites()), isEmpty);
    });

    test("returns favorites newest-first", () async {
      final List<Map<String, dynamic>> seeded = <Map<String, dynamic>>[
        const Favorite(
          id: "old",
          kind: ContentKind.movie,
          title: "Old",
          addedAtMillis: 100,
        ).toJson(),
        const Favorite(
          id: "new",
          kind: ContentKind.movie,
          title: "New",
          addedAtMillis: 200,
        ).toJson(),
      ];
      await cache.write("favorites_s1", jsonEncode(seeded));
      final IList<Favorite> favs = rightOf(await repo.getFavorites());
      expect(favs.map((Favorite f) => f.id).toList(), <String>["new", "old"]);
    });
  });
}

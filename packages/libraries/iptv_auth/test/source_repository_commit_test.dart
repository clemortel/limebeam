import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:flutter_test/flutter_test.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_auth/src/infrastructure/source_repository.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart" show SourceSwitchCommit;
import "package:mockito/mockito.dart";

class _MockSecure extends Mock implements FlutterSecureStorage {}

class _MockFactory extends Mock implements PlaylistSourceFactory {}

/// In-memory cache whose writes can be made to fail like a full disk.
class _FakeCache implements CacheStore {
  final Map<String, String> _data = <String, String>{};
  bool failWrites = false;

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError("disk full");
    _data[key] = value;
  }

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> delete(String key) async => _data.remove(key);

  @override
  Future<void> clear() async => _data.clear();

  @override
  Future<void> compact() async {}
}

void main() {
  late _FakeCache cache;
  late SourceRepository repository;

  setUp(() {
    cache = _FakeCache();
    repository = SourceRepository(
      _MockSecure(),
      _MockFactory(),
      ActiveSourceStore(),
      cache,
    );
  });

  test("should return a Left when the demo commit hits a full disk", () async {
    final SourceSwitchCommit<Source> commit =
        (await repository.prepareDemoSource()).getOrElse(
      () => throw StateError("prepare should succeed"),
    );
    cache.failWrites = true;

    final Either<Failures, Source> result = await commit();

    expect(result.isLeft(), isTrue);
  });

  test("should return a Left when the activate commit hits a full disk",
      () async {
    final SourceSwitchCommit<Source> demoCommit =
        (await repository.prepareDemoSource()).getOrElse(
      () => throw StateError("prepare should succeed"),
    );
    final Source demo = (await demoCommit()).getOrElse(
      () => throw StateError("commit should succeed"),
    );
    final SourceSwitchCommit<Unit> commit =
        (await repository.prepareActivate(demo.id)).getOrElse(
      () => throw StateError("prepare should succeed"),
    );
    cache.failWrites = true;

    final Either<Failures, Unit> result = await commit();

    expect(result.isLeft(), isTrue);
  });
}

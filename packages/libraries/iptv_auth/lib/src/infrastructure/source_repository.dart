import "dart:convert";
import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "../demo_source.dart";
import "../models/connection_status.dart";
import "../models/source.dart";
import "../models/source_type.dart";

/// Persists sources + credentials and validates portals on connect.
///
/// Persistence is split for reliability: non-secret metadata (source list,
/// active id, host/username) lives in Hive ([CacheStore]) which always
/// survives restarts; only the **password** lives in the Keychain
/// ([FlutterSecureStorage]). This keeps routing + cached content working even
/// if the Keychain is cleared (a common iOS-simulator / unentitled-macOS
/// quirk).
abstract interface class ISourceRepository {
  Future<Either<Failures, Source>> addXtreamSource({
    required String name,
    required String host,
    required String username,
    required String password,
  });

  Future<Either<Failures, Source>> addM3uSource({
    required String name,
    required String url,
    String? epgUrl,
  });

  /// Adds the bundled offline demo source (live + VOD + series). No network.
  Future<Either<Failures, Source>> addDemoSource();

  Future<IList<Source>> getSources();

  Future<Either<Failures, Unit>> deleteSource(String id);

  Future<Either<Failures, Unit>> setActive(String id);

  /// Changes the display name only; credentials are untouched.
  Future<Either<Failures, Unit>> renameSource(String id, String name);

  /// Loads the persisted active source into [ActiveSourceStore]. Call once on
  /// launch before building the UI.
  Future<void> hydrateOnLaunch();
}

@LazySingleton(as: ISourceRepository)
class SourceRepository implements ISourceRepository {
  SourceRepository(this._secure, this._factory, this._activeStore, this._cache);

  final FlutterSecureStorage _secure;
  final PlaylistSourceFactory _factory;
  final ActiveSourceStore _activeStore;
  final CacheStore _cache;

  // Hive (non-secret).
  static const String _kIndexKey = "auth_sources_index";
  static const String _kActiveKey = "auth_active_id";
  static String _metaKey(String id) => "auth_source_meta_$id";
  static String _cfgKey(String id) => "auth_source_cfg_$id";

  // Keychain (secret) — password only.
  static String _pwdKey(String id) => "auth_pwd_$id";

  @override
  Future<Either<Failures, Source>> addXtreamSource({
    required String name,
    required String host,
    required String username,
    required String password,
  }) async {
    developer.log(
      "addXtreamSource name='$name' host='$host' user='$username'",
      name: "iptv.auth",
    );
    try {
      final SourceConfig config = SourceConfig.xtream(
        host: host,
        username: username,
        password: password,
      );

      final Either<Failures, Map<String, dynamic>> auth =
          await _factory.create(config).authenticate();

      return await auth.fold(
        (Failures failure) async {
          developer.log(
            "addXtreamSource auth failed → $failure",
            name: "iptv.auth",
          );
          return left(failure);
        },
        (Map<String, dynamic> _) async {
          final String id = DateTime.now().microsecondsSinceEpoch.toString();
          final Source source = Source(
            id: id,
            name: name,
            type: SourceType.xtream,
            createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            status: ConnectionStatus.ok,
          );
          await _persist(
            source: source,
            host: host,
            username: username,
            password: password,
          );
          await _setActiveInternal(id, config);
          developer.log(
            "addXtreamSource success id=$id (active set)",
            name: "iptv.auth",
          );
          return right(source);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Source>> addM3uSource({
    required String name,
    required String url,
    String? epgUrl,
  }) async {
    developer.log("addM3uSource name='$name' url='$url'", name: "iptv.auth");
    try {
      final SourceConfig config = SourceConfig.m3u(url: url, epgUrl: epgUrl);
      final Either<Failures, Map<String, dynamic>> auth =
          await _factory.create(config).authenticate();

      return await auth.fold(
        (Failures failure) async {
          developer.log("addM3uSource failed → $failure", name: "iptv.auth");
          return left(failure);
        },
        (Map<String, dynamic> _) async {
          final String id = DateTime.now().microsecondsSinceEpoch.toString();
          final Source source = Source(
            id: id,
            name: name,
            type: SourceType.m3u,
            createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
            status: ConnectionStatus.ok,
          );
          await _persistM3u(source: source, url: url, epgUrl: epgUrl);
          await _setActiveInternal(id, config);
          developer.log("addM3uSource success id=$id", name: "iptv.auth");
          return right(source);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Source>> addDemoSource() async {
    developer.log("addDemoSource", name: "iptv.auth");
    try {
      const SourceConfig config = SourceConfig.demo();
      final String id = DateTime.now().microsecondsSinceEpoch.toString();
      final Source source = Source(
        id: id,
        name: kDemoSourceName,
        type: SourceType.demo,
        createdAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        status: ConnectionStatus.ok,
      );
      await _persistDemo(source);
      await _setActiveInternal(id, config);
      return right(source);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<IList<Source>> getSources() async {
    final List<String> ids = await _readIndex();
    final List<Source> sources = <Source>[];
    for (final String id in ids) {
      final String? raw = await _cache.read(_metaKey(id));
      if (raw == null) continue;
      sources.add(Source.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return sources.toIList();
  }

  @override
  Future<Either<Failures, Unit>> deleteSource(String id) async {
    try {
      final List<String> ids = (await _readIndex())..remove(id);
      await _writeIndex(ids);
      await _cache.delete(_metaKey(id));
      await _cache.delete(_cfgKey(id));
      await _secure.delete(key: _pwdKey(id));
      if (_activeStore.sourceId == id) {
        _activeStore.clear();
        await _cache.delete(_kActiveKey);
      }
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> setActive(String id) async {
    try {
      final SourceConfig? config = await _readConfig(id);
      if (config == null) return left(const Failures.notFound());
      await _setActiveInternal(id, config);
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Unit>> renameSource(String id, String name) async {
    try {
      final String? raw = await _cache.read(_metaKey(id));
      if (raw == null) return left(const Failures.notFound());
      final Source current =
          Source.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      await _cache.write(
        _metaKey(id),
        jsonEncode(current.copyWith(name: name.trim()).toJson()),
      );
      return right(unit);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<void> hydrateOnLaunch() async {
    final String? activeId = await _cache.read(_kActiveKey);
    developer.log("hydrateOnLaunch activeId=$activeId", name: "iptv.auth");
    if (activeId == null) return;
    final SourceConfig? config = await _readConfig(activeId);
    if (config == null) {
      developer.log("hydrateOnLaunch: no config for $activeId",
          name: "iptv.auth");
      return;
    }
    _activeStore.set(sourceId: activeId, config: config);
    developer.log("hydrateOnLaunch: active source restored", name: "iptv.auth");
  }

  // --- persistence helpers -------------------------------------------------

  Future<void> _persist({
    required Source source,
    required String host,
    required String username,
    required String password,
  }) async {
    final List<String> ids = await _readIndex();
    if (!ids.contains(source.id)) {
      ids.add(source.id);
      await _writeIndex(ids);
    }
    await _cache.write(_metaKey(source.id), jsonEncode(source.toJson()));
    await _cache.write(
      _cfgKey(source.id),
      jsonEncode(<String, dynamic>{
        "type": "xtream",
        "host": host,
        "username": username,
      }),
    );
    await _secure.write(key: _pwdKey(source.id), value: password);
  }

  Future<void> _persistM3u({
    required Source source,
    required String url,
    String? epgUrl,
  }) async {
    final List<String> ids = await _readIndex();
    if (!ids.contains(source.id)) {
      ids.add(source.id);
      await _writeIndex(ids);
    }
    await _cache.write(_metaKey(source.id), jsonEncode(source.toJson()));
    await _cache.write(
      _cfgKey(source.id),
      jsonEncode(<String, dynamic>{
        "type": "m3u",
        "url": url,
        "epgUrl": epgUrl,
      }),
    );
  }

  Future<void> _persistDemo(Source source) async {
    final List<String> ids = await _readIndex();
    if (!ids.contains(source.id)) {
      ids.add(source.id);
      await _writeIndex(ids);
    }
    await _cache.write(_metaKey(source.id), jsonEncode(source.toJson()));
    await _cache.write(
      _cfgKey(source.id),
      jsonEncode(<String, dynamic>{"type": "demo"}),
    );
  }

  Future<void> _setActiveInternal(String id, SourceConfig config) async {
    await _cache.write(_kActiveKey, id);
    _activeStore.set(sourceId: id, config: config);
  }

  Future<List<String>> _readIndex() async {
    final String? raw = await _cache.read(_kIndexKey);
    if (raw == null) return <String>[];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> _writeIndex(List<String> ids) =>
      _cache.write(_kIndexKey, jsonEncode(ids));

  /// Rebuilds the full [SourceConfig] from Hive (host/username) + Keychain
  /// (password). Missing password falls back to empty so cached content still
  /// loads after a Keychain wipe.
  Future<SourceConfig?> _readConfig(String id) async {
    final String? raw = await _cache.read(_cfgKey(id));
    if (raw == null) return null;
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    if (json["type"] == "xtream") {
      final String? password = await _secure.read(key: _pwdKey(id));
      return SourceConfig.xtream(
        host: json["host"] as String,
        username: json["username"] as String,
        password: password ?? "",
      );
    }
    if (json["type"] == "m3u") {
      return SourceConfig.m3u(
        url: json["url"] as String,
        epgUrl: json["epgUrl"] as String?,
      );
    }
    if (json["type"] == "demo") return const SourceConfig.demo();
    return null;
  }
}

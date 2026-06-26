import "package:hive_flutter/hive_flutter.dart";
import "package:injectable/injectable.dart";

/// Key/value cache for fetched payloads (spec §6: network is a sync source,
/// parsed results are persisted). Feature repositories JSON-encode their data
/// and store it here keyed by `<feature>_<sourceId>`.
abstract interface class CacheStore {
  Future<void> write(String key, String value);
  String? read(String key);
  Future<void> delete(String key);
  Future<void> clear();
}

/// Hive box name for cached payloads, opened by `registerCore`.
const String kCacheBoxName = "iptv_cache";

@LazySingleton(as: CacheStore)
class HiveCacheStore implements CacheStore {
  HiveCacheStore(this._box);

  final Box<String> _box;

  @override
  Future<void> write(String key, String value) => _box.put(key, value);

  @override
  String? read(String key) => _box.get(key);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> clear() => _box.clear().then((int _) {});
}

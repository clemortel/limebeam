import "package:hive_flutter/hive_flutter.dart";
import "package:injectable/injectable.dart";

/// Key/value cache for fetched payloads (spec §6: network is a sync source,
/// parsed results are persisted). Feature repositories JSON-encode their data
/// and store it here keyed by `<feature>_<sourceId>`.
///
/// Reads are async: the backing box is LAZY, so values are loaded from disk on
/// demand. Opening the box eagerly decoded the entire cache (whole catalogs of
/// JSON) in one synchronous pass at startup — ~9s on Fire TV hardware, which
/// blocked the merged UI/platform thread and ANR'd the app on relaunch.
abstract interface class CacheStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
  Future<void> clear();

  /// Rewrites the backing file keeping only live entries. The box is
  /// append-only, so every catalog re-sync leaves a stale multi-MB copy
  /// behind; call this once after startup (off the first-frame path) to
  /// reclaim the space accumulated before compaction-on-write existed.
  Future<void> compact();
}

/// Hive box name for cached payloads, opened by `registerCore`.
const String kCacheBoxName = "iptv_cache";

@LazySingleton(as: CacheStore)
class HiveCacheStore implements CacheStore {
  HiveCacheStore(this._box);

  final LazyBox<String> _box;

  /// Read-through memo: a lazy box re-reads the value from disk on every
  /// `get`, which makes each catalog screen pay a multi-MB disk read + decode
  /// on every visit. First read pulls from disk, later reads are RAM — the
  /// same residency the old eager box had, but paid only for keys actually
  /// used instead of the whole box at startup.
  final Map<String, String> _memo = <String, String>{};

  @override
  Future<void> write(String key, String value) {
    _memo[key] = value;
    return _box.put(key, value);
  }

  @override
  Future<String?> read(String key) async {
    final String? cached = _memo[key];
    if (cached != null) return cached;
    final String? value = await _box.get(key);
    if (value != null) _memo[key] = value;
    return value;
  }

  @override
  Future<void> delete(String key) {
    _memo.remove(key);
    return _box.delete(key);
  }

  @override
  Future<void> clear() {
    _memo.clear();
    return _box.clear().then((int _) {});
  }

  @override
  Future<void> compact() => _box.compact();
}

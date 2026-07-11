import "package:get_it/get_it.dart";
import "package:hive_flutter/hive_flutter.dart";

import "cache/cache_store.dart";
import "source/active_source_store.dart";

/// Registers foundation singletons. Opens the cache box, so call this first
/// (after `Hive.initFlutter()`), before the other `register*` functions.
/// The box is LAZY: a regular box decodes every cached catalog at open
/// (seconds of CPU on TV hardware, startup ANR); a lazy box only indexes
/// keys and reads values on demand.
Future<void> registerCore(GetIt getIt) async {
  // Aggressive compaction: the box holds ~15 huge catalog payloads, so Hive's
  // default strategy (ratio of deleted entries) never fires and the
  // append-only file grows by a full catalog copy on every sync — startup
  // then scans hundreds of stale MB. A handful of stale frames is already
  // worth rewriting the file.
  final LazyBox<String> cacheBox = await Hive.openLazyBox<String>(
    kCacheBoxName,
    compactionStrategy: (int entries, int deletedEntries) =>
        deletedEntries > 4,
  );
  getIt
    ..registerLazySingleton<CacheStore>(() => HiveCacheStore(cacheBox))
    ..registerLazySingleton<ActiveSourceStore>(ActiveSourceStore.new);
}

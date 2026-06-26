import "package:get_it/get_it.dart";
import "package:hive_flutter/hive_flutter.dart";

import "cache/cache_store.dart";
import "source/active_source_store.dart";

/// Registers foundation singletons. Opens the cache box, so call this first
/// (after `Hive.initFlutter()`), before the other `register*` functions.
Future<void> registerCore(GetIt getIt) async {
  final Box<String> cacheBox = await Hive.openBox<String>(kCacheBoxName);
  getIt
    ..registerLazySingleton<CacheStore>(() => HiveCacheStore(cacheBox))
    ..registerLazySingleton<ActiveSourceStore>(ActiveSourceStore.new);
}

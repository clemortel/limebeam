import "package:get_it/get_it.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/favorites_repository.dart";

/// Registers the favorites / continue-watching repository. Call after
/// [registerCore]. The same instance backs both [IFavoritesRepository] and the
/// core [WatchProgressSink] (the player records progress through the latter).
void registerFavorites(GetIt getIt) {
  getIt.registerLazySingleton<IFavoritesRepository>(
    () => FavoritesRepository(
      getIt<ActiveSourceStore>(),
      getIt<CacheStore>(),
    ),
  );
  getIt.registerLazySingleton<WatchProgressSink>(
    () => getIt<IFavoritesRepository>() as WatchProgressSink,
  );
}

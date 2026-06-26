import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/vod_repository.dart";

/// Registers the VOD repository. Call after [registerApi] / [registerCore].
void registerVod(GetIt getIt) {
  getIt.registerLazySingleton<IVodRepository>(
    () => VodRepository(
      getIt<PlaylistSourceFactory>(),
      getIt<ActiveSourceStore>(),
      getIt<CacheStore>(),
    ),
  );
}

import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/live_repository.dart";

/// Registers the live repository. Call after [registerApi] / [registerCore].
void registerLive(GetIt getIt) {
  getIt.registerLazySingleton<ILiveRepository>(
    () => LiveRepository(
      getIt<PlaylistSourceFactory>(),
      getIt<ActiveSourceStore>(),
      getIt<CacheStore>(),
    ),
  );
}

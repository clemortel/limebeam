import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/epg_repository.dart";

/// Registers the EPG repository. Call after [registerApi] / [registerCore].
void registerEpg(GetIt getIt) {
  getIt.registerLazySingleton<IEpgRepository>(
    () => EpgRepository(
      getIt<PlaylistSourceFactory>(),
      getIt<ActiveSourceStore>(),
      getIt<CacheStore>(),
    ),
  );
}

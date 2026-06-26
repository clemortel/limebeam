import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/series_repository.dart";

/// Registers the series repository. Call after [registerApi] / [registerCore].
void registerSeries(GetIt getIt) {
  getIt.registerLazySingleton<ISeriesRepository>(
    () => SeriesRepository(
      getIt<PlaylistSourceFactory>(),
      getIt<ActiveSourceStore>(),
      getIt<CacheStore>(),
    ),
  );
}

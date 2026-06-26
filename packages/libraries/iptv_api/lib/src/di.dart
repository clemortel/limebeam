import "package:get_it/get_it.dart";
import "package:iptv_core/iptv_core.dart";

import "domain/playlist_source_factory.dart";
import "http/dio_http_service.dart";

/// Registers the HTTP service + provider factory. Call after [registerCore].
void registerApi(GetIt getIt) {
  getIt
    ..registerLazySingleton<HttpService>(DioHttpService.create)
    ..registerLazySingleton<PlaylistSourceFactory>(
      () => PlaylistSourceFactory(getIt<HttpService>()),
    );
}

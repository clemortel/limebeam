import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";

import "infrastructure/source_repository.dart";

/// Registers secure storage + the source repository. Call after [registerApi].
void registerAuth(GetIt getIt) {
  getIt
    ..registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    )
    ..registerLazySingleton<ISourceRepository>(
      () => SourceRepository(
        getIt<FlutterSecureStorage>(),
        getIt<PlaylistSourceFactory>(),
        getIt<ActiveSourceStore>(),
        getIt<CacheStore>(),
      ),
    );
}

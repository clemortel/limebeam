import "package:get_it/get_it.dart";

import "infrastructure/cast_repository.dart";

/// Registers the cast repository. Call after [registerCore].
void registerCast(GetIt getIt) {
  getIt.registerLazySingleton<ICastRepository>(CastRepository.new);
}

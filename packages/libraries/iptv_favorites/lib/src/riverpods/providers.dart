import "package:get_it/get_it.dart";
import "package:iptv_favorites/src/infrastructure/favorites_repository.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
IFavoritesRepository favoritesRepository(FavoritesRepositoryRef ref) =>
    GetIt.instance<IFavoritesRepository>();

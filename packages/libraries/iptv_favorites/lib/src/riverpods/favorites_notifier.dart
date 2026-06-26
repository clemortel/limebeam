import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/favorite.dart";
import "providers.dart";

part "favorites_notifier.g.dart";

/// Bookmarked items, newest first. Long-lived.
@Riverpod(keepAlive: true)
class FavoritesNotifier extends _$FavoritesNotifier {
  @override
  AsyncState<IList<Favorite>> build() {
    _fetch();
    return const AsyncState<IList<Favorite>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<Favorite>> result =
        await ref.read(favoritesRepositoryProvider).getFavorites();
    state = result.fold(
      (Failures failure) => AsyncState<IList<Favorite>>.error(failure),
      (IList<Favorite> favorites) =>
          AsyncState<IList<Favorite>>.success(favorites),
    );
  }

  Future<void> toggle(Favorite favorite) async {
    await ref.read(favoritesRepositoryProvider).toggleFavorite(favorite);
    await _fetch();
  }

  /// Whether [key] (`"${kind.name}_$id"`) is currently bookmarked.
  bool isFavorite(String key) => switch (state) {
        AsyncSuccess<IList<Favorite>>(:final IList<Favorite> data) =>
          data.any((Favorite f) => f.key == key),
        _ => false,
      };
}

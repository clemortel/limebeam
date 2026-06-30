import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_ui/iptv_ui.dart";

/// App-bar heart toggle for a detail screen. Reads the favorites notifier for
/// the current state and toggles membership on tap. Lives in the app layer so
/// the feature libraries (vod / series) stay free of the favorites dependency.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({required this.favorite, super.key});

  /// The bookmark this button represents (id + kind + display data).
  final Favorite favorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    // Watch so the icon flips when the list changes.
    ref.watch(favoritesProvider);
    final bool isFavorite =
        ref.read(favoritesProvider.notifier).isFavorite(favorite.key);
    return IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? t.colors.accent : t.colors.textPrimary,
      ),
      onPressed: () =>
          ref.read(favoritesProvider.notifier).toggle(favorite),
    );
  }
}

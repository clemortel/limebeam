import "package:freezed_annotation/freezed_annotation.dart";

import "content_kind.dart";

part "favorite.freezed.dart";
part "favorite.g.dart";

/// A bookmarked item. Carries only display data + identity; the full model is
/// resolved from the cached lists when the user opens it.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Favorite with _$Favorite {
  const Favorite._();

  const factory Favorite({
    required String id,
    required ContentKind kind,
    required String title,
    required int addedAtMillis,
    String? subtitle,
    String? posterUrl,
  }) = _Favorite;

  factory Favorite.fromJson(Map<String, dynamic> json) =>
      _$FavoriteFromJson(json);

  /// Stable identity across kinds.
  String get key => "${kind.name}_$id";
}

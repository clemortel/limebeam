import "package:freezed_annotation/freezed_annotation.dart";

part "vod_category.freezed.dart";
part "vod_category.g.dart";

/// A VOD (movies) category.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class VodCategory with _$VodCategory {
  const factory VodCategory({
    required String id,
    required String name,
    @Default(false) bool isAdult,
  }) = _VodCategory;

  factory VodCategory.fromJson(Map<String, dynamic> json) =>
      _$VodCategoryFromJson(json);
}

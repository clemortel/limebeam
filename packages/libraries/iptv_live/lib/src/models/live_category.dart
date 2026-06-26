import "package:freezed_annotation/freezed_annotation.dart";

part "live_category.freezed.dart";
part "live_category.g.dart";

/// A live-channel category (e.g. "Sports", "News").
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class LiveCategory with _$LiveCategory {
  const factory LiveCategory({
    required String id,
    required String name,
    @Default(false) bool isAdult,
  }) = _LiveCategory;

  factory LiveCategory.fromJson(Map<String, dynamic> json) =>
      _$LiveCategoryFromJson(json);
}

import "package:freezed_annotation/freezed_annotation.dart";

part "series_category.freezed.dart";
part "series_category.g.dart";

/// A series category.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class SeriesCategory with _$SeriesCategory {
  const factory SeriesCategory({
    required String id,
    required String name,
    @Default(false) bool isAdult,
  }) = _SeriesCategory;

  factory SeriesCategory.fromJson(Map<String, dynamic> json) =>
      _$SeriesCategoryFromJson(json);
}

import "package:freezed_annotation/freezed_annotation.dart";

part "series.freezed.dart";
part "series.g.dart";

/// A series (show). Season/episode detail is fetched lazily via
/// get_series_info and is out of scope for this increment.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Series with _$Series {
  const factory Series({
    required String id,
    required String name,
    required String categoryId,
    String? coverUrl,
    String? plot,
    String? year,
    String? rating,
  }) = _Series;

  factory Series.fromJson(Map<String, dynamic> json) => _$SeriesFromJson(json);
}

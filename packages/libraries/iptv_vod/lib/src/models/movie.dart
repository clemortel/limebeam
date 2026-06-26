import "package:freezed_annotation/freezed_annotation.dart";

part "movie.freezed.dart";
part "movie.g.dart";

/// A VOD movie.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Movie with _$Movie {
  const factory Movie({
    required String id,
    required String name,
    required String streamId,
    required String categoryId,
    String? posterUrl,
    String? rating,
    String? year,
    @Default("mp4") String containerExtension,
  }) = _Movie;

  factory Movie.fromJson(Map<String, dynamic> json) => _$MovieFromJson(json);
}

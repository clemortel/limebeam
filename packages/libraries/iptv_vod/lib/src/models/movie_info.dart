import "package:freezed_annotation/freezed_annotation.dart";

part "movie_info.freezed.dart";

/// Extended movie details from `get_vod_info`. Parsed defensively — Xtream
/// fields are inconsistent across portals.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class MovieInfo with _$MovieInfo {
  const factory MovieInfo({
    @Default("") String plot,
    @Default("") String genre,
    @Default("") String cast,
    @Default("") String director,
    @Default("") String releaseDate,
    @Default("") String duration,
    String? backdropUrl,
    String? rating,
  }) = _MovieInfo;

  factory MovieInfo.fromVodInfo(Map<String, dynamic> json) {
    final Map<String, dynamic> info = json["info"] is Map<String, dynamic>
        ? json["info"] as Map<String, dynamic>
        : <String, dynamic>{};

    String str(List<String> keys) {
      for (final String k in keys) {
        final dynamic v = info[k];
        if (v != null && "$v".isNotEmpty) return "$v";
      }
      return "";
    }

    String? backdrop() {
      final dynamic b = info["backdrop_path"];
      if (b is List && b.isNotEmpty) return "${b.first}";
      if (b is String && b.isNotEmpty) return b;
      return null;
    }

    final String rating = str(<String>["rating"]);
    return MovieInfo(
      plot: str(<String>["plot", "description"]),
      genre: str(<String>["genre"]),
      cast: str(<String>["cast", "actors"]),
      director: str(<String>["director"]),
      releaseDate: str(<String>["releasedate", "release_date"]),
      duration: str(<String>["duration"]),
      backdropUrl: backdrop(),
      rating: rating.isEmpty ? null : rating,
    );
  }
}

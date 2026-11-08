import "package:freezed_annotation/freezed_annotation.dart";

part "episode.freezed.dart";

/// A single series episode.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Episode with _$Episode {
  const factory Episode({
    required String id,
    required String title,
    required int episodeNum,
    required int season,
    @Default("mp4") String containerExtension,
    @Default("") String plot,
    @Default("") String duration,

    /// Thumbnail from `info.movie_image`; null when the provider sends none.
    String? posterUrl,
  }) = _Episode;
}

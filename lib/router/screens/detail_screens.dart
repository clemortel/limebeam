import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_vod/iptv_vod.dart";

import "../../favorites/favorite_button.dart";
import "../../player_launch.dart";

/// Fiche film (§4.4.1).
@RoutePage()
class MovieDetailScreen extends ConsumerWidget {
  const MovieDetailScreen({required this.movie, super.key});

  final Movie movie;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MovieDetailView(
      movie: movie,
      onPlay: () => ref.openMovie(context, movie),
      actions: <Widget>[
        FavoriteButton(
          favorite: Favorite(
            id: movie.streamId,
            kind: ContentKind.movie,
            title: movie.name,
            subtitle: movie.year,
            posterUrl: movie.posterUrl,
            addedAtMillis: 0,
          ),
        ),
      ],
    );
  }
}

/// Fiche série (§4.4.1) with seasons + episodes.
@RoutePage()
class SeriesDetailScreen extends ConsumerWidget {
  const SeriesDetailScreen({required this.series, super.key});

  final Series series;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SeriesDetailView(
      series: series,
      onPlayEpisode: (Season season, Episode episode) =>
          ref.openEpisode(context, season, episode),
      actions: <Widget>[
        FavoriteButton(
          favorite: Favorite(
            id: series.id,
            kind: ContentKind.series,
            title: series.name,
            subtitle: series.year,
            posterUrl: series.coverUrl,
            addedAtMillis: 0,
          ),
        ),
      ],
    );
  }
}

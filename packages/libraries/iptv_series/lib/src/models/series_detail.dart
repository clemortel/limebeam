import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

import "episode.dart";
import "season.dart";

part "series_detail.freezed.dart";

/// Full series details from `get_series_info`: plot/cover + seasons/episodes.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class SeriesDetail with _$SeriesDetail {
  const factory SeriesDetail({
    @Default("") String plot,
    String? coverUrl,
    required IList<Season> seasons,

    /// True when this is the on-disk copy because the network was
    /// unreachable or answered with an empty sheet. Never persisted.
    /// Other refresh failures (5xx, auth) do not set it.
    @Default(false) bool fromCache,
  }) = _SeriesDetail;

  factory SeriesDetail.fromSeriesInfo(Map<String, dynamic> json) {
    final Map<String, dynamic> info = json["info"] is Map<String, dynamic>
        ? json["info"] as Map<String, dynamic>
        : <String, dynamic>{};

    // `episodes` is usually a Map { "1": [...], "2": [...] } but some panels
    // send a List (indexed by season) or a Map-of-Maps per season.
    final List<Season> seasons = <Season>[];
    final dynamic episodesRoot = json["episodes"];

    void addSeason(int seasonNumber, dynamic rawEpisodes) {
      final List<dynamic> list = _asList(rawEpisodes);
      final List<Episode> episodes = list
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> e) => _episode(e, seasonNumber))
          .toList(growable: false);
      if (episodes.isEmpty) return;
      seasons.add(
        Season(
          number: seasonNumber,
          name: "Saison $seasonNumber",
          episodes: episodes.toIList(),
        ),
      );
    }

    if (episodesRoot is Map<String, dynamic>) {
      for (final MapEntry<String, dynamic> entry in episodesRoot.entries) {
        addSeason(int.tryParse(entry.key) ?? 0, entry.value);
      }
    } else if (episodesRoot is List) {
      for (int i = 0; i < episodesRoot.length; i++) {
        addSeason(i + 1, episodesRoot[i]);
      }
    }

    seasons.sort((Season a, Season b) => a.number.compareTo(b.number));

    return SeriesDetail(
      plot: "${info["plot"] ?? ""}",
      coverUrl: safeHttpUrl(info["cover"]),
      seasons: seasons.toIList(),
    );
  }

  /// Coerces a season's episodes to a list, handling List and Map-of-episodes.
  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value is Map) return value.values.toList(growable: false);
    return <dynamic>[];
  }

  static Episode _episode(Map<String, dynamic> e, int seasonNumber) {
    final Map<String, dynamic> epInfo = e["info"] is Map<String, dynamic>
        ? e["info"] as Map<String, dynamic>
        : <String, dynamic>{};
    return Episode(
      id: "${e["id"]}",
      title: "${e["title"] ?? "Épisode ${e["episode_num"] ?? ""}"}",
      episodeNum: int.tryParse("${e["episode_num"] ?? 0}") ?? 0,
      season: int.tryParse("${e["season"] ?? seasonNumber}") ?? seasonNumber,
      containerExtension: "${e["container_extension"] ?? "mp4"}",
      plot: "${epInfo["plot"] ?? ""}",
      duration: "${epInfo["duration"] ?? ""}",
      posterUrl: safeHttpUrl(epInfo["movie_image"]),
    );
  }

  /// Provider-supplied image URL, or null unless it is http(s) with a host:
  /// it is cached and handed to the image loader, so nothing else passes.
  static String? safeHttpUrl(dynamic value) {
    final String? raw = _nonEmpty(value);
    if (raw == null) return null;
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final bool http = uri.scheme == "http" || uri.scheme == "https";
    return http && uri.host.isNotEmpty ? raw : null;
  }

  /// Null for absent/blank values (providers send "" instead of omitting).
  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final String s = "$value".trim();
    return s.isEmpty ? null : s;
  }
}

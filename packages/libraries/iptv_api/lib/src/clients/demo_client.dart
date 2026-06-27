import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";

import "../domain/playlist_source.dart";

/// Bundled, offline demo catalog source. Returns built-in, legally-public
/// sample content (Blender open movies + official HLS test streams) shaped like
/// the Xtream payloads the repositories already parse, so the whole app
/// (home rails, Films/Séries grids, detail pages) populates without any
/// account. The app ships no real content — this only exists so a first-time
/// user or a store reviewer can explore the UI.
///
/// Item ids are stable + unique; the playable URL is resolved internally so the
/// same underlying test stream can back several catalog entries.
class DemoPlaylistSource implements IPlaylistSource {
  const DemoPlaylistSource();

  String _resolve(String id) => _kPlayUrlById[id] ?? id;

  @override
  Future<Either<Failures, Map<String, dynamic>>> authenticate() async =>
      right(const <String, dynamic>{});

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchLiveStreams() async =>
      right(<String, dynamic>{
        "categories": <Map<String, dynamic>>[
          <String, dynamic>{"category_id": _kCatLive, "category_name": "Direct"},
        ],
        "streams": <Map<String, dynamic>>[
          for (final (int i, _DemoLive c) in _kLive.indexed)
            <String, dynamic>{
              "stream_id": c.id,
              "name": c.name,
              "stream_icon": c.logo,
              "category_id": _kCatLive,
              "epg_channel_id": "",
              "num": i + 1,
            },
        ],
      });

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchVod() async =>
      right(<String, dynamic>{
        "categories": <Map<String, dynamic>>[
          <String, dynamic>{"category_id": _kCatFilms, "category_name": "Films"},
        ],
        "streams": <Map<String, dynamic>>[
          for (final _DemoMovie m in _kMovies)
            <String, dynamic>{
              "stream_id": m.id,
              "name": m.name,
              "stream_icon": m.poster,
              "category_id": _kCatFilms,
              "rating": m.rating,
              "year": m.year,
              "container_extension": "mp4",
            },
        ],
      });

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchSeries() async =>
      right(<String, dynamic>{
        "categories": <Map<String, dynamic>>[
          <String, dynamic>{
            "category_id": _kCatSeries,
            "category_name": "Séries",
          },
        ],
        "series": <Map<String, dynamic>>[
          for (final _DemoSeries s in _kSeries)
            <String, dynamic>{
              "series_id": s.id,
              "name": s.name,
              "cover": s.cover,
              "category_id": _kCatSeries,
              "plot": s.plot,
              "year": s.year,
              "rating": s.rating,
            },
        ],
      });

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchVodInfo(
    String vodId,
  ) async {
    final _DemoMovie? m =
        _kMovies.where((_DemoMovie e) => e.id == vodId).firstOrNull;
    if (m == null) return right(const <String, dynamic>{});
    return right(<String, dynamic>{
      "info": <String, dynamic>{
        "plot": m.plot,
        "genre": m.genre,
        "director": "Open Movie Project",
        "releasedate": m.year,
        "duration": m.duration,
        "rating": m.rating,
      },
    });
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchSeriesInfo(
    String seriesId,
  ) async {
    final _DemoSeries? s =
        _kSeries.where((_DemoSeries e) => e.id == seriesId).firstOrNull;
    if (s == null) return right(const <String, dynamic>{});
    return right(<String, dynamic>{
      "info": <String, dynamic>{"plot": s.plot, "cover": s.cover},
      "episodes": <String, dynamic>{
        "1": <Map<String, dynamic>>[
          for (final (int i, _DemoEpisode e) in s.episodes.indexed)
            <String, dynamic>{
              "id": e.id,
              "title": e.title,
              "episode_num": i + 1,
              "season": 1,
              "container_extension": "mp4",
              "info": <String, dynamic>{"plot": e.plot, "duration": e.duration},
            },
        ],
      },
    });
  }

  @override
  Future<Either<Failures, String>> fetchEpg() async => right("");

  @override
  String buildLiveUrl(String streamId, {bool hls = false}) => _resolve(streamId);

  @override
  String buildMovieUrl(String streamId, String containerExtension) =>
      _resolve(streamId);

  @override
  String buildSeriesUrl(String episodeId, String containerExtension) =>
      _resolve(episodeId);
}

// --- Catalog data --------------------------------------------------------

const String _kCatLive = "demo-live";
const String _kCatFilms = "demo-films";
const String _kCatSeries = "demo-series";

// Official, legally-public HLS test/sample streams (verified reachable).
const String _sBunny = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8";
const String _sTos =
    "https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8";
const String _sSintel = "https://test-streams.mux.dev/pts_shift/master.m3u8";
const String _sElephants =
    "https://test-streams.mux.dev/dai-discontinuity-deltatre/manifest.m3u8";
const String _sSkate =
    "https://sample.vodobox.net/skate_phantom_flex_4k/skate_phantom_flex_4k.m3u8";
const String _sBipbop =
    "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8";
const String _sLiveA =
    "https://cph-p2p-msl.akamaized.net/hls/live/2000341/test/master.m3u8";
const String _sLiveB =
    "https://moctobpltc-i.akamaihd.net/hls/live/571329/eight/playlist.m3u8";

String _poster(String seed) => "https://picsum.photos/seed/$seed/400/600";

const String _bunnyPoster =
    "https://upload.wikimedia.org/wikipedia/commons/c/c5/Big_buck_bunny_poster_big.jpg";

class _DemoLive {
  const _DemoLive(this.id, this.name, this.logo, this.url);
  final String id;
  final String name;
  final String logo;
  final String url;
}

class _DemoMovie {
  const _DemoMovie({
    required this.id,
    required this.name,
    required this.poster,
    required this.year,
    required this.rating,
    required this.duration,
    required this.genre,
    required this.plot,
    required this.url,
  });
  final String id;
  final String name;
  final String poster;
  final String year;
  final String rating;
  final String duration;
  final String genre;
  final String plot;
  final String url;
}

class _DemoEpisode {
  const _DemoEpisode(this.id, this.title, this.plot, this.duration, this.url);
  final String id;
  final String title;
  final String plot;
  final String duration;
  final String url;
}

class _DemoSeries {
  const _DemoSeries({
    required this.id,
    required this.name,
    required this.cover,
    required this.plot,
    required this.year,
    required this.rating,
    required this.episodes,
  });
  final String id;
  final String name;
  final String cover;
  final String plot;
  final String year;
  final String rating;
  final List<_DemoEpisode> episodes;
}

final List<_DemoLive> _kLive = <_DemoLive>[
  _DemoLive("demo-live-1", "LimeBeam News 24", _poster("lbnews"), _sLiveA),
  _DemoLive("demo-live-2", "LimeBeam Sport", _poster("lbsport"), _sLiveB),
  _DemoLive("demo-live-3", "Demo HD", _poster("demohd"), _sBipbop),
  _DemoLive("demo-live-4", "4K Showcase", _poster("showcase4k"), _sSkate),
];

final List<_DemoMovie> _kMovies = <_DemoMovie>[
  _DemoMovie(
    id: "demo-movie-bunny",
    name: "Big Buck Bunny",
    poster: _bunnyPoster,
    year: "2008",
    rating: "8.1",
    duration: "10",
    genre: "Animation",
    plot: "Un lapin géant et placide se venge avec malice de trois rongeurs "
        "qui ont gâché sa journée. Court-métrage libre du projet Blender.",
    url: _sBunny,
  ),
  _DemoMovie(
    id: "demo-movie-tos",
    name: "Tears of Steel",
    poster: _poster("tearsofsteel"),
    year: "2012",
    rating: "7.9",
    duration: "12",
    genre: "Science-fiction",
    plot: "Dans un Amsterdam futuriste, une équipe tente de sauver le monde "
        "des robots. Film libre de droits (Blender Foundation).",
    url: _sTos,
  ),
  _DemoMovie(
    id: "demo-movie-sintel",
    name: "Sintel",
    poster: _poster("sintel"),
    year: "2010",
    rating: "8.2",
    duration: "15",
    genre: "Aventure",
    plot: "Une jeune femme part à la recherche d'un dragon qu'elle a recueilli "
        "enfant. Court-métrage d'animation libre.",
    url: _sSintel,
  ),
  _DemoMovie(
    id: "demo-movie-elephants",
    name: "Elephant's Dream",
    poster: _poster("elephantsdream"),
    year: "2006",
    rating: "7.4",
    duration: "11",
    genre: "Animation",
    plot: "Deux personnages explorent une machine étrange et sans fin. "
        "Le tout premier film ouvert de la Blender Foundation.",
    url: _sElephants,
  ),
  _DemoMovie(
    id: "demo-movie-skate",
    name: "Skate Phantom Flex 4K",
    poster: _poster("skate4k"),
    year: "2014",
    rating: "7.0",
    duration: "5",
    genre: "Démo 4K",
    plot: "Démonstration de ralenti 4K filmée à très haute cadence. "
        "Idéal pour tester la qualité d'image.",
    url: _sSkate,
  ),
  _DemoMovie(
    id: "demo-movie-cosmos",
    name: "Cosmos Drift",
    poster: _poster("cosmosdrift"),
    year: "2023",
    rating: "6.8",
    duration: "9",
    genre: "Démo",
    plot: "Séquence de démonstration adaptative (HLS multi-débit) pour "
        "illustrer le lecteur LimeBeam.",
    url: _sBipbop,
  ),
  _DemoMovie(
    id: "demo-movie-neon",
    name: "Neon Nights",
    poster: _poster("neonnights"),
    year: "2022",
    rating: "7.2",
    duration: "10",
    genre: "Démo",
    plot: "Contenu de démonstration pour explorer les fiches détaillées et la "
        "reprise de lecture.",
    url: _sBunny,
  ),
  _DemoMovie(
    id: "demo-movie-horizon",
    name: "Open Horizon",
    poster: _poster("openhorizon"),
    year: "2021",
    rating: "7.6",
    duration: "12",
    genre: "Démo",
    plot: "Échantillon vidéo libre pour la démonstration du catalogue.",
    url: _sTos,
  ),
];

final List<_DemoSeries> _kSeries = <_DemoSeries>[
  _DemoSeries(
    id: "demo-series-originals",
    name: "LimeBeam Originals",
    cover: _poster("lboriginals"),
    plot: "Une série de démonstration pour explorer saisons, épisodes et "
        "reprise de lecture.",
    year: "2024",
    rating: "8.0",
    episodes: <_DemoEpisode>[
      _DemoEpisode("demo-ep-o1", "Pilote", "Le tout premier épisode.", "10",
          _sBunny),
      _DemoEpisode("demo-ep-o2", "La découverte", "L'aventure continue.", "12",
          _sTos),
      _DemoEpisode("demo-ep-o3", "Le tournant", "Tout bascule.", "11",
          _sSintel),
      _DemoEpisode("demo-ep-o4", "Le final", "Dénouement de la saison.", "13",
          _sElephants),
    ],
  ),
  _DemoSeries(
    id: "demo-series-chronicles",
    name: "Test Chronicles",
    cover: _poster("testchronicles"),
    plot: "Deuxième série de démonstration, idéale pour les captures d'écran.",
    year: "2023",
    rating: "7.5",
    episodes: <_DemoEpisode>[
      _DemoEpisode("demo-ep-c1", "Chapitre 1", "Mise en place.", "9", _sBipbop),
      _DemoEpisode("demo-ep-c2", "Chapitre 2", "Montée en tension.", "10",
          _sSkate),
      _DemoEpisode("demo-ep-c3", "Chapitre 3", "Conclusion.", "11", _sBunny),
    ],
  ),
];

/// Resolves a catalog item id to its playable stream URL.
final Map<String, String> _kPlayUrlById = <String, String>{
  for (final _DemoLive c in _kLive) c.id: c.url,
  for (final _DemoMovie m in _kMovies) m.id: m.url,
  for (final _DemoSeries s in _kSeries)
    for (final _DemoEpisode e in s.episodes) e.id: e.url,
};

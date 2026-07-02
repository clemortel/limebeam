/// iptv_vod — movies (VOD).
///
/// Public surface only. Implementation stays private under `src/`.
library;

export "src/di.dart";
export "src/infrastructure/vod_repository.dart" show IVodRepository;
export "src/models/movie.dart";
export "src/models/movie_info.dart";
export "src/models/vod_category.dart";
export "src/riverpods/providers.dart";
export "src/ui/movie_detail_view.dart";
export "src/ui/vod_grid_view.dart";

/// iptv_series — series / seasons / episodes.
///
/// Public surface only. Implementation stays private under `src/`.
library iptv_series;

export "src/di.dart";
export "src/infrastructure/series_repository.dart" show ISeriesRepository;
export "src/models/episode.dart";
export "src/models/season.dart";
export "src/models/series.dart";
export "src/models/series_category.dart";
export "src/models/series_detail.dart";
export "src/riverpods/providers.dart";
export "src/ui/series_detail_view.dart";
export "src/ui/series_grid_view.dart";

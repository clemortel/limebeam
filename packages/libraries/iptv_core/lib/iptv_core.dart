/// iptv_core — shared foundation for every IPTV package.
///
/// Exposes the public surface only; implementation stays under `src/`.
library iptv_core;

export "src/async_state/async_state.dart";
export "src/cache/cache_store.dart";
export "src/di.dart";
export "src/env/env.dart";
export "src/failures/catch_error.dart";
export "src/failures/failures.dart";
export "src/http/http_service.dart";
export "src/parental/adult_filter.dart";
export "src/progress/playback_preferences.dart";
export "src/progress/watch_progress_sink.dart";
export "src/progress/watch_time_sink.dart";
export "src/source/active_source_store.dart";
export "src/source/source_config.dart";
export "src/utils/run_parse.dart";

/// iptv_player — playback.
///
/// [PlayerView] is a self-contained media_kit surface with a fully custom
/// overlay; the engine stays hidden behind this boundary. Build a
/// [PlaybackQueue] of [PlaybackRequest]s and pass it in. Call
/// [ensurePlayerInitialized] once at startup.
library iptv_player;

export "src/domain/media_track.dart";
export "src/domain/playback_queue.dart";
export "src/domain/playback_request.dart";
export "src/domain/subtitle_style.dart";
export "src/player_init.dart";
export "src/riverpods/player_controller.dart";
export "src/riverpods/player_ui_state.dart";
export "src/ui/player_view.dart";

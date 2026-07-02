import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";

import "../domain/media_track.dart";

part "player_ui_state.freezed.dart";

/// Immutable UI snapshot the player overlay renders from. Owned and mutated by
/// [PlaybackController] — never by the widget.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class PlayerUiState with _$PlayerUiState {
  const factory PlayerUiState({
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(Duration.zero) Duration buffer,
    @Default(false) bool playing,
    @Default(true) bool buffering,
    @Default(true) bool overlayVisible,
    @Default(false) bool isLive,
    @Default(0) int queueIndex,
    @Default(false) bool active,
    @Default(true) bool expanded,
    @Default(0) int countdownSeconds,
    Failures? error,
    // Non-null while playback is handed off to a TV (Chromecast / AirPlay);
    // the overlay then acts as a remote and `position`/`duration` track the
    // remote clock. Null = local playback.
    CastDevice? castDevice,
    // Audio + subtitle tracks for the current item and the active selection.
    @Default(PlayerTracks()) PlayerTracks tracks,
    // Sync offsets in milliseconds (positive = the track plays later).
    @Default(0) int subtitleDelayMs,
    @Default(0) int audioDelayMs,
    // Whether the active engine supports sync offsets (media_kit yes, AVPlayer
    // no) — the overlay hides those controls when false.
    @Default(false) bool supportsSyncOffsets,
    // Non-null for _kSeekFlashMs after a double-tap seek so the widget can
    // display the flash pill without owning any timer state.
    String? seekFlash,
  }) = _PlayerUiState;
}

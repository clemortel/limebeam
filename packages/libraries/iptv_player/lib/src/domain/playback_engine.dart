import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/widgets.dart";

import "media_track.dart";
import "subtitle_style.dart";

/// Snapshot of the tracks available for the current item, by kind.
typedef AvailableTracks = ({
  IList<MediaTrack> audio,
  IList<MediaTrack> subtitle,
});

/// The ids of the currently-selected audio / subtitle tracks (null = none).
typedef SelectedTrackIds = ({String? audioId, String? subtitleId});

/// The local playback engine behind [PlaybackController]. Two implementations:
/// `MediaKitEngine` (libmpv — Android/desktop) and `AvPlayerEngine` (native
/// iOS AVPlayer, so AirPlay streams video). Engine types never cross this
/// boundary; the notifier owns all timers/state and only consumes these
/// streams + the [buildView] surface.
///
/// All streams are broadcast (the notifier listens, and `open`'s resume-seek
/// also awaits [duration]).
abstract interface class PlaybackEngine {
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Duration> get buffer;
  Stream<bool> get playing;
  Stream<bool> get buffering;

  /// Fires `true` when the current item plays to its end.
  Stream<bool> get completed;

  /// Fires a message string when playback fails.
  Stream<String> get error;

  /// The audio + subtitle tracks for the current item. Re-emits when the
  /// stream's track list changes (e.g. shortly after [open]). Broadcast.
  Stream<AvailableTracks> get tracks;

  /// The currently-selected track ids. Re-emits on engine-side or user-driven
  /// selection changes. Broadcast.
  Stream<SelectedTrackIds> get selectedTracks;

  /// Current subtitle text to display, or empty string for none. Only engines
  /// that do NOT render subtitles onto the video surface themselves emit here
  /// (ExoPlayer, whose SurfaceView shows raw video); libmpv/AVPlayer burn
  /// subtitles into their surface and emit an empty stream. Broadcast.
  Stream<String> get subtitleCues;

  /// Current volume as a 0..100 percentage (matches media_kit's scale).
  double get volume;

  /// Whether this engine supports audio/subtitle sync offsets. media_kit does;
  /// native AVPlayer does not, so the UI hides those controls there.
  bool get supportsSyncOffsets;

  /// Opens [url] and begins playback. Does not seek — the notifier handles
  /// resume-position by awaiting [duration] then calling [seek].
  Future<void> open(String url);

  Future<void> play();
  Future<void> pause();
  Future<void> playOrPause();
  Future<void> seek(Duration position);

  /// Sets volume as a 0..100 percentage.
  Future<void> setVolume(double volume);

  /// Selects an audio track by [id], or the [MediaTrack.autoId] /
  /// [MediaTrack.noneId] sentinels for the engine default / disabled.
  Future<void> setAudioTrack(String id);

  /// Selects a subtitle track by [id], or [MediaTrack.noneId] to hide
  /// subtitles.
  Future<void> setSubtitleTrack(String id);

  /// Shifts subtitle timing by [milliseconds] (positive = later). No-op on
  /// engines where [supportsSyncOffsets] is false.
  Future<void> setSubtitleDelay(int milliseconds);

  /// Shifts audio timing by [milliseconds] (positive = later). No-op on
  /// engines where [supportsSyncOffsets] is false.
  Future<void> setAudioDelay(int milliseconds);

  /// Applies subtitle appearance to the engine's renderer.
  Future<void> applySubtitleStyle(SubtitleStyle style);

  /// The video surface widget for this engine (media_kit `Video` or the iOS
  /// AVPlayer platform view).
  Widget buildView();

  Future<void> dispose();
}

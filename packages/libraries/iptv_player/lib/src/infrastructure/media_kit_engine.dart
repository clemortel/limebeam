import "dart:async";

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:media_kit/media_kit.dart";
import "package:media_kit_video/media_kit_video.dart";

import "../domain/media_track.dart";
import "../domain/playback_engine.dart";
import "../domain/subtitle_style.dart";
import "../player_init.dart";

/// Milliseconds-per-second, used to convert sync offsets to mpv's float
/// seconds.
const double _kMillisPerSecond = 1000;

/// libmpv-backed [PlaybackEngine]. Default on Android / desktop. Wraps the
/// media_kit [Player] + [VideoController]; the media_kit types stay inside
/// this file.
class MediaKitEngine implements PlaybackEngine {
  MediaKitEngine() {
    // Surface libmpv open/demux/network failures (their real reason, not just
    // the generic "Failed to open <url>"); error level only, debug builds only.
    _player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.error),
    );
    if (kDebugMode) {
      _logSub = _player.stream.log.listen(
        (PlayerLog log) => debugPrint("mpv[${log.level}] ${log.prefix}: ${log.text}"),
      );
    }
    // Emulators can't create a hardware GL context (black video), so fall back
    // to software rendering there; real devices keep acceleration.
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !playerSoftwareRenderingOnly,
      ),
    );
  }

  late final Player _player;
  late final VideoController _videoController;
  StreamSubscription<PlayerLog>? _logSub;

  /// The libmpv-specific player, used to set properties (sub/audio delay,
  /// subtitle styling) that have no high-level media_kit API. Stays internal.
  NativePlayer? get _native => _player.platform is NativePlayer
      ? _player.platform! as NativePlayer
      : null;

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<Duration> get buffer => _player.stream.buffer;

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

  @override
  Stream<bool> get completed => _player.stream.completed;

  @override
  Stream<String> get error => _player.stream.error;

  @override
  Stream<AvailableTracks> get tracks => _player.stream.tracks.map(_mapTracks);

  @override
  Stream<SelectedTrackIds> get selectedTracks =>
      _player.stream.track.map(_mapSelected);

  @override
  double get volume => _player.state.volume;

  @override
  bool get supportsSyncOffsets => true;

  @override
  Future<void> open(String url) => _player.open(Media(url));

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  @override
  Future<void> setAudioTrack(String id) => _player.setAudioTrack(
        switch (id) {
          MediaTrack.noneId => AudioTrack.no(),
          MediaTrack.autoId => AudioTrack.auto(),
          _ => AudioTrack(id, null, null),
        },
      );

  @override
  Future<void> setSubtitleTrack(String id) => _player.setSubtitleTrack(
        switch (id) {
          MediaTrack.noneId => SubtitleTrack.no(),
          MediaTrack.autoId => SubtitleTrack.auto(),
          _ => SubtitleTrack(id, null, null),
        },
      );

  @override
  Future<void> setSubtitleDelay(int milliseconds) async =>
      _native?.setProperty("sub-delay", _seconds(milliseconds));

  @override
  Future<void> setAudioDelay(int milliseconds) async =>
      _native?.setProperty("audio-delay", _seconds(milliseconds));

  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async {
    final NativePlayer? native = _native;
    if (native == null) return;
    await native.setProperty("sub-scale", "${style.fontScale}");
    await native.setProperty("sub-color", _mpvColor(style.textColorArgb));
    await native.setProperty(
      "sub-back-color",
      _mpvColor(_blackWithOpacity(style.backgroundOpacity)),
    );
  }

  @override
  Widget buildView() =>
      Video(controller: _videoController, controls: null, fit: BoxFit.contain);

  @override
  Future<void> dispose() async {
    await _logSub?.cancel();
    await _player.dispose();
  }

  // --- Mapping helpers -----------------------------------------------------

  /// Maps the engine's available tracks into the primitive [AvailableTracks].
  AvailableTracks _mapTracks(Tracks t) {
    return (
      audio: t.audio
          .where(_isReal)
          .map(
            (AudioTrack a) => MediaTrack(
              id: a.id,
              kind: TrackKind.audio,
              title: a.title,
              language: a.language,
              isDefault: a.isDefault ?? false,
            ),
          )
          .toIList(),
      subtitle: t.subtitle
          .where(_isReal)
          .map(
            (SubtitleTrack s) => MediaTrack(
              id: s.id,
              kind: TrackKind.subtitle,
              title: s.title,
              language: s.language,
              isDefault: s.isDefault ?? false,
            ),
          )
          .toIList(),
    );
  }

  /// Maps the engine's currently-selected track to its ids.
  SelectedTrackIds _mapSelected(Track t) =>
      (audioId: t.audio.id, subtitleId: t.subtitle.id);

  /// Drops the synthetic `auto`/`no` entries mpv always reports — those are
  /// surfaced as explicit affordances in the UI instead. Accepts either
  /// media_kit track type (both expose `id`).
  bool _isReal(dynamic track) {
    final String id = track.id as String;
    return id != MediaTrack.autoId && id != MediaTrack.noneId;
  }

  /// mpv expects sync offsets as floating-point seconds.
  String _seconds(int milliseconds) => "${milliseconds / _kMillisPerSecond}";

  /// mpv color literal `#AARRGGBB` from a Dart ARGB int.
  String _mpvColor(int argb) =>
      "#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}";

  /// Opaque black tinted by [opacity] (0..1) for the subtitle background box.
  int _blackWithOpacity(double opacity) {
    final int alpha = (opacity.clamp(0.0, 1.0) * 0xFF).round();
    return (alpha << 24) & 0xFF000000;
  }
}

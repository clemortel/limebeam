import "dart:async";

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";

import "../domain/media_track.dart";
import "../domain/playback_engine.dart";
import "../domain/subtitle_style.dart";

/// Method channel for AVPlayer transport control (Dart → native).
const MethodChannel _kAvControl = MethodChannel("limebeam/avplayer");

/// Event channel streaming AVPlayer state (native → Dart).
const EventChannel _kAvEvents = EventChannel("limebeam/avplayer/events");

/// Platform-view id for the AVPlayerLayer surface. Matches the iOS factory.
const String _kAvViewType = "limebeam/avplayer_view";

/// Default starting volume (percent), kept in sync with media_kit's 0..100.
const double _kDefaultVolume = 100;

/// Native iOS AVPlayer-backed [PlaybackEngine]. Chosen on iOS so AirPlay
/// streams *video* (libmpv cannot AirPlay). State arrives over [_kAvEvents] and
/// is fanned into broadcast streams; control goes out over [_kAvControl].
class AvPlayerEngine implements PlaybackEngine {
  AvPlayerEngine() {
    _eventsSub = _kAvEvents.receiveBroadcastStream().listen(_onEvent);
  }

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _buffer =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<bool> _completed = StreamController<bool>.broadcast();
  final StreamController<String> _error = StreamController<String>.broadcast();
  final StreamController<AvailableTracks> _tracks =
      StreamController<AvailableTracks>.broadcast();
  final StreamController<SelectedTrackIds> _selected =
      StreamController<SelectedTrackIds>.broadcast();

  StreamSubscription<dynamic>? _eventsSub;
  double _volume = _kDefaultVolume;

  void _onEvent(dynamic event) {
    if (event is! Map) return;
    final Map<dynamic, dynamic> map = event;
    switch (map["event"]) {
      case "position":
        _position.add(Duration(milliseconds: (map["value"] as num).round()));
      case "duration":
        _duration.add(Duration(milliseconds: (map["value"] as num).round()));
      case "buffer":
        _buffer.add(Duration(milliseconds: (map["value"] as num).round()));
      case "playing":
        _playing.add(map["value"] == true);
      case "buffering":
        _buffering.add(map["value"] == true);
      case "completed":
        _completed.add(true);
      case "error":
        _error.add((map["message"] as String?) ?? "Playback error");
      case "tracks":
        final AvailableTracks available = (
          audio: _parseTracks(map["audio"], TrackKind.audio),
          subtitle: _parseTracks(map["subtitle"], TrackKind.subtitle),
        );
        _tracks.add(available);
      case "selectedTracks":
        final SelectedTrackIds selected = (
          audioId: map["audioId"] as String?,
          subtitleId: map["subtitleId"] as String?,
        );
        _selected.add(selected);
    }
  }

  /// Maps the native track payload (a list of `{id,title,language,isDefault}`
  /// maps) into [MediaTrack]s.
  IList<MediaTrack> _parseTracks(dynamic raw, TrackKind kind) {
    if (raw is! List) return const IListConst<MediaTrack>(<MediaTrack>[]);
    return raw
        .whereType<Map<dynamic, dynamic>>()
        .map((Map<dynamic, dynamic> m) {
      return MediaTrack(
        id: "${m["id"]}",
        kind: kind,
        title: m["title"] as String?,
        language: m["language"] as String?,
        isDefault: m["isDefault"] == true,
      );
    }).toIList();
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<Duration> get buffer => _buffer.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<bool> get buffering => _buffering.stream;

  @override
  Stream<bool> get completed => _completed.stream;

  @override
  Stream<String> get error => _error.stream;

  @override
  Stream<AvailableTracks> get tracks => _tracks.stream;

  @override
  Stream<SelectedTrackIds> get selectedTracks => _selected.stream;

  @override
  double get volume => _volume;

  // AVPlayer has no first-class per-track sync offset, so the UI hides those
  // controls; the delay setters below are accepted but no-op natively.
  @override
  bool get supportsSyncOffsets => false;

  @override
  Future<void> open(String url) =>
      _kAvControl.invokeMethod<void>("open", <String, dynamic>{"url": url});

  @override
  Future<void> play() => _kAvControl.invokeMethod<void>("play");

  @override
  Future<void> pause() => _kAvControl.invokeMethod<void>("pause");

  @override
  Future<void> playOrPause() => _kAvControl.invokeMethod<void>("playOrPause");

  @override
  Future<void> seek(Duration position) => _kAvControl.invokeMethod<void>(
        "seek",
        <String, dynamic>{"ms": position.inMilliseconds},
      );

  @override
  Future<void> setVolume(double volume) {
    _volume = volume.clamp(0, 100);
    return _kAvControl.invokeMethod<void>(
      "setVolume",
      <String, dynamic>{"volume": _volume / 100},
    );
  }

  @override
  Future<void> setAudioTrack(String id) => _kAvControl
      .invokeMethod<void>("setAudioTrack", <String, dynamic>{"id": id});

  @override
  Future<void> setSubtitleTrack(String id) => _kAvControl
      .invokeMethod<void>("setSubtitleTrack", <String, dynamic>{"id": id});

  // No-op natively (see [supportsSyncOffsets]); forwarded for contract parity.
  @override
  Future<void> setSubtitleDelay(int milliseconds) =>
      _kAvControl.invokeMethod<void>(
        "setSubtitleDelay",
        <String, dynamic>{"ms": milliseconds},
      );

  @override
  Future<void> setAudioDelay(int milliseconds) =>
      _kAvControl.invokeMethod<void>(
        "setAudioDelay",
        <String, dynamic>{"ms": milliseconds},
      );

  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) =>
      _kAvControl.invokeMethod<void>("applySubtitleStyle", <String, dynamic>{
        "fontScale": style.fontScale,
        "textColorArgb": style.textColorArgb,
        "backgroundOpacity": style.backgroundOpacity,
      });

  /// Built once and reused; the RepaintBoundary isolates the platform view so
  /// overlay repaints never invalidate the AVPlayer surface.
  Widget? _view;

  @override
  Widget buildView() => _view ??= const RepaintBoundary(
        child: UiKitView(
          viewType: _kAvViewType,
          creationParamsCodec: StandardMessageCodec(),
        ),
      );

  @override
  Future<void> dispose() async {
    await _eventsSub?.cancel();
    await _kAvControl.invokeMethod<void>("dispose");
    await _position.close();
    await _duration.close();
    await _buffer.close();
    await _playing.close();
    await _buffering.close();
    await _completed.close();
    await _error.close();
    await _tracks.close();
    await _selected.close();
  }
}

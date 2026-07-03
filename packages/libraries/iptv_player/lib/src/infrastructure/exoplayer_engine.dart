import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/gestures.dart";
import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter/widgets.dart";

import "../domain/playback_engine.dart";
import "../domain/subtitle_style.dart";

/// Method channel for ExoPlayer transport control (Dart → native).
const MethodChannel _kControl = MethodChannel("limebeam/exoplayer");

/// Event channel streaming ExoPlayer state (native → Dart).
const EventChannel _kEvents = EventChannel("limebeam/exoplayer/events");

/// Platform-view id for the SurfaceView surface. Matches the Android factory.
const String _kViewType = "limebeam/exoplayer_view";

/// Default starting volume (percent), kept in sync with media_kit's 0..100.
const double _kDefaultVolume = 100;

/// Native Android ExoPlayer (androidx.media3) engine, rendered through a
/// **SurfaceView** platform view. Chosen only for LIVE playback on Android TV:
/// a SurfaceView gets its own SurfaceFlinger composition layer (a hardware
/// overlay), so the app GPU never composites video frames — which is what lets
/// a weak Fire TV Stick present 50/60 fps live without dropping frames (the
/// libmpv texture path cannot, since Flutter composites every frame).
///
/// Mirrors the iOS [AvPlayerEngine]: one shared native player driven over
/// [_kControl], state fanned into broadcast streams from [_kEvents], and the
/// surface bound to the same player by the platform view. Sync offsets and
/// track selection are not implemented in v1 (the UI hides them because
/// [supportsSyncOffsets] is false and the track streams stay empty).
class ExoPlayerEngine implements PlaybackEngine {
  ExoPlayerEngine() {
    _eventsSub = _kEvents.receiveBroadcastStream().listen(_onEvent);
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
  Widget? _view;

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
    }
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

  // v1: no track enumeration/selection (live usually has a single audio track).
  // Empty streams keep the CC button + track rows hidden (the UI gates on
  // `tracks.hasAny`). A follow-up can wire media3 track selection.
  @override
  Stream<AvailableTracks> get tracks => _tracks.stream;

  @override
  Stream<SelectedTrackIds> get selectedTracks => _selected.stream;

  @override
  double get volume => _volume;

  // ExoPlayer has no per-track sync offset; the UI hides those controls.
  @override
  bool get supportsSyncOffsets => false;

  @override
  Future<void> open(String url) =>
      _kControl.invokeMethod<void>("open", <String, dynamic>{"url": url});

  @override
  Future<void> play() => _kControl.invokeMethod<void>("play");

  @override
  Future<void> pause() => _kControl.invokeMethod<void>("pause");

  @override
  Future<void> playOrPause() => _kControl.invokeMethod<void>("playOrPause");

  @override
  Future<void> seek(Duration position) => _kControl.invokeMethod<void>(
        "seek",
        <String, dynamic>{"ms": position.inMilliseconds},
      );

  @override
  Future<void> setVolume(double volume) {
    _volume = volume.clamp(0, 100);
    return _kControl.invokeMethod<void>(
      "setVolume",
      <String, dynamic>{"volume": _volume / 100},
    );
  }

  // No-op for v1 (see [tracks]); forwarded for contract parity.
  @override
  Future<void> setAudioTrack(String id) => _kControl
      .invokeMethod<void>("setAudioTrack", <String, dynamic>{"id": id});

  @override
  Future<void> setSubtitleTrack(String id) => _kControl
      .invokeMethod<void>("setSubtitleTrack", <String, dynamic>{"id": id});

  // No-op natively (see [supportsSyncOffsets]); forwarded for contract parity.
  @override
  Future<void> setSubtitleDelay(int milliseconds) => _kControl.invokeMethod<void>(
        "setSubtitleDelay",
        <String, dynamic>{"ms": milliseconds},
      );

  @override
  Future<void> setAudioDelay(int milliseconds) => _kControl.invokeMethod<void>(
        "setAudioDelay",
        <String, dynamic>{"ms": milliseconds},
      );

  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) =>
      _kControl.invokeMethod<void>("applySubtitleStyle", <String, dynamic>{
        "fontScale": style.fontScale,
        "textColorArgb": style.textColorArgb,
        "backgroundOpacity": style.backgroundOpacity,
      });

  /// Built once and reused. Uses **hybrid composition**
  /// ([PlatformViewsService.initExpensiveAndroidView]) so the SurfaceView is a
  /// real view in the hierarchy composited by SurfaceFlinger — the whole point
  /// of this engine. (Virtual-display / texture-layer modes would route video
  /// back through the Flutter texture we are trying to avoid.) The RepaintBoundary
  /// isolates it; Flutter controls draw in an overlay above it.
  @override
  Widget buildView() => _view ??= RepaintBoundary(
        child: PlatformViewLink(
          viewType: _kViewType,
          surfaceFactory: (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              hitTestBehavior: PlatformViewHitTestBehavior.transparent,
              gestureRecognizers:
                  const <Factory<OneSequenceGestureRecognizer>>{},
            );
          },
          onCreatePlatformView: (PlatformViewCreationParams params) {
            return PlatformViewsService.initExpensiveAndroidView(
              id: params.id,
              viewType: _kViewType,
              layoutDirection: TextDirection.ltr,
              creationParams: const <String, dynamic>{},
              creationParamsCodec: const StandardMessageCodec(),
              onFocus: () => params.onFocusChanged(true),
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create();
          },
        ),
      );

  @override
  Future<void> dispose() async {
    await _eventsSub?.cancel();
    await _kControl.invokeMethod<void>("dispose");
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

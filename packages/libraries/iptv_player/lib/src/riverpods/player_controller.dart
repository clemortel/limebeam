import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:get_it/get_it.dart";
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../domain/media_track.dart";
import "../domain/playback_engine.dart";
import "../domain/playback_queue.dart";
import "../domain/playback_request.dart";
import "../domain/subtitle_style.dart";
import "../infrastructure/airplay_monitor.dart";
import "../infrastructure/av_player_engine.dart";
import "../infrastructure/exoplayer_engine.dart";
import "../infrastructure/media_kit_engine.dart";
import "../pip/media_session_service.dart";
import "../player_init.dart";
import "player_ui_state.dart";

part "player_controller.g.dart";

/// Overlay auto-hide delay once playback is running.
const Duration _kOverlayAutoHide = Duration(seconds: 4);

/// Double-tap seek step (VOD / series only — live is non-DVR).
const Duration _kPlayerSeekStep = Duration(seconds: 10);

/// Minimum gap between throttled resume-point saves during playback.
const int _kSaveIntervalSeconds = 5;

/// Minimum accrued watch time before flushing it to the watch-time sink.
const int _kWatchFlushSeconds = 30;

/// Netflix-style "next episode" auto-play countdown length.
const int _kAutoplayCountdownSeconds = 5;

/// Tick interval for the next-episode countdown.
const Duration _kCountdownTick = Duration(seconds: 1);

/// How long to wait for the stream duration before giving up on resume-seek.
const Duration _kResumeSeekTimeout = Duration(seconds: 6);

/// Poll interval for the remote (Chromecast) playhead while casting.
const Duration _kCastPollInterval = Duration(seconds: 1);

/// Duration of the seek-flash pill shown after double-tap seek.
const int _kSeekFlashMs = 700;

/// Maximum subtitle / audio sync offset the UI allows, in milliseconds (±10s).
const int _kMaxSyncOffsetMs = 10000;

/// Minimum gap between position/buffer → state emits during playback. libmpv
/// emits far more often than the seek bar needs; coalescing to ~4 Hz removes
/// the per-tick full-state notification that rebuilt the whole player and
/// janked Fire TV (build spikes → dropped video frames). A large jump
/// (open/seek) always emits so the bar snaps immediately.
const Duration _kPositionEmitInterval = Duration(milliseconds: 250);

/// App-scoped playback engine (keepAlive): playback **survives** popping the
/// full-screen player, which is what powers the docked mini-player. Call
/// [start] to (re)play a queue; [stop] tears the engine down. The concrete
/// [PlaybackEngine] (media_kit on Android, native AVPlayer on iOS) stays behind
/// its boundary; all logic/timers live here, not in widgets.
@Riverpod(keepAlive: true)
class PlaybackController extends _$PlaybackController {
  PlaybackEngine? _engine;
  PlaybackQueue? _queue;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  Timer? _hideTimer;
  Timer? _countdownTimer;
  Timer? _flashTimer;
  bool _disposed = false;
  int _lastSavedSeconds = 0;

  /// Last position/buffer actually pushed to [state]; the throttle compares
  /// against these to decide whether to emit (see [_kPositionEmitInterval]).
  Duration _lastEmittedPosition = Duration.zero;
  Duration _lastEmittedBuffer = Duration.zero;

  /// Optional continue-watching sink (registered by iptv_favorites).
  final WatchProgressSink? _progressSink =
      GetIt.instance.isRegistered<WatchProgressSink>()
          ? GetIt.instance<WatchProgressSink>()
          : null;

  /// Optional total-watch-time sink (registered by iptv_settings) — feeds the
  /// rare Tip Jar prompt heuristic only.
  final WatchTimeSink? _watchSink =
      GetIt.instance.isRegistered<WatchTimeSink>()
          ? GetIt.instance<WatchTimeSink>()
          : null;

  /// Accrues real playback time while [_set] reports `playing == true`.
  final Stopwatch _watchClock = Stopwatch();

  /// Optional cast repository (registered by iptv_cast). Null if casting is
  /// unavailable — every cast action then no-ops and the UI hides the button.
  final ICastRepository? _castRepo =
      GetIt.instance.isRegistered<ICastRepository>()
          ? GetIt.instance<ICastRepository>()
          : null;

  /// Optional playback preferences (registered by iptv_settings) — drives
  /// track auto-selection and subtitle styling. Null = no preferences seam.
  final PlaybackPreferences? _prefs =
      GetIt.instance.isRegistered<PlaybackPreferences>()
          ? GetIt.instance<PlaybackPreferences>()
          : null;

  /// True between opening an item and applying the preferred-language
  /// auto-selection once its track list first arrives.
  bool _autoSelectPending = false;

  /// Watches the iOS output route so playback can swap to the AVPlayer engine
  /// while AirPlay is active and back to libmpv otherwise. Null off iOS.
  StreamSubscription<bool>? _routeSub;

  /// True while the active local engine is the AVPlayer (iOS AirPlay handoff).
  bool _externalPlayback = false;

  /// Polls the remote playhead while casting; null when playing locally.
  Timer? _castPollTimer;

  /// Watches for the remote session ending externally (e.g. from the TV).
  StreamSubscription<bool>? _castConnSub;

  /// True while playback is handed off to a TV (Chromecast / AirPlay).
  bool get isCasting => state.castDevice != null;

  /// Whether casting is supported on this build (repository registered).
  bool get canCast => _castRepo != null;

  static const MediaSessionService _mediaSession = MediaSessionService();

  @override
  PlayerUiState build() {
    ref.onDispose(_release);
    // Forward native media-button intents (voice, HDMI-CEC, lock screen) to
    // the playback engine. The handler is idempotent — safe to re-register on
    // hot-restart because the MethodChannel replaces the previous handler.
    _mediaSession.setCommandHandler((bool play) {
      final bool alreadyInState = play == state.playing;
      if (!alreadyInState) playOrPause();
    });
    return const PlayerUiState();
  }

  /// The engine's video surface, or null when nothing is playing. iOS renders
  /// the native AVPlayer view; elsewhere the media_kit `Video`.
  Widget? buildVideoView() => _engine?.buildView();

  /// Whether an engine exists (playback is active).
  bool get hasVideo => _engine != null;

  /// The active queue, or null when nothing is playing.
  PlaybackQueue? get queue => _queue;

  /// The currently-playing item, or null when nothing is playing.
  PlaybackRequest? get currentRequest {
    final PlaybackQueue? q = _queue;
    if (q == null) return null;
    return q.items[state.queueIndex];
  }

  /// Whether LIVE playback should use the native SurfaceView ExoPlayer engine:
  /// Android TV only. Its hardware-overlay surface avoids the video-frame drops
  /// the libmpv texture path suffers with high-fps live on weak TV GPUs. Phones
  /// and all VOD keep media_kit.
  bool _wantsNativeLive(bool isLive) =>
      defaultTargetPlatform == TargetPlatform.android &&
      playerIsTelevision &&
      isLive;

  /// Builds the local engine for the given content. Default everywhere is
  /// libmpv (media_kit), which decodes the MPEG-TS / MKV that Xtream serves.
  /// Live on Android TV uses ExoPlayer (SurfaceView). On iOS we switch to the
  /// native AVPlayer only while [_externalPlayback] (AirPlay) is active, since
  /// libmpv renders to a texture and cannot AirPlay video.
  PlaybackEngine _createEngine(bool isLive) {
    if (_wantsNativeLive(isLive)) {
      return ExoPlayerEngine();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS && _externalPlayback) {
      return AvPlayerEngine();
    }
    return MediaKitEngine();
  }

  /// Cancels the current engine's stream subscriptions and disposes it so a
  /// different engine can take over (e.g. VOD↔live transition on TV). Cancelling
  /// a subscription stops delivery immediately, so the old engine's late events
  /// never reach the newly-installed one; dispose runs in the background.
  void _replaceEngineSubscriptions() {
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    final PlaybackEngine? old = _engine;
    _engine = null;
    unawaited(old?.dispose());
  }

  /// Begins (or replaces) playback with [queue].
  void start(PlaybackQueue queue) {
    _countdownTimer?.cancel();
    final bool isLive = queue.current.isLive;
    // Reuse the existing engine only if it is still the right kind for this
    // content (live→ExoPlayer vs everything-else→media_kit on TV). Otherwise
    // tear it down and build the correct one — handles VOD↔live without stop().
    final bool engineMatches =
        _engine != null && (_engine is ExoPlayerEngine) == _wantsNativeLive(isLive);
    if (!engineMatches) {
      _replaceEngineSubscriptions();
      final PlaybackEngine engine = _createEngine(isLive);
      _engine = engine;
      _listen(engine);
    }
    _watchOutputRoute();
    _queue = queue;
    _lastSavedSeconds = 0;
    _set(
      PlayerUiState(
        active: true,
        overlayVisible: true,
        isLive: queue.current.isLive,
        queueIndex: queue.index,
        supportsSyncOffsets: _engine?.supportsSyncOffsets ?? false,
      ),
    );
    unawaited(_openIndex(queue.index, queue.current.startAt));
    _restartHideTimer();
  }

  /// Subscribes once to the iOS output-route stream; swaps engines as AirPlay
  /// comes and goes. No-op off iOS (the stream is empty there).
  void _watchOutputRoute() {
    if (_routeSub != null) return;
    _routeSub = const AirPlayMonitor().airPlayActive.listen(_onAirPlayChanged);
  }

  /// Swaps to the AVPlayer engine when AirPlay turns on and back to libmpv when
  /// it turns off, preserving the current position. Ignored while Chromecast
  /// owns playback (that path manages its own handoff).
  Future<void> _onAirPlayChanged(bool active) async {
    if (_disposed || isCasting || active == _externalPlayback) return;
    _externalPlayback = active;
    if (_engine == null) return;
    await _swapEngine();
  }

  /// Tears down the current engine and rebuilds it via [_createEngine] at the
  /// current position, re-subscribing its streams. Used for the AirPlay handoff.
  Future<void> _swapEngine() async {
    final PlaybackQueue? q = _queue;
    if (q == null) return;
    final Duration resumeAt = state.isLive ? Duration.zero : state.position;
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _engine?.dispose();
    if (_disposed) return;
    final PlaybackEngine engine = _createEngine(state.isLive);
    _engine = engine;
    _listen(engine);
    _set(
      state.copyWith(
        buffering: true,
        supportsSyncOffsets: engine.supportsSyncOffsets,
      ),
    );
    await _openIndex(state.queueIndex, resumeAt);
  }

  /// Stops playback and releases the engine (mini-player close).
  Future<void> stop() async {
    _accrueWatchTime(resume: false);
    _maybeSaveProgress(force: true);
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    _castPollTimer?.cancel();
    _castPollTimer = null;
    await _castConnSub?.cancel();
    _castConnSub = null;
    await _routeSub?.cancel();
    _routeSub = null;
    _externalPlayback = false;
    if (isCasting) await _castRepo?.endSession();
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _engine?.dispose();
    _engine = null;
    _queue = null;
    _set(const PlayerUiState());
  }

  void _listen(PlaybackEngine engine) {
    // While casting, the local engine is paused and the remote owns playback
    // state; ignore its (stale) stream events so they don't clobber the UI.
    _subscriptions.add(
      engine.position.listen((Duration p) {
        if (isCasting) return;
        // Coalesce to ~4 Hz; a jump (open/seek) exceeds the interval and emits.
        final int deltaMs = (p - _lastEmittedPosition).inMilliseconds.abs();
        if (deltaMs >= _kPositionEmitInterval.inMilliseconds) {
          _lastEmittedPosition = p;
          _set(state.copyWith(position: p));
        }
        // Save/watch-time run every raw tick (cheap, second-granularity) so the
        // throttle never delays a resume-point write.
        _maybeSaveProgress();
        if (_watchClock.elapsed.inSeconds >= _kWatchFlushSeconds) {
          _accrueWatchTime(resume: true);
        }
      }),
    );
    _subscriptions.add(
      engine.duration.listen((Duration d) {
        if (isCasting) return;
        _set(state.copyWith(duration: d));
      }),
    );
    _subscriptions.add(
      engine.playing.listen((bool p) {
        if (isCasting) return;
        _set(state.copyWith(playing: p, error: p ? null : state.error));
        // Keep the native MediaSession in sync so the OS knows whether the
        // pause was intentional (prevents Fire TV auto-resume after ~3 s).
        unawaited(_mediaSession.setPlaying(playing: p));
        if (p) {
          _watchClock.start();
        } else {
          _accrueWatchTime(resume: false);
          _maybeSaveProgress(force: true);
        }
      }),
    );
    _subscriptions.add(
      engine.buffering.listen((bool b) {
        if (isCasting) return;
        _set(state.copyWith(buffering: b));
      }),
    );
    _subscriptions.add(
      engine.buffer.listen((Duration b) {
        if (isCasting) return;
        // Buffer ticks as often as position; coalesce it the same way.
        final int deltaMs = (b - _lastEmittedBuffer).inMilliseconds.abs();
        if (deltaMs >= _kPositionEmitInterval.inMilliseconds) {
          _lastEmittedBuffer = b;
          _set(state.copyWith(buffer: b));
        }
      }),
    );
    _subscriptions.add(
      engine.error.listen((String message) {
        if (isCasting) return;
        // Surface the engine's real reason in debug builds; the UI keeps the
        // generic failure. Helps diagnose codec/container issues (e.g. AVPlayer
        // rejecting MPEG-TS / MKV) that otherwise leave no trace.
        debugPrint("PlaybackEngine error: $message");
        // Audio-init failures (no output device — common on the iOS Simulator)
        // are NOT fatal: video keeps playing, so never show the error overlay.
        final String reason = message.toLowerCase();
        if (reason.contains("audio device") || reason.contains("no sound")) {
          return;
        }
        // If the AVPlayer (AirPlay) engine fails — e.g. the HLS variant is
        // rejected — fall back to libmpv so local playback continues instead of
        // a hard error. AirPlay then degrades to audio-only rather than failing.
        if (_externalPlayback) {
          _externalPlayback = false;
          unawaited(_swapEngine());
          return;
        }
        _set(
          state.copyWith(
            error: const Failures.streamUnavailable(),
            buffering: false,
          ),
        );
      }),
    );
    _subscriptions.add(
      engine.completed.listen((bool c) {
        if (isCasting) return;
        _onCompleted(c);
      }),
    );
    _subscriptions.add(
      engine.tracks.listen((AvailableTracks t) {
        if (isCasting) return;
        _set(
          state.copyWith(
            tracks: state.tracks.copyWith(
              audio: t.audio,
              subtitle: t.subtitle,
            ),
          ),
        );
        _maybeAutoSelectTracks();
      }),
    );
    _subscriptions.add(
      engine.selectedTracks.listen((SelectedTrackIds s) {
        if (isCasting) return;
        _set(
          state.copyWith(
            tracks: state.tracks.copyWith(
              selectedAudioId: s.audioId,
              selectedSubtitleId: s.subtitleId,
            ),
          ),
        );
      }),
    );
  }

  /// Applies the user's preferred audio/subtitle languages once the freshly
  /// opened item reports its track list. Runs at most once per open.
  void _maybeAutoSelectTracks() {
    if (!_autoSelectPending) return;
    final PlaybackEngine? engine = _engine;
    final PlayerTracks tracks = state.tracks;
    if (engine == null || !tracks.hasAny) return;
    _autoSelectPending = false;
    final PlaybackPreferences? prefs = _prefs;
    if (prefs == null) return;

    final String? audioLang = prefs.preferredAudioLanguage;
    if (audioLang != null) {
      final MediaTrack? match = matchTrackByLanguage(tracks.audio, audioLang);
      if (match != null) unawaited(engine.setAudioTrack(match.id));
    }

    if (prefs.subtitlesEnabledByDefault) {
      final String? subLang = prefs.preferredSubtitleLanguage;
      final MediaTrack? match = subLang == null
          ? null
          : matchTrackByLanguage(tracks.subtitle, subLang);
      if (match != null) unawaited(engine.setSubtitleTrack(match.id));
    } else {
      // Honor "subtitles off by default" explicitly.
      unawaited(engine.setSubtitleTrack(MediaTrack.noneId));
    }
  }

  /// Pushes the user's saved subtitle appearance to the engine.
  void _applySavedSubtitleStyle() {
    final PlaybackEngine? engine = _engine;
    final PlaybackPreferences? prefs = _prefs;
    if (engine == null || prefs == null) return;
    unawaited(
      engine.applySubtitleStyle(
        SubtitleStyle(
          fontScale: prefs.subtitleFontScale,
          textColorArgb: prefs.subtitleTextColorArgb,
          backgroundOpacity: prefs.subtitleBackgroundOpacity,
        ),
      ),
    );
  }

  Future<void> _openIndex(int index, Duration startAt) async {
    final PlaybackEngine? engine = _engine;
    final PlaybackQueue? q = _queue;
    if (engine == null || q == null) return;
    // New item: re-run preferred-track auto-select and reset any sync offsets.
    _autoSelectPending = true;
    _set(
      state.copyWith(
        error: null,
        buffering: true,
        tracks: const PlayerTracks(),
        subtitleDelayMs: 0,
        audioDelayMs: 0,
      ),
    );
    if (engine.supportsSyncOffsets) {
      unawaited(engine.setSubtitleDelay(0));
      unawaited(engine.setAudioDelay(0));
    }
    // AVPlayer (AirPlay) needs the HLS variant; libmpv uses the default URL.
    final PlaybackRequest item = q.items[index];
    final String url =
        _externalPlayback ? (item.externalUrl ?? item.url) : item.url;
    await engine.open(url);
    _applySavedSubtitleStyle();
    if (startAt > Duration.zero) {
      // `orElse` guards against "Bad state: No element": if the engine fails to
      // open (e.g. AVPlayer rejected by the source), its duration stream closes
      // without emitting, and a bare firstWhere would throw an unhandled async
      // error instead of just skipping the resume-seek.
      final Duration total = await engine.duration
          .firstWhere(
            (Duration d) => d > Duration.zero,
            orElse: () => Duration.zero,
          )
          .timeout(_kResumeSeekTimeout, onTimeout: () => Duration.zero);
      // Bail if disposed or the user switched content during the await.
      if (_disposed || state.queueIndex != index) return;
      if (total > Duration.zero) await engine.seek(startAt);
    }
  }

  void _onCompleted(bool completed) {
    if (_disposed || !completed || _queue == null) return;
    _hideTimer?.cancel();
    _maybeSaveProgress(force: true);
    final bool hasNext = state.queueIndex + 1 < _queue!.items.length;
    if (_queue!.autoplayNext && hasNext) {
      _startCountdown();
      return;
    }
    _set(state.copyWith(overlayVisible: true));
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _set(
      state.copyWith(
        countdownSeconds: _kAutoplayCountdownSeconds,
        overlayVisible: true,
      ),
    );
    _countdownTimer = Timer.periodic(_kCountdownTick, (Timer timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      final int remaining = state.countdownSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        _set(state.copyWith(countdownSeconds: 0));
        playNext();
      } else {
        _set(state.copyWith(countdownSeconds: remaining));
      }
    });
  }

  /// Dismisses the next-episode countdown (stay on the finished frame).
  void cancelCountdown() {
    _countdownTimer?.cancel();
    _set(state.copyWith(countdownSeconds: 0));
  }

  /// Skips the countdown and plays the next item immediately.
  void playNextNow() {
    _countdownTimer?.cancel();
    _set(state.copyWith(countdownSeconds: 0));
    playNext();
  }

  /// Latest known playhead / duration. May lag the engine by up to
  /// [_kPositionEmitInterval] due to throttling — fine for touch scrub gestures
  /// (the only readers), which start from the current playhead.
  Duration get currentPosition => state.position;
  Duration get currentDuration => state.duration;

  /// Current volume as a 0..1 fraction (for the gesture HUD).
  double get currentVolume01 => (_engine?.volume ?? 100) / 100;

  /// Whether the full-screen player is on screen. When false (and active), the
  /// floating in-app PiP window is shown instead.
  void setExpanded(bool value) => _set(state.copyWith(expanded: value));

  /// Flushes accrued real playback time to the watch-time sink. [resume] keeps
  /// the clock running afterwards (periodic flush) vs. stopping it (pause/stop).
  void _accrueWatchTime({required bool resume}) {
    _watchClock.stop();
    final int seconds = _watchClock.elapsed.inSeconds;
    if (seconds > 0) {
      unawaited(_watchSink?.addWatchSeconds(seconds));
    }
    _watchClock.reset();
    if (resume) _watchClock.start();
  }

  void _maybeSaveProgress({bool force = false}) {
    final WatchProgressSink? sink = _progressSink;
    final PlaybackQueue? q = _queue;
    if (sink == null || q == null) return;
    final PlaybackRequest request = q.items[state.queueIndex];
    if (request.isLive) return;
    final int position = state.position.inSeconds;
    final int duration = state.duration.inSeconds;
    if (duration <= 0) return;
    if (!force && (position - _lastSavedSeconds).abs() < _kSaveIntervalSeconds) {
      return;
    }
    _lastSavedSeconds = position;
    unawaited(
      sink.saveProgress(
        id: request.contentId,
        kind: request.kind.name,
        containerExtension: request.containerExtension,
        title: request.title,
        positionSeconds: position,
        durationSeconds: duration,
        subtitle: request.subtitle,
        posterUrl: request.posterUrl,
      ),
    );
  }

  void _set(PlayerUiState next) {
    if (_disposed) return;
    state = next;
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_kOverlayAutoHide, () {
      if (_disposed) return;
      if (state.playing) _set(state.copyWith(overlayVisible: false));
    });
  }

  // --- Public actions (called from the overlay / mini-player) -------------

  void toggleOverlay() {
    final bool show = !state.overlayVisible;
    _set(state.copyWith(overlayVisible: show));
    if (show) _restartHideTimer();
  }

  void revealOverlay() {
    _set(state.copyWith(overlayVisible: true));
    _restartHideTimer();
  }

  /// Keeps the visible overlay alive after a D-pad interaction — restarts the
  /// auto-hide timer without churning state (so navigating the controls on TV
  /// doesn't let them vanish mid-interaction). No-op when already hidden.
  void pokeOverlay() {
    if (state.overlayVisible) _restartHideTimer();
  }

  /// Hides the controls immediately (first Back press on TV).
  void hideOverlay() {
    _hideTimer?.cancel();
    if (state.overlayVisible) _set(state.copyWith(overlayVisible: false));
  }

  void playOrPause() {
    if (isCasting) {
      final bool willPlay = !state.playing;
      unawaited(willPlay ? _castRepo?.play() : _castRepo?.pause());
      _set(state.copyWith(playing: willPlay));
      revealOverlay();
      return;
    }
    unawaited(_engine?.playOrPause());
    revealOverlay();
  }

  void seekForward() {
    _seekBy(_kPlayerSeekStep);
    _showSeekFlash("+ 10s");
  }

  void seekBackward() {
    _seekBy(-_kPlayerSeekStep);
    _showSeekFlash("− 10s");
  }

  void seekTo(Duration target) => _seekTo(target);

  void _seekBy(Duration delta) {
    if (state.isLive) return;
    _seekTo(state.position + delta);
  }

  void _showSeekFlash(String label) {
    _flashTimer?.cancel();
    _set(state.copyWith(seekFlash: label));
    _flashTimer = Timer(
      const Duration(milliseconds: _kSeekFlashMs),
      () => _set(state.copyWith(seekFlash: null)),
    );
  }

  void playAt(int index) {
    final PlaybackQueue? q = _queue;
    if (q == null || index < 0 || index >= q.items.length) return;
    _countdownTimer?.cancel();
    _maybeSaveProgress(force: true);
    final PlaybackRequest request = q.items[index];
    _lastSavedSeconds = 0;
    final CastDevice? device = state.castDevice;
    _set(
      state.copyWith(
        queueIndex: index,
        isLive: request.isLive,
        countdownSeconds: 0,
      ),
    );
    if (device != null) {
      // Casting: load the new item onto the receiver (session is reused).
      unawaited(_castLoad(device, request, request.startAt));
    } else {
      unawaited(_openIndex(index, request.startAt));
    }
    revealOverlay();
  }

  void playNext() {
    final PlaybackQueue? q = _queue;
    if (q != null && state.queueIndex + 1 < q.items.length) {
      playAt(state.queueIndex + 1);
    }
  }

  void playPrevious() {
    if (state.queueIndex - 1 >= 0) playAt(state.queueIndex - 1);
  }

  Future<void> setVolume(double volume) async =>
      _engine?.setVolume(volume);

  void nudgeVolume(double deltaFraction) {
    final PlaybackEngine? engine = _engine;
    if (engine == null) return;
    final double next = (engine.volume + deltaFraction * 100).clamp(0, 100);
    unawaited(engine.setVolume(next));
  }

  /// Re-opens the current item after a stream error.
  void retry() {
    final PlaybackQueue? q = _queue;
    if (q == null) return;
    unawaited(_openIndex(state.queueIndex, q.items[state.queueIndex].startAt));
    revealOverlay();
  }

  // --- Track selection & sync (called from the overlay) -------------------

  /// Selects an audio track by [id] ([MediaTrack.autoId] for engine default).
  /// The resulting selection flows back via the engine's selectedTracks stream.
  void selectAudioTrack(String id) {
    unawaited(_engine?.setAudioTrack(id));
    revealOverlay();
  }

  /// Selects a subtitle track by [id], or [MediaTrack.noneId] to hide them.
  void selectSubtitleTrack(String id) {
    unawaited(_engine?.setSubtitleTrack(id));
    revealOverlay();
  }

  void setSubtitleDelay(int milliseconds) {
    final int clamped = milliseconds.clamp(-_kMaxSyncOffsetMs, _kMaxSyncOffsetMs);
    unawaited(_engine?.setSubtitleDelay(clamped));
    _set(state.copyWith(subtitleDelayMs: clamped));
    revealOverlay();
  }

  void setAudioDelay(int milliseconds) {
    final int clamped = milliseconds.clamp(-_kMaxSyncOffsetMs, _kMaxSyncOffsetMs);
    unawaited(_engine?.setAudioDelay(clamped));
    _set(state.copyWith(audioDelayMs: clamped));
    revealOverlay();
  }

  /// Applies subtitle appearance (already persisted by the settings notifier)
  /// to the running engine.
  void applySubtitleStyle(SubtitleStyle style) {
    unawaited(_engine?.applySubtitleStyle(style));
    revealOverlay();
  }

  void _seekTo(Duration target) {
    Duration clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (state.duration > Duration.zero && clamped > state.duration) {
      clamped = state.duration;
    }
    if (isCasting) {
      unawaited(_castRepo?.seek(clamped));
      _set(state.copyWith(position: clamped));
      revealOverlay();
      return;
    }
    unawaited(_engine?.seek(clamped));
    revealOverlay();
  }

  // --- Casting (Chromecast / AirPlay handoff) -----------------------------

  /// Hands the current item off to [device]: pauses local playback and starts
  /// remote playback at the current position. The overlay then drives the TV.
  Future<void> castTo(CastDevice device) async {
    final PlaybackRequest? request = currentRequest;
    if (_castRepo == null || request == null) return;
    final Duration startAt = state.isLive ? Duration.zero : state.position;
    await _engine?.pause();
    _accrueWatchTime(resume: false);
    await _castLoad(device, request, startAt);
    revealOverlay();
  }

  /// Loads [request] onto [device]. Reused for both the initial handoff and
  /// queue changes while already casting (the SDK session is reused).
  Future<void> _castLoad(
    CastDevice device,
    PlaybackRequest request,
    Duration startAt,
  ) async {
    final ICastRepository? repo = _castRepo;
    if (repo == null) return;
    _set(state.copyWith(buffering: true, error: null));
    final Either<Failures, Unit> result = await repo.connectAndLoad(
      device,
      url: request.url,
      title: request.title,
      subtitle: request.subtitle,
      posterUrl: request.posterUrl,
      contentType: _castContentType(request),
      startAt: startAt,
      isLive: request.isLive,
    );
    if (_disposed) return;
    result.fold(
      (Failures failure) =>
          _set(state.copyWith(error: failure, buffering: false)),
      (_) {
        _set(
          state.copyWith(
            castDevice: device,
            playing: true,
            buffering: false,
            error: null,
          ),
        );
        _startCastPolling(repo);
        _watchCastConnection(repo);
      },
    );
  }

  /// Ends the cast session and resumes local playback at the remote position.
  Future<void> stopCasting() async {
    final ICastRepository? repo = _castRepo;
    if (repo == null || !isCasting) return;
    _castPollTimer?.cancel();
    _castPollTimer = null;
    await _castConnSub?.cancel();
    _castConnSub = null;
    final Duration resumeAt = await repo.endSession();
    if (_disposed) return;
    final bool live = state.isLive;
    _set(state.copyWith(castDevice: null, buffering: true));
    // _openIndex re-opens the local engine and auto-plays; live restarts at 0.
    unawaited(_openIndex(state.queueIndex, live ? Duration.zero : resumeAt));
    revealOverlay();
  }

  /// Mirrors the remote playhead into [state] once per [_kCastPollInterval].
  void _startCastPolling(ICastRepository repo) {
    _castPollTimer?.cancel();
    _castPollTimer = Timer.periodic(_kCastPollInterval, (Timer _) {
      if (_disposed || !isCasting) return;
      _set(state.copyWith(position: repo.position));
    });
  }

  /// Resumes local playback if the session ends from outside the app (the TV,
  /// the system notification, or a network drop).
  void _watchCastConnection(ICastRepository repo) {
    unawaited(_castConnSub?.cancel());
    _castConnSub = repo.connection().listen((bool connected) {
      if (_disposed || connected || !isCasting) return;
      unawaited(stopCasting());
    });
  }

  /// Best-effort MIME type for the receiver. Live Xtream streams are HLS;
  /// VOD/series map from the container extension, defaulting to MP4.
  String _castContentType(PlaybackRequest request) {
    if (request.isLive) return "application/x-mpegURL";
    return switch (request.containerExtension.toLowerCase()) {
      "m3u8" => "application/x-mpegURL",
      "mkv" => "video/x-matroska",
      "ts" => "video/mp2t",
      "webm" => "video/webm",
      _ => "video/mp4",
    };
  }

  Future<void> _release() async {
    _disposed = true;
    _accrueWatchTime(resume: false);
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _castPollTimer?.cancel();
    await _castConnSub?.cancel();
    await _routeSub?.cancel();
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    await _engine?.dispose();
  }
}

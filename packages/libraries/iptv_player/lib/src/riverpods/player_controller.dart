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
import "player_transitions.dart";
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

/// If playback stays buffering (never starts / stalls) this long without a
/// single playing frame, surface the retryable error overlay instead of an
/// endless spinner. Covers dead/slow Xtream streams and the case where a
/// network-timed-out ExoPlayer falls back to media_kit, which then buffers the
/// same unreachable URL forever.
const Duration _kBufferTimeout = Duration(seconds: 25);

/// Shorter stall budget for the first ExoPlayer attempt: some containers/codecs
/// (e.g. MPEG-4 Part 2 / odd audio) neither play nor raise an error on the Fire
/// TV decoder — ExoPlayer just hangs. Fall back to media_kit (libmpv decodes
/// far more) quickly instead of making the user wait the full timeout.
const Duration _kExoStallTimeout = Duration(seconds: 12);

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
  Timer? _bufferWatchdog;
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
  final WatchTimeSink? _watchSink = GetIt.instance.isRegistered<WatchTimeSink>()
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

  /// True while the iOS output route is AirPlay: online items then get the
  /// AVPlayer engine (see [_wantsAirPlayEngine]). Not "the engine is AVPlayer".
  bool _externalPlayback = false;

  /// Serialises engine swaps and cast hand-offs, see [TransitionQueue].
  final TransitionQueue _transitions = TransitionQueue();

  /// Identity of the playback session: bumped by [start] and [stop] only.
  /// Trap: a transition generation also moves on [playAt]/[castTo], which
  /// keep the session; anything that outlives an await and owns a resource
  /// of the session (a cast load) compares this, not the generation.
  int _session = 0;

  /// Polls the remote playhead while casting; null when playing locally.
  Timer? _castPollTimer;

  /// Watches for the remote session ending externally (e.g. from the TV).
  StreamSubscription<bool>? _castConnSub;

  /// True while playback is handed off to a TV (Chromecast / AirPlay).
  bool get isCasting => state.castDevice != null;

  /// Whether casting is supported on this build (repository registered).
  bool get canCast => _castRepo != null && !(currentRequest?.isLocal ?? false);

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

  /// Set once ExoPlayer reports an error it can't recover from (e.g. a codec /
  /// container it doesn't support). Forces the media_kit (libmpv) fallback for
  /// the rest of the session so playback never dead-ends — libmpv plays almost
  /// anything Xtream serves. Reset on each new [start].
  bool _nativeEngineFailed = false;

  /// Whether this device should use the native SurfaceView ExoPlayer engine:
  /// Android TV only (its hardware-overlay surface avoids the video-frame drops
  /// the libmpv texture path suffers on weak TV GPUs). Used for both live and
  /// VOD on TV. Phones keep media_kit (their GPU handles the texture path, and
  /// the SurfaceView would clash with the phone mini-player). Disabled once the
  /// native engine has failed on unsupported media this session.
  bool _wantsNativeEngine() =>
      defaultTargetPlatform == TargetPlatform.android &&
      playerIsTelevision &&
      !_nativeEngineFailed;

  /// Builds the local engine. media_kit (libmpv) is the default and decodes the
  /// MPEG-TS / MKV / odd codecs Xtream serves. Android TV uses ExoPlayer
  /// (SurfaceView) unless it has failed this session ([_nativeEngineFailed]).
  /// On iOS we switch to native AVPlayer only while [_externalPlayback]
  /// (AirPlay) is active, since libmpv renders to a texture and cannot AirPlay.
  PlaybackEngine _createEngine(PlaybackRequest? item) {
    final PlaybackEngine Function()? factory = debugPlaybackEngineFactory;
    if (factory != null) return factory();
    if (_wantsNativeEngine()) {
      return ExoPlayerEngine();
    }
    if (_wantsAirPlayEngine(item)) {
      return AvPlayerEngine();
    }
    return MediaKitEngine();
  }

  /// AirPlay is on and [item] can travel over it. Trap: a downloaded file
  /// cannot be handed to AVPlayer/AirPlay, so it always plays on libmpv.
  bool _wantsAirPlayEngine(PlaybackRequest? item) =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      _externalPlayback &&
      !(item?.isLocal ?? false);

  /// Moves to the engine [item] needs when the AirPlay route and the item
  /// kind disagree with the running engine (online item reached while
  /// AirPlay is on after a local one, or the reverse).
  bool _engineMismatch(PlaybackRequest item) =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      (_engine is AvPlayerEngine) != _wantsAirPlayEngine(item);

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
    // Any swap or hand-off still in flight belongs to the old session.
    _transitions.bump();
    _session++;
    _abandonCastSession();
    _countdownTimer?.cancel();
    // New session: give ExoPlayer a fresh chance (a previous codec failure
    // shouldn't stick to unrelated new content).
    _nativeEngineFailed = false;
    // Reuse the existing engine only if it is still the right kind for this
    // device (ExoPlayer on TV vs media_kit elsewhere). Otherwise tear it down
    // and build the correct one — handles a leftover keepAlive engine of the
    // wrong type without a stop() in between.
    final bool engineMatches = canReuseEngine(
      hasEngine: _engine != null,
      engineIsNative: _engine is ExoPlayerEngine,
      wantsNative: _wantsNativeEngine(),
      airPlayMismatch: _engineMismatch(queue.current),
    );
    if (!engineMatches) {
      _replaceEngineSubscriptions();
      final PlaybackEngine engine = _createEngine(queue.current);
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

  /// Ends a live cast session synchronously (the TV would keep playing the
  /// old item) without awaiting: [start] cannot wait. No-op when not casting.
  void _abandonCastSession() {
    _castPollTimer?.cancel();
    _castPollTimer = null;
    final StreamSubscription<bool>? conn = _castConnSub;
    _castConnSub = null;
    unawaited(conn?.cancel());
    if (isCasting) unawaited(_castRepo?.endSession());
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
    // Always record the route, even over a local item: the next online item
    // must still go to AirPlay, and no further route event will tell us.
    _externalPlayback = active;
    // A local file cannot be handed to AVPlayer/AirPlay; keep libmpv.
    if (currentRequest?.isLocal ?? false) return;
    if (_engine == null) return;
    await _swapEngine();
  }

  /// Test hook for the swap triggers (AirPlay, ExoPlayer fallback).
  @visibleForTesting
  Future<void> debugSwapEngine() => _swapEngine();

  /// Queues an engine rebuild behind every other swap and cast hand-off.
  /// Used for the AirPlay handoff and the ExoPlayer fallback.
  Future<void> _swapEngine({Duration? resumeFrom}) {
    final int gen = _transitions.generation;
    return _runTransition(
      gen,
      () => _swapEngineNow(gen, resumeFrom: resumeFrom),
    );
  }

  /// The only way to queue a transition. Structural rule: a body that was
  /// superseded after an await writes nothing and may leave [_engine] null
  /// (a swap does), so once the body is done the current transition makes
  /// sure that a session without a cast has an engine ([_settle]). Without
  /// this, a failed cast load left the player dead on a one-item queue.
  Future<void> _runTransition(int gen, Future<void> Function() body) {
    return _transitions.run(
      () async {
        try {
          await body();
        } finally {
          await _settle(gen);
        }
      },
      onError: _logTransitionError,
    );
  }

  /// Rebuilds a missing engine at the current position when nothing else
  /// will: [gen] must still be current, otherwise whoever bumped (a queued
  /// transition settles itself; [start] builds one; [stop] ends the queue).
  Future<void> _settle(int gen) async {
    if (_disposed || _queue == null || isCasting || _engine != null) return;
    if (!_transitions.isCurrent(gen)) return;
    await _swapEngineNow(gen);
  }

  void _logTransitionError(Object error, StackTrace stackTrace) =>
      debugPrint("Player transition failed: ${error.runtimeType}");

  /// Tears down the current engine and rebuilds it via [_createEngine] at the
  /// current position, re-subscribing its streams. Runs inside the
  /// [_transitions] queue only: it is the single place an engine is created
  /// after [start]. A swap superseded while it disposes creates nothing and
  /// leaves [_engine] null; [_settle] of the superseding transition rebuilds.
  Future<void> _swapEngineNow(int gen, {Duration? resumeFrom}) async {
    if (_disposed || _queue == null || !_transitions.isCurrent(gen)) return;
    final Duration resumeAt =
        resumeFrom ?? (state.isLive ? Duration.zero : state.position);
    // Detached before the first await so nobody else disposes them again.
    final List<StreamSubscription<dynamic>> subs = _subscriptions.toList();
    _subscriptions.clear();
    final PlaybackEngine? old = _engine;
    _engine = null;
    for (final StreamSubscription<dynamic> sub in subs) {
      await sub.cancel();
    }
    await old?.dispose();
    final PlaybackQueue? q = _queue;
    if (_disposed || q == null || !_transitions.isCurrent(gen)) return;
    final PlaybackEngine engine = _createEngine(q.items[state.queueIndex]);
    _engine = engine;
    _listen(engine);
    // Carry the zoom-to-fill preference across the engine swap.
    if (state.videoFill) unawaited(engine.setFill(true));
    _set(
      state.copyWith(
        buffering: true,
        supportsSyncOffsets: engine.supportsSyncOffsets,
      ),
    );
    unawaited(_openIndex(state.queueIndex, resumeAt));
  }

  /// Arms the stall watchdog: after [_kBufferTimeout] with no playing frame,
  /// replace the endless spinner with the retryable error overlay.
  void _armBufferWatchdog() {
    _bufferWatchdog?.cancel();
    // ExoPlayer's first attempt gets the shorter budget so a silent decoder
    // stall falls back to media_kit fast; media_kit (or a retry) gets the full
    // timeout before the error surfaces.
    final bool exoFirstTry = _engine is ExoPlayerEngine && !_nativeEngineFailed;
    _bufferWatchdog =
        Timer(exoFirstTry ? _kExoStallTimeout : _kBufferTimeout, () {
      if (_disposed || isCasting || state.playing) return;
      // ExoPlayer stalled with no error (unsupported codec/container it neither
      // plays nor rejects) — swap to media_kit before giving up.
      if (_engine is ExoPlayerEngine && !_nativeEngineFailed) {
        _nativeEngineFailed = true;
        unawaited(_swapEngine());
        return;
      }
      _set(
        state.copyWith(
          error: const Failures.streamUnavailable(),
          buffering: false,
        ),
      );
    });
  }

  void _cancelBufferWatchdog() {
    _bufferWatchdog?.cancel();
    _bufferWatchdog = null;
  }

  /// Stops playback and releases the engine (mini-player close).
  Future<void> stop() async {
    _transitions.bump();
    _session++;
    _accrueWatchTime(resume: false);
    _maybeSaveProgress(force: true);
    _cancelBufferWatchdog();
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _flashTimer?.cancel();
    _castPollTimer?.cancel();
    _castPollTimer = null;
    // Everything below is detached before the first await: a start() landing
    // during the awaits owns fresh fields that stop() must never touch.
    final StreamSubscription<bool>? conn = _castConnSub;
    final StreamSubscription<bool>? route = _routeSub;
    _castConnSub = null;
    _routeSub = null;
    _externalPlayback = false;
    final Future<Duration>? ending = isCasting ? _castRepo?.endSession() : null;
    final List<StreamSubscription<dynamic>> subs = _subscriptions.toList();
    _subscriptions.clear();
    final PlaybackEngine? old = _engine;
    _engine = null;
    _queue = null;
    _set(const PlayerUiState());
    await conn?.cancel();
    await route?.cancel();
    await ending;
    for (final StreamSubscription<dynamic> sub in subs) {
      await sub.cancel();
    }
    await old?.dispose();
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
        // A playing frame means the stream is alive — clear the stall watchdog.
        if (p) _cancelBufferWatchdog();
        _set(state.copyWith(playing: p, error: p ? null : state.error));
        // Keep the native MediaSession in sync so the OS knows whether the
        // pause was intentional (prevents Fire TV auto-resume after ~3 s).
        unawaited(_mediaSession.setPlaying(playing: p));
        if (p) {
          _watchClock.start();
          // Begin the auto-hide countdown from the moment playback actually
          // starts. On a slow-starting stream the initial timer (armed at
          // open) fires while still buffering — playing was false, so it did
          // nothing — and the controls used to hang on screen until the user
          // interacted. Re-arm here so they fade ~4 s after the first frame.
          if (state.overlayVisible) _restartHideTimer();
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
        // Arm the stall watchdog while buffering; a playing frame or the buffer
        // clearing disarms it.
        if (b && !state.playing) {
          _armBufferWatchdog();
        } else {
          _cancelBufferWatchdog();
        }
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
        // ExoPlayer (Android TV) couldn't play this media — likely a codec /
        // container it doesn't support. Fall back to media_kit (libmpv) for the
        // rest of the session and re-open at the same position, so playback
        // continues instead of dead-ending. libmpv plays what ExoPlayer can't.
        if (_engine is ExoPlayerEngine && !_nativeEngineFailed) {
          _nativeEngineFailed = true;
          unawaited(_swapEngine());
          return;
        }
        _cancelBufferWatchdog();
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
    _subscriptions.add(
      // ExoPlayer emits subtitle text to overlay in Flutter (its SurfaceView
      // shows raw video). Other engines emit nothing (empty stream).
      engine.subtitleCues.listen((String text) {
        if (isCasting) return;
        _set(state.copyWith(subtitleCue: text));
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
  void _applySavedSubtitleStyle(PlaybackEngine engine) {
    final PlaybackPreferences? prefs = _prefs;
    if (prefs == null) return;
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
    // Start the stall watchdog: if this URL never yields a playing frame,
    // surface the retryable error instead of buffering forever.
    _armBufferWatchdog();
    if (engine.supportsSyncOffsets) {
      unawaited(engine.setSubtitleDelay(0));
      unawaited(engine.setAudioDelay(0));
    }
    // AVPlayer (AirPlay) needs the HLS variant; libmpv uses the default URL.
    final PlaybackRequest item = q.items[index];
    final String url = _externalPlayback && !item.isLocal
        ? (item.externalUrl ?? item.url)
        : item.url;
    await engine.open(url);
    // The engine may have been swapped or torn down while opening.
    if (_disposed || !identical(_engine, engine)) return;
    _applySavedSubtitleStyle(engine);
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
      if (_disposed || !identical(_engine, engine)) return;
      if (state.queueIndex != index) return;
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
    if (!force &&
        (position - _lastSavedSeconds).abs() < _kSaveIntervalSeconds) {
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
        seriesId: request.seriesId,
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

  /// Toggles zoom-to-fill (YouTube/Netflix style): fit (letterbox) ↔ fill
  /// (crop to cover the screen). Applied to the current engine immediately.
  void toggleVideoFill() {
    final bool next = !state.videoFill;
    _set(state.copyWith(videoFill: next));
    unawaited(_engine?.setFill(next));
  }

  /// Enters/leaves scrubbing mode (holding ◀/▶ on the seek bar). While active
  /// the chrome fades and the overlay is pinned open; leaving restarts the
  /// auto-hide countdown.
  void setScrubbing({required bool active}) {
    if (state.scrubbing == active) return;
    _set(state.copyWith(scrubbing: active));
    if (active) {
      _hideTimer?.cancel();
    } else {
      _restartHideTimer();
    }
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
    _set(
      state.copyWith(
        queueIndex: index,
        isLive: request.isLive,
        countdownSeconds: 0,
      ),
    );
    // What to do depends on the cast and engine state when it is this
    // item's turn, not now: earlier transitions may still be running.
    final int gen = _transitions.bump();
    unawaited(
      _runTransition(gen, () => _navigate(index, request.startAt, gen)),
    );
    revealOverlay();
  }

  bool _engineReusableFor(PlaybackRequest item) => canReuseEngine(
        hasEngine: _engine != null,
        engineIsNative: _engine is ExoPlayerEngine,
        wantsNative: _wantsNativeEngine(),
        airPlayMismatch: _engineMismatch(item),
      );

  /// Reaches queue item [index]; runs inside the [_transitions] queue.
  Future<void> _navigate(int index, Duration startAt, int gen) async {
    final PlaybackQueue? q = _queue;
    if (_disposed || q == null || !_transitions.isCurrent(gen)) return;
    final PlaybackRequest request = q.items[index];
    final CastDevice? device = state.castDevice;
    NavigationAction action = decideNavigation(
      casting: device != null,
      itemIsLocal: request.isLocal,
      engineReusable: _engineReusableFor(request),
    );
    switch (action) {
      case NavigationAction.castLoad:
        if (device == null) return;
        await _castLoad(device, request, startAt, gen);
        return;
      case NavigationAction.leaveCast:
        // A receiver cannot read a file:// URL: leave the cast for this item.
        final int session = _session;
        await _dropCastSession();
        // start()/stop() replaced the session: its state is not ours to edit.
        if (_disposed || session != _session) return;
        // The session is over whatever happened since: castDevice follows.
        _set(state.copyWith(castDevice: null, buffering: true));
        if (!_transitions.isCurrent(gen)) return;
        action = decideAfterLeavingCast(
          engineReusable: _engineReusableFor(request),
        );
      case NavigationAction.swapEngine:
      case NavigationAction.openLocal:
        break;
    }
    if (action == NavigationAction.swapEngine) {
      await _swapEngineNow(gen, resumeFrom: startAt);
    } else {
      unawaited(_openIndex(index, startAt));
    }
  }

  /// Stops cast polling and the connection watch, then ends the session.
  /// Returns the remote playhead.
  Future<Duration> _dropCastSession() async {
    _castPollTimer?.cancel();
    _castPollTimer = null;
    await _castConnSub?.cancel();
    _castConnSub = null;
    return await _castRepo?.endSession() ?? Duration.zero;
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

  Future<void> setVolume(double volume) async => _engine?.setVolume(volume);

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
    final int clamped =
        milliseconds.clamp(-_kMaxSyncOffsetMs, _kMaxSyncOffsetMs);
    unawaited(_engine?.setSubtitleDelay(clamped));
    _set(state.copyWith(subtitleDelayMs: clamped));
    revealOverlay();
  }

  void setAudioDelay(int milliseconds) {
    final int clamped =
        milliseconds.clamp(-_kMaxSyncOffsetMs, _kMaxSyncOffsetMs);
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
    final PlaybackRequest? first = currentRequest;
    if (_castRepo == null || first == null || first.isLocal) return;
    final int gen = _transitions.bump();
    await _runTransition(gen, () async {
      final PlaybackRequest? request = currentRequest;
      if (_disposed || !_transitions.isCurrent(gen)) return;
      if (request == null || request.isLocal) return;
      final Duration startAt = state.isLive ? Duration.zero : state.position;
      await _engine?.pause();
      // Superseded while pausing: the newer transition decides, no cast.
      if (_disposed || !_transitions.isCurrent(gen)) return;
      _accrueWatchTime(resume: false);
      await _castLoad(device, request, startAt, gen);
    });
    revealOverlay();
  }

  /// Loads [request] onto [device]. Reused for both the initial handoff and
  /// queue changes while already casting (the SDK session is reused). Runs
  /// inside the [_transitions] queue. Trap: [state]'s castDevice must follow
  /// the real session, so a successful load records it even when a newer
  /// transition has superseded this one (that one then leaves or reloads).
  /// Only a new [_session] (start/stop) voids the load and ends it.
  Future<void> _castLoad(
    CastDevice device,
    PlaybackRequest request,
    Duration startAt,
    int gen,
  ) async {
    final ICastRepository? repo = _castRepo;
    // Every hand-off is guarded, not only the current item: see [playAt].
    if (repo == null || request.isLocal) return;
    final int session = _session;
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
    if (_disposed || _queue == null || session != _session) {
      // Stopped, disposed or restarted on another queue meanwhile: the load
      // belongs to a dead session. End it, write nothing.
      if (result.isRight()) unawaited(repo.endSession());
      return;
    }
    result.fold(
      (Failures failure) {
        if (_transitions.isCurrent(gen)) {
          _set(state.copyWith(error: failure, buffering: false));
        }
      },
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
    if (_castRepo == null || !isCasting) return;
    // Not a navigation: a playAt queued after this keeps its own say.
    final int gen = _transitions.generation;
    await _runTransition(gen, () async {
      if (_disposed || !isCasting) return;
      final int session = _session;
      final Duration resumeAt = await _dropCastSession();
      if (_disposed || session != _session) return;
      final bool live = state.isLive;
      _set(state.copyWith(castDevice: null, buffering: true));
      if (!_transitions.isCurrent(gen)) return;
      final PlaybackRequest? request = currentRequest;
      if (request == null) return;
      final Duration at = live ? Duration.zero : resumeAt;
      if (_engineReusableFor(request)) {
        // Re-opens the local engine and auto-plays; live restarts at 0.
        unawaited(_openIndex(state.queueIndex, at));
      } else {
        await _swapEngineNow(gen, resumeFrom: at);
      }
    });
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
    _transitions.bump();
    _accrueWatchTime(resume: false);
    _bufferWatchdog?.cancel();
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _castPollTimer?.cancel();
    // `state` is off limits while disposing; the watch exists iff casting.
    if (_castConnSub != null) unawaited(_castRepo?.endSession());
    await _castConnSub?.cancel();
    await _routeSub?.cancel();
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    await _engine?.dispose();
  }
}

/// Test seam: replaces every engine the controller builds (libmpv, ExoPlayer
/// and AVPlayer need native code). Null in production.
@visibleForTesting
PlaybackEngine Function()? debugPlaybackEngineFactory;

/// Whether [PlaybackController.start] may keep the running engine. Trap: the
/// phone mini-player leaves the engine and the AirPlay flag alive between
/// sessions, so the AirPlay/local-file mismatch must be checked here too —
/// otherwise a download opens on AVPlayer, or an online item under AirPlay
/// stays on libmpv and never reaches the TV.
@visibleForTesting
bool canReuseEngine({
  required bool hasEngine,
  required bool engineIsNative,
  required bool wantsNative,
  required bool airPlayMismatch,
}) =>
    hasEngine && engineIsNative == wantsNative && !airPlayMismatch;

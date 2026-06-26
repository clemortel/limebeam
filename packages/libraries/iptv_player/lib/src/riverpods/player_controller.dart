import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:get_it/get_it.dart";
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:media_kit/media_kit.dart";
import "package:media_kit_video/media_kit_video.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../domain/playback_queue.dart";
import "../domain/playback_request.dart";
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

/// App-scoped playback engine (keepAlive): playback **survives** popping the
/// full-screen player, which is what powers the docked mini-player. Call
/// [start] to (re)play a queue; [stop] tears the engine down. The media_kit
/// types never leave this file; all logic/timers live here, not in widgets.
@Riverpod(keepAlive: true)
class PlaybackController extends _$PlaybackController {
  Player? _player;
  VideoController? _videoController;
  PlaybackQueue? _queue;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  Timer? _hideTimer;
  Timer? _countdownTimer;
  bool _disposed = false;
  int _lastSavedSeconds = 0;

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

  /// Polls the remote playhead while casting; null when playing locally.
  Timer? _castPollTimer;

  /// Watches for the remote session ending externally (e.g. from the TV).
  StreamSubscription<bool>? _castConnSub;

  /// True while playback is handed off to a TV (Chromecast / AirPlay).
  bool get isCasting => state.castDevice != null;

  /// Whether casting is supported on this build (repository registered).
  bool get canCast => _castRepo != null;

  @override
  PlayerUiState build() {
    ref.onDispose(_release);
    return const PlayerUiState();
  }

  /// Non-null only while playback is active (the [Video] widget needs it).
  VideoController? get videoController => _videoController;

  /// The active queue, or null when nothing is playing.
  PlaybackQueue? get queue => _queue;

  /// The currently-playing item, or null when nothing is playing.
  PlaybackRequest? get currentRequest {
    final PlaybackQueue? q = _queue;
    if (q == null) return null;
    return q.items[state.queueIndex];
  }

  /// Begins (or replaces) playback with [queue].
  void start(PlaybackQueue queue) {
    _countdownTimer?.cancel();
    if (_player == null) {
      final Player player = Player();
      _player = player;
      // Emulators can't create a hardware GL context (black video), so fall
      // back to software rendering there; real devices keep acceleration.
      _videoController = VideoController(
        player,
        configuration: VideoControllerConfiguration(
          enableHardwareAcceleration: !playerSoftwareRenderingOnly,
        ),
      );
      _listen(player);
    }
    _queue = queue;
    _lastSavedSeconds = 0;
    _set(
      PlayerUiState(
        active: true,
        overlayVisible: true,
        isLive: queue.current.isLive,
        queueIndex: queue.index,
      ),
    );
    unawaited(_openIndex(queue.index, queue.current.startAt));
    _restartHideTimer();
  }

  /// Stops playback and releases the engine (mini-player close).
  Future<void> stop() async {
    _accrueWatchTime(resume: false);
    _maybeSaveProgress(force: true);
    _hideTimer?.cancel();
    _countdownTimer?.cancel();
    _castPollTimer?.cancel();
    _castPollTimer = null;
    await _castConnSub?.cancel();
    _castConnSub = null;
    if (isCasting) await _castRepo?.endSession();
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    await _player?.dispose();
    _player = null;
    _videoController = null;
    _queue = null;
    _set(const PlayerUiState());
  }

  void _listen(Player player) {
    // While casting, the local engine is paused and the remote owns playback
    // state; ignore its (stale) stream events so they don't clobber the UI.
    _subscriptions.add(
      player.stream.position.listen((Duration p) {
        if (isCasting) return;
        _set(state.copyWith(position: p));
        _maybeSaveProgress();
        if (_watchClock.elapsed.inSeconds >= _kWatchFlushSeconds) {
          _accrueWatchTime(resume: true);
        }
      }),
    );
    _subscriptions.add(
      player.stream.duration.listen((Duration d) {
        if (isCasting) return;
        _set(state.copyWith(duration: d));
      }),
    );
    _subscriptions.add(
      player.stream.playing.listen((bool p) {
        if (isCasting) return;
        _set(state.copyWith(playing: p, error: p ? null : state.error));
        if (p) {
          _watchClock.start();
        } else {
          _accrueWatchTime(resume: false);
          _maybeSaveProgress(force: true);
        }
      }),
    );
    _subscriptions.add(
      player.stream.buffering.listen((bool b) {
        if (isCasting) return;
        _set(state.copyWith(buffering: b));
      }),
    );
    _subscriptions.add(
      player.stream.buffer.listen((Duration b) {
        if (isCasting) return;
        _set(state.copyWith(buffer: b));
      }),
    );
    _subscriptions.add(
      player.stream.error.listen((String _) {
        if (isCasting) return;
        _set(
          state.copyWith(
            error: const Failures.streamUnavailable(),
            buffering: false,
          ),
        );
      }),
    );
    _subscriptions.add(
      player.stream.completed.listen((bool c) {
        if (isCasting) return;
        _onCompleted(c);
      }),
    );
  }

  Future<void> _openIndex(int index, Duration startAt) async {
    final Player? player = _player;
    final PlaybackQueue? q = _queue;
    if (player == null || q == null) return;
    _set(state.copyWith(error: null, buffering: true));
    await player.open(Media(q.items[index].url));
    if (startAt > Duration.zero) {
      final Duration total = await player.stream.duration
          .firstWhere((Duration d) => d > Duration.zero)
          .timeout(_kResumeSeekTimeout, onTimeout: () => Duration.zero);
      // Bail if disposed or the user switched content during the await.
      if (_disposed || state.queueIndex != index) return;
      if (total > Duration.zero) await player.seek(startAt);
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

  /// Current volume as a 0..1 fraction (for the gesture HUD).
  double get currentVolume01 => (_player?.state.volume ?? 100) / 100;

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

  void playOrPause() {
    if (isCasting) {
      final bool willPlay = !state.playing;
      unawaited(willPlay ? _castRepo?.play() : _castRepo?.pause());
      _set(state.copyWith(playing: willPlay));
      revealOverlay();
      return;
    }
    _player?.playOrPause();
    revealOverlay();
  }

  void seekForward() => _seekBy(_kPlayerSeekStep);

  void seekBackward() => _seekBy(-_kPlayerSeekStep);

  void seekTo(Duration target) => _seekTo(target);

  void _seekBy(Duration delta) {
    if (state.isLive) return;
    _seekTo(state.position + delta);
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
      _player?.setVolume(volume);

  void nudgeVolume(double deltaFraction) {
    final Player? player = _player;
    if (player == null) return;
    final double next = (player.state.volume + deltaFraction * 100).clamp(0, 100);
    unawaited(player.setVolume(next));
  }

  /// Re-opens the current item after a stream error.
  void retry() {
    final PlaybackQueue? q = _queue;
    if (q == null) return;
    unawaited(_openIndex(state.queueIndex, q.items[state.queueIndex].startAt));
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
    unawaited(_player?.seek(clamped));
    revealOverlay();
  }

  // --- Casting (Chromecast / AirPlay handoff) -----------------------------

  /// Hands the current item off to [device]: pauses local playback and starts
  /// remote playback at the current position. The overlay then drives the TV.
  Future<void> castTo(CastDevice device) async {
    final PlaybackRequest? request = currentRequest;
    if (_castRepo == null || request == null) return;
    final Duration startAt = state.isLive ? Duration.zero : state.position;
    await _player?.pause();
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
    for (final StreamSubscription<dynamic> sub in _subscriptions) {
      await sub.cancel();
    }
    await _player?.dispose();
  }
}

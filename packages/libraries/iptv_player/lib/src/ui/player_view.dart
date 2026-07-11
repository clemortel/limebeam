import "dart:async" show Timer;

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:screen_brightness/screen_brightness.dart";

import "../domain/media_track.dart";
import "../domain/playback_queue.dart";
import "../domain/playback_request.dart";
import "../pip/pip_service.dart";
import "../riverpods/player_controller.dart";
import "../riverpods/player_ui_state.dart";

const double _kPlayButtonSize = 72;

/// Max width of the player controls on TV so buttons don't stretch across a
/// 1080p/4K screen. The gradient scrim remains full-width.
const double _kTvControlsMaxWidth = 1280;

/// Step applied by the subtitle/audio sync stepper buttons (250 ms).
const int _kSyncStepMs = 250;

/// Milliseconds per second, for formatting sync offsets as seconds.
const double _kMillisPerSecond = 1000;

/// Fixed width for the sync offset readout so the steppers don't jump.
const double _kSyncValueWidth = 64;
const double _kSkipButtonSize = 40;
const double _kLiveDotSize = 8;
const double _kQueueThumbSize = 44;
const double _kWatermarkSize = 26;
const double _kWatermarkOpacity = 0.55;
const double _kHudIconSize = 28;

/// Vertical drag pixels for a full-range (0→100%) volume/brightness change.
const double _kVolumeDragSpan = 300;
const Color _kPlayerBackground = Color(0xFF000000);
const Color _kScrimTop = Color(0x99000000);
const Color _kScrimBottom = Color(0xCC000000);
const Color _kPillBg = Color(0xCC000000);

/// Width of the TV side panel (tracks / queue picker).
const double _kTvPanelWidth = 320;

/// Slide-in / slide-out duration for the TV side panel.
const Duration _kTvPanelDuration = Duration(milliseconds: 220);

/// Which level the gesture HUD is showing.
enum _Hud { volume, brightness }

/// The subset of [PlayerUiState] that changes the player's *structure* (which
/// overlays exist, focus routing, gesture enablement). [PlayerView] watches
/// only this via `.select`, so the high-frequency playhead / buffer ticks never
/// rebuild the whole tree — only the seek bar + labels inside [_Controls] do.
typedef _PlayerVm = ({
  bool active,
  bool overlayVisible,
  bool playing,
  bool buffering,
  bool isLive,
  bool canScrub,
  bool scrubbing,
  CastDevice? castDevice,
  Failures? error,
  String? seekFlash,
  int countdownSeconds,
});

/// Full-screen player surface (§4.5). One gesture surface sits under the
/// controls; all transient feedback (HUD / scrub preview / double-tap flash) is
/// drawn on top. Reads the app-scoped [PlaybackController] so the engine keeps
/// playing (mini-player) when this route is popped.
class PlayerView extends ConsumerStatefulWidget {
  const PlayerView({super.key});

  @override
  ConsumerState<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends ConsumerState<PlayerView> {
  bool _landscape = false;
  double _doubleTapDx = 0;
  double? _scrubMs;
  _Hud? _hud;
  double _hudValue = 0;

  // Owns key input on TV: reclaims focus whenever the overlay auto-hides so the
  // remote keeps driving transport (play/pause/seek) with no visible controls.
  final FocusNode _tvFocusNode = FocusNode(debugLabel: "player-tv");

  // Receives focus when the overlay becomes visible so the remote immediately
  // lands on the play/pause button (Apple TV behaviour).
  final FocusNode _playFocusNode = FocusNode(debugLabel: "player-play");

  // The other two D-pad stops. Up/Down on TV walks play → seek → CC
  // deterministically (see [_moveTvFocus]) rather than trusting the beam, which
  // proved unable to land on these widgets reliably.
  final FocusNode _seekFocusNode = FocusNode(debugLabel: "player-seek");
  final FocusNode _ccFocusNode = FocusNode(debugLabel: "player-cc");

  // TV side panel (tracks picker). Never shown on touch devices.
  bool _tvPanelVisible = false;

  // Device class, cached from the inherited scope. On TV there is no
  // mini-player, so popping the player stops playback rather than docking it.
  bool _isTv = false;

  // Captured in [initState] so [dispose] never touches `ref` (which is invalid
  // once the element is defunct). The controller is an app-scoped keepAlive
  // singleton, so the reference stays valid after this route is popped.
  late final PlaybackController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ref.read(playbackControllerProvider.notifier);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Full-screen is showing → hide the floating window.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _controller.setExpanded(true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isTv = FormFactorScope.isTv(context);
  }

  @override
  void dispose() {
    _tvFocusNode.dispose();
    _playFocusNode.dispose();
    _seekFocusNode.dispose();
    _ccFocusNode.dispose();
    // Deferred to the next frame: mutating the provider this widget watches
    // *during* dispose would notify our own now-defunct element. Runs after
    // this element is fully unmounted.
    final PlaybackController controller = _controller;
    final bool wasTv = _isTv;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (wasTv) {
        // TV has no docked mini-player, so leaving the full-screen player must
        // stop playback — otherwise audio keeps going in the background menu.
        controller.stop();
      } else {
        // Phone: dock into the floating mini-player and keep playing.
        controller.setExpanded(false);
      }
    });
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    ScreenBrightness().resetApplicationScreenBrightness();
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() => _landscape = !_landscape);
    SystemChrome.setPreferredOrientations(
      _landscape
          ? <DeviceOrientation>[
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : <DeviceOrientation>[DeviceOrientation.portraitUp],
    );
  }

  void _doubleSeek(bool isLeft) {
    if (isLeft) {
      _controller.seekBackward();
    } else {
      _controller.seekForward();
    }
  }

  void _verticalStart(bool isLeft) {
    if (isLeft) {
      _hud = _Hud.brightness;
      ScreenBrightness().application.then((double v) {
        if (mounted && _hud == _Hud.brightness) setState(() => _hudValue = v);
      });
      setState(() {});
    } else {
      setState(() {
        _hud = _Hud.volume;
        _hudValue = _controller.currentVolume01.clamp(0, 1);
      });
    }
  }

  void _verticalUpdate(double delta) {
    if (_hud == null) return;
    final double next = (_hudValue - delta / _kVolumeDragSpan).clamp(0, 1);
    setState(() => _hudValue = next);
    if (_hud == _Hud.brightness) {
      ScreenBrightness().setApplicationScreenBrightness(next);
    } else {
      _controller.setVolume(next * 100);
    }
  }

  /// Walks the overlay's D-pad stops in order — play → seek → CC — moving
  /// focus one step. Only mounted controls participate, so absent ones (no seek
  /// bar on live, no CC without tracks) are skipped. Deterministic on purpose:
  /// dpad's geometric beam wouldn't reliably land on these specific widgets.
  void _moveTvFocus({required bool forward}) {
    final List<FocusNode> stops = <FocusNode>[
      _playFocusNode,
      _seekFocusNode,
      _ccFocusNode,
    ].where((FocusNode n) => n.context != null && n.canRequestFocus).toList();
    if (stops.isEmpty) return;
    final int current = stops.indexWhere((FocusNode n) => n.hasFocus);
    if (current < 0) {
      stops.first.requestFocus();
      return;
    }
    final int next =
        (current + (forward ? 1 : -1)).clamp(0, stops.length - 1);
    stops[next].requestFocus();
  }

  /// Maps remote/D-pad keys to playback on TV. When the overlay is visible the
  /// directional keys are left to the focus system (so the on-screen buttons
  /// are reachable); when it is hidden the remote drives transport directly.
  KeyEventResult _handleTvKey(
    KeyEvent event,
    _PlayerVm vm,
    PlaybackController controller,
    PlaybackQueue queue,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final bool canScrub = vm.canScrub;
    final LogicalKeyboardKey key = event.logicalKey;

    // A playback error shows a modal overlay. The remote must ONLY Retry (OK)
    // or exit (Back) — every other key is swallowed so it can't leak to the
    // player behind the overlay (which is why "Retry" used to instead toggle
    // play/pause or zap to the next channel focused underneath it).
    if (vm.error != null) {
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.browserBack) {
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.space) {
        controller.retry();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    // TV side panel open: Back/Escape closes it before any other key handling.
    if (_tvPanelVisible &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack ||
            key == LogicalKeyboardKey.browserBack)) {
      setState(() => _tvPanelVisible = false);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _playFocusNode.requestFocus(),
      );
      return KeyEventResult.handled;
    }

    // Transport media keys work regardless of overlay visibility / focus.
    // mediaPlay / mediaPause are state-conditional so Fire TV's spurious "play"
    // event (sent a few seconds after pausing) never accidentally resumes.
    if (key == LogicalKeyboardKey.mediaPlayPause) {
      controller.playOrPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPlay) {
      if (!vm.playing) controller.playOrPause();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.mediaPause) {
      if (vm.playing) controller.playOrPause();
      return KeyEventResult.handled;
    }
    if (canScrub && key == LogicalKeyboardKey.mediaFastForward) {
      controller.seekForward();
      return KeyEventResult.handled;
    }
    if (canScrub && key == LogicalKeyboardKey.mediaTrackPrevious) {
      controller.playPrevious();
      return KeyEventResult.handled;
    }
    if (canScrub && key == LogicalKeyboardKey.mediaTrackNext) {
      controller.playNext();
      return KeyEventResult.handled;
    }
    if (canScrub && key == LogicalKeyboardKey.mediaRewind) {
      controller.seekBackward();
      return KeyEventResult.handled;
    }

    // Controls visible: first Back/Escape hides them (a second Back then exits
    // the player); every other navigation key keeps them alive (restart the
    // auto-hide timer) and is left to the focus system so the on-screen buttons
    // stay reachable and don't vanish mid-interaction.
    if (vm.overlayVisible) {
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.goBack ||
          key == LogicalKeyboardKey.browserBack) {
        controller.hideOverlay();
        return KeyEventResult.handled;
      }
      controller.pokeOverlay();
      // While the track panel is open, its own FocusScope owns navigation.
      if (!_tvPanelVisible) {
        // ◀/▶ from elsewhere jumps onto the seek bar so scrubbing happens in
        // one place (preview cursor + commit); the bar then owns ◀/▶ itself.
        if (canScrub &&
            !_seekFocusNode.hasFocus &&
            (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.arrowRight)) {
          _seekFocusNode.requestFocus();
          return KeyEventResult.handled;
        }
        // ▲/▼ walk the ordered stops play → seek → CC (deterministic).
        if (key == LogicalKeyboardKey.arrowUp) {
          _moveTvFocus(forward: false);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          _moveTvFocus(forward: true);
          return KeyEventResult.handled;
        }
      }
      // OK/Select (and anything else) → focus system activates the focused
      // control (play/pause, open CC panel).
      return KeyEventResult.ignored;
    }

    // Controls hidden → the remote drives the player directly.
    if (key == LogicalKeyboardKey.arrowLeft) {
      canScrub ? controller.seekBackward() : controller.revealOverlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      canScrub ? controller.seekForward() : controller.revealOverlay();
      return KeyEventResult.handled;
    }
    // OK/Select wakes the controls first (Apple TV / Netflix behaviour) rather
    // than blindly toggling playback; play/pause happens on the focused button.
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space) {
      controller.revealOverlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown) {
      // Live TV + queue with siblings: D-pad up/down = channel zapping.
      // Any other content: just reveal the overlay.
      if (vm.isLive && queue.hasSiblings) {
        if (key == LogicalKeyboardKey.arrowUp) {
          controller.playPrevious();
        } else {
          controller.playNext();
        }
      } else {
        controller.revealOverlay();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _scrubUpdate(double delta, double width, Duration duration) {
    final double total = duration.inMilliseconds.toDouble();
    final double base = _scrubMs ?? 0;
    setState(() => _scrubMs = (base + delta / width * total).clamp(0, total));
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // Structure-only watch: playhead/duration/buffer are excluded so their
    // high-frequency ticks don't rebuild this tree (see [_PlayerVm]).
    final _PlayerVm vm = ref.watch(
      playbackControllerProvider.select(
        (PlayerUiState s) => (
          active: s.active,
          overlayVisible: s.overlayVisible,
          playing: s.playing,
          buffering: s.buffering,
          isLive: s.isLive,
          canScrub: !s.isLive && s.duration > Duration.zero,
          scrubbing: s.scrubbing,
          castDevice: s.castDevice,
          error: s.error,
          seekFlash: s.seekFlash,
          countdownSeconds: s.countdownSeconds,
        ),
      ),
    );
    final PlaybackController controller = _controller;
    final PlaybackQueue? queue = controller.queue;
    final PlaybackRequest? request = controller.currentRequest;
    final Widget? videoView = controller.buildVideoView();

    if (!vm.active || queue == null || request == null || videoView == null) {
      return const Scaffold(backgroundColor: _kPlayerBackground);
    }

    final bool canScrub = vm.canScrub;
    final bool isTv = FormFactorScope.isTv(context);
    // Touch gestures (drag scrub, swipe volume/brightness, double-tap seek)
    // make no sense with a remote — TV drives the player from [_handleTvKey].
    final bool gestures = queue.gesturesEnabled && !isTv;
    final bool scrubGesture = canScrub && !isTv;

    // Overlay visibility → focus management on TV.
    // Visible: auto-focus the play button so the remote lands on it instantly.
    // Hidden: reclaim the player focus node so left/right/OK drive transport.
    if (isTv) {
      ref.listen<bool>(
        playbackControllerProvider
            .select((PlayerUiState s) => s.overlayVisible),
        (bool? previous, bool next) {
          if (next) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _playFocusNode.requestFocus(),
            );
          } else {
            // Hidden: close any panel and leave focus on the current control —
            // the full-screen key interceptor drives transport while hidden.
            // (The interceptor is no longer focusable, so don't focus it.)
            setState(() => _tvPanelVisible = false);
          }
        },
      );
    }

    return Scaffold(
      backgroundColor: _kPlayerBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double width = c.maxWidth;
          // Ancestor of the whole player: descendant buttons win their own
          // taps; every empty tap / double-tap / drag falls through to here.
          final Widget gestureLayer = GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (_) => controller.toggleOverlay(),
            onDoubleTapDown: (TapDownDetails d) =>
                _doubleTapDx = d.localPosition.dx,
            onDoubleTap: vm.isLive || isTv
                ? null
                : () => _doubleSeek(_doubleTapDx < width / 2),
            onHorizontalDragStart: scrubGesture
                ? (_) => setState(
                      () => _scrubMs =
                          controller.currentPosition.inMilliseconds.toDouble(),
                    )
                : null,
            onHorizontalDragUpdate: scrubGesture
                ? (DragUpdateDetails d) => _scrubUpdate(
                      d.primaryDelta ?? 0,
                      width,
                      controller.currentDuration,
                    )
                : null,
            onHorizontalDragEnd: scrubGesture
                ? (_) {
                    final double? ms = _scrubMs;
                    if (ms != null) {
                      controller.seekTo(Duration(milliseconds: ms.round()));
                    }
                    setState(() => _scrubMs = null);
                  }
                : null,
            onVerticalDragStart: gestures
                ? (DragStartDetails d) =>
                    _verticalStart(d.localPosition.dx < width / 2)
                : null,
            onVerticalDragUpdate: gestures
                ? (DragUpdateDetails d) => _verticalUpdate(d.primaryDelta ?? 0)
                : null,
            onVerticalDragEnd:
                gestures ? (_) => setState(() => _hud = null) : null,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Video fills the stack: a Texture has no intrinsic size and
                // collapses to 0×0 under loose constraints (endless buffering).
                Positioned.fill(child: videoView),

                // While casting the local surface is idle (black); explain why
                // and name the receiver so the black screen isn't confusing.
                if (vm.castDevice != null)
                  IgnorePointer(
                    child: _CastingOverlay(device: vm.castDevice!),
                  ),

                // Brand watermark while watching (controls hidden).
                if (!vm.overlayVisible)
                  Positioned(
                    top: t.space.x6,
                    right: t.space.x4,
                    child: const IgnorePointer(
                      child: Opacity(
                        opacity: _kWatermarkOpacity,
                        child: LimeBeamMark(size: _kWatermarkSize),
                      ),
                    ),
                  ),

                // Full-screen spinner only when controls are hidden; while
                // they're shown the centre play button becomes the spinner
                // (avoids a spinner stacked behind the play glyph).
                if (vm.buffering && vm.error == null && !vm.overlayVisible)
                  const IgnorePointer(child: Center(child: _Buffering())),

                // Subtitle text for engines that don't burn subs into their own
                // surface (ExoPlayer). Inert otherwise (empty cue). Above the
                // video, below the controls so a shown HUD sits on top.
                const _SubtitleOverlay(),

                // Controls — above gestures; pointer-ignored + faded when hidden.
                // Empty areas pass through to the gesture surface (tap to
                // toggle). The subtree is *unmounted* while hidden (after the
                // fade) so playhead ticks never rebuild the gradient / bars /
                // seek bar — the main Fire TV jank source. [_Controls] watches
                // the live state itself, so it only rebuilds while mounted.
                _ControlsLayer(
                  visible: vm.overlayVisible,
                  duration: t.motion.base,
                  // On TV all playback uses the SurfaceView engine (video off
                  // the app GPU), so keep the controls mounted: their D-pad
                  // focus nodes stay attached (the remote can always reach
                  // play/CC/seek) and the HUD reveals instantly. Unmounting is
                  // only for the touch/texture path, where hidden rebuilds cost.
                  keepMounted: isTv,
                  builder: (BuildContext context) => _Controls(
                    request: request,
                    queue: queue,
                    controller: controller,
                    playFocusNode: _playFocusNode,
                    seekFocusNode: _seekFocusNode,
                    ccFocusNode: _ccFocusNode,
                    isLandscape: _landscape,
                    scrubbing: vm.scrubbing,
                    onToggleFullscreen: _toggleFullscreen,
                    onMinimize: () => Navigator.of(context).maybePop(),
                    onShowTracksPanel: isTv
                        ? () => setState(() => _tvPanelVisible = true)
                        : null,
                  ),
                ),

                // TV side panel — slides in from the right; contains the track
                // picker (audio + subtitles). Never rendered on touch devices.
                if (isTv)
                  _TvSidePanel(
                    controller: controller,
                    visible: _tvPanelVisible,
                    onClose: () {
                      setState(() => _tvPanelVisible = false);
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _playFocusNode.requestFocus(),
                      );
                    },
                  ),

                // Transient feedback — always on top, never blocks input.
                if (_scrubMs != null)
                  IgnorePointer(
                    child: Center(
                      child: _Pill(
                        text:
                            "${_formatDuration(Duration(milliseconds: _scrubMs!.round()))}"
                            " / ${_formatDuration(controller.currentDuration)}",
                      ),
                    ),
                  ),
                if (_hud != null)
                  IgnorePointer(
                    child: Center(
                      child: _HudIndicator(kind: _hud!, value: _hudValue),
                    ),
                  ),
                if (vm.seekFlash != null)
                  IgnorePointer(
                    child: Center(child: _Pill(text: vm.seekFlash!)),
                  ),

                if (vm.countdownSeconds > 0)
                  _NextEpisodeCard(
                    seconds: vm.countdownSeconds,
                    onPlayNow: controller.playNextNow,
                    onCancel: controller.cancelCountdown,
                  ),
                if (vm.error != null)
                  _ErrorOverlay(
                    failure: vm.error!,
                    onRetry: controller.retry,
                    isTv: isTv,
                  ),
              ],
            ),
          );
          // On TV the player owns key input; on touch it is returned as-is.
          if (!isTv) return gestureLayer;
          return Focus(
            focusNode: _tvFocusNode,
            // Pure key interceptor: it must NEVER hold focus or be a traversal
            // target. dpad owns focus (the play button is the screen's one
            // `autofocus`, and dpad's beam moves between the controls). Because
            // this node wraps the whole player, its onKeyEvent still fires for
            // the focused control's key events — so transport keys work — while
            // canRequestFocus:false stops it from stealing focus (which left the
            // remote dead) and skipTraversal keeps the beam off this
            // full-screen rect.
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: (FocusNode node, KeyEvent event) =>
                _handleTvKey(event, vm, controller, queue),
            child: gestureLayer,
          );
        },
      ),
    );
  }
}

/// Bare video surface (no controls/gestures) reading the app-scoped engine.
/// Used by the in-app floating PiP window so the app never imports media_kit.
class PlayerSurface extends ConsumerWidget {
  const PlayerSurface({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playbackControllerProvider); // rebuild when the engine swaps
    final Widget? view =
        ref.read(playbackControllerProvider.notifier).buildVideoView();
    if (view == null) return const ColoredBox(color: _kPlayerBackground);
    return view;
  }
}

class _Buffering extends StatelessWidget {
  const _Buffering();

  @override
  Widget build(BuildContext context) =>
      CircularProgressIndicator(color: context.appTheme.colors.accent);
}

/// Renders the current subtitle text for engines that don't paint subtitles
/// onto their own surface (ExoPlayer on Android TV). Watches only [subtitleCue]
/// so it rebuilds only when the caption changes; empty cue → nothing (so it is
/// inert for libmpv/AVPlayer, which burn subtitles into their video surface).
class _SubtitleOverlay extends ConsumerWidget {
  const _SubtitleOverlay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String cue = ref.watch(
      playbackControllerProvider.select((PlayerUiState s) => s.subtitleCue),
    );
    if (cue.isEmpty) return const SizedBox.shrink();
    final AppTheme t = context.appTheme;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: t.space.x10,
            left: t.space.x6,
            right: t.space.x6,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: _kPillBg),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space.x3,
                vertical: t.space.x1,
              ),
              child: Text(
                cue,
                textAlign: TextAlign.center,
                style: t.typography.bodyStrong.copyWith(
                  color: t.colors.textPrimary,
                  shadows: const <Shadow>[
                    Shadow(blurRadius: 4, color: Color(0xFF000000)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fades the controls in/out and, crucially, **unmounts** them once the
/// fade-out completes so the (state-watching) [_Controls] subtree stops
/// rebuilding while hidden. Ignores pointers whenever not visible so empty taps
/// fall through to the gesture surface. [builder] is only invoked while the
/// controls are on screen — during steady hidden playback nothing is built.
class _ControlsLayer extends StatefulWidget {
  const _ControlsLayer({
    required this.visible,
    required this.duration,
    required this.builder,
    this.keepMounted = false,
  });

  final bool visible;
  final Duration duration;
  final WidgetBuilder builder;

  /// Keep the subtree mounted while hidden (just fade it). Used on the
  /// SurfaceView live path: video is composited off the app GPU there, so the
  /// per-tick rebuild is cheap, and staying mounted makes the overlay appear
  /// instantly — no remount and no hybrid-composition overlay-surface spin-up
  /// on reveal. The texture path (VOD) leaves this false so hidden playback
  /// rebuilds nothing.
  final bool keepMounted;

  @override
  State<_ControlsLayer> createState() => _ControlsLayerState();
}

class _ControlsLayerState extends State<_ControlsLayer> {
  late bool _mounted = widget.visible || widget.keepMounted;

  @override
  void didUpdateWidget(_ControlsLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Becoming visible (or asked to stay mounted): mount so the reveal has
    // something to show without rebuilding first.
    if ((widget.visible || widget.keepMounted) && !_mounted) {
      setState(() => _mounted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.visible,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: widget.duration,
        // Fade-out finished → drop the subtree so it no longer rebuilds, unless
        // asked to stay mounted (live/SurfaceView path — instant reveal).
        onEnd: () {
          if (!widget.visible && !widget.keepMounted && _mounted) {
            setState(() => _mounted = false);
          }
        },
        child: _mounted ? widget.builder(context) : const SizedBox.shrink(),
      ),
    );
  }
}

/// The transport overlay (scrim + top/center/bottom bars). A plain
/// [StatelessWidget]: it does NOT watch player state, so the gradient scrim and
/// layout never rebuild on playhead ticks. Each bar is its own [ConsumerWidget]
/// watching only the narrow slice it needs, and the playhead (position /
/// duration) only rebuilds the small [_SeekSection] leaf. This keeps the UI
/// thread free during playback (the whole-tree 4 Hz rebuild otherwise starves
/// key input and ANRs on weak Fire TV hardware).
class _Controls extends StatelessWidget {
  const _Controls({
    required this.request,
    required this.queue,
    required this.controller,
    required this.playFocusNode,
    required this.seekFocusNode,
    required this.ccFocusNode,
    required this.isLandscape,
    required this.scrubbing,
    required this.onToggleFullscreen,
    required this.onMinimize,
    this.onShowTracksPanel,
  });

  final PlaybackRequest request;
  final PlaybackQueue queue;
  final PlaybackController controller;
  final FocusNode playFocusNode;
  final FocusNode seekFocusNode;
  final FocusNode ccFocusNode;
  final bool isLandscape;

  /// While true the user is holding to scrub — fade the top bar + centre
  /// controls so the video shows behind the seek bar.
  final bool scrubbing;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onMinimize;

  /// Non-null on TV: opens the side panel instead of a bottom sheet.
  final VoidCallback? onShowTracksPanel;

  @override
  Widget build(BuildContext context) {
    final bool isTv = FormFactorScope.isTv(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_kScrimTop, Color(0x00000000), _kScrimBottom],
          stops: <double>[0, 0.5, 1],
        ),
      ),
      // Gradient is full-width; only the controls content is constrained on TV
      // so the scrim stays edge-to-edge while buttons don't span a 55" screen.
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTv ? _kTvControlsMaxWidth : double.infinity,
            ),
            child: Column(
              children: <Widget>[
                // Chrome fades out while scrubbing (kept in the tree at opacity
                // 0 + ignored so focus nodes stay attached and layout is
                // stable); the seek bar below remains fully visible.
                AnimatedOpacity(
                  opacity: scrubbing ? 0 : 1,
                  duration: context.appTheme.motion.fast,
                  child: IgnorePointer(
                    ignoring: scrubbing,
                    child: _TopBar(request: request, onMinimize: onMinimize),
                  ),
                ),
                Expanded(
                  child: AnimatedOpacity(
                    opacity: scrubbing ? 0 : 1,
                    duration: context.appTheme.motion.fast,
                    child: IgnorePointer(
                      ignoring: scrubbing,
                      child: Center(
                        child: _CenterControls(
                          queue: queue,
                          controller: controller,
                          playFocusNode: playFocusNode,
                        ),
                      ),
                    ),
                  ),
                ),
                _BottomBar(
                  request: request,
                  queue: queue,
                  controller: controller,
                  seekFocusNode: seekFocusNode,
                  ccFocusNode: ccFocusNode,
                  isLandscape: isLandscape,
                  onToggleFullscreen: onToggleFullscreen,
                  onShowTracksPanel: onShowTracksPanel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.request, required this.onMinimize});

  final PlaybackRequest request;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    // Only the live badge depends on state; watch just that.
    final bool isLive = ref.watch(
      playbackControllerProvider.select((PlayerUiState s) => s.isLive),
    );
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x2, vertical: t.space.x1),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down, color: t.colors.textPrimary),
            onPressed: onMinimize,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  request.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.h3.copyWith(color: t.colors.textPrimary),
                ),
                if (request.subtitle != null && request.subtitle!.isNotEmpty)
                  Text(
                    request.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.typography.caption
                        .copyWith(color: t.colors.textSecondary),
                  ),
              ],
            ),
          ),
          if (isLive) ...<Widget>[
            SizedBox(width: t.space.x2),
            const _LiveBadge(),
            SizedBox(width: t.space.x2),
          ],
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: _kLiveDotSize,
          height: _kLiveDotSize,
          decoration: BoxDecoration(
            color: t.colors.live,
            borderRadius: t.radius.fullAll,
          ),
        ),
        SizedBox(width: t.space.x1),
        Text(
          AppLocalizations.of(context).playerLive,
          style: t.typography.micro.copyWith(color: t.colors.textPrimary),
        ),
      ],
    );
  }
}

class _CenterControls extends ConsumerWidget {
  const _CenterControls({
    required this.queue,
    required this.controller,
    required this.playFocusNode,
  });

  final PlaybackQueue queue;
  final PlaybackController controller;

  /// Receives focus when the overlay becomes visible on TV.
  final FocusNode playFocusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final bool hasSiblings = queue.hasSiblings;
    // Watch only the transport fields — never position/duration, so the play
    // glyph doesn't rebuild on every playhead tick.
    final ({bool playing, bool buffering, int queueIndex}) state = ref.watch(
      playbackControllerProvider.select(
        (PlayerUiState s) => (
          playing: s.playing,
          buffering: s.buffering,
          queueIndex: s.queueIndex,
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (hasSiblings)
          IconButton(
            iconSize: _kSkipButtonSize,
            icon: Icon(Icons.skip_previous, color: t.colors.textPrimary),
            onPressed: state.queueIndex > 0 ? controller.playPrevious : null,
          ),
        SizedBox(width: t.space.x4),
        // Always mount the PressableScale that owns [playFocusNode], even while
        // buffering — otherwise revealing the overlay right after a channel /
        // episode switch focuses an unmounted node and the remote goes dead
        // (the buffering spinner just swaps in as its child).
        PressableScale(
          focusNode: playFocusNode,
          // dpad's "one autofocus per screen": the primary action anchors the
          // remote when the player opens, so focus is never null (a null focus
          // is a dead remote). dpad's beam moves off it to the other controls.
          autofocus: true,
          onTap: controller.playOrPause,
          focusBorderRadius: t.radius.fullAll,
          child: SizedBox(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
            child: state.buffering
                ? Padding(
                    padding: EdgeInsets.all(t.space.x3),
                    child: CircularProgressIndicator(color: t.colors.accent),
                  )
                : Icon(
                    state.playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: _kPlayButtonSize,
                    color: t.colors.textPrimary,
                  ),
          ),
        ),
        SizedBox(width: t.space.x4),
        if (hasSiblings)
          IconButton(
            iconSize: _kSkipButtonSize,
            icon: Icon(Icons.skip_next, color: t.colors.textPrimary),
            onPressed: state.queueIndex < queue.items.length - 1
                ? controller.playNext
                : null,
          ),
      ],
    );
  }
}

class _BottomBar extends ConsumerWidget {
  const _BottomBar({
    required this.request,
    required this.queue,
    required this.controller,
    required this.seekFocusNode,
    required this.ccFocusNode,
    required this.isLandscape,
    required this.onToggleFullscreen,
    this.onShowTracksPanel,
  });

  final PlaybackRequest request;
  final PlaybackQueue queue;
  final PlaybackController controller;
  final FocusNode seekFocusNode;
  final FocusNode ccFocusNode;
  final bool isLandscape;
  final VoidCallback onToggleFullscreen;

  /// Non-null on TV: opens the side panel instead of a bottom sheet.
  final VoidCallback? onShowTracksPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final bool isTv = FormFactorScope.isTv(context);
    final AppLocalizations l = AppLocalizations.of(context);
    // Position/duration are consumed by the [_SeekSection] leaf below — not
    // here — so this bar doesn't rebuild on every playhead tick.
    final ({bool isLive, PlayerTracks tracks, int queueIndex, bool videoFill})
        state = ref.watch(
      playbackControllerProvider.select(
        (PlayerUiState s) => (
          isLive: s.isLive,
          tracks: s.tracks,
          queueIndex: s.queueIndex,
          videoFill: s.videoFill,
        ),
      ),
    );
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!state.isLive)
            _SeekSection(
              controller: controller,
              isTv: isTv,
              focusNode: seekFocusNode,
            ),
          Row(
            children: <Widget>[
              if (queue.hasSiblings)
                // PressableScale wrapper gives the TV focus ring to the queue
                // button (TextButton.icon has no focus ring affordance).
                PressableScale(
                  onTap: () => _showQueue(context, state.queueIndex),
                  focusBorderRadius: t.radius.smAll,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space.x2,
                      vertical: t.space.x2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.playlist_play,
                          color: t.colors.textPrimary,
                        ),
                        SizedBox(width: t.space.x1),
                        Text(
                          request.isLive ? l.playerChannels : l.playerEpisodes,
                          style: t.typography.bodyStrong
                              .copyWith(color: t.colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              if (state.tracks.hasAny)
                AppIconButton(
                  icon: state.tracks.hasSubtitleOn
                      ? Icons.closed_caption
                      : Icons.closed_caption_outlined,
                  active: state.tracks.hasSubtitleOn,
                  focusNode: ccFocusNode,
                  onPressed: () => _showTracks(context),
                ),
              const _PipButton(),
              _CastButton(controller: controller),
              // Zoom-to-fill toggle (YouTube/Netflix): crop the video to cover
              // the screen instead of letterboxing. The main way to "go
              // fullscreen" on TV, where the orientation toggle is meaningless.
              AppIconButton(
                icon: state.videoFill
                    ? Icons.fullscreen_exit
                    : Icons.aspect_ratio,
                active: state.videoFill,
                onPressed: controller.toggleVideoFill,
              ),
              // No orientation toggle on TV — it is already full-screen
              // landscape and has no portrait mode.
              if (!isTv)
                AppIconButton(
                  icon: isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
                  onPressed: onToggleFullscreen,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQueue(BuildContext context, int currentIndex) {
    final AppLocalizations l = AppLocalizations.of(context);
    AppBottomSheet.show<void>(
      context,
      title: request.isLive ? l.playerChannels : l.playerEpisodes,
      child: _QueueList(
        queue: queue,
        currentIndex: currentIndex,
        onSelect: (int index) {
          controller.playAt(index);
          Navigator.of(context).maybePop();
        },
      ),
    );
  }

  void _showTracks(BuildContext context) {
    // TV: delegate to the side panel callback (set by _PlayerViewState).
    if (onShowTracksPanel != null) {
      onShowTracksPanel!();
      return;
    }
    AppBottomSheet.show<void>(
      context,
      title: AppLocalizations.of(context).playerTracks,
      child: _TracksSheet(controller: controller),
    );
  }
}

/// Audio + subtitle track picker and (where supported) sync offsets. Reads the
/// live player state via [ref]; every row delegates to the controller.
class _TracksSheet extends ConsumerWidget {
  const _TracksSheet({required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlayerUiState state = ref.watch(playbackControllerProvider);
    final PlayerTracks tracks = state.tracks;
    return ListView(
      shrinkWrap: true,
      children: <Widget>[
        if (tracks.audio.isNotEmpty) ...<Widget>[
          _TrackSectionHeader(label: AppLocalizations.of(context).playerAudio),
          for (final MediaTrack track in tracks.audio)
            _TrackTile(
              label: _trackLabel(track, AppLocalizations.of(context)),
              selected: track.id == tracks.selectedAudioId,
              onTap: () => controller.selectAudioTrack(track.id),
            ),
        ],
        if (tracks.subtitle.isNotEmpty) ...<Widget>[
          _TrackSectionHeader(
            label: AppLocalizations.of(context).playerSubtitles,
          ),
          _TrackTile(
            label: AppLocalizations.of(context).playerSubtitlesOff,
            selected: !tracks.hasSubtitleOn,
            onTap: () => controller.selectSubtitleTrack(MediaTrack.noneId),
          ),
          for (final MediaTrack track in tracks.subtitle)
            _TrackTile(
              label: _trackLabel(track, AppLocalizations.of(context)),
              selected: track.id == tracks.selectedSubtitleId,
              onTap: () => controller.selectSubtitleTrack(track.id),
            ),
        ],
        if (state.supportsSyncOffsets) ...<Widget>[
          _TrackSectionHeader(label: AppLocalizations.of(context).playerSync),
          _SyncRow(
            label: AppLocalizations.of(context).playerSubtitles,
            valueMs: state.subtitleDelayMs,
            onChanged: controller.setSubtitleDelay,
          ),
          _SyncRow(
            label: AppLocalizations.of(context).playerAudio,
            valueMs: state.audioDelayMs,
            onChanged: controller.setAudioDelay,
          ),
        ],
      ],
    );
  }

  /// Human label for a track row, falling back to language then a generic id.
  String _trackLabel(MediaTrack track, AppLocalizations l) =>
      track.label ?? l.playerTrackFallback(track.id);
}

class _TrackSectionHeader extends StatelessWidget {
  const _TrackSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding:
          EdgeInsets.fromLTRB(t.space.x4, t.space.x3, t.space.x4, t.space.x1),
      child: Text(
        label,
        style: t.typography.caption.copyWith(color: t.colors.textTertiary),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListTile(
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: t.typography.body.copyWith(
          color: selected ? t.colors.accent : t.colors.textPrimary,
        ),
      ),
      trailing: selected ? Icon(Icons.check, color: t.colors.accent) : null,
      onTap: onTap,
    );
  }
}

/// A label + current offset + −/+ steppers for one sync axis. Pure UI: the
/// clamp/business logic lives in the controller.
class _SyncRow extends StatelessWidget {
  const _SyncRow({
    required this.label,
    required this.valueMs,
    required this.onChanged,
  });

  final String label;
  final int valueMs;
  final void Function(int milliseconds) onChanged;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x1),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
          ),
          IconButton(
            icon: Icon(Icons.remove, color: t.colors.textPrimary),
            onPressed: () => onChanged(valueMs - _kSyncStepMs),
          ),
          SizedBox(
            width: _kSyncValueWidth,
            child: Text(
              _formatOffset(valueMs),
              textAlign: TextAlign.center,
              style: t.typography.bodyStrong.copyWith(color: t.colors.accent),
            ),
          ),
          IconButton(
            icon: Icon(Icons.add, color: t.colors.textPrimary),
            onPressed: () => onChanged(valueMs + _kSyncStepMs),
          ),
        ],
      ),
    );
  }

  /// Signed offset in seconds, e.g. "0 s", "+0.25 s", "-0.5 s".
  String _formatOffset(int milliseconds) {
    if (milliseconds == 0) return "0 s";
    final String sign = milliseconds > 0 ? "+" : "-";
    final double seconds = milliseconds.abs() / _kMillisPerSecond;
    return "$sign$seconds s";
  }
}

/// Scrubber + time labels. A leaf [ConsumerWidget] that watches ONLY the
/// playhead (position/duration), so the ~4 Hz updates rebuild just this small
/// subtree — never the whole controls tree (which starved the UI thread and
/// ANR'd on weak Fire TV hardware). VOD only (live has no seek bar).
class _SeekSection extends ConsumerWidget {
  const _SeekSection({
    required this.controller,
    required this.isTv,
    required this.focusNode,
  });

  final PlaybackController controller;
  final bool isTv;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final ({Duration position, Duration duration}) vm = ref.watch(
      playbackControllerProvider.select(
        (PlayerUiState s) => (position: s.position, duration: s.duration),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SeekBar(
          position: vm.position,
          duration: vm.duration,
          onSeek: controller.seekTo,
          isTv: isTv,
          focusNode: focusNode,
          onScrubbing: (bool active) =>
              controller.setScrubbing(active: active),
        ),
        Row(
          children: <Widget>[
            Text(
              _formatDuration(vm.position),
              style:
                  t.typography.caption.copyWith(color: t.colors.textSecondary),
            ),
            const Spacer(),
            Text(
              _formatDuration(vm.duration),
              style:
                  t.typography.caption.copyWith(color: t.colors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

/// Base step per ◀/▶ press while scrubbing on TV. Holding accelerates: each
/// key-repeat adds a step multiplier so a long press travels far, matching
/// how TV players fast-forward the longer the button is held.
const int _kTvScrubStepMs = 10000;

/// Cap on the hold-acceleration multiplier (base step × this at most).
const int _kMaxScrubMultiplier = 12;

/// Idle delay after the last ◀/▶ press before the pending scrub is committed.
const Duration _kScrubCommitDelay = Duration(milliseconds: 700);

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
    this.isTv = false,
    this.focusNode,
    this.onScrubbing,
  });

  final Duration position;
  final Duration duration;
  final void Function(Duration target) onSeek;

  /// On TV the bar becomes a focusable D-pad scrubber: ◀/▶ move a *preview*
  /// cursor without seeking; the jump is committed on OK or after a short
  /// idle delay (so you pick the exact spot instead of stepping ±10s live).
  final bool isTv;

  /// External node so the player's ordered up/down navigation can focus the
  /// bar directly (the beam couldn't reliably reach it).
  final FocusNode? focusNode;

  /// Fired with `true` when a preview scrub begins and `false` when it commits,
  /// so the player can fade the chrome and pin the overlay open meanwhile.
  final ValueChanged<bool>? onScrubbing;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;
  // Preview position selected with the remote, not yet committed.
  double? _pendingMs;
  Timer? _commitTimer;
  bool _focused = false;
  // Consecutive ◀/▶ repeats in the current hold — drives acceleration.
  int _repeat = 0;

  @override
  void dispose() {
    _commitTimer?.cancel();
    super.dispose();
  }

  double get _maxMs =>
      widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);

  /// Moves the preview cursor by an accelerating step and (re)arms the
  /// idle-commit timer. [repeat] is true for held-key auto-repeat events.
  void _scrubBy({required bool forward, required bool repeat}) {
    if (repeat) {
      _repeat++;
    } else {
      _repeat = 0;
    }
    // Grow the step every few repeats, capped, so a held button ramps up.
    final int multiplier = (1 + _repeat ~/ 3).clamp(1, _kMaxScrubMultiplier);
    final int deltaMs = _kTvScrubStepMs * multiplier * (forward ? 1 : -1);
    final double base =
        _pendingMs ?? widget.position.inMilliseconds.toDouble();
    final bool starting = _pendingMs == null;
    setState(() => _pendingMs = (base + deltaMs).clamp(0, _maxMs));
    if (starting) widget.onScrubbing?.call(true);
    _commitTimer?.cancel();
    _commitTimer = Timer(_kScrubCommitDelay, _commit);
  }

  /// Applies the pending preview position as a real seek.
  void _commit() {
    _commitTimer?.cancel();
    _repeat = 0;
    final double? ms = _pendingMs;
    if (ms == null) return;
    widget.onSeek(Duration(milliseconds: ms.round()));
    widget.onScrubbing?.call(false);
    if (mounted) setState(() => _pendingMs = null);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final bool repeat = event is KeyRepeatEvent;
    final LogicalKeyboardKey key = event.logicalKey;
    // ◀/▶ move the preview cursor and are consumed so focus stays on the bar.
    if (key == LogicalKeyboardKey.arrowLeft) {
      _scrubBy(forward: false, repeat: repeat);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _scrubBy(forward: true, repeat: repeat);
      return KeyEventResult.handled;
    }
    // OK/Select commits the pending jump immediately (skip the idle wait).
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.gameButtonA ||
        key == LogicalKeyboardKey.space) {
      if (_pendingMs != null) {
        _commit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    // Leaving the bar (▲/▼) commits any pending jump first, then lets the
    // focus system move away.
    if (_pendingMs != null) _commit();
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final double max = _maxMs;
    final double current =
        (_pendingMs ?? _dragValue ?? widget.position.inMilliseconds.toDouble())
            .clamp(0, max);
    final Widget slider = SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: t.colors.accent,
        inactiveTrackColor: t.colors.borderDefault,
        thumbColor: t.colors.accent,
        overlayColor: t.colors.accentSubtle,
      ),
      child: Slider(
        value: current,
        max: max,
        onChanged: (double v) => setState(() => _dragValue = v),
        onChangeEnd: (double v) {
          widget.onSeek(Duration(milliseconds: v.round()));
          setState(() => _dragValue = null);
        },
      ),
    );

    if (!widget.isTv) return slider;

    // A time bubble above the thumb shows the target while previewing so the
    // user sees exactly where the jump will land before committing.
    final Widget bar = Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ExcludeFocus(child: slider),
        if (_pendingMs != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final double fraction = max <= 0 ? 0 : (_pendingMs! / max);
                return Align(
                  alignment: Alignment(fraction * 2 - 1, -1.8),
                  child: _Pill(
                    text: _formatDuration(
                      Duration(milliseconds: _pendingMs!.round()),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );

    // The Material Slider's own focus is excluded so the remote's ◀/▶ aren't
    // double-handled; our Focus owns the keys and the glass focus ring.
    return Focus(
      debugLabel: "player-seek",
      focusNode: widget.focusNode,
      onFocusChange: (bool f) {
        setState(() => _focused = f);
        // Losing focus commits any pending jump so it isn't dropped silently.
        if (!f && _pendingMs != null) _commit();
      },
      onKeyEvent: _onKey,
      child: AnimatedContainer(
        duration: t.motion.fast,
        decoration: focusFloat(t, t.radius.smAll, focused: _focused),
        foregroundDecoration: focusSkin(t, t.radius.smAll, focused: _focused),
        child: bar,
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({
    required this.queue,
    required this.currentIndex,
    required this.onSelect,
  });

  final PlaybackQueue queue;
  final int currentIndex;
  final void Function(int index) onSelect;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: queue.items.length,
      itemBuilder: (BuildContext context, int index) {
        final PlaybackRequest item = queue.items[index];
        final bool selected = index == currentIndex;
        return ListTile(
          leading: _QueueThumb(item: item, selected: selected),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typography.body.copyWith(
              color: selected ? t.colors.accent : t.colors.textPrimary,
            ),
          ),
          subtitle: item.subtitle == null || item.subtitle!.isEmpty
              ? null
              : Text(
                  item.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.caption
                      .copyWith(color: t.colors.textSecondary),
                ),
          onTap: () => onSelect(index),
        );
      },
    );
  }
}

class _QueueThumb extends StatelessWidget {
  const _QueueThumb({required this.item, required this.selected});

  final PlaybackRequest item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final String? url = item.posterUrl;
    if (url == null || url.isEmpty) {
      return Icon(
        selected ? Icons.play_arrow : Icons.circle_outlined,
        color: selected ? t.colors.accent : t.colors.textTertiary,
      );
    }
    return ClipRRect(
      borderRadius: t.radius.smAll,
      child: Image.network(
        url,
        width: _kQueueThumbSize,
        height: _kQueueThumbSize,
        fit: BoxFit.cover,
        errorBuilder: (BuildContext c, Object e, StackTrace? s) => Icon(
          selected ? Icons.play_arrow : Icons.tv,
          color: selected ? t.colors.accent : t.colors.textTertiary,
        ),
      ),
    );
  }
}

/// Enters OS Picture-in-Picture (Android only — media_kit's libmpv texture has
/// no AVPlayerLayer for native iOS PiP, so the button is hidden there).
class _PipButton extends StatelessWidget {
  const _PipButton();

  @override
  Widget build(BuildContext context) {
    // Android-only, and never on TV (full-screen only — no floating window).
    if (defaultTargetPlatform != TargetPlatform.android ||
        FormFactorScope.isTv(context)) {
      return const SizedBox.shrink();
    }
    final AppTheme t = context.appTheme;
    return IconButton(
      icon: Icon(Icons.picture_in_picture_alt, color: t.colors.textPrimary),
      onPressed: _enterPip,
    );
  }

  Future<void> _enterPip() async {
    const PipService pip = PipService();
    if (await pip.isSupported()) await pip.enter();
  }
}

/// Cast button: opens the device picker, then lights up (lime) while a TV owns
/// playback. Hidden entirely when casting is unavailable on this build.
class _CastButton extends ConsumerWidget {
  const _CastButton({required this.controller});

  final PlaybackController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // No casting from a TV — it is already the cast target. Also hidden when
    // casting is unavailable on this build.
    if (!controller.canCast || FormFactorScope.isTv(context)) {
      return const SizedBox.shrink();
    }
    final AppTheme t = context.appTheme;
    final bool casting = ref.watch(
      playbackControllerProvider.select(
        (PlayerUiState s) => s.castDevice != null,
      ),
    );
    return IconButton(
      icon: Icon(
        casting ? Icons.cast_connected : Icons.cast,
        color: casting ? t.colors.accent : t.colors.textPrimary,
      ),
      onPressed: () => _open(context),
    );
  }

  void _open(BuildContext context) {
    AppBottomSheet.show<void>(
      context,
      title: AppLocalizations.of(context).castTo,
      child: _CastDeviceSheet(controller: controller),
    );
  }
}

/// Centred "now casting" message over the idle local surface.
class _CastingOverlay extends StatelessWidget {
  const _CastingOverlay({required this.device});

  final CastDevice device;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.cast_connected,
            size: _kPlayButtonSize,
            color: t.colors.accent,
          ),
          SizedBox(height: t.space.x4),
          Text(
            AppLocalizations.of(context).castingOn,
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x1),
          Text(
            device.name,
            style: t.typography.h3.copyWith(color: t.colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Device-picker sheet body. Starts Chromecast discovery on open and stops it
/// on close (the subscription/timer live in the notifier, not here). On iOS the
/// native AirPlay route picker is shown above the Chromecast list.
class _CastDeviceSheet extends ConsumerStatefulWidget {
  const _CastDeviceSheet({required this.controller});

  final PlaybackController controller;

  @override
  ConsumerState<_CastDeviceSheet> createState() => _CastDeviceSheetState();
}

class _CastDeviceSheetState extends ConsumerState<_CastDeviceSheet> {
  @override
  void initState() {
    super.initState();
    // Defer to after first frame so we mutate the provider outside build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(castDevicesProvider.notifier).startDiscovery();
    });
  }

  @override
  void dispose() {
    ref.read(castDevicesProvider.notifier).stopDiscovery();
    super.dispose();
  }

  void _onSelect(CastDevice device) {
    widget.controller.castTo(device);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<CastDevice>> devices =
        ref.watch(castDevicesProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (defaultTargetPlatform == TargetPlatform.iOS) ...<Widget>[
          const AirPlayRouteTile(),
          Divider(color: t.colors.borderSubtle, height: t.space.x6),
        ],
        switch (devices) {
          AsyncIdle<IList<CastDevice>>() ||
          AsyncLoading<IList<CastDevice>>() =>
            const _CastDiscovering(),
          AsyncSuccess<IList<CastDevice>>(:final IList<CastDevice> data) =>
            data.isEmpty
                ? const _CastDiscovering()
                : _CastDeviceList(devices: data, onSelect: _onSelect),
          AsyncError<IList<CastDevice>>(:final Failures failure) => EmptyState(
              icon: Icons.cast,
              title: AppLocalizations.of(context).castUnavailableTitle,
              message: failure.localized(AppLocalizations.of(context)),
            ),
        },
      ],
    );
  }
}

/// Shown while scanning the network (no devices yet).
class _CastDiscovering extends StatelessWidget {
  const _CastDiscovering();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.x6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            width: _kHudIconSize,
            height: _kHudIconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(t.colors.accent),
            ),
          ),
          SizedBox(width: t.space.x3),
          Text(
            AppLocalizations.of(context).castDiscovering,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CastDeviceList extends StatelessWidget {
  const _CastDeviceList({required this.devices, required this.onSelect});

  final IList<CastDevice> devices;
  final void Function(CastDevice device) onSelect;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView.builder(
      shrinkWrap: true,
      itemCount: devices.length,
      itemBuilder: (BuildContext context, int index) {
        final CastDevice device = devices[index];
        return ListTile(
          leading: Icon(Icons.tv, color: t.colors.textPrimary),
          title: Text(
            device.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.typography.body.copyWith(color: t.colors.textPrimary),
          ),
          onTap: () => onSelect(device),
        );
      },
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return GlassSurface(
      kind: GlassKind.pill,
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x2),
      child: Text(
        text,
        style: t.typography.bodyStrong.copyWith(color: t.colors.textPrimary),
      ),
    );
  }
}

class _HudIndicator extends StatelessWidget {
  const _HudIndicator({required this.kind, required this.value});

  final _Hud kind;
  final double value;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return GlassSurface(
      kind: GlassKind.pill,
      radius: t.radius.lgAll,
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            kind == _Hud.brightness ? Icons.brightness_6 : Icons.volume_up,
            color: t.colors.accent,
            size: _kHudIconSize,
          ),
          SizedBox(width: t.space.x3),
          Text(
            "${(value * 100).round()}%",
            style:
                t.typography.bodyStrong.copyWith(color: t.colors.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// Netflix-style "next episode" countdown card (bottom-right).
class _NextEpisodeCard extends StatelessWidget {
  const _NextEpisodeCard({
    required this.seconds,
    required this.onPlayNow,
    required this.onCancel,
  });

  final int seconds;
  final VoidCallback onPlayNow;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Positioned(
      right: t.space.x4,
      bottom: t.space.x10,
      child: GlassSurface(
        kind: GlassKind.panel,
        padding: EdgeInsets.all(t.space.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              AppLocalizations.of(context).nextEpisodeIn(seconds),
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
            SizedBox(height: t.space.x3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    AppLocalizations.of(context).commonCancel,
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.textSecondary),
                  ),
                ),
                SizedBox(width: t.space.x2),
                PrimaryButton(
                  label: AppLocalizations.of(context).commonPlay,
                  expand: false,
                  onPressed: onPlayNow,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({
    required this.failure,
    required this.onRetry,
    this.isTv = false,
  });

  final Failures failure;
  final VoidCallback onRetry;
  final bool isTv;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // Opaque backdrop so the paused player never shows through; a FocusScope
    // with the Retry button autofocused keeps the remote's focus ring on the
    // overlay (transport keys are already swallowed upstream in _handleTvKey).
    return FocusScope(
      autofocus: isTv,
      child: ColoredBox(
        color: _kPillBg,
        child: SafeArea(
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: t.colors.textPrimary),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: AppLocalizations.of(context).playerError,
                  message: failure.localized(AppLocalizations.of(context)),
                  action: PrimaryButton(
                    label: AppLocalizations.of(context).commonRetry,
                    expand: false,
                    autofocus: isTv,
                    onPressed: onRetry,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDuration(Duration d) {
  final int totalSeconds = d.inSeconds;
  final int hours = totalSeconds ~/ 3600;
  final int minutes = (totalSeconds % 3600) ~/ 60;
  final int seconds = totalSeconds % 60;
  final String mm = minutes.toString().padLeft(2, "0");
  final String ss = seconds.toString().padLeft(2, "0");
  return hours > 0 ? "$hours:$mm:$ss" : "$mm:$ss";
}

// ── TV side panel — track picker ─────────────────────────────────────────────

/// Slide-in panel on the right side of the player screen for TV/D-pad track
/// selection. Replaces the bottom sheet so the user can navigate with
/// up/down without having to interact with a modal overlay.
class _TvSidePanel extends ConsumerWidget {
  const _TvSidePanel({
    required this.controller,
    required this.visible,
    required this.onClose,
  });

  final PlaybackController controller;
  final bool visible;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    // Watch only the track list — the panel is independent of the playhead.
    final PlayerTracks tracks = ref.watch(
      playbackControllerProvider.select((PlayerUiState s) => s.tracks),
    );

    return AnimatedPositioned(
      duration: _kTvPanelDuration,
      curve: Curves.easeOut,
      top: 0,
      bottom: 0,
      right: visible ? 0 : -_kTvPanelWidth,
      width: _kTvPanelWidth,
      child: ColoredBox(
        color: const Color(0xEE0A0A0A),
        // Build the rows ONLY while open. An always-mounted list never re-fires
        // `autofocus` when it slides in, so the D-pad never entered the panel.
        // Building on open makes the first row's autofocus fire; the FocusScope
        // contains traversal to the panel (no wandering into the controls
        // behind it), and closing returns focus to the play button.
        child: visible
            ? FocusScope(
                child: SafeArea(
                  child: ListView(
                    padding: EdgeInsets.symmetric(vertical: t.space.x4),
                    children: <Widget>[
                      if (tracks.audio.isNotEmpty) ...<Widget>[
                        _TvPanelHeader(label: l.playerAudio),
                        for (int i = 0; i < tracks.audio.length; i++)
                          _TvTrackItem(
                            label: _trackLabel(tracks.audio[i], l),
                            selected:
                                tracks.audio[i].id == tracks.selectedAudioId,
                            autofocus: i == 0,
                            onTap: () {
                              controller.selectAudioTrack(tracks.audio[i].id);
                              onClose();
                            },
                          ),
                      ],
                      if (tracks.subtitle.isNotEmpty) ...<Widget>[
                        _TvPanelHeader(label: l.playerSubtitles),
                        _TvTrackItem(
                          label: l.playerSubtitlesOff,
                          selected: !tracks.hasSubtitleOn,
                          autofocus: tracks.audio.isEmpty,
                          onTap: () {
                            controller.selectSubtitleTrack(MediaTrack.noneId);
                            onClose();
                          },
                        ),
                        for (final MediaTrack track in tracks.subtitle)
                          _TvTrackItem(
                            label: _trackLabel(track, l),
                            selected: track.id == tracks.selectedSubtitleId,
                            onTap: () {
                              controller.selectSubtitleTrack(track.id);
                              onClose();
                            },
                          ),
                      ],
                    ],
                  ),
                ),
              )
            : const SizedBox.expand(),
      ),
    );
  }

  String _trackLabel(MediaTrack track, AppLocalizations l) =>
      track.label ?? l.playerTrackFallback(track.id);
}

class _TvPanelHeader extends StatelessWidget {
  const _TvPanelHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding:
          EdgeInsets.fromLTRB(t.space.x4, t.space.x3, t.space.x4, t.space.x1),
      child: Text(
        label,
        style: t.typography.caption.copyWith(color: t.colors.textTertiary),
      ),
    );
  }
}

class _TvTrackItem extends StatelessWidget {
  const _TvTrackItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.autofocus = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return PressableScale(
      onTap: onTap,
      autofocus: autofocus,
      focusBorderRadius: t.radius.smAll,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.x4,
          vertical: t.space.x3,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.body.copyWith(
                  color: selected ? t.colors.accent : t.colors.textPrimary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, size: 18, color: t.colors.accent),
          ],
        ),
      ),
    );
  }
}

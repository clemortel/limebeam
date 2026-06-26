import "dart:async";

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:media_kit_video/media_kit_video.dart";
import "package:screen_brightness/screen_brightness.dart";

import "../domain/playback_queue.dart";
import "../domain/playback_request.dart";
import "../pip/pip_service.dart";
import "../riverpods/player_controller.dart";
import "../riverpods/player_ui_state.dart";

const double _kPlayButtonSize = 72;
const double _kSkipButtonSize = 40;
const double _kLiveDotSize = 8;
const double _kQueueThumbSize = 44;
const double _kWatermarkSize = 26;
const double _kWatermarkOpacity = 0.55;
const double _kHudIconSize = 28;

/// Vertical drag pixels for a full-range (0→100%) volume/brightness change.
const double _kVolumeDragSpan = 300;
const int _kSeekFlashMs = 700;
const Color _kPlayerBackground = Color(0xFF000000);
const Color _kScrimTop = Color(0x99000000);
const Color _kScrimBottom = Color(0xCC000000);
const Color _kPillBg = Color(0xCC000000);

/// Which level the gesture HUD is showing.
enum _Hud { volume, brightness }

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
  String? _seekFlash;
  Timer? _flashTimer;

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
  void dispose() {
    _flashTimer?.cancel();
    // Popped (minimized) → show the floating window, keep playing.
    _controller.setExpanded(false);
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
    isLeft ? _controller.seekBackward() : _controller.seekForward();
    setState(() => _seekFlash = isLeft ? "− 10s" : "+ 10s");
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: _kSeekFlashMs), () {
      if (mounted) setState(() => _seekFlash = null);
    });
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

  void _scrubUpdate(double delta, double width, Duration duration) {
    final double total = duration.inMilliseconds.toDouble();
    final double base = _scrubMs ?? 0;
    setState(() => _scrubMs = (base + delta / width * total).clamp(0, total));
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final PlayerUiState state = ref.watch(playbackControllerProvider);
    final PlaybackController controller = _controller;
    final PlaybackQueue? queue = controller.queue;
    final PlaybackRequest? request = controller.currentRequest;
    final VideoController? videoController = controller.videoController;

    if (!state.active ||
        queue == null ||
        request == null ||
        videoController == null) {
      return const Scaffold(backgroundColor: _kPlayerBackground);
    }

    final bool canScrub = !state.isLive && state.duration > Duration.zero;
    final bool gestures = queue.gesturesEnabled;

    return Scaffold(
      backgroundColor: _kPlayerBackground,
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final double width = c.maxWidth;
          // Ancestor of the whole player: descendant buttons win their own
          // taps; every empty tap / double-tap / drag falls through to here.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (_) => controller.toggleOverlay(),
            onDoubleTapDown: (TapDownDetails d) =>
                _doubleTapDx = d.localPosition.dx,
            onDoubleTap: state.isLive
                ? null
                : () => _doubleSeek(_doubleTapDx < width / 2),
            onHorizontalDragStart: canScrub
                ? (_) => setState(
                      () => _scrubMs = state.position.inMilliseconds.toDouble(),
                    )
                : null,
            onHorizontalDragUpdate: canScrub
                ? (DragUpdateDetails d) =>
                    _scrubUpdate(d.primaryDelta ?? 0, width, state.duration)
                : null,
            onHorizontalDragEnd: canScrub
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
                Positioned.fill(
                  child: Video(
                    controller: videoController,
                    controls: null,
                    fit: BoxFit.contain,
                  ),
                ),

                // While casting the local surface is idle (black); explain why
                // and name the receiver so the black screen isn't confusing.
                if (state.castDevice != null)
                  IgnorePointer(
                    child: _CastingOverlay(device: state.castDevice!),
                  ),

                // Brand watermark while watching (controls hidden).
                if (!state.overlayVisible)
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
                if (state.buffering &&
                    state.error == null &&
                    !state.overlayVisible)
                  const IgnorePointer(child: Center(child: _Buffering())),

                // Controls — above gestures; pointer-ignored + faded when hidden.
                // Empty areas pass through to the gesture surface (tap to toggle).
                IgnorePointer(
                  ignoring: !state.overlayVisible,
                  child: AnimatedOpacity(
                    opacity: state.overlayVisible ? 1 : 0,
                    duration: t.motion.base,
                    child: _Controls(
                      state: state,
                      request: request,
                      queue: queue,
                      controller: controller,
                      isLandscape: _landscape,
                      onToggleFullscreen: _toggleFullscreen,
                      onMinimize: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),

                // Transient feedback — always on top, never blocks input.
                if (_scrubMs != null)
                  IgnorePointer(
                    child: Center(
                      child: _Pill(
                        text:
                            "${_formatDuration(Duration(milliseconds: _scrubMs!.round()))}"
                            " / ${_formatDuration(state.duration)}",
                      ),
                    ),
                  ),
                if (_hud != null)
                  IgnorePointer(
                    child: Center(
                      child: _HudIndicator(kind: _hud!, value: _hudValue),
                    ),
                  ),
                if (_seekFlash != null)
                  IgnorePointer(child: Center(child: _Pill(text: _seekFlash!))),

                if (state.countdownSeconds > 0)
                  _NextEpisodeCard(
                    seconds: state.countdownSeconds,
                    onPlayNow: controller.playNextNow,
                    onCancel: controller.cancelCountdown,
                  ),
                if (state.error != null)
                  _ErrorOverlay(
                    failure: state.error!,
                    onRetry: controller.retry,
                  ),
              ],
            ),
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
    final VideoController? vc =
        ref.read(playbackControllerProvider.notifier).videoController;
    if (vc == null) return const ColoredBox(color: _kPlayerBackground);
    return Video(controller: vc, controls: null, fit: BoxFit.contain);
  }
}

class _Buffering extends StatelessWidget {
  const _Buffering();

  @override
  Widget build(BuildContext context) =>
      CircularProgressIndicator(color: context.appTheme.colors.accent);
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.request,
    required this.queue,
    required this.controller,
    required this.isLandscape,
    required this.onToggleFullscreen,
    required this.onMinimize,
  });

  final PlayerUiState state;
  final PlaybackRequest request;
  final PlaybackQueue queue;
  final PlaybackController controller;
  final bool isLandscape;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_kScrimTop, Color(0x00000000), _kScrimBottom],
          stops: <double>[0, 0.5, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _TopBar(
              request: request,
              isLive: state.isLive,
              onMinimize: onMinimize,
            ),
            Expanded(
              child: Center(
                child: _CenterControls(
                  state: state,
                  queue: queue,
                  controller: controller,
                ),
              ),
            ),
            _BottomBar(
              state: state,
              request: request,
              queue: queue,
              controller: controller,
              isLandscape: isLandscape,
              onToggleFullscreen: onToggleFullscreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.request,
    required this.isLive,
    required this.onMinimize,
  });

  final PlaybackRequest request;
  final bool isLive;
  final VoidCallback onMinimize;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
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
          "DIRECT",
          style: t.typography.micro.copyWith(color: t.colors.textPrimary),
        ),
      ],
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.state,
    required this.queue,
    required this.controller,
  });

  final PlayerUiState state;
  final PlaybackQueue queue;
  final PlaybackController controller;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool hasSiblings = queue.hasSiblings;
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
        if (state.buffering)
          SizedBox(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
            child: Padding(
              padding: EdgeInsets.all(t.space.x3),
              child: CircularProgressIndicator(color: t.colors.accent),
            ),
          )
        else
          IconButton(
            iconSize: _kPlayButtonSize,
            icon: Icon(
              state.playing
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: t.colors.textPrimary,
            ),
            onPressed: controller.playOrPause,
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

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.state,
    required this.request,
    required this.queue,
    required this.controller,
    required this.isLandscape,
    required this.onToggleFullscreen,
  });

  final PlayerUiState state;
  final PlaybackRequest request;
  final PlaybackQueue queue;
  final PlaybackController controller;
  final bool isLandscape;
  final VoidCallback onToggleFullscreen;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (!state.isLive) ...<Widget>[
            _SeekBar(
              position: state.position,
              duration: state.duration,
              onSeek: controller.seekTo,
            ),
            Row(
              children: <Widget>[
                Text(
                  _formatDuration(state.position),
                  style: t.typography.caption
                      .copyWith(color: t.colors.textSecondary),
                ),
                const Spacer(),
                Text(
                  _formatDuration(state.duration),
                  style: t.typography.caption
                      .copyWith(color: t.colors.textSecondary),
                ),
              ],
            ),
          ],
          Row(
            children: <Widget>[
              if (queue.hasSiblings)
                TextButton.icon(
                  onPressed: () => _showQueue(context),
                  icon: Icon(Icons.playlist_play, color: t.colors.textPrimary),
                  label: Text(
                    request.isLive ? "Chaînes" : "Épisodes",
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.textPrimary),
                  ),
                ),
              const Spacer(),
              const _PipButton(),
              _CastButton(controller: controller),
              IconButton(
                icon: Icon(
                  isLandscape ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: t.colors.textPrimary,
                ),
                onPressed: onToggleFullscreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQueue(BuildContext context) {
    AppBottomSheet.show<void>(
      context,
      title: request.isLive ? "Chaînes" : "Épisodes",
      child: _QueueList(
        queue: queue,
        currentIndex: state.queueIndex,
        onSelect: (int index) {
          controller.playAt(index);
          Navigator.of(context).maybePop();
        },
      ),
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final void Function(Duration target) onSeek;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final double max =
        widget.duration.inMilliseconds.toDouble().clamp(1, double.infinity);
    final double current =
        (_dragValue ?? widget.position.inMilliseconds.toDouble()).clamp(0, max);
    return SliderTheme(
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
    if (defaultTargetPlatform != TargetPlatform.android) {
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
    if (!controller.canCast) return const SizedBox.shrink();
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
      title: "Diffuser sur",
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
          Icon(Icons.cast_connected, size: _kPlayButtonSize, color: t.colors.accent),
          SizedBox(height: t.space.x4),
          Text(
            "Diffusion sur",
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
      ref.read(castDevicesNotifierProvider.notifier).startDiscovery();
    });
  }

  @override
  void dispose() {
    ref.read(castDevicesNotifierProvider.notifier).stopDiscovery();
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
        ref.watch(castDevicesNotifierProvider);
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
              title: "Diffusion indisponible",
              message: failure.computeErrorMessage(),
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
            "Recherche d'appareils…",
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
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x2),
      decoration: BoxDecoration(
        color: _kPillBg,
        borderRadius: t.radius.fullAll,
      ),
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
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x3),
      decoration: BoxDecoration(
        color: _kPillBg,
        borderRadius: t.radius.lgAll,
      ),
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
      child: Container(
        padding: EdgeInsets.all(t.space.x4),
        decoration: BoxDecoration(
          color: t.colors.bgElevated,
          borderRadius: t.radius.lgAll,
          border: Border.all(color: t.colors.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              "Épisode suivant dans ${seconds}s",
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
            SizedBox(height: t.space.x3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextButton(
                  onPressed: onCancel,
                  child: Text(
                    "Annuler",
                    style: t.typography.bodyStrong
                        .copyWith(color: t.colors.textSecondary),
                  ),
                ),
                SizedBox(width: t.space.x2),
                PrimaryButton(
                  label: "Lire",
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
  const _ErrorOverlay({required this.failure, required this.onRetry});

  final Failures failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ColoredBox(
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
                title: "Lecture impossible",
                message: failure.computeErrorMessage(),
                action: PrimaryButton(
                  label: "Réessayer",
                  expand: false,
                  onPressed: onRetry,
                ),
              ),
            ),
          ],
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

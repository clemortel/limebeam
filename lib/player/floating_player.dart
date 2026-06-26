import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_player/iptv_player.dart";
import "package:iptv_ui/iptv_ui.dart";

const double _kFloatInitialWidth = 200;
const double _kFloatMinWidth = 140;
const double _kFloatMaxWidth = 340;
const double _kFloatMargin = 12;
const double _kFloatAspect = 16 / 9;
const double _kFloatElevation = 8;
const double _kFloatIconSize = 18;
const Color _kFloatVideoBg = Color(0xFF000000);
const Color _kFloatIconBg = Color(0x99000000);

/// In-app floating player (YouTube-style PiP): a small video window you can
/// drag anywhere and pinch to resize while browsing. Tap to expand back to the
/// full player; close to stop. Cross-platform (no OS PiP needed). Shown when
/// playback is active and the full-screen player is not on top.
class FloatingPlayer extends ConsumerStatefulWidget {
  const FloatingPlayer({required this.onExpand, super.key});

  /// Re-opens the full-screen player.
  final VoidCallback onExpand;

  @override
  ConsumerState<FloatingPlayer> createState() => _FloatingPlayerState();
}

class _FloatingPlayerState extends ConsumerState<FloatingPlayer> {
  Offset? _topLeft;
  double _width = _kFloatInitialWidth;
  double _baseWidth = _kFloatInitialWidth;

  @override
  Widget build(BuildContext context) {
    final PlayerUiState state = ref.watch(playbackControllerProvider);
    if (!state.active || state.expanded) return const SizedBox.shrink();

    final AppTheme t = context.appTheme;
    final PlaybackController controller =
        ref.read(playbackControllerProvider.notifier);
    final MediaQueryData mq = MediaQuery.of(context);
    final Size screen = mq.size;
    final double height = _width / _kFloatAspect;

    final double maxX =
        (screen.width - _width - _kFloatMargin).clamp(0, double.infinity);
    final double minY = mq.padding.top + _kFloatMargin;
    final double maxY =
        (screen.height - height - _kFloatMargin - mq.padding.bottom)
            .clamp(minY, double.infinity);

    final Offset pos = _topLeft ?? Offset(maxX, maxY);
    final double left = pos.dx.clamp(_kFloatMargin, maxX);
    final double top = pos.dy.clamp(minY, maxY);

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: widget.onExpand,
        onScaleStart: (_) => _baseWidth = _width,
        onScaleUpdate: (ScaleUpdateDetails d) => setState(() {
          if (d.scale != 1.0) {
            _width =
                (_baseWidth * d.scale).clamp(_kFloatMinWidth, _kFloatMaxWidth);
          }
          _topLeft = Offset(left, top) + d.focalPointDelta;
        }),
        child: Material(
          elevation: _kFloatElevation,
          color: _kFloatVideoBg,
          borderRadius: t.radius.mdAll,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: _width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const PlayerSurface(),
                Positioned(
                  top: 0,
                  left: 0,
                  child: _MiniIcon(
                    icon: state.playing ? Icons.pause : Icons.play_arrow,
                    onTap: controller.playOrPause,
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _MiniIcon(
                    icon: Icons.close,
                    onTap: () => controller.stop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  const _MiniIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.all(t.space.x1),
        padding: EdgeInsets.all(t.space.x1),
        decoration: const BoxDecoration(
          color: _kFloatIconBg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: _kFloatIconSize, color: t.colors.textPrimary),
      ),
    );
  }
}

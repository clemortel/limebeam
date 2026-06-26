import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

/// Shared press feedback (§1.6 / §1.7): scales the child to
/// `motion.pressScale` while pressed, over `motion.fast`. Used by buttons and
/// cards so press behaviour is uniform.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = context.appTheme;
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      onLongPress: widget.enabled ? widget.onLongPress : null,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? theme.motion.pressScale : 1,
        duration: theme.motion.fast,
        curve: theme.motion.fastCurve,
        child: widget.child,
      ),
    );
  }
}

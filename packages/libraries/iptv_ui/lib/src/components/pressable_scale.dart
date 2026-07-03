import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";
import "focus_style.dart";

/// Shared press feedback (§1.6 / §1.7): scales the child to
/// `motion.pressScale` while pressed, over `motion.fast`. Used by buttons and
/// cards so press behaviour is uniform.
///
/// Also the design system's focus primitive: it is a focus node that activates
/// [onTap] on the remote's OK/Select button (`ActivateIntent`), scales up, and
/// draws an accent ring while focused. The ring only appears under directional
/// (D-pad / keyboard) focus — touch interaction on phones is unchanged.
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.showFocusRing = true,
    this.focusBorderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enabled;

  /// Requests focus on first build — anchor the remote on the primary item of
  /// a screen (e.g. the first poster) so the user always has a starting point.
  final bool autofocus;
  final FocusNode? focusNode;

  /// Draws an accent outline while focused. Disable where the item already
  /// shows its own focus affordance.
  final bool showFocusRing;

  /// Corner radius of the focus ring; defaults to the `md` radius. Pass the
  /// item's own radius (pill chips, `lg` cards) so the ring hugs its shape.
  final BorderRadius? focusBorderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;
  bool _focused = false;

  void _setPressed(bool value) {
    if (!widget.enabled) return;
    setState(() => _pressed = value);
  }

  void _handleHighlight(bool value) {
    setState(() => _focused = value);
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = context.appTheme;
    final BorderRadius radius =
        widget.focusBorderRadius ?? theme.radius.mdAll;
    final bool focusedRing = _focused && widget.showFocusRing;
    // Pressed beats focused: an active press always reads as the press scale.
    final double scale = _pressed
        ? theme.motion.pressScale
        : (_focused ? kFocusScale : 1.0);

    return FocusableActionDetector(
      enabled: widget.enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      // Highlight follows focus-highlight mode: true on D-pad/keyboard
      // traversal, false after a touch — so phones never show a ring.
      onShowFocusHighlight: _handleHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            if (widget.enabled) widget.onTap?.call();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        onLongPress: widget.enabled ? widget.onLongPress : null,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: AnimatedScale(
          scale: scale,
          duration: theme.motion.fast,
          curve: theme.motion.fastCurve,
          child: AnimatedContainer(
            duration: theme.motion.fast,
            // Float shadow + glow sit *behind* the child; the glass skin + ring
            // sit *over* it via foregroundDecoration so focusing never shifts
            // layout. Blur-free (see focus_style.dart). Directional focus only,
            // so touch on phones stays clean.
            decoration: focusFloat(theme, radius, focused: focusedRing),
            foregroundDecoration: focusSkin(theme, radius, focused: focusedRing),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

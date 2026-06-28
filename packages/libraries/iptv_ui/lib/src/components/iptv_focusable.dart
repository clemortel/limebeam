import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

/// Width of the accent ring drawn around a focused item, in logical pixels.
const double _kFocusRingWidth = 2.5;

/// D-pad / TV focus wrapper. Bakes focus state into the design system so
/// Android TV / Fire TV / webOS navigation is consistent across components.
///
/// Pure UI: it reports focus through a callback, scales its child, draws an
/// accent ring, and activates [onTap] on both touch *and* the remote's
/// OK/Select button (`ActivateIntent`). Call sites supply the content; no
/// business logic here.
class IptvFocusable extends StatefulWidget {
  const IptvFocusable({
    required this.child,
    this.onTap,
    this.onFocusChange,
    this.autofocus = false,
    this.focusedScale = 1.06,
    this.showFocusRing = true,
    this.focusBorderRadius,
    this.focusNode,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final double focusedScale;

  /// Draws an accent outline when focused. Disable for items that already show
  /// their own focus affordance (e.g. a fully highlighted nav row).
  final bool showFocusRing;

  /// Corner radius of the focus ring. Defaults to the design-system `md`
  /// radius so the ring matches typical card/tile rounding.
  final BorderRadius? focusBorderRadius;

  /// Optional external node so call sites can request/observe focus (e.g. to
  /// scroll the focused item into view).
  final FocusNode? focusNode;

  @override
  State<IptvFocusable> createState() => _IptvFocusableState();
}

class _IptvFocusableState extends State<IptvFocusable> {
  bool _focused = false;

  void _handleHighlight(bool value) {
    setState(() => _focused = value);
  }

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final AppTheme theme = context.appTheme;
    final BorderRadius radius = widget.focusBorderRadius ?? theme.radius.mdAll;

    // `foregroundDecoration` paints the ring over the child without affecting
    // layout, so focusing never shifts surrounding items.
    final Widget content = AnimatedContainer(
      duration: theme.motion.fast,
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: _focused && widget.showFocusRing
              ? theme.colors.accent
              : const Color(0x00000000),
          width: _kFocusRingWidth,
        ),
      ),
      child: widget.child,
    );

    return FocusableActionDetector(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      // Visual highlight follows the focus-highlight mode (true on D-pad
      // traversal), so touch taps do not draw a permanent ring.
      onShowFocusHighlight: _handleHighlight,
      onFocusChange: widget.onFocusChange,
      actions: <Type, Action<Intent>>{
        // OK / Select / Enter on a remote dispatches ActivateIntent.
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            _activate();
            return null;
          },
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? widget.focusedScale : 1,
          duration: theme.motion.fast,
          child: content,
        ),
      ),
    );
  }
}

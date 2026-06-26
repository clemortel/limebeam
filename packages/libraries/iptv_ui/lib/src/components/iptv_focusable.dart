import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

/// D-pad / TV focus wrapper. Bakes focus state into the design system so
/// Android TV navigation is consistent across components.
///
/// Pure UI: it reports focus through a callback and scales its child. Call
/// sites supply the visual emphasis; no business logic here.
class IptvFocusable extends StatefulWidget {
  const IptvFocusable({
    required this.child,
    this.onTap,
    this.onFocusChange,
    this.autofocus = false,
    this.focusedScale = 1.06,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onFocusChange;
  final bool autofocus;
  final double focusedScale;

  @override
  State<IptvFocusable> createState() => _IptvFocusableState();
}

class _IptvFocusableState extends State<IptvFocusable> {
  bool _focused = false;

  void _handleFocusChange(bool value) {
    setState(() => _focused = value);
    widget.onFocusChange?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _focused ? widget.focusedScale : 1,
          duration: context.appTheme.motion.fast,
          child: widget.child,
        ),
      ),
    );
  }
}

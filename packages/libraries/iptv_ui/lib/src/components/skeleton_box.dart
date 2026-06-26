import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

/// Shimmering placeholder block (§2.11). Compose these to mirror the final
/// layout (poster grid, carousels, channel rows) — never a spinner for lists.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    this.width,
    this.height,
    this.borderRadius,
    super.key,
  });

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final Color color = Color.lerp(
          t.colors.bgSurface,
          t.colors.bgElevated,
          _controller.value,
        )!;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: widget.borderRadius ?? t.radius.smAll,
          ),
        );
      },
    );
  }
}

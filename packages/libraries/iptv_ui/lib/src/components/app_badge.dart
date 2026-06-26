import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

const double _kBadgeHeight = 20;

/// Badge kinds with the locked color map (§2.3 / §1.1). Classification badges
/// are neutral; only action (NEW) and now (LIVE) are colored.
enum AppBadgeKind { live, isNew, classification, resume }

/// Compact UPPERCASE badge. Use [AppBadgeKind] to pick the color pair.
class AppBadge extends StatelessWidget {
  const AppBadge({required this.label, required this.kind, super.key});

  const AppBadge.live({super.key}) : label = "LIVE", kind = AppBadgeKind.live;
  const AppBadge.isNew({super.key})
      : label = "NEW",
        kind = AppBadgeKind.isNew;

  final String label;
  final AppBadgeKind kind;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final (Color bg, Color fg) = switch (kind) {
      AppBadgeKind.live => (t.colors.live, const Color(0xFFFFFFFF)),
      AppBadgeKind.isNew => (t.colors.accent, t.colors.textOnAccent),
      AppBadgeKind.classification =>
        (t.colors.bgElevated, t.colors.textSecondary),
      AppBadgeKind.resume => (t.colors.accentSubtle, t.colors.accent),
    };
    return Container(
      height: _kBadgeHeight,
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: t.space.x2),
      decoration: BoxDecoration(color: bg, borderRadius: t.radius.smAll),
      child: Text(
        label.toUpperCase(),
        style: t.typography.micro.copyWith(color: fg),
      ),
    );
  }
}

/// Live status dot (§2.3): 8pt circle in `state/live`.
class LiveDot extends StatelessWidget {
  const LiveDot({this.size = 8, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: t.colors.live, shape: BoxShape.circle),
    );
  }
}

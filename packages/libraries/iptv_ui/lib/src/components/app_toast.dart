import "package:flutter/material.dart" show Icons;
import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

/// Toast severity — drives the leading icon color only (§2.9), never the bg.
enum ToastKind { success, warning, error, info }

/// Inline feedback toast (§2.9). Build it, then show it via [AppToast.show]
/// using an [Overlay]. The toast itself is a pure widget.
class AppToast extends StatelessWidget {
  const AppToast({required this.message, this.kind = ToastKind.info, super.key});

  final String message;
  final ToastKind kind;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final (IconData icon, Color color) = switch (kind) {
      ToastKind.success => (Icons.check_circle, t.colors.success),
      ToastKind.warning => (Icons.warning_amber, t.colors.warning),
      ToastKind.error => (Icons.error_outline, t.colors.error),
      ToastKind.info => (Icons.info_outline, t.colors.textSecondary),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.space.x3,
        vertical: t.space.x3,
      ),
      decoration: BoxDecoration(
        color: t.colors.bgElevated,
        borderRadius: t.radius.mdAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: color, size: 20),
          SizedBox(width: t.space.x2),
          Flexible(
            child: Text(
              message,
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  /// Convenience: slide a toast up from above the tab bar, auto-dismiss in 3s.
  static void show(
    BuildContext context, {
    required String message,
    ToastKind kind = ToastKind.info,
  }) {
    final AppTheme t = context.appTheme;
    final OverlayState overlay = Overlay.of(context);
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        left: t.space.x4,
        right: t.space.x4,
        bottom: t.space.x10 + t.space.x6,
        child: SafeArea(
          child: AppToast(message: message, kind: kind),
        ),
      ),
    );
    overlay.insert(entry);
    Future<void>.delayed(const Duration(seconds: 3), entry.remove);
  }
}

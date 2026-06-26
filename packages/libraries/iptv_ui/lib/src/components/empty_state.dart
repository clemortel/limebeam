import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

const double _kIconSize = 48;

/// Empty / error state template (§2.12): icon, title, explanation, one action.
/// Primitive-only — the action is a caller-supplied widget (e.g. PrimaryButton).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.x6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: _kIconSize, color: t.colors.textTertiary),
          SizedBox(height: t.space.x4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.typography.h2.copyWith(color: t.colors.textPrimary),
          ),
          SizedBox(height: t.space.x2),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
          if (action != null) ...<Widget>[
            SizedBox(height: t.space.x6),
            action!,
          ],
        ],
      ),
    );
  }
}

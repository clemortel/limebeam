import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";
import "pressable_scale.dart";

const double _kChipHeight = 34;

/// Filter / category chip (§2.2). Selected = accent-subtle bg + accent label.
class FilterChipX extends StatelessWidget {
  const FilterChipX({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional active-filter count badge appended to the label.
  final int? count;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Color fg = selected ? t.colors.accent : t.colors.textSecondary;
    final String text = count != null ? "$label · $count" : label;
    return PressableScale(
      onTap: onTap,
      child: Container(
        height: _kChipHeight,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: t.space.x3),
        decoration: BoxDecoration(
          color: selected ? t.colors.accentSubtle : t.colors.bgElevated,
          borderRadius: t.radius.fullAll,
        ),
        child: Text(text, style: t.typography.micro.copyWith(color: fg)),
      ),
    );
  }
}

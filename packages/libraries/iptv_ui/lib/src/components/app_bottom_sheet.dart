import "package:flutter/material.dart";

import "../theme/app_theme.dart";
import "glass_surface.dart";

const double _kHandleWidth = 36;
const double _kHandleHeight = 4;

/// Bottom sheet container (§2.10): elevated surface, top xl corners, grab
/// handle. Use [AppBottomSheet.show] to present any child over content.
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({required this.child, this.title, super.key});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // Frosted sheet with top-only rounding; the grab handle reads as the lens
    // accent. Falls back to a solid elevated surface under "Reduce
    // transparency" / high contrast (see GlassSurface).
    return GlassSurface(
      kind: GlassKind.dialog,
      radius: t.radius.sheetTop,
      padding: EdgeInsets.only(bottom: t.space.x4),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(height: t.space.x2),
            Container(
              width: _kHandleWidth,
              height: _kHandleHeight,
              decoration: BoxDecoration(
                color: t.colors.borderDefault,
                borderRadius: t.radius.fullAll,
              ),
            ),
            if (title != null) ...<Widget>[
              SizedBox(height: t.space.x3),
              Text(
                title!,
                style: t.typography.h3.copyWith(color: t.colors.textPrimary),
              ),
            ],
            SizedBox(height: t.space.x3),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }

  static Future<T?> show<T>(
    BuildContext context, {
    required Widget child,
    String? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: const Color(0x00000000),
      isScrollControlled: true,
      builder: (BuildContext context) =>
          AppBottomSheet(title: title, child: child),
    );
  }
}

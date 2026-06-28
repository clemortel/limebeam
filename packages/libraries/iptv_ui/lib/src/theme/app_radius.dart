import "package:flutter/widgets.dart";

/// Radius scale per design spec §1.4.
///
/// [scale] magnifies the finite radii for 10-foot (TV) layouts; `full` stays
/// fixed (it is an effectively-infinite pill radius). Defaults to 1.0.
class AppRadius {
  const AppRadius({this.scale = 1.0});

  final double scale;

  double get sm => 8 * scale;
  double get md => 12 * scale;
  double get lg => 16 * scale;
  double get xl => 24 * scale;
  double get full => 999;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get fullAll => BorderRadius.circular(full);

  /// Top-only rounding for bottom sheets (§2.10).
  BorderRadius get sheetTop =>
      BorderRadius.vertical(top: Radius.circular(xl));
}

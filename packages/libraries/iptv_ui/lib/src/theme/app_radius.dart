import "package:flutter/widgets.dart";

/// Radius scale per design spec §1.4.
class AppRadius {
  const AppRadius();

  final double sm = 8;
  final double md = 12;
  final double lg = 16;
  final double xl = 24;
  final double full = 999;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get fullAll => BorderRadius.circular(full);

  /// Top-only rounding for bottom sheets (§2.10).
  BorderRadius get sheetTop =>
      BorderRadius.vertical(top: Radius.circular(xl));
}

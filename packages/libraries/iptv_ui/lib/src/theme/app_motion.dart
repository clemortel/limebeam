import "package:flutter/animation.dart";

/// Motion tokens per design spec §1.6.
class AppMotion {
  const AppMotion();

  final Duration fast = const Duration(milliseconds: 120);
  final Duration base = const Duration(milliseconds: 220);
  final Duration slow = const Duration(milliseconds: 360);

  /// Player controls auto-hide delay.
  final Duration controlsAutoHide = const Duration(seconds: 3);

  Curve get fastCurve => Curves.easeOut;
  Curve get baseCurve => Curves.easeInOut;
  Curve get slowCurve => Curves.easeInOutCubic;

  /// Cards & buttons scale to this on press over [fast].
  final double pressScale = 0.97;
}

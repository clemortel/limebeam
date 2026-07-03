import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

/// Shared "liquid glass grey" focus treatment for TV / D-pad. One definition
/// so every focusable (cards, tiles, chips, buttons, nav rail) reads
/// identically from the couch. Blur-free by design — [BackdropFilter] is too
/// slow on Fire TV GPUs, so the glass look is faked with a translucent grey
/// sheen + bright top rim + accent ring + float shadow (all cheap raster ops).
///
/// Opacities are intentionally restrained so a focused poster gains a glassy
/// gloss rather than a grey wash; tune the constants below to taste.

/// Scale applied to a focused item. Wide buttons use [kFocusScaleWide] so they
/// lift without jumping.
const double kFocusScale = 1.06;
const double kFocusScaleWide = 1.04;

/// Accent ring width (logical px) — reads as "this is the one" from 10 feet.
const double _kRingWidth = 3;

/// Translucent-grey glass skin painted OVER a focused item
/// (`foregroundDecoration`): a bright top rim fading to a faint body sheen,
/// ringed in accent. Transparent (radius only) when not focused.
BoxDecoration focusSkin(
  AppTheme t,
  BorderRadius radius, {
  required bool focused,
}) {
  if (!focused) return BoxDecoration(borderRadius: radius);
  return BoxDecoration(
    borderRadius: radius,
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      // Bright hairline rim → faint sheen → near-nothing at the bottom.
      colors: <Color>[Color(0x33FFFFFF), Color(0x0FFFFFFF), Color(0x05FFFFFF)],
      stops: <double>[0.0, 0.2, 1.0],
    ),
    border: Border.all(color: t.colors.accent, width: _kRingWidth),
  );
}

/// Float shadow + soft accent glow painted BEHIND a focused item
/// (`decoration`) so it lifts off the surface. Transparent when not focused.
BoxDecoration focusFloat(
  AppTheme t,
  BorderRadius radius, {
  required bool focused,
}) {
  if (!focused) return BoxDecoration(borderRadius: radius);
  return BoxDecoration(
    borderRadius: radius,
    boxShadow: <BoxShadow>[
      const BoxShadow(
        color: Color(0x59000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
      BoxShadow(
        color: t.colors.accentSubtle,
        blurRadius: 14,
        spreadRadius: 1,
      ),
    ],
  );
}

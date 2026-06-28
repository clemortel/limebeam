import "package:flutter/widgets.dart";

/// Liquid-glass tokens for the app's floating chrome (tab bar, player
/// controls, sheets, dialogs, mini-player). Glass is a deliberate, scoped
/// elevation tier — it never lands on scrollable content.
///
/// Approach (mirrors Stairling's `StairlingGlassSurface`): a real backdrop
/// blur + a faint top-to-bottom white sheen + a thin rim. No shader, so it is
/// cheap, predictable, and reads as glass over any image/gradient. Read via
/// `context.appTheme.glass`; defaults are dark, [AppGlass.lightScheme] is light.
///
/// Two intensities: base ([fillTop]/[fillBottom], a translucent sheen for
/// bars/pills) and strong ([fillStrong], a more opaque fill for sheets/dialogs
/// that must occlude busy content behind them).
class AppGlass {
  const AppGlass({
    this.fillTop = const Color(0x24FFFFFF),
    this.fillBottom = const Color(0x0FFFFFFF),
    this.fillStrong = const Color(0xCC1D2024),
    this.border = const Color(0x33FFFFFF),
    this.blurSigma = 10,
    this.blurSigmaStrong = 18,
  });

  /// Light scheme: a stronger white sheen reads over light content, the strong
  /// fill goes near-white, and the rim becomes a dark hairline (white is
  /// invisible on light surfaces).
  const AppGlass.lightScheme()
      : this(
          fillTop: const Color(0x59FFFFFF),
          fillBottom: const Color(0x26FFFFFF),
          fillStrong: const Color(0xF2FFFFFF),
          border: const Color(0x1F000000),
        );

  /// Top-edge sheen color (lighter) for the base intensity.
  final Color fillTop;

  /// Bottom-edge fill color (fainter) for the base intensity.
  final Color fillBottom;

  /// Flat fill for the strong intensity (sheets/dialogs) — more opaque so text
  /// stays legible over busy content behind the surface.
  final Color fillStrong;

  /// Thin rim drawn around the glass for the "lens edge" read.
  final Color border;

  /// Backdrop blur sigma for the base intensity.
  final double blurSigma;

  /// Backdrop blur sigma for the strong intensity.
  final double blurSigmaStrong;
}

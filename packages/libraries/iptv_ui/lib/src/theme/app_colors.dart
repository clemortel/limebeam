import "package:flutter/widgets.dart";

/// Color roles per design spec §1.1. Lime means "you can act on this"; red
/// means "now/stop". Never read these consts directly in screens — read them
/// through `AppTheme` (`context.appTheme.colors`).
///
/// Defaults are the dark scheme; [AppColors.lightScheme] overrides the surface
/// and text roles for the light theme (the lime accent is shared).
class AppColors {
  const AppColors({
    this.bgBase = const Color(0xFF0B0C0E),
    this.bgSurface = const Color(0xFF141619),
    this.bgElevated = const Color(0xFF1D2024),
    this.bgInput = const Color(0xFF191C20),
    this.borderSubtle = const Color(0x14FFFFFF),
    this.borderDefault = const Color(0x24FFFFFF),
    this.borderStrong = const Color(0xFF2A2E33),
    this.textPrimary = const Color(0xFFF4F6F8),
    this.textSecondary = const Color(0xFFA7AEB6),
    this.textTertiary = const Color(0xFF6B7280),
    this.textOnAccent = const Color(0xFF0B0C0E),
    this.accent = const Color(0xFFC5F03A),
    this.accentPressed = const Color(0xFFA8D625),
    this.accentSubtle = const Color(0xFF2E3A12),
    this.accentTextOnDark = const Color(0xFFC5F03A),
    this.live = const Color(0xFFFF5247),
    this.success = const Color(0xFF3DD68C),
    this.warning = const Color(0xFFF5A623),
    this.error = const Color(0xFFFF5247),
    this.offline = const Color(0xFF6B7280),
  });

  /// Light scheme: inverted surfaces + text; lime accent kept, but accent text
  /// links darken to stay readable on light backgrounds.
  const AppColors.lightScheme()
      : this(
          bgBase: const Color(0xFFF7F8F5),
          bgSurface: const Color(0xFFFFFFFF),
          bgElevated: const Color(0xFFFFFFFF),
          bgInput: const Color(0xFFF0F1EE),
          borderSubtle: const Color(0x14000000),
          borderDefault: const Color(0x24000000),
          borderStrong: const Color(0xFFD2D7DE),
          textPrimary: const Color(0xFF16181B),
          textSecondary: const Color(0xFF5A616B),
          textTertiary: const Color(0xFF9AA1AB),
          accentSubtle: const Color(0xFFEAF7C4),
          // Darkened lime for link text on light surfaces (the lime fill is
          // identical on both themes, but pure lime text is unreadable here).
          accentTextOnDark: const Color(0xFF5C7A0E),
        );

  // Surfaces.
  final Color bgBase;
  final Color bgSurface;
  final Color bgElevated;
  final Color bgInput;

  // Borders & dividers.
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;

  // Text.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;

  // Accent — lime (scalpel).
  final Color accent;
  final Color accentPressed;
  final Color accentSubtle;
  final Color accentTextOnDark;

  // Semantic states.
  final Color live;
  final Color success;
  final Color warning;
  final Color error;
  final Color offline;
}

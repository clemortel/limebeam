import "package:flutter/material.dart";

import "app_colors.dart";
import "app_glass.dart";
import "app_motion.dart";
import "app_radius.dart";
import "app_space.dart";
import "app_type.dart";

/// Single design-system entry point, attached to [ThemeData] as a
/// [ThemeExtension]. Widgets read tokens via `context.appTheme` and never
/// touch raw consts — this keeps theme/font-scale swaps clean (spec §6).
class AppTheme extends ThemeExtension<AppTheme> {
  const AppTheme({
    required this.colors,
    required this.typography,
    required this.space,
    required this.radius,
    required this.motion,
    required this.glass,
  });

  final AppColors colors;
  final AppType typography;
  final AppSpace space;
  final AppRadius radius;
  final AppMotion motion;
  final AppGlass glass;

  /// Dark scheme (default).
  static const AppTheme dark = AppTheme(
    colors: AppColors(),
    typography: AppType(),
    space: AppSpace(),
    radius: AppRadius(),
    motion: AppMotion(),
    glass: AppGlass(),
  );

  /// Light scheme — same tokens, inverted surfaces/text.
  static const AppTheme light = AppTheme(
    colors: AppColors.lightScheme(),
    typography: AppType(),
    space: AppSpace(),
    radius: AppRadius(),
    motion: AppMotion(),
    glass: AppGlass.lightScheme(),
  );

  /// Token magnification for the 10-foot (TV) layout. Bumps spacing, type, and
  /// radii so the UI reads from across a room. Tuned to grow comfortably on
  /// 1080p without overflowing dense screens.
  static const double tvTokenScale = 1.3;

  /// Builds a token set for [brightness], scaling spacing/type/radii by
  /// [tokenScale] (1.0 = phone/tablet, [tvTokenScale] = TV).
  static AppTheme scheme(Brightness brightness, {double tokenScale = 1.0}) {
    final bool isLight = brightness == Brightness.light;
    return AppTheme(
      colors: isLight ? const AppColors.lightScheme() : const AppColors(),
      typography: AppType(scale: tokenScale),
      space: AppSpace(scale: tokenScale),
      radius: AppRadius(scale: tokenScale),
      motion: const AppMotion(),
      glass: isLight ? const AppGlass.lightScheme() : const AppGlass(),
    );
  }

  /// Builds the Material [ThemeData] for [brightness], carrying the matching
  /// token set as an extension. Screens still read tokens via [appTheme].
  /// [tokenScale] magnifies the design tokens for the TV layout.
  static ThemeData themeData({
    Brightness brightness = Brightness.dark,
    double tokenScale = 1.0,
  }) {
    final AppTheme t = scheme(brightness, tokenScale: tokenScale);
    final ColorScheme scheme0 = ColorScheme.fromSeed(
      seedColor: t.colors.accent,
      brightness: brightness,
      surface: t.colors.bgSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.colors.bgBase,
      colorScheme: scheme0.copyWith(
        primary: t.colors.accent,
        onPrimary: t.colors.textOnAccent,
        error: t.colors.error,
      ),
      fontFamily: AppType.fontFamily,
      extensions: <ThemeExtension<dynamic>>[t],
    );
  }

  @override
  AppTheme copyWith({
    AppColors? colors,
    AppType? typography,
    AppSpace? space,
    AppRadius? radius,
    AppMotion? motion,
    AppGlass? glass,
  }) {
    return AppTheme(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      motion: motion ?? this.motion,
      glass: glass ?? this.glass,
    );
  }

  // Tokens are immutable singletons; there is nothing meaningful to lerp.
  @override
  AppTheme lerp(ThemeExtension<AppTheme>? other, double t) => this;
}

/// Ergonomic access: `context.appTheme.colors.accent`.
extension AppThemeContext on BuildContext {
  AppTheme get appTheme =>
      Theme.of(this).extension<AppTheme>() ?? AppTheme.dark;
}

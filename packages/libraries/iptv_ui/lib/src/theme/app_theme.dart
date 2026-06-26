import "package:flutter/material.dart";

import "app_colors.dart";
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
  });

  final AppColors colors;
  final AppType typography;
  final AppSpace space;
  final AppRadius radius;
  final AppMotion motion;

  /// Dark scheme (default).
  static const AppTheme dark = AppTheme(
    colors: AppColors(),
    typography: AppType(),
    space: AppSpace(),
    radius: AppRadius(),
    motion: AppMotion(),
  );

  /// Light scheme — same tokens, inverted surfaces/text.
  static const AppTheme light = AppTheme(
    colors: AppColors.lightScheme(),
    typography: AppType(),
    space: AppSpace(),
    radius: AppRadius(),
    motion: AppMotion(),
  );

  /// Builds the Material [ThemeData] for [brightness], carrying the matching
  /// token set as an extension. Screens still read tokens via [appTheme].
  static ThemeData themeData({Brightness brightness = Brightness.dark}) {
    final AppTheme t = brightness == Brightness.light ? light : dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: t.colors.accent,
      brightness: brightness,
      surface: t.colors.bgSurface,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: t.colors.bgBase,
      colorScheme: scheme.copyWith(
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
  }) {
    return AppTheme(
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      space: space ?? this.space,
      radius: radius ?? this.radius,
      motion: motion ?? this.motion,
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

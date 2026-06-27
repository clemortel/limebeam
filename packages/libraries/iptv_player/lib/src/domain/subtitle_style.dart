import "package:freezed_annotation/freezed_annotation.dart";

part "subtitle_style.freezed.dart";

/// Subtitle appearance applied to the engine's renderer. Persisted globally in
/// the user's preferences (not per-item). Engines translate these primitives
/// into their own knobs (mpv `sub-scale`/`sub-color`/`sub-back-color`, or iOS
/// `AVTextStyleRule`).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class SubtitleStyle with _$SubtitleStyle {
  const SubtitleStyle._();

  const factory SubtitleStyle({
    @Default(SubtitleStyle.defaultFontScale) double fontScale,
    @Default(SubtitleStyle.defaultTextColorArgb) int textColorArgb,
    @Default(SubtitleStyle.defaultBackgroundOpacity) double backgroundOpacity,
  }) = _SubtitleStyle;

  /// Renderer-native default scale (1.0 = the engine's own default size).
  static const double defaultFontScale = 1.0;

  /// Opaque white — the conventional subtitle text color.
  static const int defaultTextColorArgb = 0xFFFFFFFF;

  /// No background box by default.
  static const double defaultBackgroundOpacity = 0.0;

  /// Bounds for the font-scale slider, kept here so call sites avoid magic
  /// numbers.
  static const double minFontScale = 0.5;
  static const double maxFontScale = 3.0;
}

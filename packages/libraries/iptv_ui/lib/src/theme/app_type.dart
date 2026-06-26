import "package:flutter/widgets.dart";

/// Typography scale per design spec §1.2. One family; weight + size carry the
/// hierarchy. SF Pro on iOS via the system fallback; bundled Inter elsewhere.
class AppType {
  const AppType();

  static const String fontFamily = "Inter";
  static const List<String> fontFamilyFallback = <String>[".SF Pro Text"];

  TextStyle get display => _base(34, 40, FontWeight.w700);
  TextStyle get h1 => _base(28, 34, FontWeight.w700);
  TextStyle get h2 => _base(22, 28, FontWeight.w600);
  TextStyle get h3 => _base(17, 22, FontWeight.w600);
  TextStyle get body => _base(15, 22, FontWeight.w400);
  TextStyle get bodyStrong => _base(15, 20, FontWeight.w600);
  TextStyle get caption => _base(13, 18, FontWeight.w400);
  TextStyle get micro => _base(11, 14, FontWeight.w600);

  TextStyle _base(double size, double lineHeight, FontWeight weight) {
    return TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
    );
  }
}

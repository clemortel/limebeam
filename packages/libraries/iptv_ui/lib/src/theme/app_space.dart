/// 4pt spacing scale per design spec §1.3. Never hardcode raw pixels in
/// widgets — reference these tokens.
///
/// [scale] magnifies every step for 10-foot (TV) layouts; defaults to 1.0 so
/// phone/tablet are unaffected.
class AppSpace {
  const AppSpace({this.scale = 1.0});

  final double scale;

  double get x0 => 0;
  double get x1 => 4 * scale;
  double get x2 => 8 * scale;
  double get x3 => 12 * scale;
  double get x4 => 16 * scale;
  double get x5 => 20 * scale;
  double get x6 => 24 * scale;
  double get x8 => 32 * scale;
  double get x10 => 40 * scale;
}

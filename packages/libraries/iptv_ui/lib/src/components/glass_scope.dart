import "package:flutter/widgets.dart";

/// App-wide switch for liquid-glass effects. The app wraps its tree once with
/// `GlassScope(enabled: !reduceTransparency)`; every [GlassSurface] reads this
/// as its default, so the "Reduce transparency" preference reaches deeply
/// nested chrome (sheets, player overlays) without prop-drilling.
///
/// Defaults to enabled when no scope is present.
class GlassScope extends InheritedWidget {
  const GlassScope({
    required this.enabled,
    required super.child,
    super.key,
  });

  final bool enabled;

  /// Whether glass is enabled in the nearest scope (true when absent).
  static bool of(BuildContext context) {
    final GlassScope? scope =
        context.dependOnInheritedWidgetOfExactType<GlassScope>();
    return scope?.enabled ?? true;
  }

  @override
  bool updateShouldNotify(GlassScope oldWidget) => enabled != oldWidget.enabled;
}

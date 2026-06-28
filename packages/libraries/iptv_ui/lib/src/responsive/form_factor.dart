import "package:flutter/widgets.dart";

/// The device class the UI adapts to. Resolved once at app root and exposed
/// app-wide via [FormFactorScope], mirroring how `GlassScope` carries the
/// "reduce transparency" preference.
///
/// `phone`/`tablet` are touch-first; `tv` switches to a focus-first 10-foot
/// layout (side rail navigation, larger density, D-pad focus, solid surfaces).
enum FormFactor {
  phone,
  tablet,
  tv;

  bool get isTv => this == FormFactor.tv;
  bool get isHandset => this == FormFactor.phone;
  bool get isTablet => this == FormFactor.tablet;
}

/// Width (in logical pixels) at/above which a touch device is treated as a
/// tablet rather than a phone. Uses the shortest side so orientation does not
/// flip the class.
const double _kTabletShortestSide = 600;

/// Resolves the touch device class from layout size. Only distinguishes
/// phone vs tablet — TV is decided by a platform signal upstream, never by
/// size alone (a TV and a tablet can share a viewport).
FormFactor formFactorFromSize(Size size) {
  final double shortestSide =
      size.shortestSide == 0 ? size.width : size.shortestSide;
  return shortestSide >= _kTabletShortestSide
      ? FormFactor.tablet
      : FormFactor.phone;
}

/// Poster-grid column count per device class. Phones stay at 2; tablets and
/// TVs fan out to use the wider viewport (TV is fewer than tablet because the
/// side rail eats horizontal space and cards are scaled up for distance).
int posterGridColumns(FormFactor formFactor) => switch (formFactor) {
      FormFactor.phone => 2,
      FormFactor.tablet => 4,
      FormFactor.tv => 5,
    };

/// App-wide form-factor switch. The app wraps its tree once with
/// `FormFactorScope(formFactor: ...)`; any widget reads the active class via
/// [FormFactorScope.of] without prop-drilling, keeping this package free of
/// Riverpod / business dependencies.
///
/// Defaults to [FormFactor.phone] when no scope is present.
class FormFactorScope extends InheritedWidget {
  const FormFactorScope({
    required this.formFactor,
    required super.child,
    super.key,
  });

  final FormFactor formFactor;

  /// The active form factor in the nearest scope ([FormFactor.phone] when
  /// absent).
  static FormFactor of(BuildContext context) {
    final FormFactorScope? scope =
        context.dependOnInheritedWidgetOfExactType<FormFactorScope>();
    return scope?.formFactor ?? FormFactor.phone;
  }

  /// Convenience: whether the nearest scope is a TV.
  static bool isTv(BuildContext context) => of(context).isTv;

  @override
  bool updateShouldNotify(FormFactorScope oldWidget) =>
      formFactor != oldWidget.formFactor;
}

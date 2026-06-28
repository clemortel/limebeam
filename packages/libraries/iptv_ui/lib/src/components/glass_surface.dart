import "dart:ui";

import "package:flutter/material.dart";

import "../theme/app_glass.dart";
import "../theme/app_theme.dart";
import "glass_scope.dart";

/// The role of a glass surface — drives its default corner radius and the
/// blur/fill intensity.
enum GlassKind {
  /// Full-width chrome with square corners (e.g. an edge-to-edge bar).
  bar,

  /// Stadium/capsule pill (e.g. the floating nav bar, player HUD pills).
  pill,

  /// Rounded floating panel (e.g. next-episode card, mini-player frame).
  panel,

  /// Strong-occlusion surface (e.g. bottom sheets, dialogs).
  dialog,
}

/// Frosted-glass surface: a real backdrop blur under a faint top-to-bottom
/// sheen with a thin rim (mirrors Stairling's `StairlingGlassSurface`). The
/// blur samples whatever is painted behind it, so it only reads as glass over
/// an image/gradient/scrolling content — which is why glass is reserved for
/// floating chrome, never scrollable lists.
///
/// This is the ONE glass primitive every surface composes, so the look and the
/// accessibility fallback live in a single place. Glass is replaced by a
/// **solid** surface when [enabled] is false (the "Reduce transparency"
/// preference) OR when the OS high-contrast flag is on.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    this.kind = GlassKind.panel,
    this.radius,
    this.enabled,
    this.padding,
    super.key,
  });

  final Widget child;
  final GlassKind kind;

  /// Explicit corner radius. Defaults to a sensible value for [kind].
  final BorderRadius? radius;

  /// When false, renders a solid surface instead of glass. Defaults to the
  /// nearest [GlassScope] (driven by the "Reduce transparency" preference).
  final bool? enabled;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppGlass g = t.glass;
    final BorderRadius shape = radius ?? _defaultRadius(t);

    // Resolve from the explicit flag or the inherited scope, then honor the OS
    // high-contrast signal regardless — belt and suspenders so no caller can
    // ship an inaccessible surface.
    final bool requested = enabled ?? GlassScope.of(context);
    final bool useGlass = requested && !MediaQuery.highContrastOf(context);
    final bool strong = kind == GlassKind.dialog;

    // A Material lets ListTile/ink children find an ancestor below the glass.
    final Widget content = Padding(
      padding: padding ?? EdgeInsets.zero,
      child: Material(type: MaterialType.transparency, child: child),
    );

    if (!useGlass) {
      return _solidFallback(t, shape, strong: strong, content: content);
    }

    final double sigma = strong ? g.blurSigmaStrong : g.blurSigma;
    final BoxDecoration decoration = BoxDecoration(
      borderRadius: shape,
      border: Border.all(color: g.border),
      // Strong surfaces use a flat opaque-ish fill (occlusion); base surfaces
      // use a faint top-lighter sheen so they stay see-through.
      color: strong ? g.fillStrong : null,
      gradient: strong
          ? null
          : LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[g.fillTop, g.fillBottom],
            ),
    );

    // RepaintBoundary isolates the backdrop-blur layer so it is not
    // re-rasterized when sibling widgets repaint (e.g. tab transitions).
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: DecoratedBox(decoration: decoration, child: content),
        ),
      ),
    );
  }

  Widget _solidFallback(
    AppTheme t,
    BorderRadius shape, {
    required bool strong,
    required Widget content,
  }) {
    final Color fill = strong ? t.colors.bgElevated : t.colors.bgSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: shape,
        border: Border.all(color: t.colors.borderSubtle),
      ),
      child: ClipRRect(borderRadius: shape, child: content),
    );
  }

  BorderRadius _defaultRadius(AppTheme t) {
    switch (kind) {
      case GlassKind.bar:
        return BorderRadius.zero;
      case GlassKind.pill:
        return t.radius.fullAll;
      case GlassKind.panel:
        return t.radius.lgAll;
      case GlassKind.dialog:
        return t.radius.lgAll;
    }
  }
}

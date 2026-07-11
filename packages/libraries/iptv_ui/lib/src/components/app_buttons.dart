import "package:flutter/widgets.dart";

import "../responsive/form_factor.dart";
import "../theme/app_theme.dart";
import "pressable_scale.dart";

const double _kButtonHeight = 50;
const double _kTertiaryHeight = 44;
const double _kIconButtonSize = 44;
const double _kDisabledOpacity = 0.4;

/// On TV, a full-width (`expand`) button is capped to this content width and
/// centered, so the focus ring frames the action instead of a full-bleed row
/// (a 10-foot anti-pattern). Phones keep the full-width button unchanged.
const double _kTvButtonMaxWidth = 320;

/// Caps + centers an `expand` button on TV; transparent passthrough on phones.
class _TvButtonWidth extends StatelessWidget {
  const _TvButtonWidth({required this.expand, required this.child});

  final bool expand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!expand || !FormFactorScope.isTv(context)) return child;
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kTvButtonMaxWidth),
        child: child,
      ),
    );
  }
}

/// Primary CTA (§2.1). One per screen. Lime fill, near-black label.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  /// Requests focus on first build — used to anchor the TV remote on the
  /// primary action (e.g. "Lire" on a detail page).
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool enabled = onPressed != null;
    return _TvButtonWidth(
      expand: expand,
      child: Opacity(
        opacity: enabled ? 1 : _kDisabledOpacity,
        child: PressableScale(
          enabled: enabled,
          autofocus: autofocus,
          onTap: onPressed,
          child: Container(
            height: _kButtonHeight,
            width: expand ? double.infinity : null,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: t.space.x5),
            decoration: BoxDecoration(
              color: t.colors.accent,
              borderRadius: t.radius.mdAll,
            ),
            child: Text(
              label,
              style:
                  t.typography.bodyStrong.copyWith(color: t.colors.textOnAccent),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary button (§2.1): transparent + default border.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool enabled = onPressed != null;
    return _TvButtonWidth(
      expand: expand,
      child: Opacity(
        opacity: enabled ? 1 : _kDisabledOpacity,
        child: PressableScale(
          enabled: enabled,
          autofocus: autofocus,
          onTap: onPressed,
          child: Container(
            height: _kButtonHeight,
            width: expand ? double.infinity : null,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: t.space.x5),
            decoration: BoxDecoration(
              borderRadius: t.radius.mdAll,
              border: Border.all(color: t.colors.borderDefault),
            ),
            child: Text(
              label,
              style:
                  t.typography.bodyStrong.copyWith(color: t.colors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tertiary / text button (§2.1): lime label, no fill.
class TertiaryButton extends StatelessWidget {
  const TertiaryButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : _kDisabledOpacity,
      child: PressableScale(
        enabled: enabled,
        onTap: onPressed,
        child: Container(
          height: _kTertiaryHeight,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: t.space.x4),
          child: Text(
            label,
            style: t.typography.bodyStrong
                .copyWith(color: t.colors.accentTextOnDark),
          ),
        ),
      ),
    );
  }
}

/// Destructive button (§2.1): error-colored label + border.
class DestructiveButton extends StatelessWidget {
  const DestructiveButton({
    required this.label,
    required this.onPressed,
    this.expand = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool enabled = onPressed != null;
    return _TvButtonWidth(
      expand: expand,
      child: Opacity(
        opacity: enabled ? 1 : _kDisabledOpacity,
        child: PressableScale(
          enabled: enabled,
          onTap: onPressed,
          child: Container(
            height: _kButtonHeight,
            width: expand ? double.infinity : null,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(horizontal: t.space.x5),
            decoration: BoxDecoration(
              borderRadius: t.radius.mdAll,
              border: Border.all(color: t.colors.error),
            ),
            child: Text(
              label,
              style: t.typography.bodyStrong.copyWith(color: t.colors.error),
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular icon button (§2.1): 44×44, elevated surface.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.semanticLabel,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool active;
  final String? semanticLabel;

  /// Optional external focus node — lets a screen drive D-pad focus onto this
  /// button explicitly (e.g. the TV player's ordered up/down navigation).
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : _kDisabledOpacity,
      child: PressableScale(
        enabled: enabled,
        focusNode: focusNode,
        autofocus: autofocus,
        onTap: onPressed,
        child: Container(
          width: _kIconButtonSize,
          height: _kIconButtonSize,
          decoration: BoxDecoration(
            color: t.colors.bgElevated,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 22,
            semanticLabel: semanticLabel,
            color: active ? t.colors.accent : t.colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

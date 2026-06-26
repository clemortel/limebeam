import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

const String _kMarkAsset = "assets/brand/limebeam_mark_512.png";
const String _kPackage = "iptv_ui";
const double _kDefaultMarkSize = 96;
const double _kLockupMarkSize = 40;

/// The LimeBeam symbol (the beam): a lime point source projecting a triangular
/// beam to the right. Fixed-color asset on a transparent ground — works on
/// dark and light surfaces (the lime is theme-independent per the charte).
class LimeBeamMark extends StatelessWidget {
  const LimeBeamMark({this.size = _kDefaultMarkSize, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _kMarkAsset,
      package: _kPackage,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// "LimeBeam" wordmark — one word, internal "LB" casing, bicolor: `Lime` in
/// text/primary, `Beam` in accent. Never "Lime Beam" / "LIMEBEAM".
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({this.style, super.key});

  /// Base text style; defaults to `h1`. Colors are applied per word.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final TextStyle base = style ?? t.typography.h1;
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: "Lime",
            style: base.copyWith(color: t.colors.textPrimary),
          ),
          TextSpan(
            text: "Beam",
            style: base.copyWith(color: t.colors.accent),
          ),
        ],
      ),
    );
  }
}

/// Horizontal lockup: the mark + the wordmark. For onboarding / headers.
class LimeBeamLockup extends StatelessWidget {
  const LimeBeamLockup({this.markSize = _kLockupMarkSize, this.style, super.key});

  final double markSize;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        LimeBeamMark(size: markSize),
        SizedBox(width: t.space.x2),
        BrandWordmark(style: style),
      ],
    );
  }
}

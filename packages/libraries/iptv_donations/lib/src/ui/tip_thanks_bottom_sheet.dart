import "package:flutter/material.dart";
import "package:iptv_ui/iptv_ui.dart";

const double _kEmblemSize = 96;
const double _kHeartSize = 46;
const double _kGlowSize = 132;
const Duration _kPopDuration = Duration(milliseconds: 700);

/// Celebratory, tasteful thank-you shown after a successful tip. Pure UI — warm
/// gratitude, no dark patterns. Presented as a bottom sheet (same surface as the
/// prompt) so it sits under Material and shares the app's styling.
class TipThanksBottomSheet extends StatelessWidget {
  const TipThanksBottomSheet({super.key});

  /// Presents the thank-you and resolves when it is dismissed.
  static Future<void> show(BuildContext context) =>
      AppBottomSheet.show<void>(context, child: const TipThanksBottomSheet());

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.x4,
        t.space.x2,
        t.space.x4,
        t.space.x2,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: _kPopDuration,
            curve: Curves.elasticOut,
            builder: (BuildContext context, double scale, Widget? child) =>
                Transform.scale(scale: scale, child: child),
            child: SizedBox(
              width: _kGlowSize,
              height: _kGlowSize,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Soft accent glow behind the emblem.
                  Container(
                    width: _kGlowSize,
                    height: _kGlowSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          t.colors.accentSubtle,
                          t.colors.bgElevated.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: _kEmblemSize,
                    height: _kEmblemSize,
                    decoration: BoxDecoration(
                      color: t.colors.accentSubtle,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.colors.accent),
                    ),
                    child: Icon(
                      Icons.favorite,
                      size: _kHeartSize,
                      color: t.colors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.space.x5),
          Text(
            "Merci ❤️",
            textAlign: TextAlign.center,
            style: t.typography.h2.copyWith(color: t.colors.textPrimary),
          ),
          SizedBox(height: t.space.x3),
          Text(
            "Ton soutien fait vraiment la différence. Grâce à toi, LimeBeam "
            "continue d'avancer — gratuit, sans pub et sans tracking.",
            textAlign: TextAlign.center,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: t.space.x3,
              vertical: t.space.x2,
            ),
            decoration: BoxDecoration(
              color: t.colors.accentSubtle,
              borderRadius: t.radius.fullAll,
            ),
            child: Text(
              "✨ Supporter",
              style: t.typography.bodyStrong.copyWith(color: t.colors.accent),
            ),
          ),
          SizedBox(height: t.space.x6),
          PrimaryButton(
            label: "Avec plaisir",
            onPressed: () => Navigator.of(context).pop(),
          ),
          SizedBox(height: t.space.x2),
        ],
      ),
    );
  }
}

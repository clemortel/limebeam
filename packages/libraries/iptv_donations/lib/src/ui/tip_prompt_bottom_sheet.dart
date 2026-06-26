import "package:flutter/material.dart";
import "package:iptv_ui/iptv_ui.dart";

/// Contextual, non-blocking "support the dev" prompt (shown rarely). Pure UI:
/// it resolves to the user's choice so the caller decides what to do (navigate
/// to the Tip Jar, mark it as shown, …). No external links.
class TipPromptBottomSheet extends StatelessWidget {
  const TipPromptBottomSheet({super.key});

  /// Presents the prompt; resolves to `true` when the user taps "Soutenir
  /// LimeBeam", `false` otherwise (incl. dismiss-by-drag).
  static Future<bool> show(BuildContext context) async {
    final bool? result = await AppBottomSheet.show<bool>(
      context,
      title: "Tu aimes LimeBeam ?",
      child: const TipPromptBottomSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            "LimeBeam est gratuit, sans pub et sans tracking. Si l'app te "
            "simplifie la vie, tu peux m'offrir un café pour soutenir le "
            "dev ☕.",
            textAlign: TextAlign.center,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x5),
          PrimaryButton(
            label: "Soutenir LimeBeam",
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: t.space.x2),
          TertiaryButton(
            label: "Plus tard",
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

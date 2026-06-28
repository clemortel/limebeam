import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
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
      title: AppLocalizations.of(context).tipPromptTitle,
      child: const TipPromptBottomSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            l.tipPromptBody,
            textAlign: TextAlign.center,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x5),
          PrimaryButton(
            label: l.tipPromptSupport,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: t.space.x2),
          TertiaryButton(
            label: l.tipPromptLater,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

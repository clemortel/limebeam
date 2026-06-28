import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

/// Bienvenue (§4.1.1). Logo, primary CTA, persistent legal note, secondary
/// link. Pure view — navigation is delegated via callbacks.
class WelcomeView extends StatelessWidget {
  const WelcomeView({
    required this.onAddSource,
    required this.onHaveSource,
    required this.onTryDemo,
    super.key,
  });

  final VoidCallback onAddSource;
  final VoidCallback onHaveSource;

  /// Loads the bundled demo playlist so the app can be tried with no source.
  final VoidCallback onTryDemo;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: t.space.x4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: t.space.x10),
                      const LimeBeamMark(),
                      SizedBox(height: t.space.x6),
                      BrandWordmark(style: t.typography.display),
                      SizedBox(height: t.space.x2),
                      Text(
                        l.welcomeTagline,
                        style: t.typography.body
                            .copyWith(color: t.colors.textSecondary),
                      ),
                      SizedBox(height: t.space.x8),
                      const _LegalNote(),
                      const Spacer(),
                      PrimaryButton(
                        label: l.authAddSource,
                        onPressed: onAddSource,
                      ),
                      SizedBox(height: t.space.x2),
                      SecondaryButton(
                        label: l.welcomeTryDemo,
                        onPressed: onTryDemo,
                      ),
                      SizedBox(height: t.space.x2),
                      TertiaryButton(
                        label: l.welcomeHaveSource,
                        onPressed: onHaveSource,
                      ),
                      SizedBox(height: t.space.x4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LegalNote extends StatelessWidget {
  const _LegalNote();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      padding: EdgeInsets.all(t.space.x4),
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        borderRadius: t.radius.mdAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: t.colors.textSecondary),
          SizedBox(width: t.space.x3),
          Expanded(
            child: Text(
              AppLocalizations.of(context).welcomeLegal,
              style: t.typography.caption.copyWith(color: t.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

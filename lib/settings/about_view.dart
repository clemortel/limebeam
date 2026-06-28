import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:package_info_plus/package_info_plus.dart";

const double _kInfoIconSize = 20;

/// Réglages → À propos (charte §7.3): brand, legal note, privacy,
/// open-source licenses, and the app version. 100% client-side, no backend.
class AboutView extends StatelessWidget {
  const AboutView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.aboutTitle, style: t.typography.h3),
      ),
      body: ListView(
        padding: EdgeInsets.all(t.space.x4),
        children: <Widget>[
          SizedBox(height: t.space.x4),
          const Center(child: LimeBeamLockup(markSize: 48)),
          SizedBox(height: t.space.x2),
          const Center(child: _Version()),
          SizedBox(height: t.space.x6),
          _Card(icon: Icons.info_outline, text: l.aboutNoContent),
          SizedBox(height: t.space.x3),
          _Card(icon: Icons.lock_outline, text: l.aboutPrivacy),
          SizedBox(height: t.space.x4),
          _NavRow(
            icon: Icons.workspaces_outline,
            label: l.aboutLicenses,
            onTap: () => _showLicenses(context),
          ),
        ],
      ),
    );
  }

  Future<void> _showLicenses(BuildContext context) async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!context.mounted) return;
    showLicensePage(
      context: context,
      applicationName: "LimeBeam",
      applicationVersion: info.version,
    );
  }
}

class _Version extends StatelessWidget {
  const _Version();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (BuildContext context, AsyncSnapshot<PackageInfo> snapshot) {
        final PackageInfo? info = snapshot.data;
        final String label = info == null
            ? l.aboutVersionLoading
            : l.aboutVersion(info.version, info.buildNumber);
        return Text(
          label,
          style: t.typography.caption.copyWith(color: t.colors.textTertiary),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      padding: EdgeInsets.all(t.space.x4),
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        borderRadius: t.radius.mdAll,
        border: Border.all(color: t.colors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: _kInfoIconSize, color: t.colors.textSecondary),
          SizedBox(width: t.space.x3),
          Expanded(
            child: Text(
              text,
              style:
                  t.typography.caption.copyWith(color: t.colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        borderRadius: t.radius.lgAll,
        border: Border.all(color: t.colors.borderSubtle),
      ),
      // Transparent Material so the ListTile's tap ripple stays visible over
      // the colored container.
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          leading: Icon(icon, color: t.colors.textSecondary),
          title: Text(
            label,
            style: t.typography.body.copyWith(color: t.colors.textPrimary),
          ),
          trailing: Icon(Icons.chevron_right, color: t.colors.textTertiary),
          onTap: onTap,
        ),
      ),
    );
  }
}

import "package:flutter/material.dart";
import "package:iptv_ui/iptv_ui.dart";

const double _kTypeCardIconSize = 28;

/// Ajouter une source — type selection (§4.1.2): Xtream portal or M3U.
class SourceTypeView extends StatelessWidget {
  const SourceTypeView({
    required this.onXtream,
    required this.onM3u,
    super.key,
  });

  final VoidCallback onXtream;
  final VoidCallback onM3u;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text("Ajouter une source", style: t.typography.h3),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space.x4),
          child: Column(
            children: <Widget>[
              _TypeCard(
                icon: Icons.vpn_key,
                title: "Xtream / Portail",
                subtitle: "Host + identifiants",
                onTap: onXtream,
              ),
              SizedBox(height: t.space.x4),
              _TypeCard(
                icon: Icons.playlist_play,
                title: "Playlist M3U",
                subtitle: "URL de playlist (chaînes en direct)",
                onTap: onM3u,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final bool enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: PressableScale(
        enabled: enabled,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(t.space.x5),
          decoration: BoxDecoration(
            color: t.colors.bgSurface,
            borderRadius: t.radius.lgAll,
            border: Border.all(color: t.colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: _kTypeCardIconSize, color: t.colors.accent),
              SizedBox(height: t.space.x3),
              Text(title, style: t.typography.h3.copyWith(
                color: t.colors.textPrimary,
              ),),
              SizedBox(height: t.space.x1),
              Text(subtitle, style: t.typography.caption.copyWith(
                color: t.colors.textSecondary,
              ),),
            ],
          ),
        ),
      ),
    );
  }
}

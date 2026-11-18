import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

/// Asks before deleting a finished download, then calls [onConfirmed].
/// Only completed downloads are worth a confirmation: they cost data.
Future<void> confirmRemoveDownload(
  BuildContext context,
  VoidCallback onConfirmed,
) async {
  final bool? confirmed = await AppBottomSheet.show<bool>(
    context,
    title: AppLocalizations.of(context).downloadsRemoveTitle,
    child: const RemoveDownloadSheet(),
  );
  if (confirmed ?? false) onConfirmed();
}

class RemoveDownloadSheet extends StatelessWidget {
  const RemoveDownloadSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space.x4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l.downloadsRemoveMessage,
            textAlign: TextAlign.center,
            style: t.typography.body.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x4),
          DestructiveButton(
            label: l.downloadsRemove,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: t.space.x2),
          SecondaryButton(
            label: l.commonCancel,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    );
  }
}

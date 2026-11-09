import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

const double _kMinHeight = 44;
const double _kIconSize = 18;

/// Whole-season download control beside the season chips. Counts come from the
/// caller, so this package never sees the series models.
///
/// Label: action, then "done/total" once anything is queued, then "season
/// downloaded". Tapping while partially done requests the missing episodes.
class SeasonDownloadButton extends StatelessWidget {
  const SeasonDownloadButton({
    required this.totalCount,
    required this.completedCount,
    required this.startedCount,
    required this.onDownload,
    super.key,
  });

  final int totalCount;
  final int completedCount;

  /// Episodes with a record in any phase (queued, running, done, failed).
  final int startedCount;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool allDone = totalCount > 0 && completedCount >= totalCount;
    final String label = allDone
        ? l.downloadsSeasonDone
        : startedCount > 0
            ? l.downloadsSeasonProgress(completedCount, totalCount)
            : l.downloadsSeasonAction;
    final IconData icon =
        allDone ? Icons.check_circle : Icons.download_outlined;
    final Color color = allDone ? t.colors.success : t.colors.accentTextOnDark;
    final VoidCallback? onTap = allDone ? null : onDownload;

    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _kMinHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.x2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: _kIconSize, color: color),
                SizedBox(width: t.space.x1),
                Text(
                  label,
                  style: t.typography.bodyStrong.copyWith(color: color),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

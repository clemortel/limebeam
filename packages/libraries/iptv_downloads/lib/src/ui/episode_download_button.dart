import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/download_phase.dart";
import "../models/download_record.dart";
import "../riverpods/providers.dart";
import "remove_download_sheet.dart";

const double _kTapTarget = 44;
const double _kGlyphSize = 24;
const double _kProgressSize = 22;
const double _kProgressStroke = 2.5;
const int _kPercent = 100;

/// Per-episode download control. Plain widget: the caller owns the state.
///
/// [onDownload] fires for "no record" and "failed" (retry). Tapping a
/// completed one asks for confirmation, then calls [onRemove]. The row
/// around it keeps playing on tap. Pause and resume go straight to the
/// downloads notifier, so callers keep the same three parameters.
class EpisodeDownloadButton extends ConsumerWidget {
  const EpisodeDownloadButton({
    required this.record,
    required this.onDownload,
    required this.onRemove,
    super.key,
  });

  final DownloadRecord? record;
  final VoidCallback onDownload;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final DownloadRecord? current = record;

    final (String label, Widget glyph, VoidCallback? onTap) = current == null
        ? (
            l.downloadsEpisodeDownload,
            Icon(
              Icons.download_outlined,
              size: _kGlyphSize,
              color: t.colors.textSecondary,
            ),
            onDownload,
          )
        : switch (current.phase) {
            DownloadPaused() => (
                l.downloadsEpisodePaused,
                Icon(
                  Icons.pause_circle_outline,
                  size: _kGlyphSize,
                  color: t.colors.textSecondary,
                ),
                () => ref.read(downloadsProvider.notifier).resume(current.key),
              ),
            DownloadQueued() => (
                l.downloadsEpisodeQueued,
                SizedBox(
                  width: _kProgressSize,
                  height: _kProgressSize,
                  child: CircularProgressIndicator(
                    strokeWidth: _kProgressStroke,
                    color: t.colors.textTertiary,
                  ),
                ),
                null,
              ),
            DownloadRunning(:final double progress) => (
                l.downloadsEpisodeRunning((progress * _kPercent).round()),
                SizedBox(
                  width: _kProgressSize,
                  height: _kProgressSize,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: _kProgressStroke,
                    color: t.colors.accent,
                    backgroundColor: t.colors.borderDefault,
                  ),
                ),
                () => ref.read(downloadsProvider.notifier).pause(current.key),
              ),
            DownloadCompleted() => (
                l.downloadsEpisodeDone,
                Icon(
                  Icons.check_circle,
                  size: _kGlyphSize,
                  color: t.colors.success,
                ),
                () => confirmRemoveDownload(context, onRemove),
              ),
            DownloadFailed() => (
                l.downloadsEpisodeRetry,
                Icon(
                  Icons.refresh,
                  size: _kGlyphSize,
                  color: t.colors.error,
                ),
                onDownload,
              ),
          };

    return Semantics(
      button: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _kTapTarget,
          height: _kTapTarget,
          child: Center(child: glyph),
        ),
      ),
    );
  }
}

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/download_failure_reason.dart";
import "../models/download_phase.dart";
import "../models/download_record.dart";
import "../models/download_storage_info.dart";
import "../riverpods/providers.dart";
import "byte_format.dart";
import "downloads_grouping.dart";
import "remove_download_sheet.dart";

const double _kPosterWidth = 48;
const double _kPosterAspect = 2 / 3;
const double _kSkeletonHeight = 120;
const double _kDeleteSize = 44;
const double _kProgressSize = 22;
const double _kProgressStroke = 2.5;
const double _kGlyphSize = 24;

/// Offline library: every download grouped series > season > episode.
///
/// Works with no network and makes none: records are local metadata, and the
/// poster falls back to a placeholder when it cannot load.
class DownloadsView extends ConsumerWidget {
  const DownloadsView({
    required this.onPlay,
    required this.onRetry,
    required this.sourceId,
    super.key,
  });

  final void Function(DownloadRecord record) onPlay;

  /// A failed record cannot restart from here: its URL is not stored, so
  /// the app layer rebuilds it from the record's own source.
  final void Function(DownloadRecord record) onRetry;

  /// The active playlist source: only its downloads are listed. Null when
  /// none is connected.
  final String? sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncState<IList<DownloadRecord>> state =
        ref.watch(downloadsProvider);
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.downloadsTitle, style: t.typography.h1),
      ),
      body: switch (state) {
        AsyncIdle<IList<DownloadRecord>>() =>
          SkeletonBox(height: _kSkeletonHeight, borderRadius: t.radius.smAll),
        AsyncLoading<IList<DownloadRecord>>() =>
          SkeletonBox(height: _kSkeletonHeight, borderRadius: t.radius.smAll),
        AsyncError<IList<DownloadRecord>>(:final Failures failure) => Center(
            child: Text(
              failure.localized(l),
              style:
                  t.typography.caption.copyWith(color: t.colors.textSecondary),
            ),
          ),
        AsyncSuccess<IList<DownloadRecord>>(
          data: final IList<DownloadRecord> all,
        ) =>
          recordsOfSource(all, sourceId).isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.download_for_offline_outlined,
                    title: l.downloadsEmptyTitle,
                    message: l.downloadsEmptyMessage,
                  ),
                )
              : _DownloadsList(
                  groups: groupDownloads(recordsOfSource(all, sourceId)),
                  sourceId: sourceId,
                  onPlay: onPlay,
                  onRetry: onRetry,
                  onPause: (String key) =>
                      ref.read(downloadsProvider.notifier).pause(key),
                  onResume: (String key) =>
                      ref.read(downloadsProvider.notifier).resume(key),
                  onRemove: (String key) =>
                      ref.read(downloadsProvider.notifier).remove(key),
                ),
      },
    );
  }
}

class _DownloadsList extends StatelessWidget {
  const _DownloadsList({
    required this.groups,
    required this.sourceId,
    required this.onPlay,
    required this.onRetry,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final IList<DownloadSeriesGroup> groups;
  final String? sourceId;
  final void Function(DownloadRecord record) onPlay;
  final void Function(DownloadRecord record) onRetry;
  final void Function(String key) onPause;
  final void Function(String key) onResume;
  final void Function(String key) onRemove;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView(
      padding: EdgeInsets.only(
        left: t.space.x4,
        right: t.space.x4,
        bottom: t.space.x8 + MediaQuery.paddingOf(context).bottom,
      ),
      children: <Widget>[
        _StorageHeader(sourceId: sourceId),
        for (final DownloadSeriesGroup group in groups) ...<Widget>[
          _SeriesHeader(group: group),
          for (final DownloadSeasonGroup season in group.seasons) ...<Widget>[
            _SeasonHeader(number: season.number),
            for (final DownloadRecord record in season.episodes)
              _DownloadRow(
                record: record,
                onPlay: () => onPlay(record),
                onRetry: () => onRetry(record),
                onPause: () => onPause(record.key),
                onResume: () => onResume(record.key),
                onRemove: () => onRemove(record.key),
              ),
          ],
          SizedBox(height: t.space.x4),
        ],
      ],
    );
  }
}

/// Space used by finished episodes and free space left on the device.
class _StorageHeader extends ConsumerWidget {
  const _StorageHeader({required this.sourceId});

  /// The active source, whose downloads the figure counts.
  final String? sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncState<DownloadStorageInfo> state =
        ref.watch(downloadStorageProvider(sourceId));
    final String text = switch (state) {
      AsyncIdle<DownloadStorageInfo>() => "",
      AsyncLoading<DownloadStorageInfo>() => "",
      AsyncError<DownloadStorageInfo>() => "",
      AsyncSuccess<DownloadStorageInfo>(:final DownloadStorageInfo data) =>
        <String>[
          l.downloadsStorageUsed(formatBytes(data.usedBytes)),
          if (data.totalUsedBytes > data.usedBytes)
            l.downloadsStorageTotal(formatBytes(data.totalUsedBytes)),
          if (data.freeBytes != null)
            l.downloadsStorageFree(formatBytes(data.freeBytes!)),
        ].join(" · "),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: t.space.x2),
      child: Text(
        text,
        style: t.typography.caption.copyWith(color: t.colors.textSecondary),
      ),
    );
  }
}

class _SeriesHeader extends StatelessWidget {
  const _SeriesHeader({required this.group});

  final DownloadSeriesGroup group;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.only(top: t.space.x4, bottom: t.space.x2),
      child: Row(
        children: <Widget>[
          _Poster(url: group.coverUrl),
          SizedBox(width: t.space.x3),
          Expanded(
            child: Text(
              group.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.typography.h3.copyWith(color: t.colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Widget placeholder = ColoredBox(
      color: t.colors.bgElevated,
      child: Icon(Icons.movie_outlined, color: t.colors.textTertiary),
    );
    return ClipRRect(
      borderRadius: t.radius.smAll,
      child: SizedBox(
        width: _kPosterWidth,
        height: _kPosterWidth / _kPosterAspect,
        // Offline the load fails: errorBuilder keeps the list intact.
        child: url.isEmpty
            ? placeholder
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                    placeholder,
              ),
      ),
    );
  }
}

class _SeasonHeader extends StatelessWidget {
  const _SeasonHeader({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space.x2),
      child: Text(
        AppLocalizations.of(context).downloadsSeasonHeader(number),
        style: t.typography.bodyStrong.copyWith(color: t.colors.textSecondary),
      ),
    );
  }
}

class _DownloadRow extends StatelessWidget {
  const _DownloadRow({
    required this.record,
    required this.onPlay,
    required this.onRetry,
    required this.onPause,
    required this.onResume,
    required this.onRemove,
  });

  final DownloadRecord record;
  final VoidCallback onPlay;
  final VoidCallback onRetry;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool playable = isPlayable(record);
    return PressableScale(
      onTap: playable ? onPlay : null,
      enabled: playable,
      focusBorderRadius: t.radius.mdAll,
      child: Semantics(
        label: l.downloadsPlayEpisode(record.title),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: t.space.x1),
          child: Row(
            children: <Widget>[
              _PhaseGlyph(phase: record.phase),
              SizedBox(width: t.space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "${record.episodeNumber}. ${record.title}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.bodyStrong
                          .copyWith(color: t.colors.textPrimary),
                    ),
                    _RowSubtitle(record: record),
                  ],
                ),
              ),
              _ActionButton(
                phase: record.phase,
                onPause: onPause,
                onResume: onResume,
                onRetry: onRetry,
              ),
              _DeleteButton(record: record, onRemove: onRemove),
            ],
          ),
        ),
      ),
    );
  }
}

/// Duration, or why a download is stopped.
class _RowSubtitle extends StatelessWidget {
  const _RowSubtitle({required this.record});

  final DownloadRecord record;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final (String text, Color color) = switch (record.phase) {
      DownloadFailed(:final DownloadFailureReason reason) => (
          downloadFailureLabel(l, reason),
          t.colors.error,
        ),
      DownloadPaused() => (l.downloadsEpisodePaused, t.colors.textSecondary),
      DownloadCompleted() => (record.duration, t.colors.textSecondary),
      DownloadQueued() => (record.duration, t.colors.textSecondary),
      DownloadRunning() => (record.duration, t.colors.textSecondary),
    };
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      style: t.typography.caption.copyWith(color: color),
    );
  }
}

/// Pause while it moves, resume when paused, retry when failed.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.phase,
    required this.onPause,
    required this.onResume,
    required this.onRetry,
  });

  final DownloadPhase phase;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final (String, IconData, VoidCallback)? action = switch (phase) {
      DownloadRunning() => (l.downloadsPause, Icons.pause, onPause),
      DownloadQueued() => (l.downloadsPause, Icons.pause, onPause),
      DownloadPaused() => (
          l.downloadsResume,
          Icons.play_arrow_outlined,
          onResume,
        ),
      DownloadFailed() => (l.downloadsEpisodeRetry, Icons.refresh, onRetry),
      DownloadCompleted() => null,
    };
    if (action == null) return const SizedBox.shrink();
    final (String label, IconData icon, VoidCallback onTap) = action;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _kDeleteSize,
          height: _kDeleteSize,
          child: Center(
            child: Icon(
              icon,
              size: _kGlyphSize,
              color: t.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading status: play when ready, progress while running, else a state icon.
class _PhaseGlyph extends StatelessWidget {
  const _PhaseGlyph({required this.phase});

  final DownloadPhase phase;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return SizedBox(
      width: _kDeleteSize,
      height: _kDeleteSize,
      child: Center(
        child: switch (phase) {
          DownloadCompleted() => Icon(
              Icons.play_circle_outline,
              size: _kGlyphSize,
              color: t.colors.accent,
            ),
          DownloadRunning(:final double progress) => SizedBox(
              width: _kProgressSize,
              height: _kProgressSize,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: _kProgressStroke,
                color: t.colors.accent,
                backgroundColor: t.colors.borderDefault,
              ),
            ),
          DownloadQueued() => SizedBox(
              width: _kProgressSize,
              height: _kProgressSize,
              child: CircularProgressIndicator(
                strokeWidth: _kProgressStroke,
                color: t.colors.textTertiary,
              ),
            ),
          DownloadPaused() => Icon(
              Icons.pause_circle_outline,
              size: _kGlyphSize,
              color: t.colors.textSecondary,
            ),
          DownloadFailed() => Icon(
              Icons.error_outline,
              size: _kGlyphSize,
              color: t.colors.error,
            ),
        },
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.record, required this.onRemove});

  final DownloadRecord record;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final String label = AppLocalizations.of(context).downloadsRemove;
    // Finished downloads cost data, so they ask first; the others do not.
    final VoidCallback onTap = switch (record.phase) {
      DownloadCompleted() => () => confirmRemoveDownload(context, onRemove),
      DownloadQueued() => onRemove,
      DownloadRunning() => onRemove,
      DownloadPaused() => onRemove,
      DownloadFailed() => onRemove,
    };
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _kDeleteSize,
          height: _kDeleteSize,
          child: Center(
            child: Icon(
              Icons.delete_outline,
              size: _kGlyphSize,
              color: t.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

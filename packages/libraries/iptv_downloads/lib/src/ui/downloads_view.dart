import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/download_phase.dart";
import "../models/download_record.dart";
import "../riverpods/providers.dart";
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
  const DownloadsView({required this.onPlay, super.key});

  final void Function(DownloadRecord record) onPlay;

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
          :final IList<DownloadRecord> data,
        ) =>
          data.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.download_for_offline_outlined,
                    title: l.downloadsEmptyTitle,
                    message: l.downloadsEmptyMessage,
                  ),
                )
              : _DownloadsList(
                  groups: groupDownloads(data),
                  onPlay: onPlay,
                  onRemove: (String id) =>
                      ref.read(downloadsProvider.notifier).remove(id),
                ),
      },
    );
  }
}

class _DownloadsList extends StatelessWidget {
  const _DownloadsList({
    required this.groups,
    required this.onPlay,
    required this.onRemove,
  });

  final IList<DownloadSeriesGroup> groups;
  final void Function(DownloadRecord record) onPlay;
  final void Function(String contentId) onRemove;

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
        for (final DownloadSeriesGroup group in groups) ...<Widget>[
          _SeriesHeader(group: group),
          for (final DownloadSeasonGroup season in group.seasons) ...<Widget>[
            _SeasonHeader(number: season.number),
            for (final DownloadRecord record in season.episodes)
              _DownloadRow(
                record: record,
                onPlay: () => onPlay(record),
                onRemove: () => onRemove(record.contentId),
              ),
          ],
          SizedBox(height: t.space.x4),
        ],
      ],
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
    required this.onRemove,
  });

  final DownloadRecord record;
  final VoidCallback onPlay;
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
                    if (record.duration.isNotEmpty)
                      Text(
                        record.duration,
                        style: t.typography.caption
                            .copyWith(color: t.colors.textSecondary),
                      ),
                  ],
                ),
              ),
              _DeleteButton(record: record, onRemove: onRemove),
            ],
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

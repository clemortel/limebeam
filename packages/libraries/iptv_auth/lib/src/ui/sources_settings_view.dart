import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/connection_status.dart";
import "../models/source.dart";
import "../models/source_type.dart";
import "../riverpods/sources_notifier.dart";
import "source_actions_sheets.dart";

const int _kSourcesSkeletonRows = 4;
const double _kSourcesDotSize = 10;
const double _kSourcesRowHeight = 44;
const double _kSourcesProgressHeight = 3;

/// Réglages → Sources (§4.6): list with connection dot, add, delete.
class SourcesSettingsView extends ConsumerWidget {
  const SourcesSettingsView({
    required this.onAddSource,
    required this.onNoSourceLeft,
    super.key,
  });

  final VoidCallback onAddSource;

  /// Called after the last source was deleted: the app has no active source
  /// anymore, so the host sends the user back to the first-launch flow.
  final VoidCallback onNoSourceLeft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncState<IList<Source>> state = ref.watch(sourcesProvider);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.settingsSources, style: t.typography.h3),
        actions: <Widget>[
          IconButton(
            tooltip: l.sourcesAddTooltip,
            icon: Icon(Icons.add, color: t.colors.accent),
            onPressed: onAddSource,
          ),
        ],
      ),
      body: switch (state) {
        AsyncIdle<IList<Source>>() => const _SourcesSkeleton(),
        AsyncLoading<IList<Source>>() => const _SourcesSkeleton(),
        AsyncError<IList<Source>>(:final Failures failure) => Center(
            child: EmptyState(
              icon: Icons.error_outline,
              title: l.commonError,
              message: failure.localized(l),
              action: PrimaryButton(
                label: l.commonRetry,
                expand: false,
                onPressed: ref.read(sourcesProvider.notifier).refresh,
              ),
            ),
          ),
        AsyncSuccess<IList<Source>>(:final IList<Source> data) => data.isEmpty
            ? Center(
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: l.sourcesEmptyTitle,
                  message: l.sourcesEmptyMessage,
                  action: PrimaryButton(
                    label: l.authAddSource,
                    expand: false,
                    onPressed: onAddSource,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: data.length,
                itemBuilder: (BuildContext context, int index) {
                  final Source source = data[index];
                  return _SourceRow(
                    source: source,
                    onNoSourceLeft: onNoSourceLeft,
                  );
                },
              ),
      },
    );
  }
}

class _SourcesSkeleton extends StatelessWidget {
  const _SourcesSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView.separated(
      padding: EdgeInsets.all(t.space.x4),
      itemCount: _kSourcesSkeletonRows,
      separatorBuilder: (BuildContext c, int i) => SizedBox(height: t.space.x3),
      itemBuilder: (BuildContext c, int i) => Row(
        children: <Widget>[
          SkeletonBox(
            width: _kSourcesDotSize,
            height: _kSourcesDotSize,
            borderRadius: t.radius.fullAll,
          ),
          SizedBox(width: t.space.x3),
          const Expanded(child: SkeletonBox(height: _kSourcesRowHeight)),
        ],
      ),
    );
  }
}

class _SourceRow extends ConsumerWidget {
  const _SourceRow({required this.source, required this.onNoSourceLeft});

  final Source source;
  final VoidCallback onNoSourceLeft;

  Future<void> _activate(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l = AppLocalizations.of(context);
    final Either<Failures, Unit> result =
        await ref.read(sourcesProvider.notifier).activate(source.id);
    if (!context.mounted) return;
    result.fold(
      (Failures f) => AppToast.show(
        context,
        message: f.localized(l),
        kind: ToastKind.error,
      ),
      (Unit _) => AppToast.show(
        context,
        message: l.sourcesSwitched(source.name),
        kind: ToastKind.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final bool isActive = ref.watch(activeSourceIdProvider) == source.id;
    final SyncProgress progress =
        isActive ? ref.watch(sourceSyncProvider) : const SyncProgress();
    final bool syncing = progress.isRunning;
    // Any running sync (not only this row's) freezes switching: two syncs
    // at once would mix catalogs.
    final bool busy = ref.watch(
      sourceSyncProvider.select((SyncProgress p) => p.isRunning),
    );
    final Color dot = switch (source.status) {
      ConnectionStatus.ok => t.colors.success,
      ConnectionStatus.error => t.colors.error,
      ConnectionStatus.offline => t.colors.offline,
      ConnectionStatus.unknown => t.colors.textTertiary,
    };
    final String typeLabel = switch (source.type) {
      SourceType.xtream => l.sourceTypeXtream,
      SourceType.m3u => l.sourceTypeM3u,
      SourceType.demo => l.sourcesTypeDemo,
    };
    final String subtitle = syncing
        ? progress.step.label(l)
        : progress.isFailed && progress.failure != null
            ? progress.failure!.localized(l)
            : typeLabel;

    return Semantics(
      selected: isActive,
      hint: isActive ? null : l.sourcesActivateHint,
      child: ListTile(
        tileColor: t.colors.bgSurface,
        selected: isActive,
        onTap: isActive || busy ? null : () => _activate(context, ref),
        leading: Container(
          width: _kSourcesDotSize,
          height: _kSourcesDotSize,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        title: Row(
          children: <Widget>[
            Flexible(
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.typography.h3.copyWith(color: t.colors.textPrimary),
              ),
            ),
            if (isActive) ...<Widget>[
              SizedBox(width: t.space.x2),
              AppBadge(label: l.sourcesActive, kind: AppBadgeKind.resume),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              subtitle,
              style: t.typography.caption.copyWith(
                color:
                    progress.isFailed ? t.colors.error : t.colors.textSecondary,
              ),
            ),
            if (syncing) ...<Widget>[
              SizedBox(height: t.space.x1),
              LinearProgressIndicator(
                value: progress.stepNumber / kSyncStepCount,
                minHeight: _kSourcesProgressHeight,
                color: t.colors.accent,
                backgroundColor: t.colors.bgElevated,
              ),
            ],
          ],
        ),
        trailing: IconButton(
          tooltip: l.sourcesMenuTooltip,
          icon: Icon(Icons.more_horiz, color: t.colors.textSecondary),
          onPressed: () => showSourceActions(
            context,
            ref,
            source: source,
            isActive: isActive,
            canRefresh: !busy,
            onNoSourceLeft: onNoSourceLeft,
          ),
        ),
      ),
    );
  }
}

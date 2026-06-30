import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/connection_status.dart";
import "../models/source.dart";
import "../riverpods/sources_notifier.dart";

const int _kSourcesSkeletonRows = 4;
const double _kSourcesDotSize = 10;
const double _kSourcesRowHeight = 44;

/// Réglages → Sources (§4.6): list with connection dot, add, delete.
class SourcesSettingsView extends ConsumerWidget {
  const SourcesSettingsView({required this.onAddSource, super.key});

  final VoidCallback onAddSource;

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
            icon: Icon(Icons.add, color: t.colors.accent),
            onPressed: onAddSource,
          ),
        ],
      ),
      body: switch (state) {
        AsyncIdle<IList<Source>>() => const _SourcesSkeleton(),
        AsyncLoading<IList<Source>>() => const _SourcesSkeleton(),
        AsyncError<IList<Source>>(:final Failures failure) => Center(
            child: Text(
              failure.localized(AppLocalizations.of(context)),
              style: t.typography.body.copyWith(color: t.colors.textSecondary),
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
                    onDelete: () => ref
                        .read(sourcesProvider.notifier)
                        .delete(source.id),
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

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source, required this.onDelete});

  final Source source;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Color dot = switch (source.status) {
      ConnectionStatus.ok => t.colors.success,
      ConnectionStatus.error => t.colors.error,
      ConnectionStatus.offline => t.colors.offline,
      ConnectionStatus.unknown => t.colors.textTertiary,
    };
    return ListTile(
      tileColor: t.colors.bgSurface,
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
      title: Text(
        source.name,
        style: t.typography.h3.copyWith(
          color: t.colors.textPrimary,
        ),
      ),
      subtitle: Text(
        source.type.name.toUpperCase(),
        style: t.typography.caption.copyWith(color: t.colors.textSecondary),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: t.colors.textTertiary),
        onPressed: onDelete,
      ),
    );
  }
}

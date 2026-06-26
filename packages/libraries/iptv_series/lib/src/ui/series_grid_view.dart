import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/series.dart";
import "../models/series_category.dart";
import "../riverpods/providers.dart";

const int _kColumns = 2;
const double _kPosterRatio = 0.56;

/// Séries grid (§4.4) — embeddable body (no Scaffold) for the Films & Séries
/// composite.
class SeriesGridView extends ConsumerWidget {
  const SeriesGridView({this.onOpenSeries, this.hideAdult = false, super.key});

  final void Function(Series series)? onOpenSeries;

  /// Hides adult-flagged categories and their series (parental control).
  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncState<IList<Series>> state = ref.watch(seriesNotifierProvider);
    final String selected = ref.watch(selectedSeriesCategoryProvider);
    final ISet<String> adultIds = hideAdult
        ? _adultSeriesCategoryIds(ref.watch(seriesCategoriesNotifierProvider))
        : const ISetConst<String>(<String>{});

    return Column(
      children: <Widget>[
        _SeriesChips(hideAdult: hideAdult),
        Expanded(
          child: switch (state) {
            AsyncIdle<IList<Series>>() => const _GridSkeleton(),
            AsyncLoading<IList<Series>>() => const _GridSkeleton(),
            AsyncError<IList<Series>>(:final Failures failure) => Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: "Erreur",
                  message: failure.computeErrorMessage(),
                ),
              ),
            AsyncSuccess<IList<Series>>(:final IList<Series> data) => _Grid(
                series: data
                    .where(
                      (Series s) =>
                          !adultIds.contains(s.categoryId) &&
                          (selected.isEmpty || s.categoryId == selected),
                    )
                    .toIList(),
                onOpenSeries: onOpenSeries,
              ),
          },
        ),
      ],
    );
  }
}

ISet<String> _adultSeriesCategoryIds(AsyncState<IList<SeriesCategory>> state) {
  final IList<SeriesCategory> categories = switch (state) {
    AsyncSuccess<IList<SeriesCategory>>(:final IList<SeriesCategory> data) =>
      data,
    _ => const IListConst<SeriesCategory>(<SeriesCategory>[]),
  };
  return categories
      .where((SeriesCategory c) => c.isAdult)
      .map((SeriesCategory c) => c.id)
      .toISet();
}

class _SeriesChips extends ConsumerWidget {
  const _SeriesChips({required this.hideAdult});

  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<SeriesCategory>> state =
        ref.watch(seriesCategoriesNotifierProvider);
    final String selected = ref.watch(selectedSeriesCategoryProvider);
    final IList<SeriesCategory> all = switch (state) {
      AsyncSuccess<IList<SeriesCategory>>(:final IList<SeriesCategory> data) =>
        data,
      _ => const IListConst<SeriesCategory>(<SeriesCategory>[]),
    };
    final IList<SeriesCategory> categories = hideAdult
        ? all.where((SeriesCategory c) => !c.isAdult).toIList()
        : all;

    return SizedBox(
      height: 34 + t.space.x4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.x4,
          vertical: t.space.x2,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (BuildContext c, int i) =>
            SizedBox(width: t.space.x2),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return FilterChipX(
              label: "Tous",
              selected: selected.isEmpty,
              onTap: () => ref
                  .read(selectedSeriesCategoryProvider.notifier)
                  .select(""),
            );
          }
          final SeriesCategory category = categories[index - 1];
          return FilterChipX(
            label: category.name,
            selected: selected == category.id,
            onTap: () => ref
                .read(selectedSeriesCategoryProvider.notifier)
                .select(category.id),
          );
        },
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.series, required this.onOpenSeries});

  final IList<Series> series;
  final void Function(Series series)? onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    if (series.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.video_library_outlined,
          title: "Aucune série",
          message: "Aucune série dans cette source.",
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.all(t.space.x4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kColumns,
        crossAxisSpacing: t.space.x3,
        mainAxisSpacing: t.space.x5,
        childAspectRatio: _kPosterRatio,
      ),
      itemCount: series.length,
      itemBuilder: (BuildContext context, int index) {
        final Series s = series[index];
        return MediaPosterCard(
          title: s.name,
          subtitle: s.year ?? "",
          posterUrl: s.coverUrl,
          onTap: () => onOpenSeries?.call(s),
        );
      },
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return GridView.builder(
      padding: EdgeInsets.all(t.space.x4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _kColumns,
        crossAxisSpacing: t.space.x3,
        mainAxisSpacing: t.space.x5,
        childAspectRatio: _kPosterRatio,
      ),
      itemCount: 6,
      itemBuilder: (BuildContext c, int i) =>
          SkeletonBox(borderRadius: t.radius.lgAll),
    );
  }
}

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

/// Poster carousel dimensions (magnified on TV like the Home rails).
const double _kPosterWidth = 120;
const double _kPosterRailHeight = 235;

double _railDim(BuildContext context, double value) =>
    FormFactorScope.isTv(context) ? value * AppTheme.tvTokenScale : value;

/// Which catalog a [GenreBrowseView] renders. Films and Séries are separate
/// destinations (their own rail tab), each a vertical scroll of genre rows.
enum BrowseKind { films, series }

/// A catalog browsed as vertical genre rows (Netflix-style): one horizontal
/// rail per category, every title in the category shown (no cap — the rail is
/// the category). The tab names the catalog, so there is no page header.
class GenreBrowseView extends ConsumerWidget {
  const GenreBrowseView({
    required this.kind,
    this.hideAdult = false,
    this.onOpenMovie,
    this.onOpenSeries,
    super.key,
  });

  final BrowseKind kind;
  final bool hideAdult;
  final void Function(Movie movie)? onOpenMovie;
  final void Function(Series series)? onOpenSeries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);

    final List<_RailRow> rows = kind == BrowseKind.films
        ? _rows<Movie, VodCategory>(
            items: _data(ref.watch(vodProvider)),
            cats: _data(ref.watch(vodCategoriesProvider)),
            categoryIdOf: (Movie m) => m.categoryId,
            idOf: (VodCategory c) => c.id,
            nameOf: (VodCategory c) => c.name,
            isAdultOf: (VodCategory c) => c.isAdult,
          )
        : _rows<Series, SeriesCategory>(
            items: _data(ref.watch(seriesProvider)),
            cats: _data(ref.watch(seriesCategoriesProvider)),
            categoryIdOf: (Series s) => s.categoryId,
            idOf: (SeriesCategory c) => c.id,
            nameOf: (SeriesCategory c) => c.name,
            isAdultOf: (SeriesCategory c) => c.isAdult,
          );

    final bool loading = kind == BrowseKind.films
        ? _loading(ref.watch(vodProvider))
        : _loading(ref.watch(seriesProvider));

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: rows.isEmpty
          ? (loading
              ? const _GenreSkeleton()
              : Center(
                  child: EmptyState(
                    icon: Icons.movie_outlined,
                    title: l.vodEmptyTitle,
                    message: l.vodEmptyMessage,
                  ),
                ))
          : ListView.builder(
              padding: EdgeInsets.only(
                top: t.space.x4,
                bottom: t.space.x6 + MediaQuery.paddingOf(context).bottom,
              ),
              itemCount: rows.length,
              itemBuilder: (BuildContext context, int index) =>
                  rows[index].build(context, this),
            ),
    );
  }

  /// One rail per non-empty category, in category order, with every item.
  List<_RailRow> _rows<T, C>({
    required IList<T> items,
    required IList<C> cats,
    required String Function(T) categoryIdOf,
    required String Function(C) idOf,
    required String Function(C) nameOf,
    required bool Function(C) isAdultOf,
  }) {
    final Map<String, List<T>> byCategory = <String, List<T>>{};
    for (final T item in items) {
      (byCategory[categoryIdOf(item)] ??= <T>[]).add(item);
    }
    final List<_RailRow> rows = <_RailRow>[];
    for (final C c in cats) {
      if (hideAdult && isAdultOf(c)) continue;
      final List<T>? group = byCategory[idOf(c)];
      if (group == null || group.isEmpty) continue;
      rows.add(_RailRow(title: nameOf(c), items: List<Object>.from(group)));
    }
    return rows;
  }

  IList<T> _data<T>(AsyncState<IList<T>> state) => switch (state) {
        AsyncSuccess<IList<T>>(:final IList<T> data) => data,
        _ => IList<T>(const <Never>[]),
      };

  bool _loading<T>(AsyncState<T> state) =>
      state is AsyncLoading<T> || state is AsyncIdle<T>;
}

class _RailRow {
  const _RailRow({required this.title, required this.items});
  final String title;
  final List<Object> items;

  Widget build(BuildContext context, GenreBrowseView view) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.appTheme.space.x5),
      child: SectionCarousel(
        title: title,
        itemCount: items.length,
        itemExtent: _railDim(context, _kPosterWidth),
        height: _railDim(context, _kPosterRailHeight),
        itemBuilder: (BuildContext context, int index) {
          final Object item = items[index];
          if (item is Movie) {
            return MediaPosterCard(
              title: item.name,
              subtitle: item.year ?? "",
              posterUrl: item.posterUrl,
              onTap: () => view.onOpenMovie?.call(item),
            );
          }
          final Series s = item as Series;
          return MediaPosterCard(
            title: s.name,
            subtitle: s.year ?? "",
            posterUrl: s.coverUrl,
            onTap: () => view.onOpenSeries?.call(s),
          );
        },
      ),
    );
  }
}

class _GenreSkeleton extends StatelessWidget {
  const _GenreSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView(
      padding: EdgeInsets.symmetric(vertical: t.space.x4),
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        for (int rail = 0; rail < 3; rail++) ...<Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.x4),
            child:
                SkeletonBox(width: 160, height: 20, borderRadius: t.radius.smAll),
          ),
          SizedBox(height: t.space.x3),
          SizedBox(
            height: _railDim(context, _kPosterRailHeight),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: t.space.x4),
              itemCount: 4,
              separatorBuilder: (BuildContext c, int i) =>
                  SizedBox(width: t.space.x3),
              itemBuilder: (BuildContext c, int i) => SizedBox(
                width: _railDim(context, _kPosterWidth),
                child: SkeletonBox(borderRadius: t.radius.lgAll),
              ),
            ),
          ),
          SizedBox(height: t.space.x6),
        ],
      ],
    );
  }
}

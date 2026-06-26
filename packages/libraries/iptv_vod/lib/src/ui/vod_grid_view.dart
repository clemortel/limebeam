import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/movie.dart";
import "../models/vod_category.dart";
import "../riverpods/providers.dart";

const int _kColumns = 2;
const double _kPosterRatio = 0.56; // poster + 2 text lines

/// Films grid (§4.4) — embeddable body (no Scaffold) so the Films & Séries
/// composite can host it under a segmented control.
class VodGridView extends ConsumerWidget {
  const VodGridView({this.onOpenMovie, this.hideAdult = false, super.key});

  final void Function(Movie movie)? onOpenMovie;

  /// Hides adult-flagged categories and their movies (parental control).
  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncState<IList<Movie>> state = ref.watch(vodNotifierProvider);
    final String selected = ref.watch(selectedVodCategoryProvider);
    final ISet<String> adultIds = hideAdult
        ? _adultVodCategoryIds(ref.watch(vodCategoriesNotifierProvider))
        : const ISetConst<String>(<String>{});

    return Column(
      children: <Widget>[
        _VodChips(hideAdult: hideAdult),
        Expanded(
          child: switch (state) {
            AsyncIdle<IList<Movie>>() => const _GridSkeleton(),
            AsyncLoading<IList<Movie>>() => const _GridSkeleton(),
            AsyncError<IList<Movie>>(:final Failures failure) => Center(
                child: EmptyState(
                  icon: Icons.error_outline,
                  title: "Erreur",
                  message: failure.computeErrorMessage(),
                ),
              ),
            AsyncSuccess<IList<Movie>>(:final IList<Movie> data) => _Grid(
                movies: data
                    .where(
                      (Movie m) =>
                          !adultIds.contains(m.categoryId) &&
                          (selected.isEmpty || m.categoryId == selected),
                    )
                    .toIList(),
                onOpenMovie: onOpenMovie,
              ),
          },
        ),
      ],
    );
  }
}

ISet<String> _adultVodCategoryIds(AsyncState<IList<VodCategory>> state) {
  final IList<VodCategory> categories = switch (state) {
    AsyncSuccess<IList<VodCategory>>(:final IList<VodCategory> data) => data,
    _ => const IListConst<VodCategory>(<VodCategory>[]),
  };
  return categories
      .where((VodCategory c) => c.isAdult)
      .map((VodCategory c) => c.id)
      .toISet();
}

class _VodChips extends ConsumerWidget {
  const _VodChips({required this.hideAdult});

  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<VodCategory>> state =
        ref.watch(vodCategoriesNotifierProvider);
    final String selected = ref.watch(selectedVodCategoryProvider);
    final IList<VodCategory> all = switch (state) {
      AsyncSuccess<IList<VodCategory>>(:final IList<VodCategory> data) => data,
      _ => const IListConst<VodCategory>(<VodCategory>[]),
    };
    final IList<VodCategory> categories = hideAdult
        ? all.where((VodCategory c) => !c.isAdult).toIList()
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
              onTap: () =>
                  ref.read(selectedVodCategoryProvider.notifier).select(""),
            );
          }
          final VodCategory category = categories[index - 1];
          return FilterChipX(
            label: category.name,
            selected: selected == category.id,
            onTap: () => ref
                .read(selectedVodCategoryProvider.notifier)
                .select(category.id),
          );
        },
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.movies, required this.onOpenMovie});

  final IList<Movie> movies;
  final void Function(Movie movie)? onOpenMovie;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    if (movies.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.movie_outlined,
          title: "Aucun film",
          message: "Aucun film dans cette source.",
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
      itemCount: movies.length,
      itemBuilder: (BuildContext context, int index) {
        final Movie movie = movies[index];
        return MediaPosterCard(
          title: movie.name,
          subtitle: movie.year ?? "",
          posterUrl: movie.posterUrl,
          onTap: () => onOpenMovie?.call(movie),
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

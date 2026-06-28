import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

const int _kRailLimit = 12;
const double _kLiveTileWidth = 260;
const double _kLiveRailHeight = 150;
const double _kPosterWidth = 120;
const double _kPosterRailHeight = 235;

/// Magnifies a fixed carousel dimension on TV so rail items grow with the
/// scaled-up typography/density (no effect on phone/tablet).
double _railDim(BuildContext context, double value) =>
    FormFactorScope.isTv(context) ? value * AppTheme.tvTokenScale : value;
const int _kSkeletonRails = 3;
const int _kSkeletonRailItems = 4;
const double _kSkeletonTitleWidth = 160;
const double _kSkeletonTitleHeight = 20;

/// Accueil dashboard (§4.2). Composes carousels from the cached feature
/// notifiers, with continue-watching ("Reprendre") and favorites on top.
class HomeView extends ConsumerWidget {
  const HomeView({
    this.onOpenChannel,
    this.onOpenMovie,
    this.onOpenSeries,
    this.onOpenSession,
    super.key,
  });

  final void Function(Channel channel)? onOpenChannel;
  final void Function(Movie movie)? onOpenMovie;
  final void Function(Series series)? onOpenSeries;
  final void Function(WatchSession session)? onOpenSession;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<Channel>> liveState =
        ref.watch(liveChannelsNotifierProvider);
    final AsyncState<IList<Movie>> vodState = ref.watch(vodNotifierProvider);
    final AsyncState<IList<Series>> seriesState =
        ref.watch(seriesNotifierProvider);
    final IList<Channel> channels = _data(liveState);
    final IList<Movie> movies = _data(vodState);
    final IList<Series> series = _data(seriesState);
    final IList<WatchSession> sessions =
        _data(ref.watch(watchSessionsNotifierProvider));
    final IList<Favorite> favorites =
        _data(ref.watch(favoritesNotifierProvider));

    final bool everythingEmpty =
        channels.isEmpty && movies.isEmpty && series.isEmpty;
    final bool loading =
        _loading(liveState) || _loading(vodState) || _loading(seriesState);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text("Accueil", style: t.typography.h1),
      ),
      body: everythingEmpty && loading
          ? const _HomeSkeleton()
          : everythingEmpty
              ? const Center(
                  child: EmptyState(
                    icon: Icons.live_tv_outlined,
                    title: "Rien à afficher",
                    message:
                        "Vos chaînes et contenus apparaîtront ici après la "
                        "synchronisation de votre source.",
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(
                    top: t.space.x4,
                    // Clear the floating glass nav bar (folded into the bottom
                    // inset by the shell's extendBody).
                    bottom: t.space.x4 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: <Widget>[
                    if (sessions.isNotEmpty) ...<Widget>[
                      _ResumeRail(
                        sessions: sessions.take(_kRailLimit).toIList(),
                        onOpen: onOpenSession,
                      ),
                      SizedBox(height: t.space.x6),
                    ],
                    if (favorites.isNotEmpty) ...<Widget>[
                      _FavoritesRail(
                        favorites: favorites.take(_kRailLimit).toIList(),
                        movies: movies,
                        series: series,
                        onOpenMovie: onOpenMovie,
                        onOpenSeries: onOpenSeries,
                      ),
                      SizedBox(height: t.space.x6),
                    ],
                    if (channels.isNotEmpty)
                      _LiveRail(
                        channels: channels.take(_kRailLimit).toIList(),
                        onOpenChannel: onOpenChannel,
                      ),
                    if (movies.isNotEmpty) ...<Widget>[
                      SizedBox(height: t.space.x6),
                      _PosterRail<Movie>(
                        title: "Films populaires",
                        items: movies.take(_kRailLimit).toIList(),
                        titleOf: (Movie m) => m.name,
                        subtitleOf: (Movie m) => m.year ?? "",
                        posterOf: (Movie m) => m.posterUrl,
                        onTap: (int i) => onOpenMovie?.call(movies[i]),
                      ),
                    ],
                    if (series.isNotEmpty) ...<Widget>[
                      SizedBox(height: t.space.x6),
                      _PosterRail<Series>(
                        title: "Séries populaires",
                        items: series.take(_kRailLimit).toIList(),
                        titleOf: (Series s) => s.name,
                        subtitleOf: (Series s) => s.year ?? "",
                        posterOf: (Series s) => s.coverUrl,
                        onTap: (int i) => onOpenSeries?.call(series[i]),
                      ),
                    ],
                    SizedBox(height: t.space.x6),
                  ],
                ),
    );
  }

  IList<T> _data<T>(AsyncState<IList<T>> state) => switch (state) {
        AsyncSuccess<IList<T>>(:final IList<T> data) => data,
        _ => IList<T>(const <Never>[]),
      };

  bool _loading<T>(AsyncState<T> state) =>
      state is AsyncLoading<T> || state is AsyncIdle<T>;
}

/// Placeholder rails shown while the feature notifiers load for the first time.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView(
      padding: EdgeInsets.symmetric(vertical: t.space.x4),
      physics: const NeverScrollableScrollPhysics(),
      children: <Widget>[
        for (int rail = 0; rail < _kSkeletonRails; rail++) ...<Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.x4),
            child: SkeletonBox(
              width: _kSkeletonTitleWidth,
              height: _kSkeletonTitleHeight,
              borderRadius: t.radius.smAll,
            ),
          ),
          SizedBox(height: t.space.x3),
          SizedBox(
            height: _railDim(context, _kPosterRailHeight),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: t.space.x4),
              itemCount: _kSkeletonRailItems,
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

/// Gentle, dismissible "support the dev" prompt. Never blocks content.
/// Continue-watching (§4.2). Resume bars + long-press to dismiss.
class _ResumeRail extends ConsumerWidget {
  const _ResumeRail({required this.sessions, required this.onOpen});

  final IList<WatchSession> sessions;
  final void Function(WatchSession session)? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SectionCarousel(
      title: "Reprendre",
      itemCount: sessions.length,
      itemExtent: _railDim(context, _kPosterWidth),
      height: _railDim(context, _kPosterRailHeight),
      itemBuilder: (BuildContext context, int index) {
        final WatchSession session = sessions[index];
        return MediaPosterCard(
          title: session.title,
          subtitle: session.subtitle ?? "",
          posterUrl: session.posterUrl,
          resumeFraction: session.fraction,
          onTap: () => onOpen?.call(session),
          onLongPress: () => ref
              .read(watchSessionsNotifierProvider.notifier)
              .remove(session.kind, session.id),
        );
      },
    );
  }
}

/// Favorites (§4.2). Tapping resolves the bookmark to its cached model.
class _FavoritesRail extends StatelessWidget {
  const _FavoritesRail({
    required this.favorites,
    required this.movies,
    required this.series,
    required this.onOpenMovie,
    required this.onOpenSeries,
  });

  final IList<Favorite> favorites;
  final IList<Movie> movies;
  final IList<Series> series;
  final void Function(Movie movie)? onOpenMovie;
  final void Function(Series series)? onOpenSeries;

  @override
  Widget build(BuildContext context) {
    return SectionCarousel(
      title: "Favoris",
      itemCount: favorites.length,
      itemExtent: _railDim(context, _kPosterWidth),
      height: _railDim(context, _kPosterRailHeight),
      itemBuilder: (BuildContext context, int index) {
        final Favorite favorite = favorites[index];
        return MediaPosterCard(
          title: favorite.title,
          subtitle: favorite.subtitle ?? "",
          posterUrl: favorite.posterUrl,
          onTap: () => _open(favorite),
        );
      },
    );
  }

  void _open(Favorite favorite) {
    if (favorite.kind == ContentKind.series) {
      for (final Series s in series) {
        if (s.id == favorite.id) {
          onOpenSeries?.call(s);
          return;
        }
      }
      return;
    }
    for (final Movie m in movies) {
      if (m.streamId == favorite.id) {
        onOpenMovie?.call(m);
        return;
      }
    }
  }
}

class _LiveRail extends StatelessWidget {
  const _LiveRail({required this.channels, required this.onOpenChannel});

  final IList<Channel> channels;
  final void Function(Channel channel)? onOpenChannel;

  @override
  Widget build(BuildContext context) {
    return SectionCarousel(
      title: "Live maintenant",
      itemCount: channels.length,
      itemExtent: _railDim(context, _kLiveTileWidth),
      height: _railDim(context, _kLiveRailHeight),
      itemBuilder: (BuildContext context, int index) {
        final Channel channel = channels[index];
        return LiveTile(
          channelName: channel.name,
          thumbnailUrl: channel.logoUrl,
          onTap: () => onOpenChannel?.call(channel),
        );
      },
    );
  }
}

class _PosterRail<T> extends StatelessWidget {
  const _PosterRail({
    required this.title,
    required this.items,
    required this.titleOf,
    required this.subtitleOf,
    required this.posterOf,
    required this.onTap,
  });

  final String title;
  final IList<T> items;
  final String Function(T) titleOf;
  final String Function(T) subtitleOf;
  final String? Function(T) posterOf;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCarousel(
      title: title,
      itemCount: items.length,
      itemExtent: _railDim(context, _kPosterWidth),
      height: _railDim(context, _kPosterRailHeight),
      itemBuilder: (BuildContext context, int index) {
        final T item = items[index];
        return MediaPosterCard(
          title: titleOf(item),
          subtitle: subtitleOf(item),
          posterUrl: posterOf(item),
          onTap: () => onTap(index),
        );
      },
    );
  }
}

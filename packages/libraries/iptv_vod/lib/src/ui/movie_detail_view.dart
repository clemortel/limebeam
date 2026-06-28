import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/movie.dart";
import "../models/movie_info.dart";
import "../riverpods/providers.dart";

const double _kBackdropAspect = 16 / 9;
const int _kSynopsisCollapsedLines = 3;

/// On TV the hero is capped to this fraction of the viewport height so the
/// title + "Lire" stay above the fold (a full-width 16:9 image would otherwise
/// fill the whole landscape screen and push the action off-screen).
const double _kTvHeroHeightFraction = 0.4;

/// Movie detail (§4.4.1): hero, meta line, synopsis (clamped + "Plus"), Lire.
class MovieDetailView extends ConsumerWidget {
  const MovieDetailView({
    required this.movie,
    this.onPlay,
    this.actions,
    super.key,
  });

  final Movie movie;
  final VoidCallback? onPlay;

  /// App-layer actions (e.g. a favorite toggle) shown in the app bar.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<MovieInfo> info =
        ref.watch(movieInfoNotifierProvider(movie.streamId));

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(backgroundColor: t.colors.bgBase, actions: actions),
      body: ListView(
        padding: EdgeInsets.only(bottom: t.space.x8),
        children: <Widget>[
          _Hero(posterUrl: movie.posterUrl, backdropUrl: _backdrop(info)),
          Padding(
            padding: EdgeInsets.all(t.space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  movie.name,
                  style: t.typography.h2.copyWith(color: t.colors.textPrimary),
                ),
                SizedBox(height: t.space.x2),
                _MetaLine(movie: movie, info: info),
                SizedBox(height: t.space.x4),
                PrimaryButton(
                  label: "Lire",
                  onPressed: onPlay,
                  autofocus: FormFactorScope.isTv(context),
                ),
                SizedBox(height: t.space.x6),
                _Synopsis(info: info),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _backdrop(AsyncState<MovieInfo> info) => switch (info) {
        AsyncSuccess<MovieInfo>(:final MovieInfo data) => data.backdropUrl,
        _ => null,
      };
}

class _Hero extends StatelessWidget {
  const _Hero({required this.posterUrl, required this.backdropUrl});

  final String? posterUrl;
  final String? backdropUrl;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final String? url = (backdropUrl != null && backdropUrl!.isNotEmpty)
        ? backdropUrl
        : posterUrl;
    final Widget image = url == null || url.isEmpty
        ? ColoredBox(color: t.colors.bgElevated)
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (BuildContext c, String _) => const SkeletonBox(),
            errorWidget: (BuildContext c, String _, Object __) =>
                ColoredBox(color: t.colors.bgElevated),
          );
    // TV: cap the height so the action stays above the fold. Touch: full-width
    // 16:9 (only ~⅓ of a portrait phone screen).
    if (FormFactorScope.isTv(context)) {
      return SizedBox(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * _kTvHeroHeightFraction,
        child: image,
      );
    }
    return AspectRatio(aspectRatio: _kBackdropAspect, child: image);
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.movie, required this.info});

  final Movie movie;
  final AsyncState<MovieInfo> info;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final MovieInfo? data = switch (info) {
      AsyncSuccess<MovieInfo>(:final MovieInfo data) => data,
      _ => null,
    };
    final List<String> parts = <String>[
      if (movie.year != null && movie.year!.isNotEmpty) movie.year!,
      if (data != null && data.genre.isNotEmpty) data.genre,
      if (data != null && data.duration.isNotEmpty) data.duration,
      if (movie.rating != null && movie.rating!.isNotEmpty) "★ ${movie.rating}",
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(" · "),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: t.typography.caption.copyWith(color: t.colors.textSecondary),
    );
  }
}

class _Synopsis extends StatefulWidget {
  const _Synopsis({required this.info});

  final AsyncState<MovieInfo> info;

  @override
  State<_Synopsis> createState() => _SynopsisState();
}

class _SynopsisState extends State<_Synopsis> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return switch (widget.info) {
      AsyncLoading<MovieInfo>() => SkeletonBox(
          height: 60,
          borderRadius: t.radius.smAll,
        ),
      AsyncSuccess<MovieInfo>(:final MovieInfo data) =>
        data.plot.isEmpty
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    data.plot,
                    maxLines: _expanded ? null : _kSynopsisCollapsedLines,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: t.typography.body
                        .copyWith(color: t.colors.textSecondary),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: EdgeInsets.only(top: t.space.x1),
                      child: Text(
                        _expanded ? "Moins" : "Plus",
                        style: t.typography.bodyStrong
                            .copyWith(color: t.colors.accentTextOnDark),
                      ),
                    ),
                  ),
                ],
              ),
      _ => const SizedBox.shrink(),
    };
  }
}

import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/movie.dart";
import "../models/movie_info.dart";
import "../riverpods/providers.dart";

const double _kBackdropAspect = 16 / 9;
const int _kSynopsisCollapsedLines = 3;

/// TV cinematic hero: the content column is capped to this fraction of the
/// screen width (lower-left), so text measure stays readable and the backdrop
/// art breathes on the right — the Netflix / Apple TV / Google TV pattern.
const double _kTvContentWidthFraction = 0.52;

/// Cap the full-screen backdrop decode so a 4K JPEG doesn't blow the texture
/// budget on a Fire TV Stick.
const int _kTvBackdropCacheWidth = 1280;

/// Movie detail (§4.4.1). Mobile: stacked hero + meta + synopsis + Play. TV: a
/// cinematic full-bleed backdrop with lower-left content and Play autofocused.
class MovieDetailView extends ConsumerWidget {
  const MovieDetailView({
    required this.movie,
    this.onPlay,
    this.actions,
    super.key,
  });

  final Movie movie;
  final VoidCallback? onPlay;

  /// App-layer actions (e.g. a favorite toggle). On mobile they sit in the app
  /// bar; on TV they sit in the action row beside Play.
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<MovieInfo> info =
        ref.watch(movieInfoProvider(movie.streamId));

    if (FormFactorScope.isTv(context)) {
      return _CinematicMovieDetail(
        movie: movie,
        info: info,
        onPlay: onPlay,
        actions: actions,
      );
    }

    // Mobile / tablet: unchanged stacked layout.
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
                  label: AppLocalizations.of(context).commonPlay,
                  onPressed: onPlay,
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

/// TV-only cinematic detail: full-bleed backdrop + scrims + lower-left content.
class _CinematicMovieDetail extends StatelessWidget {
  const _CinematicMovieDetail({
    required this.movie,
    required this.info,
    this.onPlay,
    this.actions,
  });

  final Movie movie;
  final AsyncState<MovieInfo> info;
  final VoidCallback? onPlay;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Size size = MediaQuery.sizeOf(context);
    final String? backdrop = switch (info) {
      AsyncSuccess<MovieInfo>(:final MovieInfo data) => data.backdropUrl,
      _ => null,
    };
    final String? url = (backdrop != null && backdrop.isNotEmpty)
        ? backdrop
        : movie.posterUrl;

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (url != null && url.isNotEmpty)
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: _kTvBackdropCacheWidth,
              placeholder: (BuildContext c, String _) =>
                  ColoredBox(color: t.colors.bgElevated),
              errorWidget: (BuildContext c, String _, Object __) =>
                  ColoredBox(color: t.colors.bgElevated),
            )
          else
            ColoredBox(color: t.colors.bgElevated),
          const _ScrimGradient(),
          Padding(
            padding: tvOverscan(context),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width * _kTvContentWidthFraction,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      movie.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          t.typography.h1.copyWith(color: t.colors.textPrimary),
                    ),
                    SizedBox(height: t.space.x2),
                    _MetaLine(movie: movie, info: info),
                    SizedBox(height: t.space.x5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        PrimaryButton(
                          label: AppLocalizations.of(context).commonPlay,
                          onPressed: onPlay,
                          expand: false,
                          autofocus: true,
                        ),
                        if (actions != null) ...<Widget>[
                          SizedBox(width: t.space.x3),
                          ...actions!,
                        ],
                      ],
                    ),
                    SizedBox(height: t.space.x5),
                    _Synopsis(info: info),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left→right + bottom→up dark scrims (tinted with bgBase) so left-anchored
/// text stays legible over the backdrop. Two gradients, zero GPU cost — no blur.
class _ScrimGradient extends StatelessWidget {
  const _ScrimGradient();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Color(0xE60B0C0E), Color(0x990B0C0E), Color(0x000B0C0E)],
          stops: <double>[0.0, 0.45, 0.85],
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[Color(0xE60B0C0E), Color(0x000B0C0E)],
            stops: <double>[0.0, 0.6],
          ),
        ),
        child: SizedBox.expand(),
      ),
    );
  }
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
      AsyncSuccess<MovieInfo>(:final MovieInfo data) => data.plot.isEmpty
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.plot,
                  maxLines: _expanded ? null : _kSynopsisCollapsedLines,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style:
                      t.typography.body.copyWith(color: t.colors.textSecondary),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: IptvFocusable(
                    onTap: () => setState(() => _expanded = !_expanded),
                    focusBorderRadius: t.radius.smAll,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: t.space.x1),
                      child: Text(
                        _expanded
                            ? AppLocalizations.of(context).commonLess
                            : AppLocalizations.of(context).commonMore,
                        style: t.typography.bodyStrong
                            .copyWith(color: t.colors.accentTextOnDark),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      _ => const SizedBox.shrink(),
    };
  }
}

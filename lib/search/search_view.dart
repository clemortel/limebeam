import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_ui/iptv_ui.dart";
import "package:iptv_vod/iptv_vod.dart";

import "../perf_log.dart";
import "search_notifier.dart";

const double _kPosterWidth = 120;
const double _kPosterRailHeight = 235;

/// Recherche (§4): unified search across live / VOD / series, grouped by type.
class SearchView extends ConsumerStatefulWidget {
  const SearchView({
    this.onOpenChannel,
    this.onOpenMovie,
    this.onOpenSeries,
    super.key,
  });

  final void Function(Channel channel)? onOpenChannel;
  final void Function(Movie movie)? onOpenMovie;
  final void Function(Series series)? onOpenSeries;

  @override
  ConsumerState<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends ConsumerState<SearchView> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    perfLog("SearchView.build START");
    final AppTheme t = context.appTheme;
    final String query = ref.watch(searchQueryProvider);
    final SearchResults results = ref.watch(searchResultsProvider);
    perfLog("SearchView.build providers read (query='$query')");
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => perfLog("SearchView FRAME PAINTED"),
    );

    final AppLocalizations l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text(l.searchTitle, style: t.typography.h1),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.all(t.space.x4),
            child: AppInput(
              controller: _controller,
              placeholder: l.searchPlaceholder,
              keyboardType: TextInputType.text,
              onChanged: ref.read(searchQueryProvider.notifier).setQuery,
            ),
          ),
          Expanded(
            child: _SearchBody(
              query: query,
              results: results,
              onOpenChannel: widget.onOpenChannel,
              onOpenMovie: widget.onOpenMovie,
              onOpenSeries: widget.onOpenSeries,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBody extends StatelessWidget {
  const _SearchBody({
    required this.query,
    required this.results,
    required this.onOpenChannel,
    required this.onOpenMovie,
    required this.onOpenSeries,
  });

  final String query;
  final SearchResults results;
  final void Function(Channel channel)? onOpenChannel;
  final void Function(Movie movie)? onOpenMovie;
  final void Function(Series series)? onOpenSeries;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    if (query.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.search,
          title: l.searchPrompt,
          message: l.searchPromptMessage,
        ),
      );
    }
    if (results.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.search_off,
          title: l.searchEmptyTitle,
          message: l.searchEmptyMessage,
        ),
      );
    }

    final AppTheme t = context.appTheme;
    // Slivers keep the (up-to-50) channel rows lazy so a broad query doesn't
    // build them all in one frame; the poster rails are already lazy.
    return CustomScrollView(
      slivers: <Widget>[
        if (results.channels.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: _GroupHeader(label: "Chaînes (${results.channels.length})"),
          ),
          SliverList.builder(
            itemCount: results.channels.length,
            itemBuilder: (BuildContext c, int i) {
              final Channel channel = results.channels[i];
              return ChannelRow(
                name: channel.name,
                logoUrl: channel.logoUrl,
                isLive: true,
                onTap: () => onOpenChannel?.call(channel),
              );
            },
          ),
        ],
        if (results.movies.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: _GroupHeader(label: "Films (${results.movies.length})"),
          ),
          SliverToBoxAdapter(
            child: _PosterRow(
              count: results.movies.length,
              builder: (int i) {
                final Movie m = results.movies[i];
                return MediaPosterCard(
                  title: m.name,
                  subtitle: m.year ?? "",
                  posterUrl: m.posterUrl,
                  onTap: () => onOpenMovie?.call(m),
                );
              },
            ),
          ),
        ],
        if (results.series.isNotEmpty) ...<Widget>[
          SliverToBoxAdapter(
            child: _GroupHeader(label: "Séries (${results.series.length})"),
          ),
          SliverToBoxAdapter(
            child: _PosterRow(
              count: results.series.length,
              builder: (int i) {
                final Series s = results.series[i];
                return MediaPosterCard(
                  title: s.name,
                  subtitle: s.year ?? "",
                  posterUrl: s.coverUrl,
                  onTap: () => onOpenSeries?.call(s),
                );
              },
            ),
          ),
        ],
        // Clear the floating glass nav bar (bottom inset set by the shell).
        SliverToBoxAdapter(
          child: SizedBox(
            height: t.space.x6 + MediaQuery.paddingOf(context).bottom,
          ),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.x4,
        t.space.x4,
        t.space.x4,
        t.space.x2,
      ),
      child: Text(
        label.toUpperCase(),
        style: t.typography.micro.copyWith(color: t.colors.textTertiary),
      ),
    );
  }
}

class _PosterRow extends StatelessWidget {
  const _PosterRow({required this.count, required this.builder});

  final int count;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return SizedBox(
      height: _kPosterRailHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.space.x4),
        itemCount: count,
        separatorBuilder: (BuildContext c, int i) =>
            SizedBox(width: t.space.x3),
        itemBuilder: (BuildContext c, int i) =>
            SizedBox(width: _kPosterWidth, child: builder(i)),
      ),
    );
  }
}

import "dart:async";

import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_vod/iptv_vod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "search_notifier.g.dart";

const int _kPerGroupLimit = 50;
const Duration _kDebounce = Duration(milliseconds: 300);

/// Grouped, immutable search results across the three content types.
class SearchResults {
  const SearchResults({
    required this.channels,
    required this.movies,
    required this.series,
  });

  final IList<Channel> channels;
  final IList<Movie> movies;
  final IList<Series> series;

  bool get isEmpty => channels.isEmpty && movies.isEmpty && series.isEmpty;

  static const SearchResults empty = SearchResults(
    channels: IListConst<Channel>(<Channel>[]),
    movies: IListConst<Movie>(<Movie>[]),
    series: IListConst<Series>(<Series>[]),
  );
}

/// Holds the debounced search query. The 300ms debounce is business logic, so
/// it lives here, not in the widget (§7).
@riverpod
class SearchQuery extends _$SearchQuery {
  Timer? _debounce;

  @override
  String build() {
    ref.onDispose(() => _debounce?.cancel());
    return "";
  }

  void setQuery(String raw) {
    _debounce?.cancel();
    _debounce = Timer(_kDebounce, () => state = raw.trim());
  }
}

/// Filters the cached content by the debounced query into [SearchResults].
@riverpod
SearchResults searchResults(SearchResultsRef ref) {
  final String q = ref.watch(searchQueryProvider).toLowerCase();
  if (q.isEmpty) return SearchResults.empty;

  final IList<Channel> channels =
      _data(ref.watch(liveChannelsNotifierProvider));
  final IList<Movie> movies = _data(ref.watch(vodNotifierProvider));
  final IList<Series> series = _data(ref.watch(seriesNotifierProvider));

  // Parental masking: adult categories must not surface in search (charte §7.4).
  final bool hideAdult = ref.watch(adultHiddenProvider);
  final Set<String> adultChannels = hideAdult
      ? _adultLiveIds(ref.watch(liveCategoriesNotifierProvider))
      : const <String>{};
  final Set<String> adultMovies = hideAdult
      ? _adultVodIds(ref.watch(vodCategoriesNotifierProvider))
      : const <String>{};
  final Set<String> adultSeries = hideAdult
      ? _adultSeriesIds(ref.watch(seriesCategoriesNotifierProvider))
      : const <String>{};

  bool matches(String name) => name.toLowerCase().contains(q);

  bool channelOk(Channel c) =>
      !adultChannels.contains(c.categoryId) && matches(c.name);
  bool movieOk(Movie m) =>
      !adultMovies.contains(m.categoryId) && matches(m.name);
  bool seriesOk(Series s) =>
      !adultSeries.contains(s.categoryId) && matches(s.name);

  return SearchResults(
    channels: channels.where(channelOk).take(_kPerGroupLimit).toIList(),
    movies: movies.where(movieOk).take(_kPerGroupLimit).toIList(),
    series: series.where(seriesOk).take(_kPerGroupLimit).toIList(),
  );
}

Set<String> _adultLiveIds(AsyncState<IList<LiveCategory>> state) {
  if (state is! AsyncSuccess<IList<LiveCategory>>) return <String>{};
  return state.data
      .where((LiveCategory c) => c.isAdult)
      .map((LiveCategory c) => c.id)
      .toSet();
}

Set<String> _adultVodIds(AsyncState<IList<VodCategory>> state) {
  if (state is! AsyncSuccess<IList<VodCategory>>) return <String>{};
  return state.data
      .where((VodCategory c) => c.isAdult)
      .map((VodCategory c) => c.id)
      .toSet();
}

Set<String> _adultSeriesIds(AsyncState<IList<SeriesCategory>> state) {
  if (state is! AsyncSuccess<IList<SeriesCategory>>) return <String>{};
  return state.data
      .where((SeriesCategory c) => c.isAdult)
      .map((SeriesCategory c) => c.id)
      .toSet();
}

IList<T> _data<T>(AsyncState<IList<T>> state) => switch (state) {
      AsyncSuccess<IList<T>>(:final IList<T> data) => data,
      _ => IList<T>(const <Never>[]),
    };

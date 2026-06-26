import "dart:convert";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";

import "../domain/playlist_source.dart";

/// M3U / M3U8 playlist client. Fetches the playlist text and parses extended
/// `#EXTINF` entries (off-isolate) into the same live payload shape the live
/// repository already understands. The per-channel stream URL IS the id, so
/// [buildLiveUrl] just returns it.
///
/// M3U has no structured VOD / series API, so those payloads are empty — M3U
/// sources surface live channels (+ optional separate EPG) only.
class M3uClient implements IPlaylistSource {
  M3uClient({required M3uConfig config, required HttpService http})
      : _http = http,
        _url = config.url,
        _epgUrl = config.epgUrl;

  final HttpService _http;
  final String _url;
  final String? _epgUrl;

  @override
  Future<Either<Failures, Map<String, dynamic>>> authenticate() async {
    try {
      final String raw = await _http.getRaw(_url);
      if (!raw.contains("#EXTM3U") && !raw.contains("#EXTINF")) {
        return left(const Failures.invalidPlaylist());
      }
      return right(const <String, dynamic>{});
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchLiveStreams() async {
    try {
      final String raw = await _http.getRaw(_url);
      final Map<String, dynamic> parsed =
          await runParse(parseM3uPlaylist, raw);
      return right(parsed);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchVod() async =>
      right(const <String, dynamic>{
        "categories": <dynamic>[],
        "streams": <dynamic>[],
      });

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchSeries() async =>
      right(const <String, dynamic>{
        "categories": <dynamic>[],
        "series": <dynamic>[],
      });

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchVodInfo(
    String vodId,
  ) async =>
      right(const <String, dynamic>{});

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchSeriesInfo(
    String seriesId,
  ) async =>
      right(const <String, dynamic>{});

  @override
  Future<Either<Failures, String>> fetchEpg() async {
    final String? epg = _epgUrl;
    if (epg == null || epg.isEmpty) return right("");
    try {
      final String xml = await _http.getRaw(epg);
      return right(xml);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  // The playlist URL is the id; nothing to build for M3U.
  @override
  String buildLiveUrl(String streamId) => streamId;

  @override
  String buildMovieUrl(String streamId, String containerExtension) => streamId;

  @override
  String buildSeriesUrl(String episodeId, String containerExtension) =>
      episodeId;
}

/// Parses an extended M3U into `{ streams: [...], categories: [...] }` using
/// the Xtream-shaped keys the live repository's parser already consumes. The
/// stream id is the channel URL. Top-level for `compute` (off the UI isolate).
Map<String, dynamic> parseM3uPlaylist(String raw) {
  final List<String> lines = const LineSplitter().convert(raw);
  final List<Map<String, dynamic>> streams = <Map<String, dynamic>>[];
  final Set<String> groups = <String>{};
  String? pendingName;
  Map<String, String> pendingAttrs = <String, String>{};
  int counter = 0;

  for (final String line in lines) {
    final String l = line.trim();
    if (l.isEmpty) continue;
    if (l.startsWith("#EXTINF")) {
      pendingAttrs = _parseAttributes(l);
      final int comma = l.lastIndexOf(",");
      pendingName = comma >= 0 ? l.substring(comma + 1).trim() : "";
    } else if (l.startsWith("#")) {
      continue;
    } else if (pendingName != null) {
      final String group = pendingAttrs["group-title"] ?? "Autres";
      groups.add(group);
      final String name = pendingName.isNotEmpty
          ? pendingName
          : pendingAttrs["tvg-name"] ?? "Chaîne";
      streams.add(<String, dynamic>{
        "stream_id": l,
        "name": name,
        "category_id": group,
        "stream_icon": pendingAttrs["tvg-logo"] ?? "",
        "epg_channel_id": pendingAttrs["tvg-id"] ?? "",
        "num": counter,
      });
      counter++;
      pendingName = null;
      pendingAttrs = <String, String>{};
    }
  }

  return <String, dynamic>{
    "streams": streams,
    "categories": <Map<String, dynamic>>[
      for (final String g in groups)
        <String, dynamic>{"category_id": g, "category_name": g},
    ],
  };
}

Map<String, String> _parseAttributes(String line) {
  final RegExp pattern = RegExp('([\\w-]+)="([^"]*)"');
  final Map<String, String> attributes = <String, String>{};
  for (final RegExpMatch match in pattern.allMatches(line)) {
    attributes[match.group(1)!] = match.group(2)!;
  }
  return attributes;
}

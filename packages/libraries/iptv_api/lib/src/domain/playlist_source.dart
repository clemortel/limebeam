import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";

/// The provider abstraction the whole app depends on.
///
/// Xtream Codes vs raw M3U is a swappable implementation detail behind this
/// interface. Higher layers never branch on the provider type.
///
/// Methods return raw payloads (decoded JSON for Xtream, raw text for M3U).
/// Parsing into models happens off-isolate in feature repositories.
abstract interface class IPlaylistSource {
  /// Authenticate the portal / validate the playlist URL. Returns the decoded
  /// account info on success (status, expiry, max connections…).
  Future<Either<Failures, Map<String, dynamic>>> authenticate();

  /// Live payload: `{ "categories": [...], "streams": [...] }`.
  Future<Either<Failures, Map<String, dynamic>>> fetchLiveStreams();

  /// VOD payload: `{ "categories": [...], "streams": [...] }`.
  Future<Either<Failures, Map<String, dynamic>>> fetchVod();

  /// Series payload: `{ "categories": [...], "series": [...] }`.
  Future<Either<Failures, Map<String, dynamic>>> fetchSeries();

  /// Full info for a single movie (`get_vod_info`): `{ "info": {...}, ... }`.
  Future<Either<Failures, Map<String, dynamic>>> fetchVodInfo(String vodId);

  /// Full info for a single series (`get_series_info`):
  /// `{ "info": {...}, "seasons": [...], "episodes": { "1": [...], ... } }`.
  Future<Either<Failures, Map<String, dynamic>>> fetchSeriesInfo(
    String seriesId,
  );

  /// Raw XMLTV EPG document.
  Future<Either<Failures, String>> fetchEpg();

  /// Playable URL for a live stream (default container).
  String buildLiveUrl(String streamId);

  /// Playable URL for a VOD movie with its container extension.
  String buildMovieUrl(String streamId, String containerExtension);

  /// Playable URL for a series episode with its container extension.
  String buildSeriesUrl(String episodeId, String containerExtension);
}

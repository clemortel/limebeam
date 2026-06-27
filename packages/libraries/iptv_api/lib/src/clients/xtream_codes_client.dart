import "dart:convert";
import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";

import "../domain/playlist_source.dart";

const String _kLog = "iptv.xtream";

/// Xtream Codes provider client (player_api.php). Built per-source with its
/// credentials + a shared [HttpService]. Returns raw decoded payloads; the
/// feature repositories parse them off-isolate.
class XtreamCodesClient implements IPlaylistSource {
  XtreamCodesClient({required XtreamConfig config, required HttpService http})
      : _http = http,
        _base = _normalizeHost(config.host),
        _user = config.username,
        _pass = config.password;

  final HttpService _http;
  final String _base;
  final String _user;
  final String _pass;

  static const String _defaultLiveExt = "ts";

  /// HLS container for the live stream — used by engines that cannot decode
  /// raw MPEG-TS (iOS AVPlayer / AirPlay). The provider must allow `m3u8`.
  static const String _hlsLiveExt = "m3u8";

  String get _playerApi => "$_base/player_api.php";

  Map<String, dynamic> get _authQuery => <String, dynamic>{
        "username": _user,
        "password": _pass,
      };

  Map<String, dynamic> _action(String action) => <String, dynamic>{
        ..._authQuery,
        "action": action,
      };

  @override
  Future<Either<Failures, Map<String, dynamic>>> authenticate() async {
    developer.log("authenticate host=$_base user=$_user", name: _kLog);
    try {
      final dynamic data =
          await _http.get(_playerApi, queryParameters: _authQuery);
      final Map<String, dynamic> map = _asMap(data);
      final Map<String, dynamic> userInfo = _asMap(map["user_info"]);
      final int auth = _asInt(userInfo["auth"]);
      final String status = "${userInfo["status"] ?? ""}";
      developer.log(
        "authenticate response: auth=$auth status='$status' "
        "keys=${map.keys.toList()}",
        name: _kLog,
      );
      if (auth != 1 || status.toLowerCase() != "active") {
        developer.log(
          "authenticate → portalAuth (auth=$auth, status='$status')",
          name: _kLog,
        );
        return left(const Failures.portalAuth());
      }
      return right(map);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchLiveStreams() async {
    try {
      final dynamic categories =
          await _http.get(_playerApi, queryParameters: _action("get_live_categories"));
      final dynamic streams =
          await _http.get(_playerApi, queryParameters: _action("get_live_streams"));
      return right(<String, dynamic>{
        "categories": categories,
        "streams": streams,
      });
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchVod() async {
    try {
      final dynamic categories =
          await _http.get(_playerApi, queryParameters: _action("get_vod_categories"));
      final dynamic streams =
          await _http.get(_playerApi, queryParameters: _action("get_vod_streams"));
      return right(<String, dynamic>{
        "categories": categories,
        "streams": streams,
      });
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchSeries() async {
    try {
      final dynamic categories =
          await _http.get(_playerApi, queryParameters: _action("get_series_categories"));
      final dynamic series =
          await _http.get(_playerApi, queryParameters: _action("get_series"));
      return right(<String, dynamic>{
        "categories": categories,
        "series": series,
      });
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchVodInfo(
    String vodId,
  ) async {
    try {
      final dynamic data = await _http.get(
        _playerApi,
        queryParameters: <String, dynamic>{
          ..._action("get_vod_info"),
          "vod_id": vodId,
        },
      );
      return right(_asMap(data));
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, Map<String, dynamic>>> fetchSeriesInfo(
    String seriesId,
  ) async {
    try {
      final dynamic data = await _http.get(
        _playerApi,
        queryParameters: <String, dynamic>{
          ..._action("get_series_info"),
          "series_id": seriesId,
        },
      );
      return right(_asMap(data));
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, String>> fetchEpg() async {
    try {
      final String xml = await _http.getRaw(
        "$_base/xmltv.php",
        queryParameters: _authQuery,
      );
      return right(xml);
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  String buildLiveUrl(String streamId, {bool hls = false}) =>
      "$_base/live/$_user/$_pass/$streamId.${hls ? _hlsLiveExt : _defaultLiveExt}";

  @override
  String buildMovieUrl(String streamId, String containerExtension) =>
      "$_base/movie/$_user/$_pass/$streamId.$containerExtension";

  @override
  String buildSeriesUrl(String episodeId, String containerExtension) =>
      "$_base/series/$_user/$_pass/$episodeId.$containerExtension";

  // --- helpers -------------------------------------------------------------

  /// Ensures a scheme is present and strips any trailing slash.
  static String _normalizeHost(String host) {
    String h = host.trim();
    if (!h.startsWith("http://") && !h.startsWith("https://")) {
      h = "http://$h";
    }
    while (h.endsWith("/")) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  /// Coerces a response to a JSON map. Some portals send valid JSON with a
  /// non-JSON content-type, so Dio hands it back as a String — decode it.
  static Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is String && value.trim().isNotEmpty) {
      try {
        final dynamic decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {
        developer.log(
          "authenticate: body is not JSON (first 120 chars): "
          "${value.length > 120 ? value.substring(0, 120) : value}",
          name: _kLog,
        );
      }
    }
    return <String, dynamic>{};
  }

  static int _asInt(dynamic value) => switch (value) {
        final int v => v,
        final String v => int.tryParse(v) ?? 0,
        _ => 0,
      };
}

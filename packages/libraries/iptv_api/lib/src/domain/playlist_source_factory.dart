import "package:injectable/injectable.dart";
import "package:iptv_core/iptv_core.dart";

import "../clients/demo_client.dart";
import "../clients/m3u_client.dart";
import "../clients/xtream_codes_client.dart";
import "playlist_source.dart";

/// Builds the right [IPlaylistSource] for a runtime [SourceConfig], keeping
/// Xtream-vs-M3U a swappable detail. Holds the shared [HttpService] and
/// stamps each client with its credentials.
@lazySingleton
class PlaylistSourceFactory {
  const PlaylistSourceFactory(this._http);

  final HttpService _http;

  IPlaylistSource create(SourceConfig config) {
    return switch (config) {
      final XtreamConfig c => XtreamCodesClient(config: c, http: _http),
      final M3uConfig c => M3uClient(config: c, http: _http),
      DemoConfig() => const DemoPlaylistSource(),
    };
  }
}

/// iptv_api — transport + provider clients.
///
/// Hosts the concrete [HttpService] implementation and the swappable
/// `IPlaylistSource` provider clients (Xtream / M3U), accessed through
/// [PlaylistSourceFactory]. Concrete clients stay private under `src/`.
library;

export "src/di.dart";
export "src/domain/playlist_source.dart";
export "src/domain/playlist_source_factory.dart";
export "src/http/dio_http_service.dart";

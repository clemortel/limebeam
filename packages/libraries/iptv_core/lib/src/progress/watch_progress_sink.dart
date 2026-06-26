/// Write-only seam for continue-watching. The player records playback progress
/// through this interface using primitives only, so `iptv_player` never depends
/// on `iptv_favorites` (which implements it and registers it in GetIt).
///
/// Implementations decide retention (e.g. drop a session once it is ~finished).
abstract interface class WatchProgressSink {
  /// Persist (or update) the resume point for one VOD item. [kind] is the
  /// content kind name ("movie" | "episode"); [id] is the stream/episode id
  /// used to rebuild the playable URL on resume.
  Future<void> saveProgress({
    required String id,
    required String kind,
    required String containerExtension,
    required String title,
    required int positionSeconds,
    required int durationSeconds,
    String? subtitle,
    String? posterUrl,
  });
}

/// Write-only seam for accumulating total watch time. The player reports
/// elapsed playback seconds through this interface using primitives only, so
/// `iptv_player` never depends on `iptv_settings` (which implements it and
/// registers it in GetIt).
///
/// Used solely to time the rare, ignorable "support the developer" prompt —
/// it never gates a feature or unlocks content.
abstract interface class WatchTimeSink {
  /// Adds [seconds] of watched playback to the running total. No-ops for
  /// non-positive values.
  Future<void> addWatchSeconds(int seconds);
}

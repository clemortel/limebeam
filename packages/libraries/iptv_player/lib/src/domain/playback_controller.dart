import "playback_status.dart";

/// The playback contract every screen depends on. Backed by media_kit in
/// `infrastructure`; the engine type never crosses this boundary.
abstract interface class PlaybackController {
  /// Status stream for UI controls / buffering indicators.
  Stream<PlaybackStatus> get status;

  /// Position stream, used for resume-position autosave (logic lives in a
  /// notifier, not here).
  Stream<Duration> get position;

  Duration get duration;

  /// Open a stream URL. [startAt] resumes continue-watching.
  Future<void> open(String url, {Duration startAt = Duration.zero});

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Release engine resources. Always call when leaving the player screen.
  Future<void> dispose();
}

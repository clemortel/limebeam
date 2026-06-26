/// Engine-agnostic playback lifecycle. UI maps this to controls state.
enum PlaybackStatus {
  idle,
  buffering,
  playing,
  paused,
  completed,
  error,
}

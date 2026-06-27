/// Read-only seam exposing the user's playback preferences to the player.
/// `iptv_player` reads track-language defaults and subtitle styling through
/// this interface using primitives only, so it never depends on
/// `iptv_settings` (which implements it and registers it in GetIt).
///
/// All getters are synchronous: the implementation reads the already-open
/// preferences box.
abstract interface class PlaybackPreferences {
  /// Preferred audio language code (e.g. "eng", "fra"); null = no preference.
  String? get preferredAudioLanguage;

  /// Preferred subtitle language code; null = none.
  String? get preferredSubtitleLanguage;

  /// Whether subtitles should be turned on automatically when a stream opens.
  bool get subtitlesEnabledByDefault;

  /// Subtitle size multiplier (1.0 = the renderer's default).
  double get subtitleFontScale;

  /// Subtitle text color as a 0xAARRGGBB int.
  int get subtitleTextColorArgb;

  /// Subtitle background box opacity (0..1; 0 = no box).
  double get subtitleBackgroundOpacity;
}

import "package:iptv_core/iptv_core.dart";

import "preferences_repository.dart";

/// Adapts the stored [AppPreferences] to the player's [PlaybackPreferences]
/// seam, exposing only the playback-relevant fields as primitives. Registered
/// in GetIt so `iptv_player` can read track defaults without depending on
/// `iptv_settings`.
///
/// Reads are synchronous (the preferences box is already open) and only happen
/// when a stream opens, so re-reading on each access is cheap.
class PlaybackPreferencesAdapter implements PlaybackPreferences {
  PlaybackPreferencesAdapter(this._repository);

  final IPreferencesRepository _repository;

  @override
  String? get preferredAudioLanguage =>
      _repository.load().preferredAudioLanguage;

  @override
  String? get preferredSubtitleLanguage =>
      _repository.load().preferredSubtitleLanguage;

  @override
  bool get subtitlesEnabledByDefault =>
      _repository.load().subtitlesEnabledByDefault;

  @override
  double get subtitleFontScale => _repository.load().subtitleFontScale;

  @override
  int get subtitleTextColorArgb => _repository.load().subtitleTextColorArgb;

  @override
  double get subtitleBackgroundOpacity =>
      _repository.load().subtitleBackgroundOpacity;
}

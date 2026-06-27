import "package:flutter_test/flutter_test.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_settings/src/infrastructure/playback_preferences_adapter.dart";

/// Minimal fake returning a fixed [AppPreferences]; only [load] is exercised by
/// the adapter.
class _FakePreferencesRepository implements IPreferencesRepository {
  _FakePreferencesRepository(this._prefs);

  final AppPreferences _prefs;

  @override
  AppPreferences load() => _prefs;

  @override
  Future<void> save(AppPreferences preferences) async {}

  @override
  Future<void> setPin(String pin) async {}

  @override
  Future<String?> readPin() async => null;

  @override
  Future<void> clearPin() async {}
}

void main() {
  test("should expose stored playback preferences as primitives", () {
    const AppPreferences stored = AppPreferences(
      preferredAudioLanguage: "fra",
      preferredSubtitleLanguage: "eng",
      subtitlesEnabledByDefault: true,
      subtitleFontScale: 1.5,
      subtitleTextColorArgb: 0xFF00E5FF,
      subtitleBackgroundOpacity: 1.0,
    );
    final PlaybackPreferences adapter =
        PlaybackPreferencesAdapter(_FakePreferencesRepository(stored));

    expect(adapter.preferredAudioLanguage, "fra");
    expect(adapter.preferredSubtitleLanguage, "eng");
    expect(adapter.subtitlesEnabledByDefault, isTrue);
    expect(adapter.subtitleFontScale, 1.5);
    expect(adapter.subtitleTextColorArgb, 0xFF00E5FF);
    expect(adapter.subtitleBackgroundOpacity, 1.0);
  });
}

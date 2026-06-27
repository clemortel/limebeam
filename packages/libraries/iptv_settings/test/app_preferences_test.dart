import "package:flutter_test/flutter_test.dart";
import "package:iptv_settings/iptv_settings.dart";

void main() {
  group("AppPreferences subtitle/audio fields", () {
    test("should default to no language preferences and renderer defaults", () {
      const AppPreferences prefs = AppPreferences();
      expect(prefs.preferredAudioLanguage, isNull);
      expect(prefs.preferredSubtitleLanguage, isNull);
      expect(prefs.subtitlesEnabledByDefault, isFalse);
      expect(prefs.subtitleFontScale, AppPreferences.defaultSubtitleFontScale);
      expect(
        prefs.subtitleTextColorArgb,
        AppPreferences.defaultSubtitleTextColorArgb,
      );
      expect(
        prefs.subtitleBackgroundOpacity,
        AppPreferences.defaultSubtitleBackgroundOpacity,
      );
    });

    test("should round-trip the new fields through JSON", () {
      const AppPreferences prefs = AppPreferences(
        preferredAudioLanguage: "fra",
        preferredSubtitleLanguage: "eng",
        subtitlesEnabledByDefault: true,
        subtitleFontScale: 1.25,
        subtitleTextColorArgb: 0xFFFFEB3B,
        subtitleBackgroundOpacity: 0.5,
      );

      final AppPreferences decoded =
          AppPreferences.fromJson(prefs.toJson());

      expect(decoded, prefs);
    });

    test("should decode legacy JSON without the new keys using defaults", () {
      // A blob saved before this feature existed.
      final Map<String, dynamic> legacy = <String, dynamic>{
        "themeMode": "dark",
        "autoplayNext": true,
      };

      final AppPreferences decoded = AppPreferences.fromJson(legacy);

      expect(decoded.preferredAudioLanguage, isNull);
      expect(decoded.subtitlesEnabledByDefault, isFalse);
      expect(decoded.subtitleFontScale, AppPreferences.defaultSubtitleFontScale);
    });
  });
}

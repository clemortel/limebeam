import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/app_preferences.dart";
import "providers.dart";

part "app_preferences_notifier.g.dart";

/// App-wide preferences. Loaded synchronously from the open Hive box; each
/// mutation updates state then persists. The parental PIN is verified through
/// here but stored in secure storage by the repository.
@Riverpod(keepAlive: true)
class AppPreferencesNotifier extends _$AppPreferencesNotifier {
  @override
  AppPreferences build() => ref.read(preferencesRepositoryProvider).load();

  Future<void> _update(AppPreferences next) async {
    state = next;
    await ref.read(preferencesRepositoryProvider).save(next);
  }

  Future<void> setThemeMode(AppThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setFontScale(FontScaleOption scale) =>
      _update(state.copyWith(fontScale: scale));

  Future<void> setLanguage(AppLanguage language) =>
      _update(state.copyWith(language: language));

  Future<void> setReduceTransparency(bool value) =>
      _update(state.copyWith(reduceTransparency: value));

  Future<void> setAutoplayNext(bool value) =>
      _update(state.copyWith(autoplayNext: value));

  Future<void> setPlayerGestures(bool value) =>
      _update(state.copyWith(playerGestures: value));

  /// Counts one app launch (for the gentle donation reminder heuristic).
  Future<void> registerLaunch() =>
      _update(state.copyWith(launchCount: state.launchCount + 1));

  /// Marks the user as a supporter — stops all donation reminders.
  Future<void> markSupporter() => _update(state.copyWith(supporter: true));

  Future<void> setDonationReminders(bool value) =>
      _update(state.copyWith(donationReminders: value));

  // --- Playback track preferences -----------------------------------------

  Future<void> setPreferredAudioLanguage(String? language) =>
      _update(state.copyWith(preferredAudioLanguage: language));

  Future<void> setPreferredSubtitleLanguage(String? language) =>
      _update(state.copyWith(preferredSubtitleLanguage: language));

  Future<void> setSubtitlesEnabledByDefault(bool value) =>
      _update(state.copyWith(subtitlesEnabledByDefault: value));

  Future<void> setSubtitleFontScale(double scale) =>
      _update(state.copyWith(subtitleFontScale: scale));

  Future<void> setSubtitleTextColorArgb(int argb) =>
      _update(state.copyWith(subtitleTextColorArgb: argb));

  Future<void> setSubtitleBackgroundOpacity(double opacity) =>
      _update(state.copyWith(subtitleBackgroundOpacity: opacity));

  /// Turns parental control on and stores [pin].
  Future<void> enableParental(String pin) async {
    await ref.read(preferencesRepositoryProvider).setPin(pin);
    await _update(state.copyWith(parentalEnabled: true));
  }

  /// Turns parental control off if [pin] matches the stored one.
  Future<bool> disableParental(String pin) async {
    final String? stored = await ref.read(preferencesRepositoryProvider).readPin();
    if (stored == null || stored != pin) return false;
    await ref.read(preferencesRepositoryProvider).clearPin();
    await _update(state.copyWith(parentalEnabled: false));
    return true;
  }

  /// Whether [pin] matches the stored parental PIN.
  Future<bool> verifyPin(String pin) async {
    final String? stored = await ref.read(preferencesRepositoryProvider).readPin();
    return stored != null && stored == pin;
  }
}

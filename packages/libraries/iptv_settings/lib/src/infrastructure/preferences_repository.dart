import "dart:convert";

import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:hive/hive.dart";

import "../models/app_preferences.dart";

/// Hive box holding the single preferences blob.
const String kPrefsBoxName = "iptv_prefs";
const String _kPrefsKey = "app_preferences";
const String _kParentalPinKey = "parental_pin";

/// Reads/writes [AppPreferences] (Hive) and the parental PIN (Keychain). The
/// box is opened by `registerSettings` before the notifier reads it.
abstract interface class IPreferencesRepository {
  /// Synchronous load from the already-open box; defaults when absent.
  AppPreferences load();

  Future<void> save(AppPreferences preferences);

  Future<void> setPin(String pin);

  Future<String?> readPin();

  Future<void> clearPin();
}

class PreferencesRepository implements IPreferencesRepository {
  PreferencesRepository(this._box, this._secureStorage);

  final Box<String> _box;
  final FlutterSecureStorage _secureStorage;

  @override
  AppPreferences load() {
    final String? raw = _box.get(_kPrefsKey);
    if (raw == null || raw.isEmpty) return const AppPreferences();
    try {
      return AppPreferences.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppPreferences();
    }
  }

  @override
  Future<void> save(AppPreferences preferences) =>
      _box.put(_kPrefsKey, jsonEncode(preferences.toJson()));

  @override
  Future<void> setPin(String pin) =>
      _secureStorage.write(key: _kParentalPinKey, value: pin);

  @override
  Future<String?> readPin() => _secureStorage.read(key: _kParentalPinKey);

  @override
  Future<void> clearPin() => _secureStorage.delete(key: _kParentalPinKey);
}

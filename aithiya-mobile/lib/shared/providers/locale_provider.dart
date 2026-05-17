import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists UI language preference (`system`, `en`, `si`).
///
/// When [locale] is null, the app follows the device locale (within supported set).
class LocaleProvider extends ChangeNotifier {
  LocaleProvider(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;
  static const _prefsKey = 'app_locale_v1';

  /// `system`, `en`, or `si`.
  String _preference = 'system';
  String get preference => _preference;

  /// Resolved override for [MaterialApp.locale], or null for system default.
  Locale? _locale;
  Locale? get locale => _locale;

  void _load() {
    final stored = _prefs.getString(_prefsKey);
    switch (stored) {
      case 'en':
        _preference = 'en';
        _locale = const Locale('en');
      case 'si':
        _preference = 'si';
        _locale = const Locale('si');
      default:
        _preference = 'system';
        _locale = null;
    }
    notifyListeners();
  }

  Future<void> setPreference(String value) async {
    switch (value) {
      case 'en':
        _locale = const Locale('en');
        _preference = 'en';
        await _prefs.setString(_prefsKey, 'en');
      case 'si':
        _locale = const Locale('si');
        _preference = 'si';
        await _prefs.setString(_prefsKey, 'si');
      default:
        _locale = null;
        _preference = 'system';
        await _prefs.remove(_prefsKey);
    }
    notifyListeners();
  }
}

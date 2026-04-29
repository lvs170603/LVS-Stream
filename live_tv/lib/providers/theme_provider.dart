import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent global theme controller.
/// Stores the user's choice in SharedPreferences so preference
/// survives hot-restarts and cold launches.
class ThemeProvider extends ChangeNotifier {
  static const _key = 'themeMode';

  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  /// Called once at startup to restore saved preference.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    _mode = _fromString(saved);
    notifyListeners();
  }

  /// Switch theme and persist immediately.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _toString(mode));
  }

  // ── helpers ──────────────────────────────────────────────
  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':  return ThemeMode.light;
      case 'dark':   return ThemeMode.dark;
      default:       return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:  return 'light';
      case ThemeMode.dark:   return 'dark';
      default:               return 'system';
    }
  }
}

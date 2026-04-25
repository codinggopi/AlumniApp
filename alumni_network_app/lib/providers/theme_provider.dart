import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_mode';
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved == 'light') {
      _mode = ThemeMode.light;
    } else if (saved == 'dark') {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    // Cycle: system → light → dark → system
    if (_mode == ThemeMode.system) {
      _mode = ThemeMode.light;
    } else if (_mode == ThemeMode.light) {
      _mode = ThemeMode.dark;
    } else {
      _mode = ThemeMode.system;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, _mode.name);
    notifyListeners();
  }

  IconData get icon {
    if (_mode == ThemeMode.dark) return Icons.dark_mode;
    if (_mode == ThemeMode.light) return Icons.light_mode;
    return Icons.brightness_auto;
  }
}

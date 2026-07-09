import 'package:flutter/material.dart';

/// Holds and toggles the app's current [ThemeMode].
///
/// Consumed via the app's own [ChangeNotifierProvider]
/// (see `core/state/change_notifier_provider.dart`) — no external state
/// management package required.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode;

  ThemeProvider({ThemeMode initial = ThemeMode.light}) : _themeMode = initial;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }
}

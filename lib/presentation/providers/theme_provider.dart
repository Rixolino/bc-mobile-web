import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // Risolvi il tema attuale basato su system
  ThemeMode get resolvedThemeMode {
    if (_themeMode == ThemeMode.system) {
      final brightness = SchedulerBinding.instance.window.platformBrightness;
      return brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
    }
    return _themeMode;
  }

  // Colori dinamici basati sul tema risolto
  Color get backgroundColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.white;
      case ThemeMode.dark:
        return const Color(0xFF121212);
      default:
        return Colors.white;
    }
  }

  Color get surfaceColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.grey[100]!;
      case ThemeMode.dark:
        return const Color(0xFF1E1E1E);
      default:
        return Colors.grey[100]!;
    }
  }

  Color get primaryColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.blue.shade700;
      case ThemeMode.dark:
        return Colors.blueAccent;
      default:
        return Colors.blue.shade700;
    }
  }

  Color get textColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.black;
      case ThemeMode.dark:
        return Colors.white;
      default:
        return Colors.black;
    }
  }

  Color get secondaryTextColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.black54;
      case ThemeMode.dark:
        return Colors.white70;
      default:
        return Colors.black54;
    }
  }

  // Semantic colors
  Color get successColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.green.shade700;
      case ThemeMode.dark:
        return Colors.green;
      default:
        return Colors.green.shade700;
    }
  }

  Color get warningColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.orange.shade700;
      case ThemeMode.dark:
        return Colors.orange;
      default:
        return Colors.orange.shade700;
    }
  }

  Color get errorColor {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return Colors.red.shade700;
      case ThemeMode.dark:
        return Colors.redAccent;
      default:
        return Colors.red.shade700;
    }
  }

  Gradient get progressGradient {
    switch (resolvedThemeMode) {
      case ThemeMode.light:
        return LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]);
      case ThemeMode.dark:
        return LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]);
      default:
        return LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]);
    }
  }
}
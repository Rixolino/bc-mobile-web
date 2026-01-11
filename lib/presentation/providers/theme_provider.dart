import 'package:flutter/material.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  // Colori dinamici basati sul tema
  Color get backgroundColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.white;
      case ThemeMode.dark:
        return const Color(0xFF121212);
      case ThemeMode.system:
        // Per system, usa il default dark per ora
        return const Color(0xFF121212);
    }
  }

  Color get surfaceColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.grey[100]!;
      case ThemeMode.dark:
        return const Color(0xFF1E1E1E);
      case ThemeMode.system:
        return const Color(0xFF1E1E1E);
    }
  }

  Color get primaryColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.blue.shade700;
      case ThemeMode.dark:
        return Colors.blueAccent;
      case ThemeMode.system:
        return Colors.blueAccent;
    }
  }

  Color get textColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.black;
      case ThemeMode.dark:
        return Colors.white;
      case ThemeMode.system:
        return Colors.white;
    }
  }

  Color get secondaryTextColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.black54;
      case ThemeMode.dark:
        return Colors.white70;
      case ThemeMode.system:
        return Colors.white70;
    }
  }

  // Semantic colors
  Color get successColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.green.shade700;
      case ThemeMode.dark:
        return Colors.green;
      case ThemeMode.system:
        return Colors.green;
    }
  }

  Color get warningColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.orange.shade700;
      case ThemeMode.dark:
        return Colors.orange;
      case ThemeMode.system:
        return Colors.orange;
    }
  }

  Color get errorColor {
    switch (_themeMode) {
      case ThemeMode.light:
        return Colors.red.shade700;
      case ThemeMode.dark:
        return Colors.redAccent;
      case ThemeMode.system:
        return Colors.redAccent;
    }
  }

  Gradient get progressGradient {
    switch (_themeMode) {
      case ThemeMode.light:
        return LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400]);
      case ThemeMode.dark:
        return LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]);
      case ThemeMode.system:
        return LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]);
    }
  }
}
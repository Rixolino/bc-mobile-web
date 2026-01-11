import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyBusInterval = 'bus_refresh_interval';
  static const String keyTrainInterval = 'train_refresh_interval';
  static const String keyPlaneInterval = 'plane_refresh_interval';
  static const String keyThemeMode = 'theme_mode';

  int _busRefreshSeconds = 0; // 0 means disabled
  int _trainRefreshSeconds = 0;
  int _planeRefreshSeconds = 0;
  ThemeMode _themeMode = ThemeMode.dark;

  int get busRefreshSeconds => _busRefreshSeconds;
  int get trainRefreshSeconds => _trainRefreshSeconds;
  int get planeRefreshSeconds => _planeRefreshSeconds;
  ThemeMode get themeMode => _themeMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _busRefreshSeconds = prefs.getInt(keyBusInterval) ?? 0;
    _trainRefreshSeconds = prefs.getInt(keyTrainInterval) ?? 0;
    _planeRefreshSeconds = prefs.getInt(keyPlaneInterval) ?? 0;
    final themeIndex = prefs.getInt(keyThemeMode) ?? 1; // 0: light, 1: dark, 2: system
    _themeMode = ThemeMode.values[themeIndex];
    notifyListeners();
  }

  Future<void> setBusRefreshSeconds(int seconds) async {
    _busRefreshSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBusInterval, seconds);
  }

  Future<void> setTrainRefreshSeconds(int seconds) async {
    _trainRefreshSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyTrainInterval, seconds);
  }

  Future<void> setPlaneRefreshSeconds(int seconds) async {
    _planeRefreshSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyPlaneInterval, seconds);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyThemeMode, mode.index);
  }
}

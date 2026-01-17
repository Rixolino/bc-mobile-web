import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyBusInterval = 'bus_refresh_interval';
  static const String keyTrainInterval = 'train_refresh_interval';
  static const String keyPlaneInterval = 'plane_refresh_interval';
  static const String keyThemeMode = 'theme_mode';
  static const String keyBusClustering = 'bus_clustering_enabled';
  static const String keyStopsClustering = 'stops_clustering_enabled';

  int _busRefreshSeconds = 0; // 0 means disabled
  int _trainRefreshSeconds = 0;
  int _planeRefreshSeconds = 0;
  ThemeMode _themeMode = ThemeMode.dark;
  bool _busClusteringEnabled = false;
  bool _stopsClusteringEnabled = false;

  int get busRefreshSeconds => _busRefreshSeconds;
  int get trainRefreshSeconds => _trainRefreshSeconds;
  int get planeRefreshSeconds => _planeRefreshSeconds;
  ThemeMode get themeMode => _themeMode;
  bool get busClusteringEnabled => _busClusteringEnabled;
  bool get stopsClusteringEnabled => _stopsClusteringEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _busRefreshSeconds = prefs.getInt(keyBusInterval) ?? 0;
    _trainRefreshSeconds = prefs.getInt(keyTrainInterval) ?? 0;
    _planeRefreshSeconds = prefs.getInt(keyPlaneInterval) ?? 0;
    final themeIndex = prefs.getInt(keyThemeMode) ?? 2; // 0: light, 1: dark, 2: system
    _themeMode = ThemeMode.values[themeIndex];
    _busClusteringEnabled = prefs.getBool(keyBusClustering) ?? false;
    _stopsClusteringEnabled = prefs.getBool(keyStopsClustering) ?? false;
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

  Future<void> setBusClusteringEnabled(bool enabled) async {
    _busClusteringEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBusClustering, enabled);
  }

  Future<void> setStopsClusteringEnabled(bool enabled) async {
    _stopsClusteringEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyStopsClustering, enabled);
  }
}

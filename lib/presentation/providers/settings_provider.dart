import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/android_background_service.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyBusInterval = 'bus_refresh_interval';
  static const String keyTrainInterval = 'train_refresh_interval';
  static const String keyPlaneInterval = 'plane_refresh_interval';
  static const String keyThemeMode = 'theme_mode';
  static const String keyBusClustering = 'bus_clustering_enabled';
  static const String keyStopsClustering = 'stops_clustering_enabled';
  static const String keyTrainsWorker = 'trains_worker_enabled';
  static const String keyBusesWorker = 'buses_worker_enabled';
  static const String keyFunctionsWorker = 'functions_worker_enabled';

  static const String keyMapStyle = 'map_style';

  // Configurable parameters for background workers
  static const String keyTrainStationId = 'train_station_id';
  static const String keyTrainService = 'train_service';
  static const String keyTrainArrivalPreNotice = 'train_arrival_prenotice_minutes';
  static const String keyBusProvider = 'bus_provider';
  static const String keyBusBaseUrl = 'bus_base_url';

  int _busRefreshSeconds = 0; // 0 means disabled
  int _trainRefreshSeconds = 0;
  int _planeRefreshSeconds = 0;
  ThemeMode _themeMode = ThemeMode.dark;
  String _mapStyle = 'osm'; // 'osm', 'cartodb_dark', 'cartodb_voyager', etc.
  bool _busClusteringEnabled = false;
  bool _stopsClusteringEnabled = false;
  bool _trainsWorkerEnabled = false;
  bool _busesWorkerEnabled = false;
  bool _functionsWorkerEnabled = false;

  // Worker params
  String _trainStationId = '';
  String _trainService = 'trainboardeu';
  String _busProvider = 'bari';
  String _busBaseUrl = 'https://betacloud-transporter.is-cool.dev';

  // Arrival pre-notice for trains (minutes before effective arrival)
  int _trainArrivalPreNoticeMinutes = 10; // default 10 minutes (5-20 allowed)

  int get busRefreshSeconds => _busRefreshSeconds;
  int get trainRefreshSeconds => _trainRefreshSeconds;
  int get planeRefreshSeconds => _planeRefreshSeconds;
  ThemeMode get themeMode => _themeMode;
  String get mapStyle => _mapStyle;
  bool get busClusteringEnabled => _busClusteringEnabled;
  bool get stopsClusteringEnabled => _stopsClusteringEnabled;
  bool get trainsWorkerEnabled => _trainsWorkerEnabled;
  bool get busesWorkerEnabled => _busesWorkerEnabled;
  bool get functionsWorkerEnabled => _functionsWorkerEnabled;

  String get trainStationId => _trainStationId;
  String get trainService => _trainService;
  String get busProvider => _busProvider;
  String get busBaseUrl => _busBaseUrl;

  // New: arrival pre-notice in minutes
  int get trainArrivalPreNoticeMinutes => _trainArrivalPreNoticeMinutes;

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
    
    // Default Map Style based on theme
    final sysThemeMode = ThemeMode.values[themeIndex]; 
    final isDark = sysThemeMode == ThemeMode.dark; 
    // Or check system brightness if system... but let's stick to stored string
    _mapStyle = prefs.getString(keyMapStyle) ?? (isDark ? 'cartodb_dark' : 'osm');
    
    _busClusteringEnabled = prefs.getBool(keyBusClustering) ?? false;
    _stopsClusteringEnabled = prefs.getBool(keyStopsClustering) ?? false;
    _trainsWorkerEnabled = prefs.getBool(keyTrainsWorker) ?? false;
    _busesWorkerEnabled = prefs.getBool(keyBusesWorker) ?? false;
    _functionsWorkerEnabled = prefs.getBool(keyFunctionsWorker) ?? false;

    // Load worker params
    _trainStationId = prefs.getString(keyTrainStationId) ?? '';
    _trainService = prefs.getString(keyTrainService) ?? 'trainboardeu';
    _trainArrivalPreNoticeMinutes = prefs.getInt(keyTrainArrivalPreNotice) ?? 10;
    _busProvider = prefs.getString(keyBusProvider) ?? 'bari';
    _busBaseUrl = prefs.getString(keyBusBaseUrl) ?? 'https://betacloud-transporter.is-cool.dev';

    notifyListeners();
  }

  Future<void> setMapStyle(String style) async {
    _mapStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyMapStyle, style);
  }

  Future<void> setBusRefreshSeconds(int seconds) async {
    _busRefreshSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBusInterval, seconds);

    // If buses worker is enabled, reschedule with new interval
    if (_busesWorkerEnabled) {
      try {
        await AndroidBackgroundService.scheduleBusesWorker(provider: _busProvider, baseUrl: _busBaseUrl, enableNotifications: true, intervalSeconds: seconds);
      } catch (e) {
        print('Error rescheduling buses worker: $e');
      }
    }
  }

  Future<void> setTrainRefreshSeconds(int seconds) async {
    _trainRefreshSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyTrainInterval, seconds);

    // If trains worker is enabled, reschedule with new interval
    if (_trainsWorkerEnabled) {
      try {
        await AndroidBackgroundService.scheduleTrainsWorker(stationId: _trainStationId.isNotEmpty ? _trainStationId : null, service: _trainService, enableNotifications: true, intervalSeconds: seconds, arrivalNoticeMinutes: _trainArrivalPreNoticeMinutes);
      } catch (e) {
        print('Error rescheduling trains worker: $e');
      }
    }
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

  Future<void> setTrainsWorkerEnabled(bool enabled) async {
    _trainsWorkerEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyTrainsWorker, enabled);
  }

  Future<void> setBusesWorkerEnabled(bool enabled) async {
    _busesWorkerEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyBusesWorker, enabled);
  }

  Future<void> setFunctionsWorkerEnabled(bool enabled) async {
    _functionsWorkerEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyFunctionsWorker, enabled);
  }

  // Train worker config
  Future<void> setTrainStationId(String id) async {
    _trainStationId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTrainStationId, id);
  }

  Future<void> setTrainService(String service) async {
    _trainService = service;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyTrainService, service);
  }

  Future<void> setTrainArrivalPreNoticeMinutes(int minutes) async {
    _trainArrivalPreNoticeMinutes = minutes;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyTrainArrivalPreNotice, minutes);

    // If trains worker is enabled, reschedule with new pre-notice value
    if (_trainsWorkerEnabled) {
      try {
        await AndroidBackgroundService.scheduleTrainsWorker(stationId: _trainStationId.isNotEmpty ? _trainStationId : null, service: _trainService, enableNotifications: true, intervalSeconds: _trainRefreshSeconds, );
      } catch (e) {
        print('Error rescheduling trains worker with new arrival pre-notice: $e');
      }
    }
  }

  // Bus worker config
  Future<void> setBusProvider(String provider) async {
    _busProvider = provider;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBusProvider, provider);
  }

  Future<void> setBusBaseUrl(String baseUrl) async {
    _busBaseUrl = baseUrl;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyBusBaseUrl, baseUrl);
  }
}


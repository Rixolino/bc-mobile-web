import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bc_transporter/core/services/tts_service.dart';
import '../../core/services/android_background_service.dart';

class SettingsProvider with ChangeNotifier {
  static const String keyBusInterval = 'bus_refresh_interval';
  static const String keyTrainInterval = 'train_refresh_interval';
  static const String keyPlaneInterval = 'plane_refresh_interval';

  // Value constant for Auto mode
  static const int AUTO_REFRESH = -1;

  static const String keyThemeMode = 'theme_mode';
  static const String keyBusClustering = 'bus_clustering_enabled';
  static const String keyStopsClustering = 'stops_clustering_enabled';
  static const String keyTrainsWorker = 'trains_worker_enabled';
  static const String keyBusesWorker = 'buses_worker_enabled';
  static const String keyFunctionsWorker = 'functions_worker_enabled';

  static const String keyMapStyle = 'map_style';
  static const String keyStartScreen = 'ui_start_screen';
  static const String keyTextScale = 'ui_text_scale';
  static const String keyVectorLogos = 'ui_vector_logos_enabled';
  static const String keyLogoSource = 'ui_logo_source';
  static const String keyLanguage = 'app_language';
  static const String keyTtsEnabled = 'accessibility_tts_enabled';
  static const String keyTtsVoice = 'accessibility_tts_voice';

  // Configurable parameters for background workers
  static const String keyTrainStationId = 'train_station_id';
  static const String keyTrainService = 'train_service';
  static const String keyTrainArrivalPreNotice =
      'train_arrival_prenotice_minutes';
  static const String keyBusProvider = 'bus_provider';
  static const String keyBusBaseUrl = 'bus_base_url';
  static const String keyOfflineSyncEnabled = 'offline_sync_enabled';
  static const String keyOfflineSyncBeta = 'offline_sync_beta';

  int _busRefreshSeconds = AUTO_REFRESH; // Default to Auto (-1)
  int _trainRefreshSeconds = AUTO_REFRESH;
  int _planeRefreshSeconds = AUTO_REFRESH;

  // Auto rates fetched from server (dynamic load balancing)
  int _autoBusRate = 10;
  int _autoTrainRate = 15;
  int _autoPlaneRate = 15;
  Timer? _serverPollTimer;

  ThemeMode _themeMode = ThemeMode.dark;
  Locale? _appLocale; // Null means system default
  // stores a Mapbox style URL, e.g. 'mapbox://styles/mapbox/dark-v11'
  // older values (osm/cartodb_*) will be migrated when loaded.
  String _mapStyle = 'mapbox://styles/mapbox/dark-v11';
  bool _busClusteringEnabled = false;
  bool _stopsClusteringEnabled = false;
  bool _vectorLogosEnabled = false;
  String _logoSource = 'official';
  bool _trainsWorkerEnabled = false;
  bool _busesWorkerEnabled = false;
  bool _functionsWorkerEnabled = false;

  // Worker params
  String _trainStationId = '';
  String _trainService = 'trainboardeu';
  String _busProvider = 'bari';
  String _busBaseUrl = 'https://betacloud-transporter.is-cool.dev';

  // Schermata iniziale: 0 Home, 1 Treni, 2 Bus, 3 Aerei, 4 Autostrade
  int _startScreenMode = 0;

  // Zoom testi dell'app (non mappa): 1.0 = normale
  double _textScale = 1.0;

  // Text-to-speech for train announcements
  bool _ttsEnabled = false;
  Map<String, String> _ttsVoices = {}; // langCode -> voiceName
  double _ttsSpeechRate = 1.0;

  // Arrival pre-notice for trains (minutes before effective arrival)
  int _trainArrivalPreNoticeMinutes = 10; // default 10 minutes (5-20 allowed)

  // Offline sync feature (beta)
  bool _offlineSyncEnabled = false;

  // Returns effective rate (either manual or server-suggested auto)
  int get busRefreshSeconds =>
      _busRefreshSeconds == AUTO_REFRESH ? _autoBusRate : _busRefreshSeconds;
  int get trainRefreshSeconds => _trainRefreshSeconds == AUTO_REFRESH
      ? _autoTrainRate
      : _trainRefreshSeconds;
  int get planeRefreshSeconds => _planeRefreshSeconds == AUTO_REFRESH
      ? _autoPlaneRate
      : _planeRefreshSeconds;

  // Raw preferences for UI (use these for Dropdown value)
  int get busRefreshPreference => _busRefreshSeconds;
  int get trainRefreshPreference => _trainRefreshSeconds;
  int get planeRefreshPreference => _planeRefreshSeconds;

  bool get isBusAuto => _busRefreshSeconds == AUTO_REFRESH;
  bool get isTrainAuto => _trainRefreshSeconds == AUTO_REFRESH;
  bool get isPlaneAuto => _planeRefreshSeconds == AUTO_REFRESH;

  int get currentAutoBusRate => _autoBusRate;
  int get currentAutoTrainRate => _autoTrainRate;
  int get currentAutoPlaneRate => _autoPlaneRate;

  ThemeMode get themeMode => _themeMode;
  Locale? get appLocale => _appLocale;
  bool get isLocaleAutomatic => _appLocale == null;
  String get mapStyle => _mapStyle;
  bool get busClusteringEnabled => _busClusteringEnabled;
  bool get stopsClusteringEnabled => _stopsClusteringEnabled;
  bool get vectorLogosEnabled => _vectorLogosEnabled;
  String get logoSource => _logoSource;
  bool get trainsWorkerEnabled => _trainsWorkerEnabled;
  bool get busesWorkerEnabled => _busesWorkerEnabled;
  bool get functionsWorkerEnabled => _functionsWorkerEnabled;

  String get trainStationId => _trainStationId;
  String get trainService => _trainService;
  String get busProvider => _busProvider;
  String get busBaseUrl => _busBaseUrl;

  // New: arrival pre-notice in minutes
  int get trainArrivalPreNoticeMinutes => _trainArrivalPreNoticeMinutes;

  // Schermata iniziale dell'app
  int get startScreenMode => _startScreenMode;

  // Zoom testi dell'app
  double get textScale => _textScale;

  // Text-to-speech for train announcements
  bool get ttsEnabled => _ttsEnabled;
  String ttsVoiceForLang(String langCode) => _ttsVoices[langCode] ?? _defaultVoiceName(langCode);
  double get ttsSpeechRate => _ttsSpeechRate;

  String _defaultVoiceName(String langCode) {
    const defaults = {'it': 'Roberto', 'en': 'Daniel', 'de': 'Anna', 'fr': 'Thomas'};
    return defaults[langCode] ?? 'Roberto';
  }

  // New: offline sync feature (beta)
  bool get offlineSyncEnabled => _offlineSyncEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to AUTO (-1) if not set. 0 means manually disabled.
    _busRefreshSeconds = prefs.getInt(keyBusInterval) ?? AUTO_REFRESH;
    _trainRefreshSeconds = prefs.getInt(keyTrainInterval) ?? AUTO_REFRESH;
    _planeRefreshSeconds = prefs.getInt(keyPlaneInterval) ?? AUTO_REFRESH;
    final themeIndex =
        prefs.getInt(keyThemeMode) ?? 2; // 0: light, 1: dark, 2: system
    _themeMode = ThemeMode.values[themeIndex];

    final langCode = prefs.getString(keyLanguage);
    if (langCode != null && langCode.isNotEmpty) {
      _appLocale = Locale(langCode);
    } else {
      _appLocale = null;
    }

    // Default Map Style saved (style URL).  Normalize any legacy names.
    String stored = prefs.getString(keyMapStyle) ?? '';
    _mapStyle = _normalizeStyleUrl(stored);
    if (_mapStyle.isEmpty) {
      // fallback according to theme
      final isDark = _themeMode == ThemeMode.dark;
      _mapStyle = isDark
          ? 'mapbox://styles/mapbox/dark-v11'
          : 'mapbox://styles/mapbox/streets-v11';
    }

    _busClusteringEnabled = prefs.getBool(keyBusClustering) ?? false;
    _stopsClusteringEnabled = prefs.getBool(keyStopsClustering) ?? false;
    _vectorLogosEnabled = prefs.getBool(keyVectorLogos) ?? false;
    _logoSource = prefs.getString(keyLogoSource) ?? 'official';
    _trainsWorkerEnabled = prefs.getBool(keyTrainsWorker) ?? false;
    _busesWorkerEnabled = prefs.getBool(keyBusesWorker) ?? false;
    _functionsWorkerEnabled = prefs.getBool(keyFunctionsWorker) ?? false;
    _startScreenMode = prefs.getInt(keyStartScreen) ?? 0;
    _textScale = (prefs.getDouble(keyTextScale) ?? 1.0).clamp(0.8, 1.4);
    _ttsEnabled = prefs.getBool(keyTtsEnabled) ?? false;
    // Load TTS voice per language
    final savedVoice = prefs.getString(keyTtsVoice);
    if (savedVoice != null && savedVoice.isNotEmpty) {
      _ttsVoices['it'] = savedVoice;
    }
    // Load per-language voices from new key
    final voicesJson = prefs.getString('accessibility_tts_voices');
    if (voicesJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(voicesJson);
        _ttsVoices = decoded.map((k, v) => MapEntry(k, v.toString()));
      } catch (_) {}
    }

    // Load worker params
    _trainStationId = prefs.getString(keyTrainStationId) ?? '';
    _trainService = prefs.getString(keyTrainService) ?? 'trainboardeu';
    _trainArrivalPreNoticeMinutes =
        prefs.getInt(keyTrainArrivalPreNotice) ?? 10;
    _busProvider = prefs.getString(keyBusProvider) ?? 'bari';
    _busBaseUrl = prefs.getString(keyBusBaseUrl) ??
        'https://betacloud-transporter.is-cool.dev';

    // Load offline sync feature
    _offlineSyncEnabled = prefs.getBool(keyOfflineSyncEnabled) ?? false;

    notifyListeners();

    // Sincronizza il TTS service con le impostazioni caricate
    TtsService().setEnabled(_ttsEnabled);
    _ttsSpeechRate =
        (prefs.getDouble('accessibility_tts_rate') ?? 1.0).clamp(0.5, 1.5);
    TtsService().setSpeechRate(_ttsSpeechRate);

    // Start fetching server rates for Auto mode
    _startServerPolling();
  }

  void _startServerPolling() {
    _fetchServerRates();
    _serverPollTimer?.cancel();
    _serverPollTimer =
        Timer.periodic(const Duration(seconds: 10), (_) => _fetchServerRates());
  }

  Future<void> _fetchServerRates() async {
    try {
      final url = Uri.parse('$_busBaseUrl/api/usercount-ping');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['autoRefreshRates'] != null) {
          final rates = data['autoRefreshRates'];
          final newBus = rates['buses'] as int?;
          final newTrain = rates['trains'] as int?;
          final newPlane = rates['planes'] as int?;

          if (newBus != null && newBus != _autoBusRate) {
            _autoBusRate = newBus;
            if (isBusAuto) notifyListeners();
          }
          if (newTrain != null && newTrain != _autoTrainRate) {
            _autoTrainRate = newTrain;
            if (isTrainAuto) notifyListeners();
          }
          if (newPlane != null && newPlane != _autoPlaneRate) {
            _autoPlaneRate = newPlane;
            if (isPlaneAuto) notifyListeners();
          }
        }
      }
    } catch (_) {
      // Silent failure, keep last known rates
    }
  }

  Future<void> setMapStyle(String styleUrl) async {
    // always normalize before storing
    final normalized = _normalizeStyleUrl(styleUrl);
    debugPrint(
        'SettingsProvider.setMapStyle: input="$styleUrl" -> norm="$normalized"');
    _mapStyle = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyMapStyle, normalized);
  }

  Future<void> setBusRefreshSeconds(int seconds) async {
    _busRefreshSeconds = seconds;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyBusInterval, seconds);

    // If buses worker is enabled, reschedule with new interval
    if (_busesWorkerEnabled) {
      try {
        await AndroidBackgroundService.scheduleBusesWorker(
            provider: _busProvider,
            baseUrl: _busBaseUrl,
            enableNotifications: true,
            intervalSeconds: seconds);
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
        await AndroidBackgroundService.scheduleTrainsWorker(
            stationId: _trainStationId.isNotEmpty ? _trainStationId : null,
            service: _trainService,
            enableNotifications: true,
            intervalSeconds: seconds,
            arrivalNoticeMinutes: _trainArrivalPreNoticeMinutes);
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

  Future<void> setAppLocale(String? languageCode) async {
    if (languageCode == null || languageCode.isEmpty) {
      _appLocale = null;
    } else {
      _appLocale = Locale(languageCode);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null || languageCode.isEmpty) {
      await prefs.remove(keyLanguage);
    } else {
      await prefs.setString(keyLanguage, languageCode);
    }
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

  Future<void> setVectorLogosEnabled(bool enabled) async {
    _vectorLogosEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyVectorLogos, enabled);
  }

  Future<void> setLogoSource(String source) async {
    _logoSource = source;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLogoSource, source);
  }

  Future<void> setStartScreenMode(int mode) async {
    _startScreenMode = mode.clamp(0, 4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(keyStartScreen, _startScreenMode);
  }

  Future<void> setTextScale(double value) async {
    _textScale = value.clamp(0.8, 1.4);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(keyTextScale, _textScale);
  }

  Future<void> setTtsEnabled(bool enabled) async {
    _ttsEnabled = enabled;
    notifyListeners();
    TtsService().setEnabled(enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyTtsEnabled, _ttsEnabled);
  }

  Future<void> setTtsSpeechRate(double value) async {
    _ttsSpeechRate = value.clamp(0.5, 1.5);
    notifyListeners();
    TtsService().setSpeechRate(_ttsSpeechRate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('accessibility_tts_rate', _ttsSpeechRate);
  }

  Future<void> setTtsVoice(String voiceName, {String? langCode}) async {
    final lang = langCode ?? _appLocale?.languageCode ?? 'it';
    _ttsVoices[lang] = voiceName;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accessibility_tts_voices', jsonEncode(_ttsVoices));
    // Keep legacy key in sync for Italian
    if (lang == 'it') {
      await prefs.setString(keyTtsVoice, voiceName);
    }
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

  /// Convert a style identifier / URL into a valid Mapbox style URL.
  ///
  /// Recognizes old keywords (osm, cartodb_*) and also handles cases where an
  /// outdated Mapbox URL (`mapbox://styles/mapbox/cartodb_dark`) was stored.
  /// Normalize a style identifier or URL to a valid Mapbox style URL.
  ///
  /// This will convert legacy keywords ("osm", "cartodb_dark" etc.) and
  /// also older Mapbox URLs containing those keywords.  If the input already
  /// looks like a valid Mapbox url it is returned as‑is, otherwise the original
  /// string is returned (useful for custom HTTP urls).
  static String normalizeStyleUrl(String s) {
    if (s.isEmpty) return '';
    // if there are multiple occurrences of the prefix, keep only from last
    const prefix = 'mapbox://styles/';
    final lowerS = s.toLowerCase();
    final lastIdx = lowerS.lastIndexOf(prefix);
    if (lastIdx > 0) {
      s = s.substring(lastIdx);
    }

    final lower = s.toLowerCase();
    if (lower.contains('osm')) return 'mapbox://styles/mapbox/streets-v11';
    if (lower.contains('cartodb_dark'))
      return 'mapbox://styles/mapbox/dark-v11';
    if (lower.contains('cartodb_positron'))
      return 'mapbox://styles/mapbox/light-v11';
    if (lower.contains('cartodb_voyager'))
      return 'mapbox://styles/mapbox/outdoors-v11';
    if (lower.startsWith('mapbox://')) return s;
    return s;
  }

  // private wrapper kept for backward compatibility
  String _normalizeStyleUrl(String s) => SettingsProvider.normalizeStyleUrl(s);

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
        await AndroidBackgroundService.scheduleTrainsWorker(
          stationId: _trainStationId.isNotEmpty ? _trainStationId : null,
          service: _trainService,
          enableNotifications: true,
          intervalSeconds: _trainRefreshSeconds,
        );
      } catch (e) {
        print(
            'Error rescheduling trains worker with new arrival pre-notice: $e');
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

  Future<void> setOfflineSyncEnabled(bool enabled) async {
    _offlineSyncEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyOfflineSyncEnabled, enabled);
  }
}

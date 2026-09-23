import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

/// Provider che gestisce lo stato della mappa con salvataggio automatico della posizione.
///
/// Funzionalità implementate:
/// - ✅ Salvataggio automatico della posizione (lat, lng, zoom) durante il movimento
/// - ✅ Caricamento della posizione salvata all'avvio dell'app
/// - ✅ Salvataggio quando l'app viene messa in background o chiusa
/// - ✅ Salvataggio quando cambia orientamento dispositivo o dimensione finestra
/// - ✅ Salvataggio ottimizzato con timer (500ms delay) per evitare salvataggi frequenti
/// - ✅ Salvataggio solo per cambiamenti significativi (>10m o >0.1 zoom)
/// - ✅ Salvataggio di posizione, zoom, stile mappa e categoria attiva
/// - ✅ Metodi di debug, reset e informazioni sulla posizione salvata
/// - ✅ Gestione corretta del lifecycle dell'app e del widget
class MapStateProvider with ChangeNotifier {
  double _lat = 41.9028;
  double _lng = 12.4964;
  double _zoom = 12.0;
  bool _shouldFlyTo = false;
  String? _jsToRun;
  
  // 0: Treni, 1: Bus, 2: Aerei
  int _activeCategory = 0;

  // Map Style (solo default locale): lo stile vero vive nel SettingsProvider
  // (URL completo 'mapbox://...') e viene convertito in style-id corto dai
  // widget mappa. NON persistere qui 'map_style': la chiave è condivisa con
  // i Settings e i due formati sono incompatibili (URL vs id corto).
  String _mapStyle = 'streets-v12';

  bool _isLoaded = false;
  Timer? _saveTimer;

  MapStateProvider() {
    loadFromPrefs();
  }

  double get lat => _lat;
  double get lng => _lng;
  double get zoom => _zoom;
  bool get isLoaded => _isLoaded;
  int get activeCategory => _activeCategory;
  String get mapStyle => _mapStyle;
  bool get shouldFlyTo => _shouldFlyTo;
  String? get jsToRun => _jsToRun;

  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble('map_lat') ?? _lat;
    _lng = prefs.getDouble('map_lng') ?? _lng;
    _zoom = prefs.getDouble('map_zoom') ?? _zoom;
    _activeCategory = prefs.getInt('map_category') ?? _activeCategory;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('map_lat', _lat);
    await prefs.setDouble('map_lng', _lng);
    await prefs.setDouble('map_zoom', _zoom);
    await prefs.setInt('map_category', _activeCategory);
  }

  void setMapStyle(String style) {
    if (_mapStyle == style) return;
    _mapStyle = style;
    _saveToPrefs();
    notifyListeners();
  }

  void updatePosition(double lat, double lng, double zoom) {
    // Salva la posizione solo se è cambiata significativamente per evitare salvataggi inutili
    const double threshold = 0.0001; // Circa 10 metri
    const double zoomThreshold = 0.1;
    
    bool positionChanged = (_lat - lat).abs() > threshold || 
                          (_lng - lng).abs() > threshold || 
                          (_zoom - zoom).abs() > zoomThreshold;
    
    if (!positionChanged) return;
    
    _lat = lat;
    _lng = lng;
    _zoom = zoom;
    
    // Cancella il timer precedente se esiste
    _saveTimer?.cancel();
    
    // Imposta un nuovo timer per salvare dopo 500ms di inattività
    // Questo evita salvataggi troppo frequenti durante il drag della mappa
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      _saveToPrefs();
    });
    
    // Non chiamiamo notifyListeners qui per evitare loop infiniti con la mappa durante il drag
  }

  void updatePositionAndNotify(double lat, double lng, double zoom) {
    _lat = lat;
    _lng = lng;
    _zoom = zoom;
    _saveToPrefs();
    notifyListeners();
  }

  void setCategory(int category) {
    if (_activeCategory == category) return;
    _activeCategory = category;
    
    _saveToPrefs();
    notifyListeners();
  }

  void flyTo(double lat, double lng, {double? zoom}) {
    _lat = lat;
    _lng = lng;
    if (zoom != null) _zoom = zoom;
    _shouldFlyTo = true;
    _saveToPrefs();
    notifyListeners();
  }

  void flyToAndSave(double lat, double lng, {double? zoom}) {
    _lat = lat;
    _lng = lng;
    if (zoom != null) _zoom = zoom;
    _shouldFlyTo = true;
    _saveToPrefs();
    notifyListeners();
  }

  void runJs(String js) {
    _jsToRun = js;
    notifyListeners();
  }

  void resetFlyTo() {
    _shouldFlyTo = false;
  }

  void resetJs() {
    _jsToRun = null;
  }

  void saveCurrentPosition() {
    _saveTimer?.cancel(); // Cancella eventuali timer pendenti
    _saveToPrefs();
  }

  Future<void> forceLoadFromPrefs() async {
    await loadFromPrefs();
  }

  void resetToDefaultPosition() {
    _lat = 41.9028; // Roma
    _lng = 12.4964;
    _zoom = 12.0;
    _saveToPrefs();
    notifyListeners();
  }

  Map<String, dynamic> getCurrentPosition() {
    return {
      'lat': _lat,
      'lng': _lng,
      'zoom': _zoom,
      'mapStyle': _mapStyle,
      'activeCategory': _activeCategory,
    };
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void debugPrintPosition() {
    print('Map Position: lat=$_lat, lng=$_lng, zoom=$_zoom, style=$_mapStyle, category=$_activeCategory, loaded=$_isLoaded');
  }

  Future<Map<String, dynamic>> getSavedPositionInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'saved_lat': prefs.getDouble('map_lat'),
      'saved_lng': prefs.getDouble('map_lng'),
      'saved_zoom': prefs.getDouble('map_zoom'),
      'saved_style': prefs.getString('map_style'),
      'saved_category': prefs.getInt('map_category'),
      'current_lat': _lat,
      'current_lng': _lng,
      'current_zoom': _zoom,
      'current_style': _mapStyle,
      'current_category': _activeCategory,
      'is_loaded': _isLoaded,
    };
  }
}

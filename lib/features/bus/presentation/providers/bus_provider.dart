import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/bus_model.dart';
import '../../data/repositories/bus_repository.dart';

class BusProvider with ChangeNotifier {
  final BusRepository _repository = BusRepository();
  List<BusVehicle> _vehicles = [];
  // cache of static JSON downloaded from server (per provider name)
  final Map<String, Map<String, dynamic>> _staticData = {};
  bool _isLoading = false;
  double _downloadProgress = 0.0; // 0.0..1.0 progress of static download
  String _selectedCity = ''; // Default empty, set after loading providers
  List<BusProviderConfig> _providers = [];
  // persistent visibility map keyed by provider id (provider or name fallback)
  final Map<String, bool> _providerVisibility = {};
  BusProviderConfig? _selectedProvider;
  
  Timer? _refreshTimer;
  int _autoRefreshSeconds = 0;

  // Configuration update state
  bool _isUpdatingConfig = false;
  String? _configUpdateError;

  // Bari routing
  List<BariStop> _stops = [];
  List<BariRouteSolution> _bariSolutions = [];
  BariStop? _selectedFromStop;
  BariStop? _selectedToStop;
  BariStop? _selectedStop;
  bool _isLoadingStops = false;
  bool _isLoadingSolutions = false;

  // Selected bus for details
  BusVehicle? _selectedBus;
  BusRoutePath? _selectedBusRoutePath;
  bool _isLoadingRoutePath = false;

  // Stop search results
  List<BariStop> _stopSearchResults = [];

  // Bus Lines
  List<BusLine> _busLines = [];
  bool _isLoadingLines = false;

  List<BusVehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;
  List<BusProviderConfig> get providers => _providers;
  BusProviderConfig? get selectedProvider => _selectedProvider;

  /// whether we previously downloaded static JSON for [providerName]
  bool hasStaticData(String providerName) => _staticData.containsKey(providerName);

  /// progress of the most recent static download operation (0.0 - 1.0)
  double get downloadProgress => _downloadProgress;

  // Configuration update getters
  bool get isUpdatingConfig => _isUpdatingConfig;
  String? get configUpdateError => _configUpdateError;

  // Bari getters
  List<BariStop> get stops => _stops;
  List<BariStop> get bariStops => _stops; // Alias for backward compatibility
  List<BariRouteSolution> get bariSolutions => _bariSolutions;
  BariStop? get selectedFromStop => _selectedFromStop;
  BariStop? get selectedToStop => _selectedToStop;
  BariStop? get selectedStop => _selectedStop;
  bool get isLoadingStops => _isLoadingStops;
  bool get isLoadingSolutions => _isLoadingSolutions;

  // Selected bus getter
  BusVehicle? get selectedBus => _selectedBus;
  BusRoutePath? get selectedBusRoutePath => _selectedBusRoutePath;
  bool get isLoadingRoutePath => _isLoadingRoutePath;

  // Stop search getter
  List<BariStop> get stopSearchResults => _stopSearchResults;

  // Bus Lines getters
  List<BusLine> get busLines => _busLines;
  bool get isLoadingLines => _isLoadingLines;

  // Trip stops data
  TripStopsData? _selectedTripStops;
  bool _isLoadingTripStops = false;

  // Trip updates from API endpoint
  List<BusTripUpdate> _apiTripUpdates = [];

  TripStopsData? get selectedTripStops => _selectedTripStops;
  bool get isLoadingTripStops => _isLoadingTripStops;

  List<BusTripUpdate> get apiTripUpdates => _apiTripUpdates;
  
  // Saved search query to restore view
  String _savedStopSearchQuery = "";
  String get savedStopSearchQuery => _savedStopSearchQuery;
  
  void setSavedStopSearchQuery(String query) {
    _savedStopSearchQuery = query;
    notifyListeners();
  }

  void setApiTripUpdates(List<BusTripUpdate> updates) {
    _apiTripUpdates = updates;
    notifyListeners();
  }

  void clearApiTripUpdates() {
    _apiTripUpdates = [];
    notifyListeners();
  }

  void updateBusDestination(String vehicleId, String newDestination) {
    final index = _vehicles.indexWhere((bus) => bus.id == vehicleId);
    if (index != -1) {
      _vehicles[index] = _vehicles[index].copyWith(destination: newDestination);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  Future<void> loadProviders() async {
    try {
      _providers = await _repository.fetchBusProviders();
      // Add Flixbus if not present
      if (!_providers.any((p) => p.name == 'Flixbus')) {
        _providers.add(BusProviderConfig(
          name: 'Flixbus',
          provider: 'flixbus',
          solutionsUrl: null,
          endpoints: {
            'stops': false,
            'trip_stops': false,
            'bus_realtime': false,
            'trips': false,
            'stops_updates': false,
            'realtime': false,
            'route_path': false,
            'solutions': false,
          },
        ));
      }
      // Set default city to first provider if not set
      if (_selectedCity.isEmpty && _providers.isNotEmpty) {
        _selectedCity = _providers.first.name;
        _selectedProvider = _providers.first;
        print('Default city set to: $_selectedCity');
      }
      // Load saved order & visibility preferences if any
      await _loadProviderPreferences();
      notifyListeners();
    } catch (e) {
      print("Error loading providers: $e");
      // Only Flixbus as fallback
      _providers = [
        BusProviderConfig(
          name: 'Flixbus',
          provider: 'flixbus',
          solutionsUrl: null,
          endpoints: {
            'stops': false,
            'trip_stops': false,
            'bus_realtime': false,
            'trips': false,
            'stops_updates': false,
            'realtime': false,
            'route_path': false,
            'solutions': false,
          },
        ),
      ];
      // Set default to Flixbus
      _selectedCity = 'Flixbus';
      // load any stored preferences (will be empty in fallback)
      await _loadProviderPreferences();
      notifyListeners();
    }
  }

  Future<void> updateConfiguration() async {
    if (_isUpdatingConfig) return; // Prevent multiple simultaneous updates

    _isUpdatingConfig = true;
    _configUpdateError = null;
    notifyListeners();

    // Store current configuration for rollback on error
    final oldProviders = List<BusProviderConfig>.from(_providers);
    final oldSelectedCity = _selectedCity;
    final oldSelectedProvider = _selectedProvider;

    try {
      // Reload providers from remote
      await loadProviders();

      // Check if current selected city still exists, otherwise reset to first available
      if (_selectedCity.isNotEmpty && !_providers.any((p) => p.name == _selectedCity)) {
        if (_providers.isNotEmpty) {
          _selectedCity = _providers.first.name;
          _selectedProvider = _providers.first;
        } else {
          _selectedCity = '';
          _selectedProvider = null;
        }
      }

      _configUpdateError = null; // Success
    } catch (e) {
      _configUpdateError = 'Errore durante l\'aggiornamento: $e';
      // Restore old configuration on error
      _providers = List<BusProviderConfig>.from(oldProviders);
      _selectedCity = oldSelectedCity;
      _selectedProvider = oldSelectedProvider;
    } finally {
      _isUpdatingConfig = false;
      notifyListeners();
    }
  }

  void updateAutoRefresh(int seconds) {
    _autoRefreshSeconds = seconds;
    _stopTimer();
    if (_autoRefreshSeconds > 0) {
      _startTimer();
    }
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _startTimer() {
    _refreshTimer = Timer.periodic(Duration(seconds: _autoRefreshSeconds), (timer) {
      if (_selectedCity.isNotEmpty) {
        fetchVehicles(silent: true);
      }
    });
  }

  void selectCity(String city) {
    _selectedCity = city;
    _selectedProvider = _providers.firstWhere(
      (p) => p.name == city,
      orElse: () => BusProviderConfig(name: '', provider: '', endpoints: {}),
    );
    print('Selected city: $city, provider: ${_selectedProvider?.name}');

    // download static JSON in background so app can save it locally
    if (_selectedProvider != null && !hasStaticData(_selectedProvider!.name)) {
      downloadStaticProvider(_selectedProvider!);
    }

    if (_selectedProvider?.endpoints['stops'] == true) {
      // pass offline flag when we already have static data
      final useOffline = _staticData.containsKey(_selectedProvider!.name);
      fetchStops(offline: useOffline);
    }
    // also pass offline to vehicle fetch if data exists
    final useOfflineVeh = _staticData.containsKey(_selectedProvider?.name ?? '');
    fetchVehicles(silent: false, offline: useOfflineVeh);
    notifyListeners();
  }

  /// Reorder providers list in memory and notify listeners.
  /// Expects indices as provided by ReorderableListView (oldIndex, newIndex).
  void reorderProviders(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _providers.removeAt(oldIndex);
    _providers.insert(newIndex, item);
    // Update selected city index if necessary
    if (_selectedCity.isNotEmpty) {
      final stillHas = _providers.any((p) => p.name == _selectedCity);
      if (!stillHas && _providers.isNotEmpty) {
        _selectedCity = _providers.first.name;
        _selectedProvider = _providers.first;
      }
    }
    notifyListeners();
    _saveProviderOrder();
  }

  String _providerKey(BusProviderConfig p) => (p.provider.isNotEmpty ? p.provider : p.name);

  bool isProviderVisible(BusProviderConfig p) {
    final key = _providerKey(p);
    return _providerVisibility.containsKey(key) ? _providerVisibility[key]! : true;
  }

  Future<void> setProviderVisibility(BusProviderConfig p, bool visible) async {
    final key = _providerKey(p);
    _providerVisibility[key] = visible;
    notifyListeners();
    await _saveProviderVisibility();
  }

  Future<void> _saveProviderOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = _providers.map((p) => _providerKey(p)).toList();
      await prefs.setString('bus_providers_order_v1', jsonEncode(ids));
    } catch (e) {
      print('Error saving provider order: $e');
    }
  }

  Future<void> _saveProviderVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bus_providers_visibility_v1', jsonEncode(_providerVisibility));
    } catch (e) {
      print('Error saving provider visibility: $e');
    }
  }

  Future<void> _loadProviderPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final orderStr = prefs.getString('bus_providers_order_v1');
      if (orderStr != null && orderStr.isNotEmpty) {
        final List<dynamic> saved = jsonDecode(orderStr);
        final List<String> savedIds = saved.map((e) => e.toString()).toList();
        final Map<String, BusProviderConfig> map = { for (var p in _providers) _providerKey(p): p };
        final List<BusProviderConfig> reordered = [];
        for (var id in savedIds) {
          if (map.containsKey(id)) reordered.add(map[id]!);
        }
        // append any providers not found in saved order
        for (var p in _providers) {
          if (!reordered.contains(p)) reordered.add(p);
        }
        _providers = reordered;
      }

      final visStr = prefs.getString('bus_providers_visibility_v1');
      if (visStr != null && visStr.isNotEmpty) {
        final Map<String, dynamic> visMap = jsonDecode(visStr);
        _providerVisibility.clear();
        visMap.forEach((k, v) {
          _providerVisibility[k] = v == true;
        });
      }
    } catch (e) {
      print('Error loading provider preferences: $e');
    }
  }

  Future<void> fetchVehicles({bool silent = false, bool offline = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      print("BusProvider: Fetching vehicles for city: $_selectedCity");
      // For dynamic providers, use generic endpoint if supported
      BusProviderConfig? provider;
      try {
        provider = _providers.firstWhere((p) => p.name == _selectedCity);
      } catch (e) {
        provider = null;
      }
      if (provider != null && provider.gpsUrl != null && provider.gpsUrl!.isNotEmpty) {
        print("BusProvider: Using GPS URL: ${provider.gpsUrl} (offline=$offline)");
        _vehicles = await _repository.fetchVehicles(provider);
      } else {
        print("BusProvider: Provider ${provider?.name} does not have GPS URL or not found");
        _vehicles = [];
      }
    } catch (e) {
      print("Provider Error: $e");
      _vehicles = [];
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  Future<void> fetchBusLines() async {
    if (_selectedCity.isEmpty) return;
    
    _isLoadingLines = true;
    _busLines = [];
    notifyListeners();

    try {
      _busLines = await _repository.fetchBusLines(_selectedCity);
    } catch (e) {
      print("Error fetching bus lines for $_selectedCity: $e");
      _busLines = [];
    } finally {
      _isLoadingLines = false;
      notifyListeners();
    }
  }

  // Flixbus
  List<dynamic> _flixbusStations = [];
  Future<void> searchFlixbus(String query) async {
    _isLoading = true;
    notifyListeners();
    _flixbusStations = await _repository.searchFlixbusStations(query);
    _isLoading = false;
    notifyListeners();
  }
  
  List<dynamic> get flixbusStations => _flixbusStations;

  // Dynamic routing methods
  Future<void> fetchStops({bool offline = false}) async {
    _isLoadingStops = true;
    notifyListeners();

    try {
      if (_selectedProvider != null) {
        _stops = await _repository.fetchStops(_selectedProvider!, offline: offline);
      } else {
        _stops = [];
      }
    } catch (e) {
      print("Error fetching stops for $_selectedCity: $e");
      _stops = [];
    } finally {
      _isLoadingStops = false;
      notifyListeners();
    }
  }

  /// Download and cache the entire static dataset for [provider].
  ///
  /// Uses the special server endpoint that returns the full contents of
  /// `providersCache[provider]` (used by the web client for offline mode).
  /// The data is stored in memory and later used when calling any API with
  /// `offline:true`.
  /// Public helper that downloads the full static payload for [provider]
  /// and reports progress through [downloadProgress].
  Future<void> downloadStaticProvider(BusProviderConfig provider) async {
    _downloadProgress = 0.0;
    notifyListeners();
    try {
      final data = await _repository.fetchStaticProviderData(
        provider.name,
        onProgress: (p) {
          _downloadProgress = p.clamp(0.0, 1.0);
          notifyListeners();
        },
      );
      if (data != null) {
        _staticData[provider.name] = data;
        print('Static data downloaded for ${provider.name}');
      }
    } catch (e) {
      print('Error downloading static provider data: $e');
    } finally {
      // keep progress at 1.0 until the dialog has a chance to close;
      // reset after a short delay so UI doesn't stuck at 100%
      Future.delayed(const Duration(milliseconds: 300), () {
        _downloadProgress = 0.0;
        notifyListeners();
      });
    }
  }

  /// Verify that the cached static JSON still matches the server copy.
  ///
  /// If the remote data differs, replace the cache and return `true` so
  /// callers can alert the user.  Comparison is done via JSON string.
  Future<bool> checkAndRefreshStatic(BusProviderConfig provider) async {
    final name = provider.name;
    if (!hasStaticData(name)) return false;
    try {
      final current = _staticData[name];
      final newData = await _repository.fetchStaticProviderData(name);
      if (newData != null) {
        final curStr = jsonEncode(current);
        final newStr = jsonEncode(newData);
        if (curStr != newStr) {
          _staticData[name] = newData;
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      print('Error checking static data for $name: $e');
    }
    return false;
  }

  void selectFromStop(BariStop? stop) {
    _selectedFromStop = stop;
    notifyListeners();
  }

  void selectToStop(BariStop? stop) {
    _selectedToStop = stop;
    notifyListeners();
  }

  Future<void> fetchBariSolutions({DateTime? departureTime}) async {
    if (_selectedFromStop == null || _selectedToStop == null) return;

    _isLoadingSolutions = true;
    notifyListeners();

    try {
      _bariSolutions = await _repository.fetchBariSolutions(
        fromStopId: _selectedFromStop!.stopId,
        toStopId: _selectedToStop!.stopId,
        departureTime: departureTime,
      );
    } catch (e) {
      print("Error fetching Bari solutions: $e");
      _bariSolutions = [];
    } finally {
      _isLoadingSolutions = false;
      notifyListeners();
    }
  }

  void clearBariSolutions() {
    _bariSolutions = [];
    notifyListeners();
  }

  void clearAll() {
    _vehicles = [];
    _stops = [];
    _bariSolutions = [];
    _selectedFromStop = null;
    _selectedToStop = null;
    _selectedStop = null;
    _flixbusStations = [];
    _selectedBus = null;
    _selectedBusRoutePath = null;
    _isLoadingRoutePath = false;
    _selectedTripStops = null;
    _isLoadingTripStops = false;
    notifyListeners();
  }

  Future<void> selectBus(BusVehicle bus) async {
    _selectedBus = bus;
    // Load trip stops and route path when provider supports them
    final supportsTripStops = _selectedProvider?.endpoints['trip_stops'] == true;
    final supportsRoutePath = _selectedProvider?.endpoints['route_path'] == true;

    // For bus details we no longer rely on the `route_path` endpoint.
    // Instead request the realtime endpoint using `routeId` (line) + `tripId`.
    if (bus.tripId != null && bus.tripId!.isNotEmpty && bus.line != null && bus.line!.isNotEmpty) {
      _loadBusRoutePath(bus);
    }

    if (supportsTripStops) {
      _loadTripStops(bus);
    }

    // Also fetch destination for Bari specifically (legacy behaviour)
    if (_selectedProvider?.name.toLowerCase() == 'bari' && (bus.destination == null || bus.destination!.isEmpty)) {
      try {
        final destination = await fetchBariVehicleDestination(bus.id, bus.line);
        if (destination != null && destination.isNotEmpty) {
          _selectedBus = bus.copyWith(destination: destination);
        }
      } catch (e) {
        print("Error fetching bus destination: $e");
      }
    }
    notifyListeners();
  }

  Future<void> _loadBusRoutePath(BusVehicle bus) async {
    // Instead of using the route-path endpoint, call realtime with routeId + tripId
    _isLoadingRoutePath = true;
    _selectedBusRoutePath = null;
    notifyListeners();

    try {
      final tripId = bus.tripId;
      final routeId = bus.line;

      if (tripId != null && tripId.isNotEmpty && routeId != null && routeId.isNotEmpty) {
        final tripStops = await _repository.fetchRealtimeTripStops(routeId, tripId, providerName: _selectedProvider?.name);
        _selectedTripStops = tripStops;
      } else {
        print("No tripId/routeId available for bus ${bus.id}");
        _selectedTripStops = null;
      }
    } catch (e) {
      print("Error loading realtime trip details: $e");
      _selectedTripStops = null;
    } finally {
      _isLoadingRoutePath = false;
      notifyListeners();
    }
  }

  Future<void> _loadTripStops(BusVehicle bus) async {
    _isLoadingTripStops = true;
    _selectedTripStops = null;
    notifyListeners();

    try {
      final tripId = bus.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        final tripStops = await _repository.fetchTripStops(tripId, providerName: _selectedProvider?.name);
        _selectedTripStops = tripStops;
      } else {
        print("No tripId available for bus ${bus.id}");
        _selectedTripStops = null;
      }
    } catch (e) {
      print("Error loading trip stops: $e");
      _selectedTripStops = null;
    } finally {
      _isLoadingTripStops = false;
      notifyListeners();
    }
  }

  void clearBusSelection() {
    _selectedBus = null;
    _selectedBusRoutePath = null;
    _isLoadingRoutePath = false;
    _selectedTripStops = null;
    _isLoadingTripStops = false;
    notifyListeners();
  }

  Future<List<BusTripUpdate>> fetchBariTripUpdates(String vehicleId, String routeId) async {
    try {
      return await _repository.fetchBariTripUpdates(vehicleId, routeId);
    } catch (e) {
      print("Error fetching Bari trip updates: $e");
      return [];
    }
  }

  /// Generic trip updates fetcher: for Bari uses the specialized endpoint,
  /// otherwise attempts to load trip stops via tripId and convert them to
  /// `BusTripUpdate` entries.
  Future<List<BusTripUpdate>> fetchProviderTripUpdates(BusVehicle bus) async {
    try {
      // Bari retains specialized realtime/trip update logic
      if (_selectedProvider != null && _selectedProvider!.name.toLowerCase() == 'bari') {
        return await fetchBariTripUpdates(bus.id, bus.line);
      }

      // Prefer tripId -> tripStops if available
      final tripId = bus.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        final tripStops = await _repository.fetchTripStops(tripId, providerName: _selectedProvider?.name);
        if (tripStops != null) {
          final updates = tripStops.stops.map((ts) {
            return BusTripUpdate(
              stopId: ts.stopId,
              stopName: ts.stopName,
              expectedTime: ts.scheduledTime,
              delay: ts.delay,
              isRealtime: ts.isRealtime,
              status: ts.status,
              arrivalEstimate: null,
            );
          }).toList();
          return updates;
        }
      }

      // Nothing available
      return [];
    } catch (e) {
      print('Error fetching provider trip updates: $e');
      return [];
    }
  }

  /// Retrieves departures for a specific stop. If we have previously
  /// downloaded static data for the current provider the request is made
  /// in offline mode so that the server serves cached JSON and skips the
  /// database query.
  Future<List<StopDeparture>> fetchStopUpdates(String stopId) async {
    try {
      final providerName = _selectedProvider?.name ?? '';
      final useOffline = hasStaticData(providerName);
      if (useOffline) {
        // calculate departures entirely on the device using the downloaded
        // static dataset; no network call is needed (server only used for
        // realtime positions, which we merge separately if required).
        final local = _computeLocalDepartures(providerName, stopId);
        print('Computed ${local.length} local departures for $stopId');
        return local;
      }
      return await _repository.fetchStopUpdates(providerName, stopId);
    } catch (e) {
      print("Error fetching Bari stop updates: $e");
      return [];
    }
  }

  Future<String?> fetchBariVehicleDestination(String vehicleId, String routeId) async {
    return await _repository.fetchBariVehicleDestination(vehicleId, routeId);
  }

  void selectStop(BariStop stop) {
    _selectedStop = stop;
    notifyListeners();
  }

  void clearStopSelection() {
    _selectedStop = null;
    notifyListeners();
  }

  /// Build a list of departures using only static data previously downloaded
  /// for [providerName].  The algorithm mirrors the server's `stops-updates`
  /// logic but operates completely offline on the device.  Currently this is
  /// only used for Bari providers.
  List<StopDeparture> _computeLocalDepartures(String providerName, String stopId) {
    final md = _staticData[providerName];
    if (md == null) return [];

    // structure of md.tripStopsData is Map<tripId, List<{i:stopId, t:time, ...}>>
    final tripStops = md['tripStopsData'] as Map<String, dynamic>?;
    if (tripStops == null) return [];

    // optional static maps for destination lookup
    final stopNameMap = md['stopNameMap'] as Map<String, dynamic>? ?? {};
    final tripsMap = md['tripsMap'] as Map<String, dynamic>? ?? {};
    final routesMap = md['routesMap'] as Map<String, dynamic>? ?? {};

    final List<StopDeparture> departures = [];

    double timeFromString(String t) {
      final parts = t.split(':');
      if (parts.length < 2) return 0.0;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final now = DateTime.now();
      var dt = DateTime(now.year, now.month, now.day, h, m);
      if (dt.isBefore(now.subtract(const Duration(minutes: 1)))) {
        dt = dt.add(const Duration(days: 1));
      }
      return dt.millisecondsSinceEpoch / 1000.0;
    }

    tripStops.forEach((tripId, stops) {
      if (stops is List) {
        for (var s in stops) {
          final sid = s['i']?.toString() ?? '';
          if (sid == stopId) {
            final timeStr = s['t']?.toString() ?? '';
            final epoch = timeFromString(timeStr);
            // derive line by looking up trip->shape->route
            String line = '';
            final shapeId = tripsMap[tripId]?.toString();
            if (shapeId != null) {
              routesMap.forEach((rk, shapes) {
                if (shapes is List && shapes.contains(shapeId)) {
                  line = rk.toString();
                }
              });
            }
            departures.add(StopDeparture(
              line: line,
              tripId: tripId.toString(),
              vehicleId: 'scheduled-$tripId-$epoch',
              vehicleLabel: 'Bus',
              time: epoch,
              isRealtime: false,
              isScheduled: true,
              isLivePosition: false,
              delay: 0,
              destination: _findDestinationForTrip(tripId, stopNameMap, tripsMap),
            ));
            break;
          }
        }
      }
    });
    // if we found nothing and the stopId may correspond to a different code,
    // try to map it via stopsData and re-run the search with the mapped value
    if (departures.isEmpty) {
      final md2 = md['stopsData'] as List<dynamic>?;
      if (md2 != null) {
        final match = md2.firstWhere(
            (e) => e['stop_id'] == stopId || e['stop_code'] == stopId,
            orElse: () => null);
        if (match != null) {
          final alt = (match['stop_code'] ?? match['stop_id'])?.toString() ?? '';
          if (alt.isNotEmpty && alt != stopId) {
            // try again with alternate identifier
            tripStops.forEach((tripId, stops) {
              if (stops is List) {
                for (var s in stops) {
                  final sid = s['i']?.toString() ?? '';
                  if (sid == alt) {
                    final timeStr = s['t']?.toString() ?? '';
                    final epoch = timeFromString(timeStr);
                    String line = '';
                    final shapeId = tripsMap[tripId]?.toString();
                    if (shapeId != null) {
                      routesMap.forEach((rk, shapes) {
                        if (shapes is List && shapes.contains(shapeId)) {
                          line = rk.toString();
                        }
                      });
                    }
                    departures.add(StopDeparture(
                      line: line,
                      tripId: tripId.toString(),
                      vehicleId: 'scheduled-$tripId-$epoch',
                      vehicleLabel: 'Bus',
                      time: epoch,
                      isRealtime: false,
                      isScheduled: true,
                      isLivePosition: false,
                      delay: 0,
                      destination: _findDestinationForTrip(tripId, stopNameMap, tripsMap),
                    ));
                    break;
                  }
                }
              }
            });
          }
        }
      }
      if (departures.isEmpty) {
        print('Offline: no scheduled trips found for stop $stopId');
      }
    }

    // merge realtime vehicles if any are already loaded for this provider
    if (_vehicles.isNotEmpty) {
      final List<StopDeparture> merged = [];
      for (var dep in departures) {
        BusVehicle? match;
        for (var v in _vehicles) {
          if (v.tripId == dep.tripId || v.line == dep.line) {
            match = v;
            break;
          }
        }
        if (match != null) {
          merged.add(StopDeparture(
            line: dep.line,
            tripId: dep.tripId,
            vehicleId: match.id,
            vehicleLabel: dep.vehicleLabel,
            time: dep.time,
            isRealtime: true,
            isScheduled: dep.isScheduled,
            isLivePosition: true,
            delay: dep.delay,
            destination: dep.destination,
          ));
        } else {
          merged.add(dep);
        }
      }
      departures
        ..clear()
        ..addAll(merged);
    }

    departures.sort((a, b) => a.time.compareTo(b.time));
    return departures;
  }

  String _findDestinationForTrip(String tripId, Map<String,dynamic> stopNameMap, Map<String,dynamic> tripsMap) {
    final quoteClean = tripId.replaceAll('"','');
    final md = _staticData[_selectedProvider?.name ?? ''];
    if (md != null) {
      final tripStops = md['tripStopsData'] as Map<String,dynamic>?;
      final stops = tripStops?[quoteClean] as List<dynamic>?;
      if (stops != null && stops.isNotEmpty) {
        final last = stops.last;
        final lastId = last['i']?.toString() ?? '';
        return stopNameMap[lastId] ?? lastId;
      }
    }
    return '';
  }

  void searchStops(String query) {
    if (query.isEmpty) {
      _stopSearchResults = [];
    } else {
      _stopSearchResults = _stops.where((stop) =>
        stop.stopName.toLowerCase().contains(query.toLowerCase()) ||
        stop.stopId.toLowerCase().contains(query.toLowerCase())
      ).toList();
    }
    notifyListeners();
  }

  void clearStopSearch() {
    _stopSearchResults = [];
    notifyListeners();
  }
}

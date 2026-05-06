import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/train_model.dart';
import '../../data/repositories/train_repository.dart';
import '../../../../core/services/offline_sync_service.dart';
import 'package:flutter/foundation.dart';

class TrainProvider with ChangeNotifier {
  final TrainRepository _repository = TrainRepository();
  
  Timer? _refreshTimer;
  int _autoRefreshSeconds = 0;
  bool _offlineSyncEnabled = false;
  bool _blockOnlineAutoRefresh = false;
  int _fetchRequestId = 0;

  // New States for Service and Mode
  String _selectedService = 'trainboardeu'; // 'direct' or 'trainboardeu'
  bool _isArrivalMode = false;
  
  String get selectedService => _selectedService;
  bool get isArrivalMode => _isArrivalMode;

  // Train vector logos
  Map<String, String> _trainLogos = {};
  bool _hasLoadedLogos = false;
  bool _isLoadingLogos = false;
  Map<String, String> get trainLogos => _trainLogos;

  Future<void> loadTrainLogos() async {
    if (_hasLoadedLogos || _isLoadingLogos) return;
    _isLoadingLogos = true;
    try {
      final logos = await _repository.fetchTrainLogos();
      // Even if empty, we consider it loaded to prevent loop
      _trainLogos = logos;
      _hasLoadedLogos = true;
      if (logos.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      print("Error loading train logos: $e");
    } finally {
      _isLoadingLogos = false;
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void updateAutoRefresh(int seconds, {bool offlineSyncEnabled = false}) {
    _autoRefreshSeconds = seconds;
    _offlineSyncEnabled = offlineSyncEnabled;
    _stopTimer();
    if (_autoRefreshSeconds > 0 && !_blockOnlineAutoRefresh) {
      _startTimer();
    }
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _startTimer() {
    if (_blockOnlineAutoRefresh) return;

    _refreshTimer = Timer.periodic(Duration(seconds: _autoRefreshSeconds), (timer) {
      if (_blockOnlineAutoRefresh) {
        _stopTimer();
        return;
      }

      if (_selectedStation != null) {
        fetchDepartures(
          _selectedStation!.id,
          country: _selectedStation!.country,
          silent: true,
          offlineSyncEnabled: _offlineSyncEnabled,
        );
      }
    });
  }

  void setOnlineAutoRefreshBlocked(bool blocked) {
    if (_blockOnlineAutoRefresh == blocked) return;

    _blockOnlineAutoRefresh = blocked;
    if (blocked) {
      _stopTimer();
    } else if (_autoRefreshSeconds > 0 && _refreshTimer == null) {
      _startTimer();
    }
  }

  void setService(String service) {
    if (_selectedService == service) return;
    _selectedService = service;
    _selectedStation = null; // Clear selection because IDs differ between services
    _departures = [];
    notifyListeners();
  }

  void setArrivalMode(bool isArrival) {
    if (_isArrivalMode == isArrival) return;
    _isArrivalMode = isArrival;
    notifyListeners();
    if (_selectedStation != null) {
      fetchDepartures(_selectedStation!.id, country: _selectedStation!.country);
    }
  }

  List<TrainStation> _stationSuggestions = [];
  bool _isLoadingSuggestions = false;
  
  List<TrainDeparture> _departures = [];
  bool _isLoadingDepartures = false;
  bool _isUsingOfflineCache = false;
  TrainStation? _selectedStation;

  List<TrainStation> get stationSuggestions => _stationSuggestions;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  
  List<TrainDeparture> get departures => _departures;
  bool get isLoadingDepartures => _isLoadingDepartures;
  bool get isUsingOfflineCache => _isUsingOfflineCache;
  TrainStation? get selectedStation => _selectedStation;

  List<dynamic> _searchResults = [];
  bool _isSearchingByNumber = false;

  List<dynamic> get searchResults => _searchResults;
  bool get isSearchingByNumber => _isSearchingByNumber;

  Future<void> searchTrainByNumber(String query) async {
    if (query.length < 2) return;
    
    _isSearchingByNumber = true;
    notifyListeners();

    try {
      _searchResults = await _repository.searchTrainByNumber(query);
    } catch (e) {
      print("Provider Error: $e");
      _searchResults = [];
    } finally {
      _isSearchingByNumber = false;
      notifyListeners();
    }
  }

  void selectStation(TrainStation station) {
    _selectedStation = station;
    _stationSuggestions = []; // Clear suggestions
    notifyListeners();
    fetchDepartures(station.id, country: station.country);
  }

  // Helper to fetch with offline sync (called from UI with settings context)
  Future<void> fetchDeparturesWithOfflineSync(bool offlineSyncEnabled) async {
    _offlineSyncEnabled = offlineSyncEnabled;
    if (_selectedStation != null) {
      await fetchDepartures(
        _selectedStation!.id,
        country: _selectedStation!.country,
        offlineSyncEnabled: offlineSyncEnabled,
      );
    }
  }
  
  void clearSelection() {
    _selectedStation = null;
    _departures = [];
    _stationSuggestions = [];
    _searchResults = [];
    notifyListeners();
  }

  void clearAll() {
    clearSelection();
  }

  Future<void> searchStations(String query, {String country = 'IT', String? city}) async {
    if (query.length < 2) {
      _stationSuggestions = [];
      notifyListeners();
      return;
    }
    
    _isLoadingSuggestions = true;
    notifyListeners();

    try {
      _stationSuggestions = await _repository.searchStations(
        query, 
        country: country,
        city: city,
        service: _selectedService
      );
    } catch (e) {
      print("Provider Error: $e");
      _stationSuggestions = [];
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }

  void setStationSuggestions(List<TrainStation> suggestions) {
    _stationSuggestions = suggestions;
    notifyListeners();
  }

  void clearStationSuggestions() {
    _stationSuggestions = [];
    notifyListeners();
  }

  Future<void> fetchDepartures(String stationId, {String country = 'IT', bool silent = false, bool offlineSyncEnabled = false}) async {
    if (stationId.isEmpty) return;
    final shouldUseOfflineSync = offlineSyncEnabled || _offlineSyncEnabled;
    final requestId = ++_fetchRequestId;
    final cacheIdentifier = _cacheIdentifier(stationId, country);
    
    if (!silent) {
      _isLoadingDepartures = true;
      notifyListeners();
    }

    try {
      final newDepartures = await _repository.fetchDepartures(
        stationId, 
        country: country, 
        service: _selectedService,
        isArrival: _isArrivalMode
      );
      if (requestId != _fetchRequestId) return;
      _isUsingOfflineCache = false;
      setOnlineAutoRefreshBlocked(false);

      // Preserva le fermate (stops) se già caricate
      if (_departures.isNotEmpty && newDepartures.isNotEmpty) {
        for (int i = 0; i < newDepartures.length; i++) {
          final newDep = newDepartures[i];
          
          // Cerca lo stesso treno nella vecchia lista
          final oldDep = _departures.firstWhere(
            (d) => (d.tripId != null && d.tripId == newDep.tripId) || 
                   (d.trainNumber == newDep.trainNumber && d.destination == newDep.destination),
            orElse: () => newDep,
          );

          if (newDep.stops == null && oldDep.stops != null) {
            newDepartures[i] = newDep.copyWith(stops: oldDep.stops);
          }
        }
      }

      _departures = newDepartures;

      // Save to offline cache if enabled, after preserving already loaded details.
      if (shouldUseOfflineSync && _departures.isNotEmpty) {
        try {
          await OfflineSyncService.saveTransportData(
            transportType: 'train',
            identifier: cacheIdentifier,
            data: _departures.map((d) => d.toJson()).toList(),
          );
          debugPrint('[TrainProvider] Synced offline data for train station $stationId');
        } catch (e) {
          debugPrint('[TrainProvider] Error saving offline data: $e');
        }
      }
    } catch (e) {
       print("Provider Error: $e");
       
       // Try to load from cache if offline fetch failed and sync is enabled
       if (shouldUseOfflineSync) {
         try {
           final cachedData = await OfflineSyncService.getTransportData(
             transportType: 'train',
             identifier: cacheIdentifier,
           );
           if (requestId != _fetchRequestId) return;
           if (cachedData != null && cachedData is List) {
             _departures = (cachedData as List)
                 .map((item) => TrainDeparture.fromJson(item as Map<String, dynamic>))
                 .toList();
              _isUsingOfflineCache = true;
              setOnlineAutoRefreshBlocked(true);
              debugPrint('[TrainProvider] Loaded offline data for train station $stationId');
           } else {
              _departures = [];
              _isUsingOfflineCache = false;
           }
         } catch (e2) {
            _departures = [];
            _isUsingOfflineCache = false;
         }
       } else {
          _departures = [];
          _isUsingOfflineCache = false;
       }
    } finally {
      if (requestId == _fetchRequestId) {
        if (!silent) {
          _isLoadingDepartures = false;
        }
        notifyListeners();
      }
    }
  }

  Future<void> loadSelectedStationFromOfflineCache() async {
    if (_selectedStation == null) return;

    final stationId = _selectedStation!.id;
    final country = _selectedStation!.country;
    final cacheIdentifier = _cacheIdentifier(stationId, country);

    try {
      final cachedData = await OfflineSyncService.getTransportData(
        transportType: 'train',
        identifier: cacheIdentifier,
      );
      if (cachedData != null && cachedData is List) {
        _departures = cachedData
            .map((item) => TrainDeparture.fromJson(item as Map<String, dynamic>))
            .toList();
        _isUsingOfflineCache = true;
        setOnlineAutoRefreshBlocked(true);
        _isLoadingDepartures = false;
        debugPrint('[TrainProvider] Switched immediately to offline cache for train station $stationId');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TrainProvider] Error loading immediate offline cache: $e');
    }
  }

  Future<void> expandTrainDetails(int index, {bool forceRefresh = false}) async {
    if (index < 0 || index >= _departures.length) return;
    
    final dep = _departures[index];
    // If stops are loaded and there is no error, return, unless forced.
    if (!forceRefresh && (dep.stops != null && dep.stops!.isNotEmpty) && dep.error == null) return; 

    // Clear error state before fetching
    if (dep.error != null) {
       _departures[index] = dep.copyWith(clearError: true);
       notifyListeners(); // Update UI to show loading again
    }

    try {
      TrainDeparture? details;
      if (dep.tripId != null) {
        details = await _repository.fetchTrip(
          dep.tripId!, 
          country: _selectedStation?.country ?? 'IT',
          service: _selectedService
        );
      } else {
        details = await _repository.fetchTrainDetails(
          dep.trainNumber ?? '', 
          _selectedStation?.id ?? '',
          country: _selectedStation?.country ?? 'IT',
          service: _selectedService
        );
      }

      if (details != null && details.stops != null) {
        // Automatically determine Origin if missing (from first stop)
        String? newOrigin = details.origin;
        if ((newOrigin == null || newOrigin.isEmpty) && details.stops!.isNotEmpty) {
           newOrigin = details.stops!.first.stationName;
        }

        // Preserve previous fields but include fetched stops, country and metadata to allow downstream features to use correct country
        _departures[index] = _departures[index].copyWith(
          stops: details.stops,
          origin: newOrigin, // Update origin from details
          country: details.country,
          metadata: details.metadata,
          clearError: true,
        );
        if (_offlineSyncEnabled && _selectedStation != null) {
          await _saveCurrentDeparturesToOfflineCache(_selectedStation!.id, _selectedStation!.country);
        }
        notifyListeners();
      }
    } catch (e) {
      print("Provider Error: $e");
      String friendlyError = "Impossibile caricare i dettagli.";
      final s = e.toString();
      if (s.contains("500")) {
        friendlyError = "Servizio momentaneamente non disponibile (500).";
      } else if (s.contains("TRIP_ERROR")) {
        friendlyError = "Dettagli corsa non trovati.";
      } else if (s.contains("SocketException") || s.contains("Network")) {
        friendlyError = "Errore di connessione. Controlla la rete.";
      }
      
      _departures[index] = _departures[index].copyWith(error: friendlyError);
      notifyListeners();
    }
  }

  String _cacheIdentifier(String stationId, String country) {
    final mode = _isArrivalMode ? 'arrivals' : 'departures';
    return '${_selectedService}_${mode}_${stationId}_$country';
  }

  Future<void> _saveCurrentDeparturesToOfflineCache(String stationId, String country) async {
    if (_departures.isEmpty) return;
    try {
      await OfflineSyncService.saveTransportData(
        transportType: 'train',
        identifier: _cacheIdentifier(stationId, country),
        data: _departures.map((d) => d.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('[TrainProvider] Error saving detailed offline data: $e');
    }
  }
}

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/train_model.dart';
import '../../data/repositories/train_repository.dart';

class TrainProvider with ChangeNotifier {
  final TrainRepository _repository = TrainRepository();
  
  Timer? _refreshTimer;
  int _autoRefreshSeconds = 0;

  // New States for Service and Mode
  String _selectedService = 'trainboardeu'; // 'direct' or 'trainboardeu'
  bool _isArrivalMode = false;
  
  String get selectedService => _selectedService;
  bool get isArrivalMode => _isArrivalMode;

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
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
      if (_selectedStation != null) {
        fetchDepartures(_selectedStation!.id, country: _selectedStation!.country, silent: true);
      }
    });
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
  TrainStation? _selectedStation;

  List<TrainStation> get stationSuggestions => _stationSuggestions;
  bool get isLoadingSuggestions => _isLoadingSuggestions;
  
  List<TrainDeparture> get departures => _departures;
  bool get isLoadingDepartures => _isLoadingDepartures;
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

  Future<void> searchStations(String query, {String country = 'IT'}) async {
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

  Future<void> fetchDepartures(String stationId, {String country = 'IT', bool silent = false}) async {
    if (stationId.isEmpty) return;
    
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
    } catch (e) {
       print("Provider Error: $e");
       _departures = [];
    } finally {
      if (!silent) {
        _isLoadingDepartures = false;
      }
      notifyListeners();
    }
  }

  Future<void> expandTrainDetails(int index) async {
    if (index < 0 || index >= _departures.length) return;
    
    final dep = _departures[index];
    // If stops are loaded and there is no error, return. If error present, retry is allowed.
    if ((dep.stops != null && dep.stops!.isNotEmpty) && dep.error == null) return; 

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
        // Preserve previous fields but include fetched stops, country and metadata to allow downstream features to use correct country
        _departures[index] = _departures[index].copyWith(
          stops: details.stops,
          country: details.country,
          metadata: details.metadata,
          clearError: true,
        );
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
}

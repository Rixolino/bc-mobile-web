import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/models/bus_model.dart';
import '../../data/repositories/bus_repository.dart';
import '../../core/services/offline_sync_service.dart';
import 'package:flutter/foundation.dart';

class BusProvider with ChangeNotifier {
  final BusRepository _repository = BusRepository();
  List<BusVehicle> _vehicles = [];
  bool _isLoading = false;
  String _selectedCity = 'Roma'; // Default
  
  Timer? _refreshTimer;
  int _autoRefreshSeconds = 0;

  // Bari routing
  List<BariStop> _bariStops = [];
  List<BariRouteSolution> _bariSolutions = [];
  BariStop? _selectedFromStop;
  BariStop? _selectedToStop;
  bool _isLoadingStops = false;
  bool _isLoadingSolutions = false;

  List<BusVehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;

  // Bari getters
  List<BariStop> get bariStops => _bariStops;
  List<BariRouteSolution> get bariSolutions => _bariSolutions;
  BariStop? get selectedFromStop => _selectedFromStop;
  BariStop? get selectedToStop => _selectedToStop;
  bool get isLoadingStops => _isLoadingStops;
  bool get isLoadingSolutions => _isLoadingSolutions;

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
      if (_selectedCity.isNotEmpty) {
        fetchVehicles(silent: true);
      }
    });
  }

  void selectCity(String city) {
    _selectedCity = city;
    if (city == 'Bari') {
      fetchBariStops();
    }
    fetchVehicles();
    notifyListeners();
  }

  // Helper to fetch with offline sync (called from UI with settings context)
  Future<void> fetchVehiclesWithOfflineSync(bool offlineSyncEnabled) async {
    await fetchVehicles(offlineSyncEnabled: offlineSyncEnabled);
  }

  Future<void> fetchVehicles({bool silent = false, bool offlineSyncEnabled = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      List<BusVehicle> fetchedVehicles = [];
      
      if (_selectedCity == 'Roma') {
        fetchedVehicles = await _repository.fetchRomeVehicles();
      } else if (_selectedCity == 'Bari') {
        fetchedVehicles = await _repository.fetchBariVehicles();
      } else if (_selectedCity == 'Emilia-Romagna') {
        fetchedVehicles = await _repository.fetchERVehicles();
      }
      
      _vehicles = fetchedVehicles;
      
      // Save to offline cache if enabled
      if (offlineSyncEnabled && _vehicles.isNotEmpty) {
        try {
          await OfflineSyncService.saveTransportData(
            transportType: 'bus',
            identifier: _selectedCity,
            data: _vehicles.map((v) => v.toJson()).toList(),
          );
          debugPrint('[BusProvider] Synced offline data for $_selectedCity');
        } catch (e) {
          debugPrint('[BusProvider] Error saving offline data: $e');
        }
      }
    } catch (e) {
      print("Provider Error: $e");
      
      // Try to load from cache if offline fetch failed and sync is enabled
      if (offlineSyncEnabled) {
        try {
          final cachedData = await OfflineSyncService.getTransportData(
            transportType: 'bus',
            identifier: _selectedCity,
          );
          if (cachedData != null && cachedData is List) {
            _vehicles = cachedData
                .map((item) => BusVehicle.fromJson(item as Map<String, dynamic>))
                .toList();
            debugPrint('[BusProvider] Loaded offline data for $_selectedCity');
          } else {
            _vehicles = [];
          }
        } catch (e2) {
          _vehicles = [];
        }
      } else {
        _vehicles = [];
      }
    } finally {
      if (!silent) {
        _isLoading = false;
      }
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

  // Bari routing methods
  Future<void> fetchBariStops() async {
    _isLoadingStops = true;
    notifyListeners();

    try {
      _bariStops = await _repository.fetchBariStops();
    } catch (e) {
      print("Error fetching Bari stops: $e");
      _bariStops = [];
    } finally {
      _isLoadingStops = false;
      notifyListeners();
    }
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
}


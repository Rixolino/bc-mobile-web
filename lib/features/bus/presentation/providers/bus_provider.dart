import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/models/bus_model.dart';
import '../../data/repositories/bus_repository.dart';

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
  BariStop? _selectedStop;
  bool _isLoadingStops = false;
  bool _isLoadingSolutions = false;

  // Selected bus for details
  BusVehicle? _selectedBus;
  BusRoutePath? _selectedBusRoutePath;
  bool _isLoadingRoutePath = false;

  List<BusVehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;

  // Bari getters
  List<BariStop> get bariStops => _bariStops;
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

  Future<void> fetchVehicles({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }
    
    try {
      if (_selectedCity == 'Roma') {
        _vehicles = await _repository.fetchRomeVehicles();
      } else if (_selectedCity == 'Bari') {
        _vehicles = await _repository.fetchBariVehicles();
      } else if (_selectedCity == 'Emilia-Romagna') {
        _vehicles = await _repository.fetchERVehicles();
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

  void clearAll() {
    _vehicles = [];
    _bariStops = [];
    _bariSolutions = [];
    _selectedFromStop = null;
    _selectedToStop = null;
    _selectedStop = null;
    _flixbusStations = [];
    _selectedBus = null;
    _selectedBusRoutePath = null;
    _isLoadingRoutePath = false;
    notifyListeners();
  }

  Future<void> selectBus(BusVehicle bus) async {
    _selectedBus = bus;
    // Load route path for Bari buses
    if (_selectedCity == 'Bari' && bus.provider == 'Bari') {
      _loadBusRoutePath(bus);
      // Also fetch destination if not already present
      if (bus.destination == null || bus.destination!.isEmpty) {
        try {
          final destination = await fetchBariVehicleDestination(bus.id, bus.line);
          if (destination != null && destination.isNotEmpty) {
            _selectedBus = bus.copyWith(destination: destination);
          }
        } catch (e) {
          print("Error fetching bus destination: $e");
        }
      }
    }
    notifyListeners();
  }

  Future<void> _loadBusRoutePath(BusVehicle bus) async {
    _isLoadingRoutePath = true;
    _selectedBusRoutePath = null;
    notifyListeners();

    try {
      // Use the tripId directly from the bus data
      final tripId = bus.tripId;

      if (tripId != null && tripId.isNotEmpty) {
        final routePath = await _repository.fetchBusRoutePath(tripId);
        _selectedBusRoutePath = routePath;
      } else {
        print("No tripId available for bus ${bus.id}");
        _selectedBusRoutePath = null;
      }
    } catch (e) {
      print("Error loading bus route path: $e");
      _selectedBusRoutePath = null;
    } finally {
      _isLoadingRoutePath = false;
      notifyListeners();
    }
  }

  void clearBusSelection() {
    _selectedBus = null;
    _selectedBusRoutePath = null;
    _isLoadingRoutePath = false;
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

  Future<List<StopDeparture>> fetchBariStopUpdates(String stopId) async {
    try {
      return await _repository.fetchBariStopUpdates(stopId);
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
}

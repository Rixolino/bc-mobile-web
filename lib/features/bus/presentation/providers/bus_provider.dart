import 'package:flutter/material.dart';
import 'dart:async';
import '../../data/models/bus_model.dart';
import '../../data/repositories/bus_repository.dart';

class BusProvider with ChangeNotifier {
  final BusRepository _repository = BusRepository();
  List<BusVehicle> _vehicles = [];
  bool _isLoading = false;
  String _selectedCity = ''; // Default empty, set after loading providers
  List<BusProviderConfig> _providers = [];
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

  List<BusVehicle> get vehicles => _vehicles;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;
  List<BusProviderConfig> get providers => _providers;
  BusProviderConfig? get selectedProvider => _selectedProvider;

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
    if (_selectedProvider?.endpoints['stops'] == true) {
      fetchStops();
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
      print("BusProvider: Fetching vehicles for city: $_selectedCity");
      // For dynamic providers, use generic endpoint if supported
      BusProviderConfig? provider;
      try {
        provider = _providers.firstWhere((p) => p.name == _selectedCity);
      } catch (e) {
        provider = null;
      }
      if (provider != null && provider.gpsUrl != null && provider.gpsUrl!.isNotEmpty) {
        print("BusProvider: Using GPS URL: ${provider.gpsUrl}");
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
  Future<void> fetchStops() async {
    _isLoadingStops = true;
    notifyListeners();

    try {
      if (_selectedProvider != null) {
        _stops = await _repository.fetchStops(_selectedProvider!);
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
    // Load route path for Bari buses
    if (_selectedCity == 'Bari' && bus.provider == 'Bari') {
      _loadBusRoutePath(bus);
      _loadTripStops(bus);
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

  Future<void> _loadTripStops(BusVehicle bus) async {
    _isLoadingTripStops = true;
    _selectedTripStops = null;
    notifyListeners();

    try {
      final tripId = bus.tripId;
      if (tripId != null && tripId.isNotEmpty) {
        final tripStops = await _repository.fetchTripStops(tripId);
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

  Future<List<StopDeparture>> fetchStopUpdates(String stopId) async {
    try {
      return await _repository.fetchStopUpdates(_selectedProvider?.name ?? 'bari', stopId);
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

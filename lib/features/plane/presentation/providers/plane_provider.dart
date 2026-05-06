import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../data/models/plane_model.dart';
import '../../data/repositories/plane_repository.dart';
import '../../../../core/services/offline_sync_service.dart';
import 'package:flutter/foundation.dart';

class PlaneProvider with ChangeNotifier {
  final PlaneRepository _repository = PlaneRepository();
  List<Flight> _flights = [];
  bool _isLoading = false;
  
  Timer? _refreshTimer;
  int _autoRefreshSeconds = 0;
  bool _offlineSyncEnabled = false;
  int _fetchRequestId = 0;

  List<Flight> get flights => _flights;
  bool get isLoading => _isLoading;

  List<Airport> _airportSuggestions = [];
  List<Flight> _scheduledFlights = [];
  bool _isLoadingAirports = false;
  Airport? _selectedAirport;
  bool _isArrivalMode = false;
  Flight? _selectedFlight;
  
  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void updateAutoRefresh(int seconds, {bool offlineSyncEnabled = false}) {
    _autoRefreshSeconds = seconds;
    _offlineSyncEnabled = offlineSyncEnabled;
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
      if (_selectedAirport != null) {
        fetchAirportFlights(silent: true, offlineSyncEnabled: _offlineSyncEnabled);
      }
    });
  }

  List<Airport> get airportSuggestions => _airportSuggestions;
  List<Flight> get scheduledFlights => _scheduledFlights;
  bool get isLoadingAirports => _isLoadingAirports;
  Airport? get selectedAirport => _selectedAirport;
  bool get isArrivalMode => _isArrivalMode;
  Flight? get selectedFlight => _selectedFlight;

  Future<void> searchAirports(String query) async {
    if (query.isEmpty) {
      _airportSuggestions = [];
      notifyListeners();
      return;
    }
    _isLoadingAirports = true;
    notifyListeners();
    _airportSuggestions = await _repository.searchAirports(query);
    _isLoadingAirports = false;
    notifyListeners();
  }

  void selectAirport(Airport airport) {
    _selectedAirport = airport;
    _airportSuggestions = []; // Clear suggestions to show results
    fetchAirportFlights();
  }

  // Helper to fetch with offline sync (called from UI with settings context)
  Future<void> fetchAirportFlightsWithOfflineSync(bool offlineSyncEnabled) async {
    _offlineSyncEnabled = offlineSyncEnabled;
    await fetchAirportFlights(offlineSyncEnabled: offlineSyncEnabled);
  }

  void setArrivalMode(bool isArrival) {
    _isArrivalMode = isArrival;
    if (_selectedAirport != null) {
      fetchAirportFlights();
    }
    notifyListeners();
  }

  Future<void> fetchAirportFlights({bool silent = false, bool offlineSyncEnabled = false}) async {
    if (_selectedAirport == null) return;
    final shouldUseOfflineSync = offlineSyncEnabled || _offlineSyncEnabled;
    final requestId = ++_fetchRequestId;
    final cacheIdentifier = _cacheIdentifier(_selectedAirport!.iata);
    
    if (!silent) {
      _isLoadingAirports = true; // Re-use for loading flights list
      notifyListeners();
    }
    
    try {
      _scheduledFlights = await _repository.fetchAirportFlights(
        _selectedAirport!.iata, 
        isArrival: _isArrivalMode
      );
      if (requestId != _fetchRequestId) return;
      
      // Save to offline cache if enabled
      if (shouldUseOfflineSync && _scheduledFlights.isNotEmpty) {
        try {
          await OfflineSyncService.saveTransportData(
            transportType: 'plane',
            identifier: cacheIdentifier,
            data: _scheduledFlights.map((f) => f.toJson()).toList(),
          );
          debugPrint('[PlaneProvider] Synced offline data for ${_selectedAirport!.iata}');
        } catch (e) {
          debugPrint('[PlaneProvider] Error saving offline data: $e');
        }
      }
    } catch (e) {
      print("Provider Error: $e");
      
      // Try to load from cache if offline fetch failed and sync is enabled
      if (shouldUseOfflineSync) {
        try {
          final cachedData = await OfflineSyncService.getTransportData(
            transportType: 'plane',
            identifier: cacheIdentifier,
          );
          if (requestId != _fetchRequestId) return;
          if (cachedData != null && cachedData is List) {
            _scheduledFlights = (cachedData as List)
                .map((item) => Flight.fromJson(item as Map<String, dynamic>))
                .toList();
            debugPrint('[PlaneProvider] Loaded offline data for ${_selectedAirport!.iata}');
          } else {
            _scheduledFlights = [];
          }
        } catch (e2) {
          _scheduledFlights = [];
        }
      } else {
        _scheduledFlights = [];
      }
    } finally {
      if (requestId == _fetchRequestId) {
        if (!silent) {
          _isLoadingAirports = false;
        }
        notifyListeners();
      }
    }
  }

  String _cacheIdentifier(String airportIata) {
    final mode = _isArrivalMode ? 'arrivals' : 'departures';
    return '${airportIata}_$mode';
  }

  void clearAirportSelection() {
    _selectedAirport = null;
    _scheduledFlights = [];
    _airportSuggestions = [];
    _selectedFlight = null;
    notifyListeners();
  }

  void selectFlight(Flight flight) {
    _selectedFlight = flight;
    notifyListeners();
    // Se mancano i dati della controparte, li fetchiamo
    _fetchMissingFlightDetails(flight);
  }

  Future<void> _fetchMissingFlightDetails(Flight flight) async {
    // Se siamo in Arrivi e manca la partenza, o viceversa
    if (flight.type == 'arrival' && (flight.scheduledDeparture == null || flight.originId == null)) {
      if (flight.originId != null) {
        final others = await _repository.fetchAirportFlights(flight.originId!, isArrival: false);
        final match = others.where((o) => o.flightNumber == flight.flightNumber).firstOrNull;
        if (match != null) {
          _selectedFlight = _mergeFlights(flight, match);
          notifyListeners();
        }
      }
    } else if (flight.type == 'departure' && (flight.scheduledArrival == null || flight.destinationId == null)) {
      if (flight.destinationId != null) {
        final others = await _repository.fetchAirportFlights(flight.destinationId!, isArrival: true);
        final match = others.where((o) => o.flightNumber == flight.flightNumber).firstOrNull;
        if (match != null) {
          _selectedFlight = _mergeFlights(flight, match);
          notifyListeners();
        }
      }
    }
  }

  Flight _mergeFlights(Flight primary, Flight secondary) {
    return Flight(
      id: primary.id,
      flightNumber: primary.flightNumber,
      callsign: primary.callsign,
      airline: primary.airline,
      origin: primary.origin,
      originId: primary.originId ?? secondary.originId,
      destination: primary.destination,
      destinationId: primary.destinationId ?? secondary.destinationId,
      status: primary.status,
      statusLocalized: primary.statusLocalized ?? secondary.statusLocalized,
      scheduledTime: primary.scheduledTime ?? secondary.scheduledTime,
      estimatedTime: primary.estimatedTime ?? secondary.estimatedTime,
      scheduledDeparture: primary.scheduledDeparture ?? secondary.scheduledDeparture,
      estimatedDeparture: primary.estimatedDeparture ?? secondary.estimatedDeparture,
      scheduledArrival: primary.scheduledArrival ?? secondary.scheduledArrival,
      estimatedArrival: primary.estimatedArrival ?? secondary.estimatedArrival,
      type: primary.type,
      terminal: primary.terminal ?? secondary.terminal,
      gate: primary.gate ?? secondary.gate,
    );
  }

  void clearFlightSelection() {
    _selectedFlight = null;
    notifyListeners();
  }

  void clearAll() {
    _flights = [];
    _scheduledFlights = [];
    _airportSuggestions = [];
    _selectedAirport = null;
    _selectedFlight = null;
    notifyListeners();
  }

  Future<void> fetchFlights(double n, double s, double w, double e) async {
      try {
        _flights = await _repository.fetchFlights(n, s, w, e);
      } catch (e) {
        print("Provider Error: $e");
        _flights = [];
      }
      notifyListeners();
  }

  // Metodo per aggiornare i voli basato su coordinate visibili
  Future<void> updateVisibleArea(double centerLat, double centerLng, double zoom) async {
    // Calcola i bounds approssimativi basato su zoom level
    final padding = _calculatePaddingFromZoom(zoom);
    final n = centerLat + padding;
    final s = centerLat - padding;
    final e = centerLng + padding;
    final w = centerLng - padding;
    
    await fetchFlights(n, s, w, e);
  }

  double _calculatePaddingFromZoom(double zoom) {
    // Formula per calcolare i gradi approssimativi basati sullo zoom
    // Zoom 2: ~45 gradi
    // Zoom 12: ~0.1 gradi (città)
    return 180.0 / math.pow(2, zoom - 1);
  }

  Future<void> scanAreaForFlights(double lat, double lng, double zoom) async {
    // Calcola i bounds approssimativi basato su zoom level
    final padding = _calculatePaddingFromZoom(zoom);
    final north = lat + padding;
    final south = lat - padding;
    final east = lng + padding;
    final west = lng - padding;
    
    _isLoading = true;
    notifyListeners();
    
    try {
      _flights = await _repository.fetchFlights(north, south, west, east);
      print('Scanned area: loaded ${_flights.length} flights');
    } catch (e) {
      print("Error scanning area: $e");
      _flights = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

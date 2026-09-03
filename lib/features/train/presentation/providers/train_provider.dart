import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/train_model.dart';
import '../../data/repositories/train_repository.dart';
import '../../../../core/services/offline_sync_service.dart';
import 'package:flutter/foundation.dart';
import 'package:libsql_dart/libsql_dart.dart' if (dart.library.io) 'package:libsql_dart/libsql_dart.dart';

class TrainProvider with ChangeNotifier {
  final TrainRepository _repository = TrainRepository();
  
  // Turso database configuration
  static const String _tursoUrl = 'libsql://betacloud-transporter-rixolino.aws-eu-west-1.turso.io';
  static const String _tursoToken = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3Njg2NTc3NDEsImlkIjoiMjI1ZTU0OTgtMmUxYS00ZWM3LTg0ZWUtMDlkMGRmM2YxOWMwIiwicmlkIjoiYWNkMDBiOGYtNTMxYS00MWMxLTk5YjQtYjg5ODc2YTJkMzVhIn0.nUl4jePNi0wZvxhdGvLlwk24EI9BL4jUvBoHKEMdGpatHD_bkn5V8PpcWvMujn4gwfNhmFmqNRH7JYjcjd9zBw';

  LibsqlClient? _client;

  // ============================================================
  // METODI PER TURSO (DATABASE REMOTO)
  // ============================================================

  /// Ottiene la connessione al database Turso
  Future<LibsqlClient> getDatabase() async {
    if (_client != null) return _client!;

    try {
      debugPrint('📡 Connecting to Turso database...');
      _client = LibsqlClient.remote(_tursoUrl, authToken: _tursoToken);
      await _client!.connect();
      await _initializeDatabase();
      debugPrint('✅ Turso database connected successfully');
      return _client!;
    } catch (e) {
      debugPrint('❌ Turso connection error: $e');
      rethrow;
    }
  }

  Future<void> _initializeDatabase() async {
    final client = await getDatabase();
    await client.execute('''
      CREATE TABLE IF NOT EXISTS train_trips (
        trip_id TEXT PRIMARY KEY,
        country TEXT,
        category TEXT,
        trip_number TEXT,
        operator TEXT,
        polyline TEXT,
        stops TEXT,
        last_updated TEXT,
        delay INTEGER,
        tripNumber TEXT
      )
    ''');
    
    await client.execute('''
      CREATE INDEX IF NOT EXISTS idx_train_trips_category ON train_trips(category)
    ''');
    
    await client.execute('''
      CREATE INDEX IF NOT EXISTS idx_train_trips_trip_number ON train_trips(trip_number)
    ''');
    
    await client.execute('''
      CREATE INDEX IF NOT EXISTS idx_train_trips_last_updated ON train_trips(last_updated DESC)
    ''');
    
    debugPrint('✅ Train trips table created/verified in Turso');
  }

  Future<void> _closeDatabase() async {
    try {
      if (_client != null) {
        _client = null;
        debugPrint('📁 Turso database reference released');
      }
    } catch (e) {
      debugPrint('❌ Error releasing Turso database: $e');
    }
  }

  /// Recupera il trip_id più recente dal database Turso per categoria e numero treno
  Future<String?> getMostRecentTripId(String category, String number) async {
    try {
      final client = await getDatabase();
      
      final result = await client.query(
        'SELECT trip_id, last_updated, country FROM train_trips WHERE category = ? AND trip_number = ? ORDER BY last_updated DESC LIMIT 1',
        positional: [category, number],
      );

      if (result.isNotEmpty) {
        final first = result.first;
        final tripId = first['trip_id']?.toString();
        final lastUpdated = first['last_updated']?.toString() ?? 'N/A';
        final country = first['country']?.toString();
        
        debugPrint('✅ [Turso] Trovato trip_id: "$tripId" (last_updated: $lastUpdated)');
        
        if (country != null && country.isNotEmpty) {
          debugPrint('🌍 [Turso] Country: $country');
        }
        
        return tripId;
      } else {
        debugPrint('📭 [Turso] Nessun risultato per categoria "$category" e numero "$number"');
      }
    } catch (e) {
      debugPrint('❌ [Turso] Errore in getMostRecentTripId: $e');
    }
    
    return null;
  }

  /// Salva un trip nel database Turso
  Future<void> saveTrip(Map<String, dynamic> tripData) async {
    try {
      final client = await getDatabase();
      
      final tripId = tripData['trip_id']?.toString();
      if (tripId == null || tripId.isEmpty) {
        debugPrint('⚠️ [Turso] trip_id mancante, impossibile salvare');
        return;
      }
      
      final checkResult = await client.query(
        'SELECT trip_id FROM train_trips WHERE trip_id = ?',
        positional: [tripId],
      );
      
      if (checkResult.isNotEmpty) {
        await client.execute(
          '''UPDATE train_trips 
             SET country = ?, category = ?, trip_number = ?, operator = ?, 
                 polyline = ?, stops = ?, last_updated = ?, delay = ?, tripNumber = ?
             WHERE trip_id = ?''',
          positional: [
            tripData['country']?.toString() ?? '',
            tripData['category']?.toString() ?? '',
            tripData['trip_number']?.toString() ?? '',
            tripData['operator']?.toString() ?? '',
            tripData['polyline']?.toString() ?? '',
            tripData['stops']?.toString() ?? '',
            tripData['last_updated']?.toString() ?? DateTime.now().toIso8601String(),
            tripData['delay'] ?? 0,
            tripData['tripNumber']?.toString() ?? '',
            tripId,
          ],
        );
        debugPrint('✅ [Turso] Aggiornato trip: $tripId');
      } else {
        await client.execute(
          '''INSERT INTO train_trips (
            trip_id, country, category, trip_number, operator, 
            polyline, stops, last_updated, delay, tripNumber
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          positional: [
            tripId,
            tripData['country']?.toString() ?? '',
            tripData['category']?.toString() ?? '',
            tripData['trip_number']?.toString() ?? '',
            tripData['operator']?.toString() ?? '',
            tripData['polyline']?.toString() ?? '',
            tripData['stops']?.toString() ?? '',
            tripData['last_updated']?.toString() ?? DateTime.now().toIso8601String(),
            tripData['delay'] ?? 0,
            tripData['tripNumber']?.toString() ?? '',
          ],
        );
        debugPrint('✅ [Turso] Inserito nuovo trip: $tripId');
      }
    } catch (e) {
      debugPrint('❌ [Turso] Errore salvando trip: $e');
    }
  }

  /// Recupera un trip completo per categoria e numero
  Future<Map<String, dynamic>?> getTripByCategoryAndNumber(String category, String number) async {
    try {
      final client = await getDatabase();
      
      final result = await client.query(
        'SELECT * FROM train_trips WHERE category = ? AND trip_number = ? ORDER BY last_updated DESC LIMIT 1',
        positional: [category, number],
      );
      
      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'trip_id': row['trip_id'],
          'country': row['country'],
          'category': row['category'],
          'trip_number': row['trip_number'],
          'operator': row['operator'],
          'polyline': row['polyline'],
          'stops': row['stops'],
          'last_updated': row['last_updated'],
          'delay': row['delay'],
          'tripNumber': row['tripNumber'],
        };
      }
    } catch (e) {
      debugPrint('❌ [Turso] Errore in getTripByCategoryAndNumber: $e');
    }
    
    return null;
  }

  /// Recupera un trip per trip_id
  Future<Map<String, dynamic>?> getTripById(String tripId) async {
    try {
      final client = await getDatabase();
      
      final result = await client.query(
        'SELECT * FROM train_trips WHERE trip_id = ?',
        positional: [tripId],
      );
      
      if (result.isNotEmpty) {
        final row = result.first;
        return {
          'trip_id': row['trip_id'],
          'country': row['country'],
          'category': row['category'],
          'trip_number': row['trip_number'],
          'operator': row['operator'],
          'polyline': row['polyline'],
          'stops': row['stops'],
          'last_updated': row['last_updated'],
          'delay': row['delay'],
          'tripNumber': row['tripNumber'],
        };
      }
    } catch (e) {
      debugPrint('❌ [Turso] Errore in getTripById: $e');
    }
    
    return null;
  }

  /// Cerca trip per numero treno
  Future<List<Map<String, dynamic>>> searchTripsByNumber(String query) async {
    try {
      final client = await getDatabase();
      
      final result = await client.query(
        'SELECT * FROM train_trips WHERE trip_number LIKE ? OR tripNumber LIKE ? ORDER BY last_updated DESC LIMIT 20',
        positional: ['%$query%', '%$query%'],
      );
      
      final List<Map<String, dynamic>> results = [];
      
      for (final row in result) {
        results.add({
          'trip_id': row['trip_id'],
          'country': row['country'],
          'category': row['category'],
          'trip_number': row['trip_number'],
          'operator': row['operator'],
          'polyline': row['polyline'],
          'stops': row['stops'],
          'last_updated': row['last_updated'],
          'delay': row['delay'],
          'tripNumber': row['tripNumber'],
        });
      }
      
      return results;
    } catch (e) {
      debugPrint('❌ [Turso] Errore in searchTripsByNumber: $e');
    }
    
    return [];
  }

  /// Salva gli stops di un trip
  Future<void> saveTripStops(String tripId, List<Map<String, dynamic>> stops) async {
    try {
      final client = await getDatabase();
      
      await client.execute(
        'UPDATE train_trips SET stops = ? WHERE trip_id = ?',
        positional: [
          jsonEncode(stops),
          tripId,
        ],
      );
      
      debugPrint('✅ [Turso] Salvate stops per trip: $tripId');
    } catch (e) {
      debugPrint('❌ [Turso] Errore salvando stops: $e');
    }
  }

  /// Recupera gli stops di un trip
  Future<List<Map<String, dynamic>>?> getTripStops(String tripId) async {
    try {
      final client = await getDatabase();
      
      final result = await client.query(
        'SELECT stops FROM train_trips WHERE trip_id = ?',
        positional: [tripId],
      );
      
      if (result.isNotEmpty) {
        final stopsJson = result.first['stops']?.toString();
        if (stopsJson != null && stopsJson.isNotEmpty) {
          final decoded = jsonDecode(stopsJson);
          if (decoded is List) {
            return List<Map<String, dynamic>>.from(decoded);
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [Turso] Errore in getTripStops: $e');
    }
    
    return null;
  }

  /// Ottiene tutti i trip (per debug)
  Future<List<Map<String, dynamic>>> getAllTrips() async {
    try {
      final client = await getDatabase();
      
      final result = await client.query(
        'SELECT * FROM train_trips ORDER BY last_updated DESC LIMIT 100',
      );
      
      final List<Map<String, dynamic>> results = [];
      
      for (final row in result) {
        results.add({
          'trip_id': row['trip_id'],
          'country': row['country'],
          'category': row['category'],
          'trip_number': row['trip_number'],
          'operator': row['operator'],
          'last_updated': row['last_updated'],
          'delay': row['delay'],
          'tripNumber': row['tripNumber'],
        });
      }
      
      return results;
    } catch (e) {
      debugPrint('❌ [Turso] Errore in getAllTrips: $e');
    }
    
    return [];
  }

  // ============================================================
  // METODI ESISTENTI
  // ============================================================

  Timer? _refreshTimer;
  int _autoRefreshSeconds = 0;
  bool _offlineSyncEnabled = false;
  bool _blockOnlineAutoRefresh = false;
  int _fetchRequestId = 0;

  // New States for Service and Mode
  String _selectedService = 'trainboardeu';
  bool _isArrivalMode = false;
  
  String get selectedService => _selectedService;
  bool get isArrivalMode => _isArrivalMode;

  // Train vector logos
  Map<String, String> _trainLogos = {};
  bool _hasLoadedLogos = false;
  bool _isLoadingLogos = false;
  Map<String, String> get trainLogos => _trainLogos;

  @override
  void dispose() {
    _stopTimer();
    _closeDatabase();
    super.dispose();
  }

  Future<void> loadTrainLogos() async {
    if (_hasLoadedLogos || _isLoadingLogos) return;
    _isLoadingLogos = true;
    try {
      final logos = await _repository.fetchTrainLogos();
      if (logos.isNotEmpty) {
        _trainLogos = logos;
        _hasLoadedLogos = true;
        notifyListeners();
      } else {
        _hasLoadedLogos = false;
      }
    } catch (e) {
      _hasLoadedLogos = false;
      debugPrint("Error loading train logos: $e");
    } finally {
      _isLoadingLogos = false;
    }
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
    _selectedStation = null;
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
      debugPrint("Provider Error: $e");
      _searchResults = [];
    } finally {
      _isSearchingByNumber = false;
      notifyListeners();
    }
  }

  void selectStation(TrainStation station) {
    _selectedStation = station;
    _stationSuggestions = [];
    notifyListeners();
    fetchDepartures(station.id, country: station.country);
  }

  void selectSavedTrain(TrainStation station, TrainDeparture train, String service, String mode) {
    _selectedStation = station;
    _selectedService = service;
    _isArrivalMode = mode == 'arrivals';
    _departures = [train]; 
    _isUsingOfflineCache = true;
    _isLoadingDepartures = false;
    setOnlineAutoRefreshBlocked(true);
    notifyListeners();
  }

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
      debugPrint("Provider Error: $e");
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

      if (_departures.isNotEmpty && newDepartures.isNotEmpty) {
        for (int i = 0; i < newDepartures.length; i++) {
          final newDep = newDepartures[i];
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

      if (shouldUseOfflineSync && _departures.isNotEmpty) {
        try {
          await OfflineSyncService.saveTransportData(
            transportType: 'train',
            identifier: cacheIdentifier,
            data: {
              'station': _selectedStation?.toJson(),
              'service': _selectedService,
              'mode': _isArrivalMode ? 'arrivals' : 'departures',
              'departures': _departures.map((d) => d.toJson()).toList(),
              'lastUpdated': DateTime.now().toIso8601String(),
            },
          );
          debugPrint('[TrainProvider] Synced offline data for train station $stationId');
        } catch (e) {
          debugPrint('[TrainProvider] Error saving offline data: $e');
        }
      }
    } catch (e) {
       debugPrint("Provider Error: $e");
       
       if (shouldUseOfflineSync) {
         try {
           final cachedData = await OfflineSyncService.getTransportData(
             transportType: 'train',
             identifier: cacheIdentifier,
           );
           if (requestId != _fetchRequestId) return;
            if (cachedData != null && cachedData is Map) {
              final departuresData = cachedData['departures'] as List;
              _departures = departuresData
                  .map((item) => TrainDeparture.fromJson(item as Map<String, dynamic>))
                  .toList();
               _isUsingOfflineCache = true;
               setOnlineAutoRefreshBlocked(true);
               debugPrint('[TrainProvider] Loaded offline data for train station $stationId');
            } else if (cachedData != null && cachedData is List) {
             _departures = cachedData
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
      if (cachedData != null && cachedData is Map) {
        final departuresData = cachedData['departures'] as List;
        _departures = departuresData
            .map((item) => TrainDeparture.fromJson(item as Map<String, dynamic>))
            .toList();
        _isUsingOfflineCache = true;
        setOnlineAutoRefreshBlocked(true);
        _isLoadingDepartures = false;
        debugPrint('[TrainProvider] Switched immediately to offline cache for train station $stationId');
        notifyListeners();
      } else if (cachedData != null && cachedData is List) {
        _departures = cachedData
            .map((item) => TrainDeparture.fromJson(item as Map<String, dynamic>))
            .toList();
        _isUsingOfflineCache = true;
        setOnlineAutoRefreshBlocked(true);
        _isLoadingDepartures = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[TrainProvider] Error loading immediate offline cache: $e');
    }
  }

  Future<void> expandTrainDetails(int index, {bool forceRefresh = false}) async {
    if (index < 0 || index >= _departures.length) return;
    
    final dep = _departures[index];
    if (!forceRefresh && (dep.stops != null && dep.stops!.isNotEmpty) && dep.error == null) return; 

    if (dep.error != null) {
       _departures[index] = dep.copyWith(clearError: true);
       notifyListeners();
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
        String? newOrigin = details.origin;
        if ((newOrigin == null || newOrigin.isEmpty) && details.stops!.isNotEmpty) {
           newOrigin = details.stops!.first.stationName;
        }

        _departures[index] = _departures[index].copyWith(
          stops: details.stops,
          origin: newOrigin,
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
      debugPrint("Provider Error: $e");
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

  /// Fallback ritardo: se il refresh via trip endpoint non riesce più a
  /// fornire i minuti di ritardo, li cerca nei tabelloni delle prossime
  /// stazioni della tratta.
  ///
  /// 1. Salva gli ID di tutte le fermate della tratta.
  /// 2. Interroga partenze (arrivi per l'ultima fermata) delle prossime
  ///    fermate con ID valido, al massimo [maxStations].
  /// 3. Se il treno compare nel tabellone, ne prende il delay e aggiorna
  ///    la departure nel tabellone corrente.
  ///
  /// Non tocca loading flag, cache offline né la stazione selezionata:
  /// le query sono silenziose e con timeout breve.
  /// Restituisce il delay trovato oppure null.
  Future<int?> refreshDelayFromUpcomingStations(TrainDeparture dep, {int maxStations = 3}) async {
    final stops = dep.stops;
    if (stops == null || stops.isEmpty) return null;

    final now = DateTime.now().toUtc();

    // Indici delle prossime fermate non cancellate (prima non ancora passata)
    final indices = <int>[];
    for (int i = 0; i < stops.length && indices.length < maxStations; i++) {
      final s = stops[i];
      if (s.cancelled) continue;
      final depTime = s.estimatedDeparture?.toUtc() ?? s.departure?.toUtc();
      if (depTime != null && depTime.isBefore(now.subtract(const Duration(minutes: 2)))) {
        continue; // già passata
      }
      indices.add(i);
    }
    // Se risultano tutte passate (treno in arrivo), prova comunque le ultime
    if (indices.isEmpty) {
      for (int i = stops.length - 1; i >= 0 && indices.length < maxStations; i--) {
        if (!stops[i].cancelled) indices.insert(0, i);
      }
    }
    if (indices.isEmpty) return null;

    for (final i in indices) {
      final stop = stops[i];
      final stationId = stop.id ?? '';
      if (stationId.isEmpty) continue;
      final country = stop.country.isNotEmpty
          ? stop.country
          : (dep.country.isNotEmpty ? dep.country : 'IT');
      // Ultima fermata della tratta -> tabellone arrivi, le altre -> partenze
      final isArrival = i == stops.length - 1;

      List<TrainDeparture> board;
      try {
        board = await _repository
            .fetchDepartures(
              stationId,
              country: country,
              service: _selectedService,
              isArrival: isArrival,
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        continue;
      }

      TrainDeparture? match;
      final tripId = dep.tripId ?? '';
      if (tripId.isNotEmpty) {
        for (final d in board) {
          if (d.tripId == tripId) {
            match = d;
            break;
          }
        }
      }
      if (match == null && (dep.trainNumber ?? '').isNotEmpty) {
        for (final d in board) {
          if (d.trainNumber == dep.trainNumber) {
            match = d;
            break;
          }
        }
      }
      if (match == null) continue;

      final delay = match.delayMinutes;
      if (delay == null) continue;

      // Aggiorna la departure nel tabellone corrente
      final idx = _departures.indexWhere((d) =>
          (tripId.isNotEmpty && d.tripId == tripId) ||
          (d.trainNumber == dep.trainNumber && d.destination == dep.destination));
      if (idx != -1) {
        _departures[idx] = _departures[idx].copyWith(
          delayMinutes: delay,
          clearError: true,
        );
        notifyListeners();
      }
      debugPrint('[TrainProvider] Delay fallback da stazione ${stop.stationName}: $delay min');
      return delay;
    }
    return null;
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
        data: {
          'station': _selectedStation?.toJson(),
          'service': _selectedService,
          'mode': _isArrivalMode ? 'arrivals' : 'departures',
          'departures': _departures.map((d) => d.toJson()).toList(),
          'lastUpdated': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('[TrainProvider] Error saving detailed offline data: $e');
    }
  }

  Future<void> saveTrainOffline(TrainDeparture train) async {
    if (_selectedStation == null) return;
    
    final identifier = 'train_detail_${train.tripId}_${_selectedStation!.id}';
    await OfflineSyncService.saveTransportData(
      transportType: 'train',
      identifier: identifier,
      data: {
        'station': _selectedStation?.toJson(),
        'service': _selectedService,
        'mode': _isArrivalMode ? 'arrivals' : 'departures',
        'train': train.toJson(),
        'lastUpdated': DateTime.now().toIso8601String(),
      },
    );
    notifyListeners();
  }

  Future<bool> isTrainCachedOffline(String? tripId) async {
    if (tripId == null || _selectedStation == null) return false;
    final identifier = 'train_detail_${tripId}_${_selectedStation!.id}';
    return await OfflineSyncService.isCached(
      transportType: 'train',
      identifier: identifier,
    );
  }

  Future<List<Map<String, dynamic>>> getDownloadedTrains() async {
    final identifiers = await OfflineSyncService.getAllCachedIdentifiers('train');
    final List<Map<String, dynamic>> results = [];
    
    for (final id in identifiers) {
      if (!id.startsWith('train_detail_')) continue;
      
      final data = await OfflineSyncService.getTransportData(
        transportType: 'train',
        identifier: id,
      );
      if (data != null && data is Map) {
        results.add({
          'id': id,
          'station': data['station'],
          'service': data['service'],
          'mode': data['mode'],
          'train': data['train'],
          'lastUpdated': data['lastUpdated'],
        });
      }
    }
    return results;
  }
}
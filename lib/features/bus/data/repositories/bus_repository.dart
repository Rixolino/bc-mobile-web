import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/api_constants.dart';
import '../models/bus_model.dart';

class BusRepository {
  static const String flixbusBase = "https://prod.cuzimmartin.dev/api/flixbus";
  List<BusProviderConfig>? _cachedProviders;

  String _countryFromProviderConfig(BusProviderConfig? provider) {
    if (provider == null) return 'it';
    if (provider.country != null && provider.country!.isNotEmpty) return provider.country!;
    if (provider.apiPrefix != null && provider.apiPrefix!.contains('/')) return provider.apiPrefix!.split('/').first;
    return 'it';
  }

  Future<String> _countryForProviderName(String providerName) async {
    try {
      final providers = await fetchBusProviders();
      final matches = providers.where((x) => x.name.toLowerCase() == providerName.toLowerCase()).toList();
      final p = matches.isNotEmpty ? matches.first : null;
      if (p != null) return p.country ?? (p.apiPrefix != null ? p.apiPrefix!.split('/').first : 'it');
    } catch (_) {}
    return 'it';
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    
    // Convert to radians
    final lat1Rad = _degreesToRadians(lat1);
    final lng1Rad = _degreesToRadians(lng1);
    final lat2Rad = _degreesToRadians(lat2);
    final lng2Rad = _degreesToRadians(lng2);
    
    final dLat = lat2Rad - lat1Rad;
    final dLng = lng2Rad - lng1Rad;
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
             cos(lat1Rad) * cos(lat2Rad) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadiusKm * c;
  }
  
  double _degreesToRadians(double degrees) => degrees * pi / 180;
  
  String? _calculateArrivalEstimate(double busLat, double busLng, double stopLat, double stopLng, double currentSpeed) {
    // Validate coordinates
    if (busLat == 0.0 && busLng == 0.0) return null;
    if (stopLat == 0.0 && stopLng == 0.0) return null;
    
    final distance = _calculateDistance(busLat, busLng, stopLat, stopLng);
    
    // More precise "In arrivo" logic: within 100m OR within 200m and moving slowly (< 10 km/h)
    if (distance < 0.1 || (distance < 0.2 && currentSpeed < 10)) {
      return 'In arrivo';
    }
    
    const commercialSpeedKmh = 20.0;
    var speedToUse = commercialSpeedKmh;
    
    // If bus is moving, use weighted average
    if (currentSpeed > 2) {
      speedToUse = (commercialSpeedKmh * 0.6) + (currentSpeed * 0.4);
    }
    
    // Ensure minimum speed
    speedToUse = speedToUse.clamp(5.0, 60.0);
    
    final timeHours = distance / speedToUse;
    final timeMinutes = (timeHours * 60).ceil();
    
    // Limit to reasonable range
    if (timeMinutes > 60) return null; // Too far, don't show estimate
    if (timeMinutes < 1) return 'In arrivo';
    
    return '~${timeMinutes} min';
  }

  Future<List<BusVehicle>> fetchVehicles(BusProviderConfig provider) async {
    try {
      final response = await http.get(Uri.parse(provider.gpsUrl ?? ''));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        print('BusRepository: fetched ${provider.name} JSON keys: ${json is Map ? json.keys.toList() : "List"}');
        
        // Special handling for Emilia-Romagna (TperHellobus format)
        if (provider.name == 'Emilia-Romagna') {
          final List<dynamic> data = json is List ? json : [];
          return data.map((e) => BusVehicle.fromERJson(e)).toList();
        }
        
        List rawList = [];
        if (json is Map) {
           // Check for the new format first
           if (json['entities'] != null && json['entities'] is List) {
              rawList = json['entities'];
           }
           // Fallback to old formats
           else if (json['Entities'] != null) {
              if (json['Entities'] is List) rawList = json['Entities'];
              else if (json['Entities']['FeedEntity'] != null) {
                  var fe = json['Entities']['FeedEntity'];
                  rawList = fe is List ? fe : [fe];
              }
           } else if (json['FeedMessage'] != null && json['FeedMessage']['Entities'] != null) {
              var ents = json['FeedMessage']['Entities'];
              if (ents['FeedEntity'] != null) {
                 var fe = ents['FeedEntity'];
                 rawList = fe is List ? fe : [fe];
              } else {
                 rawList = ents is List ? ents : [ents];
              }
           }
        }
        
        return rawList.map((e) => BusVehicle.fromGtfsRtJson(e, provider.name)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching vehicles for ${provider.name}: $e");
      return [];
    }
  }

  Future<List<dynamic>> searchFlixbusStations(String query) async {
    try {
      final response = await http.get(Uri.parse("$flixbusBase/stations?query=${Uri.encodeComponent(query)}"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return data['data'] ?? [];
      }
      return [];
    } catch (e) {
       print("Error searching Flixbus stations: $e");
       return [];
    }
  }

  Future<List<BusLine>> fetchBusLines(String providerName) async {
    final List<BusLine> allLines = [];
    await fetchBusLinesIncremental(
      providerName,
      onChunk: (chunk) => allLines.addAll(chunk),
    );
    return allLines;
  }

  Future<void> fetchBusLinesIncremental(
    String providerName, {
    required void Function(List<BusLine> chunk) onChunk,
    String? query,
  }) async {
    try {
      final country = await _countryForProviderName(providerName);
      int currentPage = 1;
      int totalPages = 1;
      const int chunkSize = 100;

      do {
        var url = "${ApiConstants.baseUrl}/api/$country/bus/$providerName/lines?page=$currentPage&chunkSize=$chunkSize";
        if (query != null && query.isNotEmpty) {
          url += "&q=${Uri.encodeComponent(query)}";
        }
        
        print('BusRepository: Fetching chunk $currentPage from $url');
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          final List linesJson = data['lines'] ?? [];
          
          // Background parsing for the chunk
          final chunk = await compute(_parseBusLinesList, linesJson);
          onChunk(chunk);

          final pagination = data['pagination'];
          if (pagination != null) {
            totalPages = pagination['totalPages'] ?? 1;
          } else {
            // If no pagination object, it means it returned all lines in one go
            break;
          }
        } else {
          break;
        }
        currentPage++;
      } while (currentPage <= totalPages);

    } catch (e) {
      print("Error fetching incremental bus lines for $providerName: $e");
    }
  }

  // Helper for parsing a list of lines in background
  static List<BusLine> _parseBusLinesList(dynamic linesJson) {
    if (linesJson is! List) return [];
    return linesJson.map((l) => BusLine.fromJson(Map<String, dynamic>.from(l))).toList();
  }

  // Top-level or static helper for compute
  static List<BusLine> _parseBusLines(String responseBody) {
    final Map<String, dynamic> data = jsonDecode(responseBody);
    final List linesJson = data['lines'] ?? [];
    return linesJson.map((l) => BusLine.fromJson(Map<String, dynamic>.from(l))).toList();
  }

  Future<List<BusVehicle>> fetchFlixbusDepartures(String stationId) async {
    try {
      final response = await http.get(Uri.parse("$flixbusBase/departures?stationId=$stationId"));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> departures = data['data'] ?? [];
        return departures.map((e) => BusVehicle.fromFlixbusJson(e)).toList();
      }
      return [];
    } catch (e) {
       print("Error fetching Flixbus departures: $e");
       return [];
    }
  }

  Future<List<BariStop>> fetchStops(BusProviderConfig provider, {bool offline = false}) async {
    try {
      final country = _countryFromProviderConfig(provider);
      var url = "${ApiConstants.baseUrl}/api/$country/bus/${provider.name}/stops";
      if (offline) url += "?offline=true";
      print("[Stops] GET $url (provider=${provider.name}, offline=$offline)");
      final response = await http.get(Uri.parse(url));
      final head = response.body.substring(0, response.body.length.clamp(0, 120));
      print("[Stops] HTTP ${response.statusCode}, bodyLen=${response.body.length}, head=$head");
      if (response.statusCode == 200) {
        // Use compute for parsing potentially large stop lists (like Turin)
        final parsed = await compute(_parseBariStops, response.body);
        print("[Stops] parsed ${parsed.length} stops for ${provider.name}");
        return parsed;
      }
      print("Error fetching stops for ${provider.name}: HTTP ${response.statusCode} - ${response.body.substring(0, response.body.length.clamp(0, 200))}");
      return [];
    } catch (e) {
      print("Error fetching stops for ${provider.name}: $e");
      return [];
    }
  }

  static List<BariStop> _parseBariStops(String responseBody) {
    // Tollerante a payload inattesi (es. "null", oggetti errore o wrapper):
    // mai crashare, al massimo restituire lista vuota con diagnostica.
    dynamic decoded;
    try {
      decoded = json.decode(responseBody);
    } catch (e) {
      print("Error parsing stops JSON: $e - head: ${responseBody.substring(0, responseBody.length.clamp(0, 200))}");
      return [];
    }
    final List<dynamic> data;
    if (decoded is List) {
      data = decoded;
    } else if (decoded is Map && decoded['stops'] is List) {
      data = decoded['stops'];
    } else {
      print("Unexpected stops payload (not a list): ${responseBody.substring(0, responseBody.length.clamp(0, 200))}");
      return [];
    }
    final stops = <BariStop>[];
    for (final e in data) {
      try {
        if (e is Map) stops.add(BariStop.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        // salta singole voci malformate senza buttare tutta la lista
      }
    }
    return stops;
  }

  Future<List<BariStop>> fetchBariStops() async {
    final provider = BusProviderConfig(
      name: 'bari',
      provider: 'amtab',
      endpoints: {'stops': true},
    );
    return fetchStops(provider);
  }

  Future<List<BariRouteSolution>> fetchBariSolutions({
    required String fromStopId,
    required String toStopId,
    DateTime? departureTime,
  }) async {
    try {
      final stops = await fetchBariStops();
      final fromStop = stops.where((s) => s.stopId == fromStopId).firstOrNull;
      final toStop = stops.where((s) => s.stopId == toStopId).firstOrNull;

      if (fromStop == null || toStop == null) {
        throw Exception('Fermate non trovate');
      }

      final departureMs = (departureTime ?? DateTime.now()).millisecondsSinceEpoch;

      final body = {
        "action": "FindTPSolutions",
        "PuntoOrigine": {
          "Formato": 0,
          "Lat": fromStop.latitude,
          "Lng": fromStop.longitude
        },
        "PuntoDestinazione": {
          "Formato": 0,
          "Lat": toStop.latitude,
          "Lng": toStop.longitude
        },
        "DataPartenza": "/Date(${departureMs}+0100)/",
        "OraDa": "/Date(${departureMs}+0100)/",
        "NumMaxSoluzioni": 8,
        "NumeroAdulti": 1,
        "NumeroRagazzi": 0,
        "FiltroModalita": [0, 2, 1, 3, 15],
        "Ambiente": {"Ambiti": [0, 1, 2]},
        "TipoPercorso": 0,
        "Intermodale": false,
        "ActivateRunsOnNextDay": true
      };

      final bariCountry = await _countryForProviderName('bari');
      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/$bariCountry/bus/bari/solutions"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final oggetti = data['Oggetti'] ?? [];
        final solutions = oggetti.map((s) => BariRouteSolution.fromJson(s)).toList();

        // Filter only AMTAB solutions
        return solutions.where((sol) =>
          sol.legs.any((leg) => leg.operator == 'AMTAB')
        ).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching Bari solutions: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchBariSolutionDetail(String solutionId) async {
    try {
      final body = {
        "action": "GetTPSolutionDetail",
        "IdSoluzione": solutionId
      };

      final bariCountry = await _countryForProviderName('bari');
      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/$bariCountry/bus/bari/solutions"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print("Error fetching Bari solution detail: $e");
      return null;
    }
  }

  /// Dettaglio corsa via endpoint realtime generico, valido per tutti i provider:
  /// `GET /api/{country}/bus/{provider}/realtime?vehicleId={id}&tripId={trip}&vehicles=true`.
  /// Restituisce destinazione + fermate oppure null se non disponibili.
  Future<BusRealtimeTrip?> fetchRealtimeVehicleTrip({
    required String providerName,
    required String vehicleId,
    required String tripId,
  }) async {
    try {
      if (vehicleId.isEmpty || vehicleId == '?' || tripId.isEmpty) return null;
      final country = await _countryForProviderName(providerName);
      final url = "${ApiConstants.baseUrl}/api/$country/bus/$providerName/realtime"
          "?vehicleId=${Uri.encodeComponent(vehicleId)}"
          "&tripId=${Uri.encodeComponent(tripId)}"
          "&vehicles=true";
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json is Map<String, dynamic>) {
          final trip = BusRealtimeTrip.fromJson(json);
          if (trip.stops.isNotEmpty) return trip;
        }
      }
      return null;
    } catch (e) {
      print("Error fetching realtime vehicle trip: $e");
      return null;
    }
  }

  Future<List<BusTripUpdate>> fetchBariTripUpdates(String vehicleId, String routeId, {String? tripId}) async {
    try {
      // Endpoint realtime generico: vehicleId + tripId (+ vehicles=true).
      // Fallback legacy con routeId se il tripId non è disponibile.
      final bariCountry = await _countryForProviderName('bari');
      final realtimeResponse = await http.get(Uri.parse(
        (tripId != null && tripId.isNotEmpty)
            ? "${ApiConstants.baseUrl}/api/$bariCountry/bus/bari/realtime?vehicleId=$vehicleId&tripId=$tripId&vehicles=true"
            : "${ApiConstants.baseUrl}/api/$bariCountry/bus/bari/realtime?vehicleId=$vehicleId&routeId=$routeId",
      ));
      if (realtimeResponse.statusCode == 200) {
        final json = jsonDecode(realtimeResponse.body);
        final vehicles = json['vehicles'] as List?;
        if (vehicles != null && vehicles.isNotEmpty) {
          final vehicle = vehicles.first;
          final stopsRaw = vehicle['stops'];
          final stops = stopsRaw is List ? List<dynamic>.from(stopsRaw) : null;
          final posRaw = vehicle['position'];
          final position = posRaw is Map ? Map<String, dynamic>.from(posRaw) : null;
          
          if (stops != null) {
            // Fetch stops coordinates for arrival estimation
            final bariStops = await fetchBariStops();
            final stopsGeoMap = {for (final stop in bariStops) stop.stopId: stop};
            
            // Calculate arrival estimates
            final busLat = position?['lat']?.toDouble() ?? 0.0;
            final busLng = position?['lng']?.toDouble() ?? 0.0;
            final busSpeed = position?['speed']?.toDouble() ?? 0.0;
            
            final updatesWithEstimates = stops.map((s) {
              final update = BusTripUpdate.fromJson(s);
              
              // Calculate arrival estimate only for current and future stops
              String? estimate;
              if (update.status != 'passed') {
                if (busLat != 0.0 && busLng != 0.0) {
                  final stopGeo = stopsGeoMap[update.stopId];
                  if (stopGeo != null) {
                    estimate = _calculateArrivalEstimate(
                      busLat, busLng, stopGeo.latitude, stopGeo.longitude, busSpeed
                    );
                  }
                }
              }
              
              return BusTripUpdate(
                stopId: update.stopId,
                stopName: update.stopName,
                expectedTime: update.expectedTime,
                delay: update.delay,
                isRealtime: update.isRealtime,
                status: update.status,
                arrivalEstimate: estimate,
              );
            }).toList();
            
            return updatesWithEstimates;
          }
        }
      }
      return [];
    } catch (e) {
      print("Error fetching Bari trip updates: $e");
      return [];
    }
  }
  
  Future<BusRoutePath?> fetchBusRoutePath(String tripId, {String? providerName}) async {
    try {
      final prov = providerName ?? 'bari';
      final country = await _countryForProviderName(prov);
      final url = "${ApiConstants.baseUrl}/api/$country/bus/$prov/route-path?tripId=$tripId";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return BusRoutePath.fromJson(json);
      } else {
        print("Error fetching bus route path: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching bus route path: $e");
      return null;
    }
  }

  /// Fetch departures for a stop.  If [offline] is true the server will
  /// serve data from its in‑memory JSON and not query the database.
  Future<List<StopDeparture>> fetchStopUpdates(
      String provider, String stopId) async {
    try {
        final country = await _countryForProviderName(provider);
        final url = "${ApiConstants.baseUrl}/api/$country/bus/$provider/stops-updates?stopId=$stopId";
      print('Fetching stop updates from: $url');
      final response = await http.get(Uri.parse(url));
      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List departures = json['departures'] ?? [];
        print('Parsed ${departures.length} departures from JSON');
        // Ensure any stops arrays are passed as well
        final result = departures.map((d) {
          final map = Map<String, dynamic>.from(d as Map);
          // if stops is present but not a List<Map>, normalize it
          if (map['stops'] is List) {
            map['stops'] = (map['stops'] as List).map((s) => s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{}).toList();
          }
          return StopDeparture.fromJson(map);
        }).toList();
        print('Mapped to ${result.length} StopDeparture objects');
        return result;
      }
      print('Request failed with status ${response.statusCode}: ${response.body}');
      return [];
    } catch (e) {
      print("Error fetching Bari stop updates: $e");
      return [];
    }
  }

  Future<TripStopsData?> fetchTripStops(String tripId, {String? providerName}) async {
    try {
      // Default to 'bari' when provider is not specified to preserve
      // backward compatibility. Callers may pass the selected provider
      // name to fetch provider-specific trip stops.
      final prov = providerName ?? 'bari';
      final country = await _countryForProviderName(prov);
      final url = "${ApiConstants.baseUrl}/api/$country/bus/$prov/trip-stops?tripId=$tripId";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return TripStopsData.fromJson(json);
      } else {
        print("Error fetching trip stops: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error fetching trip stops: $e");
      return null;
    }
  }

  /// Fetch trip stops by calling the provider realtime endpoint.
  /// Endpoint generico valido per tutti i provider:
  /// `GET /api/{country}/bus/{provider}/realtime?vehicleId={id}&tripId={trip}&vehicles=true`.
  /// Se [vehicleId] non è disponibile si usa il fallback legacy `routeId` + `tripId`.
  /// Returns a `TripStopsData` constructed from the realtime response when available.
  Future<TripStopsData?> fetchRealtimeTripStops(String routeId, String tripId, {String? providerName, String? vehicleId}) async {
    try {
      final prov = providerName ?? 'bari';
      final country = await _countryForProviderName(prov);
      final hasVehicle = vehicleId != null && vehicleId.isNotEmpty && vehicleId != '?';
      final url = hasVehicle
          ? "${ApiConstants.baseUrl}/api/$country/bus/$prov/realtime?vehicleId=${Uri.encodeComponent(vehicleId!)}&tripId=${Uri.encodeComponent(tripId)}&vehicles=true"
          : "${ApiConstants.baseUrl}/api/$country/bus/$prov/realtime?routeId=${Uri.encodeComponent(routeId)}&tripId=${Uri.encodeComponent(tripId)}";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);

        // Helper to convert arbitrary Map<dynamic,dynamic> into Map<String,dynamic>
        Map<String, dynamic> _toStringMap(dynamic maybeMap) {
          if (maybeMap == null) return <String, dynamic>{};
          if (maybeMap is Map<String, dynamic>) return maybeMap;
          if (maybeMap is Map) {
            final out = <String, dynamic>{};
            maybeMap.forEach((k, v) {
              out[k.toString()] = v;
            });
            return out;
          }
          return <String, dynamic>{};
        }

        // The realtime payload may include an array `vehicles` with the matching trip
        final vehiclesRaw = json['vehicles'];
        final vehicles = vehiclesRaw is List ? vehiclesRaw : (vehiclesRaw != null ? [vehiclesRaw] : null);

        final Map<String, dynamic> vehicleJson = {};
        List<dynamic> stopsJson = [];

        if (vehicles != null && vehicles.isNotEmpty) {
          final v = vehicles.first;
          final pos = v['position'] ?? v['vehicle'] ?? v;
          final stopsCandidate = v['stops'] ?? json['stops'];
          final convertedPos = _toStringMap(pos);
          vehicleJson.addAll(convertedPos);
          if (stopsCandidate is List) stopsJson = List<dynamic>.from(stopsCandidate);
        } else if (json['vehicle'] != null) {
          vehicleJson.addAll(_toStringMap(json['vehicle']));
          final s = json['stops'];
          if (s is List) stopsJson = List<dynamic>.from(s);
        } else if (json['stops'] != null) {
          final s = json['stops'];
          if (s is List) stopsJson = List<dynamic>.from(s);
        }

        // ensure each stop entry is a Map<String,dynamic> to appease
        // TripStop.fromJson's parameter type
        final cleanStops = stopsJson.map((s) {
          if (s is Map) return Map<String, dynamic>.from(s);
          return <String, dynamic>{};
        }).toList();

        final Map<String, dynamic> assembled = <String, dynamic>{
          'tripId': tripId,
          'vehicle': vehicleJson,
          'filter': <String, dynamic>{},
          'stops': cleanStops,
        };

        try {
          return TripStopsData.fromJson(assembled);
        } catch (parseError, stack) {
          print('Failed parsing realtime trip stops assembled JSON: $assembled');
          print(parseError);
          print(stack);
          rethrow;
        }
      }

      print("Realtime trip stops request failed: ${response.statusCode} - ${response.body}");
      return null;
    } catch (e) {
      print("Error fetching realtime trip stops: $e");
      return null;
    }
  }

  Future<String?> fetchBariVehicleDestination(String vehicleId, String routeId) async {
    try {
      final bariCountry = await _countryForProviderName('bari');
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/$bariCountry/bus/bari/realtime?vehicleId=$vehicleId&routeId=$routeId"));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final vehicles = json['vehicles'] as List?;
        if (vehicles != null && vehicles.isNotEmpty) {
          final vehicle = vehicles.first;
          return vehicle['destination']?.toString();
        }
      }
      return null;
    } catch (e) {
      print("Error fetching Bari vehicle destination: $e");
      return null;
    }
  }

  Future<List<BusProviderConfig>> fetchBusProviders() async {
    if (_cachedProviders != null) return _cachedProviders!;
    try {
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/config/bus_providers.json"));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List providers = json['providers'] ?? [];
        _cachedProviders = providers.map((p) => BusProviderConfig.fromJson(p)).toList();
        return _cachedProviders!;
      }
      return [];
    } catch (e) {
      print("Error fetching bus providers: $e");
      return [];
    }
  }

  /// Retrieves the full static JSON package for a provider.
  ///
  /// The server returns the same object that is held in its in-memory
  /// `providersCache` and which is normally used to answer realtime and
  /// stops‑updates queries.  Clients use this to pre‑download all of a
  /// provider's data for offline mode.
  /// Retrieves the full static JSON package for a provider.
  ///
  /// An optional [onProgress] callback receives values between 0.0 and 1.0
  /// indicating the fraction of bytes downloaded.  The download is performed
  /// using a streamed request so the UI can display a progress indicator.
  Future<Map<String, dynamic>?> fetchStaticProviderData(String providerName,
      {void Function(double progress)? onProgress}) async {
    try {
      final country = await _countryForProviderName(providerName);
      final url = "${ApiConstants.baseUrl}/api/$country/bus/$providerName/stops-updates?static=true";
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final streamed = await client.send(request);

      if (streamed.statusCode == 200) {
        final contentLength = streamed.contentLength ?? 0;
        final bytes = <int>[];
        int received = 0;

        await for (var chunk in streamed.stream) {
          bytes.addAll(chunk);
          received += chunk.length;
          if (onProgress != null) {
            if (contentLength > 0) {
              onProgress(received / contentLength);
            } else {
              // unknown length: estimate growth based on received size to
              // give a fluid, non‑stuck experience. cap at 98% until end.
              final estimate = (received / 200000.0).clamp(0.0, 0.98);
              onProgress(estimate);
            }
          }
        }

        // always notify completion
        if (onProgress != null) onProgress(1.0);

        final bodyStr = utf8.decode(bytes);
        return json.decode(bodyStr) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print("Error fetching static provider data for $providerName: $e");
      return null;
    }
  }
}

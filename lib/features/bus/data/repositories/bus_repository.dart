import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../../../../core/api_constants.dart';
import '../models/bus_model.dart';

class BusRepository {
  static const String flixbusBase = "https://prod.cuzimmartin.dev/api/flixbus";

  Future<List<BusVehicle>> fetchRomeVehicles() async {
    try {
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/rome-realtime"));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List entities = json['entities'] ?? [];
        return entities.map((e) => BusVehicle.fromRomeJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching Rome buses: $e");
      return [];
    }
  }

  Future<List<BusVehicle>> fetchBariVehicles() async {
    try {
      final url = "${ApiConstants.baseUrl}/api/it/bus/bari/bus-realtime";
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
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
        
        return rawList.map((e) => BusVehicle.fromBariJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching Bari buses: $e");
      return [];
    }
  }

  Future<List<BusVehicle>> fetchERVehicles() async {
    try {
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/it/bus/emilia-romagna/tper/realtime"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => BusVehicle.fromERJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching ER buses: $e");
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

  Future<List<BariStop>> fetchBariStops() async {
    try {
      final response = await http.get(Uri.parse("https://betacloud-transporter.is-cool.dev/api/it/bus/bari/stops"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((e) => BariStop.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching Bari stops: $e");
      return [];
    }
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

      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/it/bus/bari/solutions"),
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

      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/it/bus/bari/solutions"),
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

  Future<List<BusTripUpdate>> fetchBariTripUpdates(String vehicleId, String routeId) async {
    try {
      // Chiama l'endpoint realtime con vehicleId e routeId
      final realtimeResponse = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/it/bus/bari/realtime?vehicleId=$vehicleId&routeId=$routeId"));
      if (realtimeResponse.statusCode == 200) {
        final json = jsonDecode(realtimeResponse.body);
        final vehicles = json['vehicles'] as List?;
        if (vehicles != null && vehicles.isNotEmpty) {
          final vehicle = vehicles.first;
          final stops = vehicle['stops'] as List?;
          final position = vehicle['position'] as Map<String, dynamic>?;
          
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

  Future<BusRoutePath?> fetchBusRoutePath(String tripId) async {
    try {
      final url = "${ApiConstants.baseUrl}/api/it/bus/bari/route-path?tripId=$tripId";
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

  Future<List<StopDeparture>> fetchBariStopUpdates(String stopId) async {
    try {
      final url = "${ApiConstants.baseUrl}/api/it/bus/bari/stops-updates?stopId=$stopId";
      print('Fetching stop updates from: $url');
      final response = await http.get(Uri.parse(url));
      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List departures = json['departures'] ?? [];
        print('Parsed ${departures.length} departures from JSON');
        final result = departures.map((d) => StopDeparture.fromJson(d)).toList();
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

  Future<String?> fetchBariVehicleDestination(String vehicleId, String routeId) async {
    try {
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/it/bus/bari/realtime?vehicleId=$vehicleId&routeId=$routeId"));
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
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
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
      final url = "${ApiConstants.baseUrl}/api/bari-realtime";
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
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/tper-realtime"));
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
      final response = await http.get(Uri.parse("https://betacloud-transporter.is-cool.dev/api/bari/stops"));
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
        Uri.parse("${ApiConstants.baseUrl}/api/bus/bari-solutions"),
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
        Uri.parse("${ApiConstants.baseUrl}/api/bus/bari-solutions"),
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

  Future<List<StopDeparture>> fetchBariStopUpdates(String stopId) async {
    try {
      final response = await http.get(Uri.parse("${ApiConstants.baseUrl}/api/it/bus/bari/stops-updates?stopId=$stopId"));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List departures = json['departures'] ?? [];
        return departures.map((d) => StopDeparture.fromJson(d)).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching Bari stop updates: $e");
      return [];
    }
  }
}


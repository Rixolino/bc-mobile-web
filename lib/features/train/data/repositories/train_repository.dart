import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/api_constants.dart';
import '../models/train_model.dart';

class TrainRepository {
  static const String baseUrl = "https://prod.cuzimmartin.dev/api";
  static const String falBaseUrl = "https://fal.ferrovieappulolucane.it"; 
  
  // Fetch available train vector logos from our server
  // Returns { "FR": { "svg": "/path.svg", "png": "/path.png" }, ... }
  Future<Map<String, Map<String, String>>> fetchTrainLogos({String source = 'official'}) async {
    try {
      final url = "${ApiConstants.baseUrl}/api/train-logos";
      debugPrint('[LogoRepo] Fetching logos from: $url (source=$source)');
      final response = await http.get(Uri.parse(url));
      
      debugPrint('[LogoRepo] Status: ${response.statusCode}');
      debugPrint('[LogoRepo] Body (first 500): ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        debugPrint('[LogoRepo] Top keys: ${data.keys.toList()}');
        
        final Map<String, dynamic> sourceData = data[source] ?? data['official'] ?? {};
        debugPrint('[LogoRepo] Source="$source" → ${sourceData.length} entries');
        
        final Map<String, Map<String, String>> logos = {};
        sourceData.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final Map<String, String> paths = {};
            value.forEach((fmt, p) {
              if (p is String) {
                paths[fmt] = p.startsWith('http') ? p : "${ApiConstants.baseUrl}$p";
              }
            });
            if (paths.isNotEmpty) logos[key] = paths;
          } else {
            debugPrint('[LogoRepo] ⚠️ Key "$key" value is ${value.runtimeType}, expected Map');
          }
        });
        
        debugPrint('[LogoRepo] ✅ Parsed ${logos.length} logos: ${logos.keys.toList()}');
        if (logos.isNotEmpty) {
          final first = logos.entries.first;
          debugPrint('[LogoRepo] Sample: ${first.key} → ${first.value}');
        }
        return logos;
      } else {
        debugPrint('[LogoRepo] ❌ HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[LogoRepo] ❌ Error: $e');
    }
    return {};
  }

  // Save a trip snapshot on the server and get back a short share id
  Future<String?> shareTrip(Map<String, dynamic> payload) async {
    try {
      final url = "${ApiConstants.baseUrl}/api/share-trip";
      debugPrint('[ShareRepo] POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode(payload),
      );
      debugPrint('[ShareRepo] Status: ${response.statusCode}');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final shareId = data['shareId']?.toString();
        debugPrint('[ShareRepo] ✅ shareId=$shareId');
        return shareId;
      } else {
        debugPrint('[ShareRepo] ❌ ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      }
    } catch (e) {
      debugPrint('[ShareRepo] ❌ Error: $e');
    }
    return null;
  }

  // Fetch a shared trip snapshot and decode it into a TrainDeparture
  Future<TrainDeparture?> fetchSharedDeparture(String shareId) async {
    try {
      final url = "${ApiConstants.baseUrl}/api/share-trip/${Uri.encodeComponent(shareId)}";
      debugPrint('[ShareRepo] GET $url');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('[ShareRepo] ❌ HTTP ${response.statusCode}');
        return null;
      }
      final Map<String, dynamic> data = json.decode(response.body);

      DateTime? parseTime(dynamic t) =>
          t == null || t.toString().isEmpty ? null : DateTime.tryParse(t.toString());

      List<TrainStop>? stops;
      if (data['stops'] is List) {
        stops = (data['stops'] as List)
            .whereType<Map>()
            .map((s) => TrainStop.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      }

      return TrainDeparture(
        tripId: data['tripId']?.toString(),
        country: data['country']?.toString() ?? '',
        category: data['category']?.toString(),
        trainNumber: data['tripNumber']?.toString(),
        origin: data['origin']?.toString(),
        destination: data['destination']?.toString(),
        platform: data['platform']?.toString(),
        delayMinutes: data['delay'] is int
            ? data['delay'] as int
            : int.tryParse(data['delay']?.toString() ?? ''),
        scheduledTime: parseTime(data['scheduledTime']),
        estimatedTime: parseTime(data['estimatedTime']),
        stops: stops,
      );
    } catch (e) {
      debugPrint('[ShareRepo] ❌ fetchSharedDeparture: $e');
      return null;
    }
  }

  Future<List<TrainStation>> searchStations(String query, {String country = 'IT', String? city, String service = 'trainboardeu'}) async {
    // If service is Direct and country is IT, use local proxy/JSON logic
    if (service == 'direct' && country == 'IT') {
      final url = "${ApiConstants.baseUrl}/proxy/viaggiatreno?q=${Uri.encodeComponent(query)}";
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          // Viaggiatreno format from our proxy: [{ "nomestazione": "NAME", "codStazione": "ID" }]
          return data.map((e) => TrainStation(
            id: e['codStazione'].toString(), 
            name: e['nomestazione'].toString(),
            country: 'IT'
          )).toList();
        }
      } catch (e) {
        print("Direct IT search error: $e");
      }
    }

    // Default to Trainboard logic (even for direct other countries, it's our best source)
    String url;
    final String tbUrl = "https://prod.cuzimmartin.dev/api"; // Always use direct trainboard URL for TB service
    
    if (country == 'UK_LONDON') {
        url = "$tbUrl/gb/london/stations?query=${Uri.encodeComponent(query)}";
    } else if (country == 'FAL') {
        url = "$tbUrl/it/stations?query=${Uri.encodeComponent(query)}&limit=10";
    } else if (country == 'GLOBAL') {
        url = "$tbUrl/global/stations?query=${Uri.encodeComponent(query)}";
    } else {
        // include city segment if provided
        if (city != null && city.isNotEmpty) {
            url = "$tbUrl/$country/$city/stations?query=${Uri.encodeComponent(query)}&limit=10";
        } else {
            url = "$tbUrl/$country/stations?query=${Uri.encodeComponent(query)}&limit=10";
        }
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);
        final List<dynamic> data = (jsonResponse is Map && jsonResponse.containsKey('data')) 
            ? jsonResponse['data'] 
            : (jsonResponse is List ? jsonResponse : []);
            
        return data.map((e) {
          if (e is Map<String, dynamic>) e['country'] = country; 
          return TrainStation.fromJson(e);
        }).toList();
      }
      return [];
    } catch (e) {
      print("Error searching stations: $e");
      return [];
    }
  }

  Future<List<TrainDeparture>> fetchDepartures(String stationId, {String country = 'IT', String service = 'trainboardeu', bool isArrival = false}) async {
    if (country == 'FAL') return fetchFALDepartures(stationId);

    String url;
    final String tbUrl = "https://prod.cuzimmartin.dev/api";

    if (service == 'direct' && country == 'IT') {
       // Direct Italy uses our server proxy to RFI
       final endpoint = isArrival ? "rfi-arrivals" : "rfi-departures";
       url = "${ApiConstants.baseUrl}/api/$endpoint?placeId=$stationId";
    } else {
       final endpoint = isArrival ? "arrivals" : "departures";
       if (country == 'UK_LONDON') {
           url = "$tbUrl/gb/london/$endpoint?stationId=$stationId";
       } else if (country == 'GLOBAL') {
           url = "$tbUrl/global/$endpoint?stationId=$stationId";
       } else {
           url = "$tbUrl/$country/$endpoint?stationId=$stationId";
       }
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dynamic jsonResponse = json.decode(response.body);
        final List<dynamic> data = (jsonResponse is Map && jsonResponse.containsKey('data')) 
            ? jsonResponse['data'] 
            : (jsonResponse is List ? jsonResponse : []);
            
        return data.map((e) => TrainDeparture.fromJson(e, isDeparture: !isArrival)).toList();
      }
      return [];
    } catch (e) {
       print("Error fetching departures: $e");
       return [];
    }
  }

  Future<TrainDeparture?> fetchTrainDetails(String trainNumber, String stationId, {String country = 'IT', String service = 'trainboardeu'}) async {
    String url;
    final String tbUrl = "https://prod.cuzimmartin.dev/api";

    if (service == 'direct' && country == 'IT') {
      url = "${ApiConstants.baseUrl}/api/rfi-train/$trainNumber";
    } else {
      url = "$tbUrl/$country/details?trainNumber=$trainNumber&stationId=$stationId";
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        return TrainDeparture.fromJson(data);
      } else {
        throw Exception("Fetch Train Details Failed: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching train details: $e");
      rethrow;
    }
    return null;
  }

  Future<TrainDeparture?> fetchTrip(String tripId, {String country = 'IT', String service = 'trainboardeu'}) async {
    // The new logic requires tripId NOT to be encoded if it's already properly formatted or if the server expects raw
    // However, usually parameters should be encoded. 
    // The user says: https://prod.cuzimmartin.dev/api/{country}/trip?tripId=[trip]
    
    String url;
    final String tbUrl = "https://prod.cuzimmartin.dev/api";

    if (service == 'direct' && country == 'IT') {
      // For RFI direct, tripId might be different or we need separate structure
      url = "${ApiConstants.baseUrl}/api/rfi-train-progress?trainNumber=$tripId"; // Fallback placeholder
    } else {
       // Using raw tripId as per user request (sometimes double encoding breaks things)
       // If the tripId contains special chars like '/', they are usually delimiters in some APIs but here it is a query param
       // Let's try to encode it because it's a query param.
       final encodedTripId = Uri.encodeComponent(tripId);
       if (country == 'GLOBAL') {
           url = "$tbUrl/global/trip?tripId=$encodedTripId";
       } else {
           url = "$tbUrl/$country/trip?tripId=$encodedTripId";
       }
    }

    print("Fetching Trip URL: $url"); // Debug log

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        // Sometimes the response IS the object, sometimes it's wrapped in 'data'
        // Check both
        dynamic tripData;
        if (data is Map) {
             if (data.containsKey('data')) {
                 tripData = data['data'];
             } else {
                 tripData = data;
             }
        } else {
             tripData = data;
        }
        
        // Ensure tripData is a Map before parsing
        if (tripData is Map<String, dynamic>) {
            return TrainDeparture.fromJson(tripData);
        }
      } else {
         print("Fetch Trip Failed: ${response.statusCode} | ${response.body}");
         throw Exception("Fetch Trip Failed: ${response.statusCode} | ${response.body}");
      }
    } catch (e) {
      print("Error fetching trip details: $e");
      rethrow;
    }
    return null;
  }

  Future<List<TrainDeparture>> fetchFALDepartures(String stationId) async {
    final url = "${ApiConstants.baseUrl}/api/fal/stop-updates?stationId=$stationId";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dynamic jsonObject = json.decode(response.body);
        
        // L'API FAL restituisce una mappa dove le chiavi sono i nomi delle destinazioni
        // e i valori sono liste di fermate (trip + stopInfo).
        if (jsonObject is Map && jsonObject.containsKey('grouped')) {
           final Map<String, dynamic> grouped = jsonObject['grouped'];
           List<TrainDeparture> departures = [];
           
           grouped.forEach((dest, list) {
             if (list is List) {
               for (var item in list) {
                 final trip = item['trip'] ?? {};
                 final stop = item['stopInfo'] ?? {};
                 departures.add(TrainDeparture(
                   trainNumber: trip['LineCode'] ?? trip['id_documento']?.toString(),
                   category: trip['type'] == 'bus' ? 'FAL (BUS)' : 'FAL',
                   destination: dest,
                   scheduledTime: DateTime.tryParse(stop['expected_passing_date'] ?? ''),
                   estimatedTime: (stop['passing_date'] != null && stop['passing_date'] != 'null') ? DateTime.tryParse(stop['passing_date']) : null,
                   status: (stop['ritardo'] != null && stop['ritardo'] != 0) ? "${stop['ritardo']}'" : 'In orario',
                   delayMinutes: stop['ritardo'] is int ? stop['ritardo'] : 0,
                 ));
               }
             }
           });
           
           // Ordina per orario
           departures.sort((a, b) => (a.scheduledTime ?? DateTime.now()).compareTo(b.scheduledTime ?? DateTime.now()));
           return departures;
        }
        return [];
      }
      return [];
    } catch (e) {
      print("Error fetching FAL departures: $e");
      return [];
    }
  }

  Future<List<dynamic>> searchTrainByNumber(String query) async {
    final url = "https://data.cuzimmartin.dev/train-map?north=85&south=-5&east=91&west=-64&duration=300&results=1000&polylines=false";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> movements = data['movements'] ?? [];
        
        final searchTerm = query.toLowerCase();
        return movements.where((m) {
          final name = (m['line']?['name'] ?? '').toString().toLowerCase();
          final id = (m['line']?['id'] ?? '').toString().toLowerCase();
          return name.contains(searchTerm) || id.contains(searchTerm);
        }).toList();
      }
      return [];
    } catch (e) {
      print("Error searching train by number: $e");
      return [];
    }
  }
}


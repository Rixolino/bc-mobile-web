import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/api_constants.dart';
import '../models/plane_model.dart';

class PlaneRepository {
  static const String skyscannerBase = "https://www.skyscanner.it/g";
  // Use the public proxy for airport arrival/departure data (set by server)
  static const String skyscannerProxyBase = "https://betacloud-transporter.is-cool.dev/proxy/skyscanner/airport";

  Future<List<Airport>> searchAirports(String query) async {
    if (query.length < 2) return [];

    final url = "$skyscannerBase/autosuggest-search/api/v1/search-flight/IT/it-IT/${Uri.encodeComponent(query)}?isDestination=true&autosuggestExp=";
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .where((item) => item['PlaceId'] != null && item['PlaceId'].length == 3)
            .map((e) => Airport.fromJson(e))
            .toList();
      }
      return [];
    } catch (e) {
      print("Error searching airports: $e");
      return [];
    }
  }

  Future<List<Flight>> fetchAirportFlights(String iata, {bool isArrival = false}) async {
    final type = isArrival ? 'arrivals' : 'departures';
    // Prefer proxy endpoint to avoid direct requests to Skyscanner from the mobile app
    final url = "$skyscannerProxyBase/${Uri.encodeComponent(iata)}/$type";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> flights = data[type] ?? [];
        return flights.map((e) => Flight.fromSkyscanner(e, isArrival ? 'arrival' : 'departure')).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching airport flights: $e");
      return [];
    }
  }

  Future<List<Flight>> fetchFlights(double north, double south, double west, double east) async {
    try {
      final url = "${ApiConstants.baseUrl}/api/flightradar?bounds=$north,$south,$west,$east";
      print("Fetching flights from: $url");
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonData = jsonDecode(response.body);
        print("Flights API success: found ${jsonData['fetched']} flights");
        List<Flight> flights = [];
        
        // Handle new proxy format: { flights: [...] }
        if (jsonData.containsKey('flights') && jsonData['flights'] is List) {
          final List<dynamic> flightsList = jsonData['flights'];
          for (var item in flightsList) {
            if (item is Map<String, dynamic>) {
              flights.add(Flight.fromFlightRadar(item));
            }
          }
        } 
        // Handle old/alternative format: { "id": [data], ... }
        else {
          jsonData.forEach((key, value) {
            if (value is List && value.length >= 13) {
              flights.add(Flight(
                id: key,
                flightNumber: (value.length > 13 ? value[13] : key) ?? '',
                callsign: (value.length > 16 ? value[16] : (value.length > 13 ? value[13] : 'UNK')) ?? 'UNK',
                airline: (value.length > 17 ? value[17] : '') ?? '',
                origin: (value.length > 11 ? value[11] : '') ?? '',
                destination: (value.length > 12 ? value[12] : '') ?? '',
                latitude: (value[1] ?? 0).toDouble(),
                longitude: (value[2] ?? 0).toDouble(),
                heading: (value[3] ?? 0).toDouble(),
                altitude: (value[4] ?? 0).toDouble(),
                speed: (value[5] ?? 0).toDouble(),
              ));
            } else if (value is Map<String, dynamic>) {
                 flights.add(Flight.fromFlightRadar(value));
            }
          });
        }
        
        return flights;
      }
      return [];
    } catch (e) {
      print("Error fetching flights: $e");
      return [];
    }
  }
}


import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/api_constants.dart';
import '../models/transport_config_model.dart';
import '../models/train_stats_model.dart';

class ApiService {
  static const int _maxRetries = 3;
  static const Duration _requestTimeout = Duration(seconds: 15);

  Future<TransportConfig> fetchConfig() async {
    int retryCount = 0;
    
    while (retryCount < _maxRetries) {
      try {
        print("Fetching config (attempt ${retryCount + 1}/$_maxRetries)...");
        final response = await http
            .get(Uri.parse(ApiConstants.configEndpoint))
            .timeout(_requestTimeout, onTimeout: () {
          throw TimeoutException('Config endpoint timeout after ${_requestTimeout.inSeconds}s');
        });
        
        if (response.statusCode == 200) {
          print("Config fetched successfully");
          return TransportConfig.fromJson(json.decode(response.body));
        } else {
          throw Exception('Failed to load configuration: ${response.statusCode}');
        }
      } catch (e) {
        retryCount++;
        print("Error fetching config (attempt $retryCount/$_maxRetries): $e");
        
        if (retryCount >= _maxRetries) {
          print("Max retries reached, using default config");
          // Fallback config in case of error - sempre ritorna qualcosa di valido
          return _getDefaultConfig();
        }
        
        // Wait before retrying (exponential backoff)
        await Future.delayed(Duration(seconds: retryCount));
      }
    }
    
    return _getDefaultConfig();
  }

  TransportConfig _getDefaultConfig() {
    return TransportConfig(
      transports: [
        TransportSource(
          id: 'default_train',
          name: 'Trainboard',
          type: 'train',
          scope: 'international',
          icon: 'train',
          endpoints: {'stations': ApiConstants.defaultTrainEndpoint},
        ),
        TransportSource(
          id: 'default_bus',
          name: 'AMTAB Bari',
          type: 'bus',
          scope: 'urban',
          icon: 'bus',
          endpoints: {'realtime': ApiConstants.defaultAmtabEndpoint},
        ),
        TransportSource(
          id: 'default_plane',
          name: 'FlightRadar',
          type: 'plane',
          scope: 'global',
          icon: 'plane',
          endpoints: {'realtime': ApiConstants.defaultFlightRadarEndpoint},
        ),
      ],
      systemEndpoints: {},
    );
  }

  // Generic fetch for other endpoints
  Future<dynamic> fetchData(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Request timeout'),
    );
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load data from $url');
    }
  }

  Future<TrainGeneralStats> fetchTrainGeneralStats() async {
    final data = await fetchData('${ApiConstants.baseUrl}/api/stats/trains/general');
    if (data is Map && data['ok'] == true) {
      return TrainGeneralStats.fromJson(data['data']);
    }
    throw Exception('Failed to fetch general train stats');
  }

  Future<List<TrainGeneralStats>> fetchTrainLineStats() async {
    final data = await fetchData('${ApiConstants.baseUrl}/api/stats/trains/lines');
    if (data is Map && data['ok'] == true) {
      final List<dynamic> statsList = data['data'];
      return statsList.map((item) => TrainGeneralStats.fromJson(item)).toList();
    }
    throw Exception('Failed to fetch train line stats');
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}


import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/roadway_model.dart';
import '../models/roadway_news_model.dart';
import '../models/roadway_toll_model.dart';
import '../models/roadway_service_model.dart';

class RoadwayService {
  final String baseUrl = 'https://viabilita.autostrade.it/json';

  Future<List<RoadwayNews>> fetchItalyRealTimeNews() async {
    final response = await http.get(Uri.parse('$baseUrl/ultimora.json'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((data) => RoadwayNews.fromJson(data)).toList();
    } else {
      throw Exception('Failed to load real-time news');
    }
  }

  Future<List<RoadwayToll>> fetchItalyTolls() async {
    final response = await http.get(Uri.parse('$baseUrl/tariffe.json'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> companies = data['tariffeUnitarieSocieta'] ?? [];
      
      List<RoadwayToll> allTolls = [];
      for (var company in companies) {
        final String name = company['nome'] ?? '';
        final List<dynamic> classes = company['classi'] ?? [];
        for (var cls in classes) {
          allTolls.add(RoadwayToll(
            companyName: name,
            category: cls['tDesCla'] ?? '',
            rate: (cls['tarP'] as num?)?.toDouble() ?? 0.0,
          ));
        }
      }
      return allTolls;
    } else {
      throw Exception('Failed to load tolls');
    }
  }

  Future<List<RoadwayModel>> fetchRoadways() async {
    // This remains as a generic fallback or for other countries
    final response = await http.get(Uri.parse('$baseUrl/topNews.json'));
    if (response.statusCode == 200) {
      return []; // The topNews.json currently returns empty events
    } else {
      throw Exception('Failed to load roadways');
    }
  }

  Future<List<RoadwayAreaService>> fetchAreaServices() async {
    final response = await http.get(Uri.parse('$baseUrl/adss.json'));

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> adss = data['adss'] ?? [];
      return adss.map((item) => RoadwayAreaService.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load area services');
    }
  }
}

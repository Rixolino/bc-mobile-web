import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/roadway_news_model.dart';
import '../models/roadway_toll_model.dart';
import '../models/roadway_service_model.dart';

class RoadwayService {
  /// Backend unificato IT + DE
  static const String baseUrl = 'https://betacloud-transporter.is-cool.dev';

  /// Paese corrente: 'it' | 'de'
  String country;

  RoadwayService({this.country = 'it'});

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await http.get(_uri(path, query));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} su $path');
    }
    final decoded = json.decode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Risposta non valida da $path');
    }
    return decoded;
  }

  // ---------------------------------------------------------------------------
  // NEWS
  // ---------------------------------------------------------------------------

  Future<List<RoadwayNews>> fetchNews({String? highways}) async {
    final query = <String, String>{};
    if (highways != null && highways.isNotEmpty) {
      query['highways'] = highways;
    }

    final body = await _getJson(
      '/api/roadways/$country/news',
      query.isEmpty ? null : query,
    );
    final List data = body['data'] as List? ?? [];
    return data
        .map((e) => RoadwayNews.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Compatibilità con il nome usato dalla pagina precedente
  Future<List<RoadwayNews>> fetchItalyRealTimeNews() => fetchNews();

  // ---------------------------------------------------------------------------
  // TOLLS / CASELLI
  // ---------------------------------------------------------------------------

  /// Ritorna caselli (IT) oppure lista vuota + nota (DE).
  Future<({List<RoadwayToll> tolls, String? note})> fetchTolls() async {
    final body = await _getJson('/api/roadways/$country/tolls');
    final List data = body['data'] as List? ?? [];
    final note = body['note']?.toString();
    final tolls = data
        .map((e) => RoadwayToll.fromJson(e as Map<String, dynamic>))
        .toList();
    return (tolls: tolls, note: note);
  }

  /// Compatibilità: solo la lista (senza nota)
  Future<List<RoadwayToll>> fetchItalyTolls() async {
    final result = await fetchTolls();
    return result.tolls;
  }

  /// Stub legacy – non più usato (lista autostrade non esposta dal backend).
  Future<List<dynamic>> fetchRoadways() async {
    return [];
  }

  // ---------------------------------------------------------------------------
  // AREE DI SERVIZIO / RASTANLAGEN
  // ---------------------------------------------------------------------------

  Future<List<RoadwayAreaService>> fetchAreaServices({
    String? highway,
    String? highways,
  }) async {
    final path = highway != null && highway.isNotEmpty
        ? '/api/roadways/$country/services/${highway.toUpperCase()}'
        : '/api/roadways/$country/services';

    final query = <String, String>{};
    if (highways != null && highways.isNotEmpty) {
      query['highways'] = highways;
    }

    final body = await _getJson(path, query.isEmpty ? null : query);
    final List data = body['data'] as List? ?? [];
    return data
        .map((e) => RoadwayAreaService.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
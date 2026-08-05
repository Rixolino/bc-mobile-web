import '../services/roadway_service.dart';
import '../models/roadway_model.dart';
import '../models/roadway_news_model.dart';
import '../models/roadway_toll_model.dart';
import '../models/roadway_service_model.dart';

class RoadwayRepository {
  final RoadwayService _service;

  RoadwayRepository(this._service);

  /// Imposta il paese ('it' | 'de') usato da tutte le chiamate successive.
  set country(String value) => _service.country = value;
  String get country => _service.country;

  Future<List<RoadwayNews>> getNews({String? highways}) {
    return _service.fetchNews(highways: highways);
  }

  /// Compatibilità col nome precedente
  Future<List<RoadwayNews>> getItalyRealTimeNews() {
    return _service.fetchNews();
  }

  Future<({List<RoadwayToll> tolls, String? note})> getTolls() {
    return _service.fetchTolls();
  }

  /// Compatibilità: solo la lista caselli
  Future<List<RoadwayToll>> getItalyTolls() async {
    final result = await _service.fetchTolls();
    return result.tolls;
  }

  Future<List<RoadwayAreaService>> getAreaServices({
    String? highway,
    String? highways,
  }) {
    return _service.fetchAreaServices(highway: highway, highways: highways);
  }

  /// Stub legacy – non più popolato dal backend unificato.
  Future<List<RoadwayModel>> getRoadways() async {
    return [];
  }
}
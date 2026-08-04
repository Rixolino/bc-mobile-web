import '../services/roadway_service.dart';
import '../models/roadway_model.dart';
import '../models/roadway_news_model.dart';
import '../models/roadway_toll_model.dart';

class RoadwayRepository {
  final RoadwayService _service;

  RoadwayRepository(this._service);

  Future<List<RoadwayNews>> getItalyRealTimeNews() {
    return _service.fetchItalyRealTimeNews();
  }

  Future<List<RoadwayToll>> getItalyTolls() {
    return _service.fetchItalyTolls();
  }

  Future<List<RoadwayModel>> getRoadways() {
    return _service.fetchRoadways();
  }
}

import 'favorite_stop.dart';
import 'favorite_train.dart';
import 'favorite_bus_line.dart';

enum FavoriteType {
  stop, // Fermate bus/stazioni/aeroporti
  train, // Treni
  busLine, // Linee bus
}

abstract class FavoriteItem {
  final String id;
  final FavoriteType type;
  final DateTime addedAt;
  final String userId;

  const FavoriteItem({
    required this.id,
    required this.type,
    required this.addedAt,
    required this.userId,
  });

  Map<String, dynamic> toJson();

  static FavoriteItem fromJson(Map<String, dynamic> json) {
    final type = FavoriteType.values.firstWhere((e) => e.name == json['type']);
    switch (type) {
      case FavoriteType.stop:
        return FavoriteStop.fromJson(json);
      case FavoriteType.train:
        return FavoriteTrain.fromJson(json);
      case FavoriteType.busLine:
        return FavoriteBusLine.fromJson(json);
    }
  }
}
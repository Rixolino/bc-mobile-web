import 'favorite_item.dart';

enum StopType {
  busStop, // Fermata bus
  trainStation, // Stazione treno
  airport, // Aeroporto
}

class FavoriteStop extends FavoriteItem {
  final String name;
  final String code;
  final StopType stopType;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? region;
  final String? provider; // Per identificare il provider (es. "tper", "fal", ecc.)

  const FavoriteStop({
    required super.id,
    required super.addedAt,
    required super.userId,
    required this.name,
    required this.code,
    required this.stopType,
    this.latitude,
    this.longitude,
    this.city,
    this.region,
    this.provider,
  }) : super(type: FavoriteType.stop);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'addedAt': addedAt.toIso8601String(),
        'userId': userId,
        'name': name,
        'code': code,
        'stopType': stopType.name,
        'latitude': latitude,
        'longitude': longitude,
        'city': city,
        'region': region,
        'provider': provider,
      };

  static FavoriteStop fromJson(Map<String, dynamic> json) => FavoriteStop(
        id: json['id'],
        addedAt: DateTime.parse(json['addedAt']),
        userId: json['userId'],
        name: json['name'],
        code: json['code'],
        stopType: StopType.values.firstWhere((e) => e.name == json['stopType']),
        latitude: json['latitude'],
        longitude: json['longitude'],
        city: json['city'],
        region: json['region'],
        provider: json['provider'],
      );

  @override
  String toString() => '$name ($code)';
}
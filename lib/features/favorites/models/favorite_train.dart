import 'favorite_item.dart';

class FavoriteTrain extends FavoriteItem {
  final String trainNumber;
  final String departureStation;
  final String arrivalStation;
  final String departureTime;
  final String arrivalTime;
  final String? operator; // Trenitalia, Italo, ecc.
  final String? category; // Regionale, InterCity, ecc.
  final String? routeId;
  final String? provider;

  const FavoriteTrain({
    required super.id,
    required super.addedAt,
    required super.userId,
    required this.trainNumber,
    required this.departureStation,
    required this.arrivalStation,
    required this.departureTime,
    required this.arrivalTime,
    this.operator,
    this.category,
    this.routeId,
    this.provider,
  }) : super(type: FavoriteType.train);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'addedAt': addedAt.toIso8601String(),
        'userId': userId,
        'trainNumber': trainNumber,
        'departureStation': departureStation,
        'arrivalStation': arrivalStation,
        'departureTime': departureTime,
        'arrivalTime': arrivalTime,
        'operator': operator,
        'category': category,
        'routeId': routeId,
        'provider': provider,
      };

  static FavoriteTrain fromJson(Map<String, dynamic> json) => FavoriteTrain(
        id: json['id'],
        addedAt: DateTime.parse(json['addedAt']),
        userId: json['userId'],
        trainNumber: json['trainNumber'],
        departureStation: json['departureStation'],
        arrivalStation: json['arrivalStation'],
        departureTime: json['departureTime'],
        arrivalTime: json['arrivalTime'],
        operator: json['operator'],
        category: json['category'],
        routeId: json['routeId'],
        provider: json['provider'],
      );

  @override
  String toString() => '$trainNumber: $departureStation → $arrivalStation';
}
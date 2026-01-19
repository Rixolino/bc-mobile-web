import 'favorite_item.dart';

class FavoriteBusLine extends FavoriteItem {
  final String lineCode;
  final String lineName;
  final String provider; // tper, fal, ecc.
  final String? routeId; // ID della route nel GTFS
  final String? agencyId; // ID dell'agenzia nel GTFS
  final String? color; // Colore della linea (hex)
  final String? textColor; // Colore del testo (hex)
  final String? description;
  final String? url; // URL della linea
  final List<String>? stops; // Lista degli ID delle fermate principali

  const FavoriteBusLine({
    required super.id,
    required super.addedAt,
    required super.userId,
    required this.lineCode,
    required this.lineName,
    required this.provider,
    this.routeId,
    this.agencyId,
    this.color,
    this.textColor,
    this.description,
    this.url,
    this.stops,
  }) : super(type: FavoriteType.busLine);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'addedAt': addedAt.toIso8601String(),
        'userId': userId,
        'lineCode': lineCode,
        'lineName': lineName,
        'provider': provider,
        'routeId': routeId,
        'agencyId': agencyId,
        'color': color,
        'textColor': textColor,
        'description': description,
        'url': url,
        'stops': stops,
      };

  static FavoriteBusLine fromJson(Map<String, dynamic> json) => FavoriteBusLine(
        id: json['id'],
        addedAt: DateTime.parse(json['addedAt']),
        userId: json['userId'],
        lineCode: json['lineCode'],
        lineName: json['lineName'],
        provider: json['provider'],
        routeId: json['routeId'],
        agencyId: json['agencyId'],
        color: json['color'],
        textColor: json['textColor'],
        description: json['description'],
        url: json['url'],
        stops: json['stops'] != null ? List<String>.from(json['stops']) : null,
      );

  @override
  String toString() => '$lineCode - $lineName ($provider)';
}
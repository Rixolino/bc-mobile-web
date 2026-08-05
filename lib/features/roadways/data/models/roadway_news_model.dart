class RoadwayNews {
  final String type;
  final String date;
  final String dateEn;
  final String location;
  final String title;
  final String titleEn;
  final String direction;
  final String directionEn;
  final String description;
  final String descriptionEn;

  /// Campi extra presenti negli eventi italiani (type == 'event')
  final String? id;
  final String? motorway;
  final String? motorwayName;
  final String? from;
  final String? to;
  final double? startKm;
  final double? endKm;
  final double? lengthKm;
  final String? cause;
  final String? causeEn;
  final double? queueKm;
  final double? averageSpeed;
  final int? delayMinutes;
  final double? latitude;
  final double? longitude;

  RoadwayNews({
    required this.type,
    required this.date,
    this.dateEn = '',
    required this.location,
    required this.title,
    this.titleEn = '',
    required this.direction,
    this.directionEn = '',
    required this.description,
    this.descriptionEn = '',
    this.id,
    this.motorway,
    this.motorwayName,
    this.from,
    this.to,
    this.startKm,
    this.endKm,
    this.lengthKm,
    this.cause,
    this.causeEn,
    this.queueKm,
    this.averageSpeed,
    this.delayMinutes,
    this.latitude,
    this.longitude,
  });

  factory RoadwayNews.fromJson(Map<String, dynamic> json) {
    return RoadwayNews(
      type: json['type']?.toString() ?? 'news',
      date: json['date']?.toString() ??
          json['updatedAt']?.toString() ??
          '',
      dateEn: json['dateEn']?.toString() ?? '',
      location: json['location']?.toString() ??
          json['motorwayName']?.toString() ??
          json['motorway']?.toString() ??
          '',
      title: json['title']?.toString() ??
          json['event']?.toString() ??
          '',
      titleEn: json['titleEn']?.toString() ??
          json['eventEn']?.toString() ??
          '',
      direction: json['direction']?.toString() ?? '',
      directionEn: json['directionEn']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      descriptionEn: json['descriptionEn']?.toString() ?? '',
      id: json['id']?.toString(),
      motorway: json['motorway']?.toString(),
      motorwayName: json['motorwayName']?.toString(),
      from: json['from']?.toString(),
      to: json['to']?.toString(),
      startKm: (json['startKm'] as num?)?.toDouble(),
      endKm: (json['endKm'] as num?)?.toDouble(),
      lengthKm: (json['lengthKm'] as num?)?.toDouble(),
      cause: json['cause']?.toString(),
      causeEn: json['causeEn']?.toString(),
      queueKm: (json['queueKm'] as num?)?.toDouble(),
      averageSpeed: (json['averageSpeed'] as num?)?.toDouble(),
      delayMinutes: (json['delayMinutes'] as num?)?.toInt(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
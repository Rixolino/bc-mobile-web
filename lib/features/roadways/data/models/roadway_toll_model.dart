class RoadwayToll {
  final String id;
  final String name;
  final String highway;
  final String highwayDescription;
  final double lat;
  final double lon;
  final double entranceLat;
  final double entranceLon;
  final String entranceType;
  final double exitLat;
  final double exitLon;
  final String exitType;
  final String status;
  final String address;
  final List<String> nearbyLocations;
  final List<RoadwayTollGate> entranceGates;
  final List<RoadwayTollGate> exitGates;
  final List<RoadwayPaymentMethod> paymentMethods;
  final double km;
  final String countryCode;
  final String regionCode;
  final String? note;

  RoadwayToll({
    required this.id,
    required this.name,
    required this.highway,
    required this.highwayDescription,
    required this.lat,
    required this.lon,
    this.entranceLat = 0,
    this.entranceLon = 0,
    this.entranceType = '',
    this.exitLat = 0,
    this.exitLon = 0,
    this.exitType = '',
    this.status = 'OPEN',
    this.address = '',
    this.nearbyLocations = const [],
    this.entranceGates = const [],
    this.exitGates = const [],
    this.paymentMethods = const [],
    this.km = 0,
    this.countryCode = '',
    this.regionCode = '',
    this.note,
  });

  factory RoadwayToll.fromJson(Map<String, dynamic> json) {
    final entranceGatesJson = json['entranceGates'] as List? ?? [];
    final exitGatesJson = json['exitGates'] as List? ?? [];
    final paymentMethodsJson = json['paymentMethods'] as List? ?? [];
    final nearby = json['nearbyLocations'] as List? ?? [];

    return RoadwayToll(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      highway: json['highway']?.toString() ?? '',
      highwayDescription: json['highwayDescription']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      entranceLat: (json['entranceLat'] as num?)?.toDouble() ?? 0.0,
      entranceLon: (json['entranceLon'] as num?)?.toDouble() ?? 0.0,
      entranceType: json['entranceType']?.toString() ?? '',
      exitLat: (json['exitLat'] as num?)?.toDouble() ?? 0.0,
      exitLon: (json['exitLon'] as num?)?.toDouble() ?? 0.0,
      exitType: json['exitType']?.toString() ?? '',
      status: json['status']?.toString() ?? 'OPEN',
      address: json['address']?.toString() ?? '',
      nearbyLocations: nearby.map((e) => e.toString()).toList(),
      entranceGates: entranceGatesJson
          .map((g) => RoadwayTollGate.fromJson(g as Map<String, dynamic>))
          .toList(),
      exitGates: exitGatesJson
          .map((g) => RoadwayTollGate.fromJson(g as Map<String, dynamic>))
          .toList(),
      paymentMethods: paymentMethodsJson
          .map((p) => RoadwayPaymentMethod.fromJson(p as Map<String, dynamic>))
          .toList(),
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      countryCode: json['countryCode']?.toString() ?? '',
      regionCode: json['regionCode']?.toString() ?? '',
      note: json['note']?.toString(),
    );
  }
}

class RoadwayTollGate {
  final String paymentMethod;
  final String description;
  final int total;
  final int available;
  final int unavailable;
  final String? lastUpdate;

  RoadwayTollGate({
    required this.paymentMethod,
    required this.description,
    this.total = 0,
    this.available = 0,
    this.unavailable = 0,
    this.lastUpdate,
  });

  factory RoadwayTollGate.fromJson(Map<String, dynamic> json) {
    return RoadwayTollGate(
      paymentMethod: json['paymentMethod']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt() ?? 0,
      available: (json['available'] as num?)?.toInt() ?? 0,
      unavailable: (json['unavailable'] as num?)?.toInt() ?? 0,
      lastUpdate: json['lastUpdate']?.toString(),
    );
  }
}

class RoadwayPaymentMethod {
  final String code;
  final String description;

  RoadwayPaymentMethod({
    required this.code,
    required this.description,
  });

  factory RoadwayPaymentMethod.fromJson(Map<String, dynamic> json) {
    return RoadwayPaymentMethod(
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }
}
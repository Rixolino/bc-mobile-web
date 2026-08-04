class RoadwayServiceItem {
  final String code;
  final String description;
  final String brand;
  final double quantity;
  final double available;

  RoadwayServiceItem({
    required this.code,
    required this.description,
    required this.brand,
    required this.quantity,
    required this.available,
  });

  factory RoadwayServiceItem.fromJson(Map<String, dynamic> json) {
    return RoadwayServiceItem(
      code: json['c_srv'] ?? '',
      description: json['t_des_srv_it'] ?? '',
      brand: json['t_name'] ?? '',
      quantity: (json['n_qty'] as num?)?.toDouble() ?? 0.0,
      available: (json['n_available'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class RoadwayAreaService {
  final String name;
  final String highway;
  final String highwayDescription;
  final String direction;
  final String destination;
  final String pmrAccessibilityDescription;
  final double benPrice;
  final double bdisPrice;
  final double bgplPrice;
  final double bhvoPrice;
  final double bgnsPrice;
  final double bmetPrice;
  final double lon;
  final double lat;
  final List<RoadwayServiceItem> services;

  RoadwayAreaService({
    required this.name,
    required this.highway,
    required this.highwayDescription,
    required this.direction,
    required this.destination,
    required this.pmrAccessibilityDescription,
    required this.benPrice,
    required this.bdisPrice,
    required this.bgplPrice,
    required this.bhvoPrice,
    required this.bgnsPrice,
    required this.bmetPrice,
    required this.lon,

    required this.lat,
    required this.services,
  });

  factory RoadwayAreaService.fromJson(Map<String, dynamic> json) {
    final servicesJson = json['srvsn'] as List? ?? [];
    return RoadwayAreaService(
      name: json['nome'] ?? '',
      highway: json['c_ram'] ?? '',
      highwayDescription: json['t_des_ram'] ?? '',
      direction: json['c_dir'] ?? '',
      destination: json['cap'] ?? '',
      pmrAccessibilityDescription: json['descAdsPmr'] ?? '',
      benPrice: (json['benPrice'] as num?)?.toDouble() ?? 0.0,
      bdisPrice: (json['bdisPrice'] as num?)?.toDouble() ?? 0.0,
      bgplPrice: (json['bgplPrice'] as num?)?.toDouble() ?? 0.0,
      bhvoPrice: (json['bhvoPrice'] as num?)?.toDouble() ?? 0.0,
      bgnsPrice: (json['bgnsPrice'] as num?)?.toDouble() ?? 0.0,
      bmetPrice: (json['bmetPrice'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      services: servicesJson.map((s) => RoadwayServiceItem.fromJson(s)).toList(),
    );
  }
}

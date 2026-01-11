class TransportConfig {
  final List<TransportSource> transports;
  final Map<String, dynamic>? systemEndpoints;
  final String? lastUpdated;

  TransportConfig({
    required this.transports,
    this.systemEndpoints,
    this.lastUpdated,
  });

  factory TransportConfig.fromJson(Map<String, dynamic> json) {
    return TransportConfig(
      transports: (json['transports'] as List<dynamic>?)
              ?.map((e) => TransportSource.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      systemEndpoints: json['system_endpoints'] as Map<String, dynamic>?,
      lastUpdated: json['lastUpdated'] as String?,
    );
  }

  // Helper methods to get categorized transports
  List<TransportSource> get trains => transports.where((t) => t.type == 'train').toList();
  List<TransportSource> get buses => transports.where((t) => t.type == 'bus').toList();
  List<TransportSource> get planes => transports.where((t) => t.type == 'plane').toList();
}

class TransportSource {
  final String id;
  final String name;
  final String type; // 'train', 'bus', 'plane'
  final String scope;
  final String? description;
  final String? country;
  final String? city;
  final String? region;
  final String? icon;
  final Map<String, String> endpoints;
  final Map<String, dynamic>? parsing;

  TransportSource({
    required this.id,
    required this.name,
    required this.type,
    required this.scope,
    this.description,
    this.country,
    this.city,
    this.region,
    this.icon,
    required this.endpoints,
    this.parsing,
  });

  String get apiUrl => endpoints['main'] ?? (endpoints.isNotEmpty ? endpoints.values.first : '');

  factory TransportSource.fromJson(Map<String, dynamic> json) {
    return TransportSource(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      scope: json['scope'] ?? '',
      description: json['description'],
      country: json['country'],
      city: json['city'],
      region: json['region'],
      icon: json['icon'],
      endpoints: (json['endpoints'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value.toString()),
          ) ??
          {},
      parsing: json['parsing'] as Map<String, dynamic>?,
    );
  }
}

class RegionalProvider {
  final String name;
  final String provider;
  final String country;
  final String region;
  final String description;
  final String apiPrefix;
  final String webPath;
  final Coordinates? coordinates;
  final ProviderEndpoints endpoints;

  RegionalProvider({
    required this.name,
    required this.provider,
    required this.country,
    required this.region,
    required this.description,
    required this.apiPrefix,
    required this.webPath,
    this.coordinates,
    required this.endpoints,
  });

  factory RegionalProvider.fromJson(Map<String, dynamic> json) {
    return RegionalProvider(
      name: json['name'] ?? '',
      provider: json['provider'] ?? '',
      country: json['country'] ?? '',
      region: json['region'] ?? '',
      description: json['description'] ?? '',
      apiPrefix: json['api_prefix'] ?? '',
      webPath: json['web_path'] ?? '',
      coordinates: json['coordinates'] != null
          ? Coordinates.fromJson(json['coordinates'])
          : null,
      endpoints: ProviderEndpoints.fromJson(json['endpoints'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'provider': provider,
      'country': country,
      'region': region,
      'description': description,
      'api_prefix': apiPrefix,
      'web_path': webPath,
      'coordinates': coordinates?.toJson(),
      'endpoints': endpoints.toJson(),
    };
  }

  String get fullApiUrl => 'https://betacloud-transporter.is-cool.dev/api/$apiPrefix';
  String get fullWebUrl => 'https://betacloud-transporter.is-cool.dev/$webPath';
}

class Coordinates {
  final double latitude;
  final double longitude;
  final int zoom;

  Coordinates({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  factory Coordinates.fromJson(Map<String, dynamic> json) {
    return Coordinates(
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      zoom: json['zoom'] ?? 11,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'zoom': zoom,
    };
  }
}

class ProviderEndpoints {
  final bool stations;
  final bool departures;
  final bool arrivals;
  final bool stopUpdates;
  final bool realtime;
  final bool trip;
  final bool lines;
  final bool news;
  final bool trains;
  final bool solutions;

  ProviderEndpoints({
    required this.stations,
    required this.departures,
    required this.arrivals,
    required this.stopUpdates,
    required this.realtime,
    required this.trip,
    required this.lines,
    required this.news,
    required this.trains,
    required this.solutions,
  });

  factory ProviderEndpoints.fromJson(Map<String, dynamic> json) {
    return ProviderEndpoints(
      stations: json['stations'] ?? false,
      departures: json['departures'] ?? false,
      arrivals: json['arrivals'] ?? false,
      stopUpdates: json['stop_updates'] ?? false,
      realtime: json['realtime'] ?? false,
      trip: json['trip'] ?? false,
      lines: json['lines'] ?? false,
      news: json['news'] ?? false,
      trains: json['trains'] ?? false,
      solutions: json['solutions'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stations': stations,
      'departures': departures,
      'arrivals': arrivals,
      'stop_updates': stopUpdates,
      'realtime': realtime,
      'trip': trip,
      'lines': lines,
      'news': news,
      'trains': trains,
      'solutions': solutions,
    };
  }
}

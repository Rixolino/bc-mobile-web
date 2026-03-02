import 'package:latlong2/latlong.dart';

class BusVehicle {
  final String id;
  final String line;
  final String? destination;
  final double latitude;
  final double longitude;
  final String? heading;
  final String? speed;
  final String? provider; // Bari, Roma, ER, Flixbus
  final String? tripId; // Trip ID for route path fetching
  final bool isLivePosition; // Flag per indicare se è un autobus rilevato come live position

  BusVehicle({
    required this.id,
    required this.line,
    this.destination,
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speed,
    this.provider,
    this.tripId,
    this.isLivePosition = false, // Default false
  });

  factory BusVehicle.fromGtfsRtJson(Map<String, dynamic> json, String providerName) {
    // Handle direct format: fields directly in json (from realtime API)
    if (json['position'] != null) {
      final pos = json['position'];
      return BusVehicle(
        id: json['vehicleId']?.toString() ?? '?',
        line: json['routeId']?.toString() ?? '?',
        destination: json['destination']?.toString(),
        latitude: pos['lat']?.toDouble() ?? 0.0,
        longitude: pos['lng']?.toDouble() ?? 0.0,
        heading: pos['bearing']?.toString(),
        speed: pos['speed']?.toString(),
        provider: providerName,
        tripId: json['tripId']?.toString(),
        isLivePosition: true, // This is from realtime API
      );
    }

    // Handle new format: {"id": "3204", "vehicle": {...}} (GTFS-RT format)
    if (json['vehicle'] != null) {
      final v = json['vehicle'];
      final pos = v['position'] ?? {};
      final trip = v['trip'] ?? {};
      final vehicle = v['vehicle'] ?? {};

      return BusVehicle(
        id: vehicle['id']?.toString() ?? json['id']?.toString() ?? '?',
        line: trip['routeId']?.toString() ?? '?',
        destination: v['destination']?.toString(),
        latitude: pos['latitude']?.toDouble() ?? 0.0,
        longitude: pos['longitude']?.toDouble() ?? 0.0,
        heading: pos['bearing']?.toString(),
        speed: pos['speed']?.toString(),
        provider: 'Bari',
        tripId: trip['tripId']?.toString(),
        isLivePosition: true, // GTFS-RT is realtime
      );
    }
    
    // Fallback to old format: {"Vehicle": {...}}
    final v = json['Vehicle'] ?? {};
    final pos = v['Position'] ?? {};
    final trip = v['Trip'] ?? {};
    final vehicleInfo = v['Vehicle'] ?? {};
    
    return BusVehicle(
      id: vehicleInfo['Id']?.toString() ?? v['Id']?.toString() ?? json['Id']?.toString() ?? json['id']?.toString() ?? '?',
      line: trip['RouteId']?.toString() ?? '?',
      destination: v['Destination']?.toString(),
      latitude: (pos['Latitude'] is String ? double.tryParse(pos['Latitude']) : (pos['Latitude'] as num?)?.toDouble()) ?? 0.0,
      longitude: (pos['Longitude'] is String ? double.tryParse(pos['Longitude']) : (pos['Longitude'] as num?)?.toDouble()) ?? 0.0,
      heading: pos['Bearing']?.toString(),
      speed: pos['Speed']?.toString(),
      provider: 'Bari',
      tripId: trip['TripId']?.toString(),
    );
  }

  factory BusVehicle.fromERJson(Map<String, dynamic> json) {
    // TperHellobus format
    return BusVehicle(
      id: json['CodiceBus']?.toString() ?? '?',
      line: json['NumeroLinea']?.toString() ?? '?',
      destination: json['DenominazioneFermata'],
      latitude: json['Latitude']?.toDouble() ?? 0.0,
      longitude: json['Longitude']?.toDouble() ?? 0.0,
      provider: 'Emilia-Romagna',
      tripId: null,
    );
  }

  factory BusVehicle.fromFlixbusJson(Map<String, dynamic> json) {
    return BusVehicle(
      id: json['id']?.toString() ?? '?',
      line: json['lineCode']?.toString() ?? 'FLX',
      destination: json['direction'],
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      provider: 'Flixbus',
      tripId: null,
    );
  }

  BusVehicle copyWith({
    String? id,
    String? line,
    String? destination,
    double? latitude,
    double? longitude,
    String? heading,
    String? speed,
    String? provider,
    String? tripId,
    bool? isLivePosition,
  }) {
    return BusVehicle(
      id: id ?? this.id,
      line: line ?? this.line,
      destination: destination ?? this.destination,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      provider: provider ?? this.provider,
      tripId: tripId ?? this.tripId,
      isLivePosition: isLivePosition ?? this.isLivePosition,
    );
  }
}

class BusTripUpdate {
  final String stopId;
  final String stopName;
  final String expectedTime;
  final int? delay; // in minutes
  final bool isRealtime;
  final String status; // 'passed', 'current', 'future'
  final String? arrivalEstimate; // "In arrivo", "~X min", etc.

  BusTripUpdate({
    required this.stopId,
    required this.stopName,
    required this.expectedTime,
    this.delay,
    this.isRealtime = false,
    this.status = 'future',
    this.arrivalEstimate,
  });

  int get delayMinutes => delay ?? 0;

  factory BusTripUpdate.fromJson(Map<String, dynamic> json) {
    return BusTripUpdate(
      stopId: json['stopId']?.toString() ?? '',
      stopName: json['stopName'] ?? '',
      expectedTime: json['scheduledTime'] ?? json['time'] ?? '',
      delay: json['delay'] ?? 0,
      isRealtime: json['isRealtime'] ?? false,
      status: json['status'] ?? 'future',
      arrivalEstimate: json['arrivalEstimate'] ?? json['estimate'],
    );
  }
}

class BariStop {
  final String stopId;
  final String stopName;
  final double latitude;
  final double longitude;

  BariStop({
    required this.stopId,
    required this.stopName,
    required this.latitude,
    required this.longitude,
  });

  factory BariStop.fromJson(Map<String, dynamic> json) {
    return BariStop(
      stopId: json['stop_id']?.toString() ?? '',
      stopName: json['stop_name'] ?? '',
      latitude: double.tryParse(json['stop_lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(json['stop_lon']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class BariRouteLeg {
  final String fromStop;
  final String toStop;
  final String routeId;
  final String lineCode;
  final String departureTime;
  final String arrivalTime;
  final int duration; // in minutes
  final String? vehicleType;
  final String? operator;

  BariRouteLeg({
    required this.fromStop,
    required this.toStop,
    required this.routeId,
    required this.lineCode,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    this.vehicleType,
    this.operator,
  });

  factory BariRouteLeg.fromJson(Map<String, dynamic> json) {
    return BariRouteLeg(
      fromStop: json['LocalitaSalita']?['Descrizione'] ?? 'Sconosciuto',
      toStop: json['LocalitaDiscesa']?['Descrizione'] ?? 'Sconosciuto',
      routeId: json['Linea']?['Codice'] ?? json['Corsa']?['CodiceInfoUtenza'] ?? 'N/A',
      lineCode: json['Linea']?['Codice'] ?? 'N/A',
      departureTime: json['OraPartenza'] ?? '',
      arrivalTime: json['OraArrivo'] ?? '',
      duration: json['Durata'] ?? 0,
      vehicleType: json['TipoMezzo'],
      operator: json['CodiceAzienda'] ?? json['Linea']?['CodiceAzienda'] ?? json['Corsa']?['CodiceAzienda'],
    );
  }
}

class BariRouteSolution {
  final String id;
  final List<BariRouteLeg> legs;
  final String departureTime;
  final String arrivalTime;
  final int totalDuration; // in minutes
  final int transfers;
  final String? price;
  final String? currency;

  BariRouteSolution({
    required this.id,
    required this.legs,
    required this.departureTime,
    required this.arrivalTime,
    required this.totalDuration,
    required this.transfers,
    this.price,
    this.currency,
  });

  factory BariRouteSolution.fromJson(Map<String, dynamic> json) {
    final tratte = json['Tratte'] ?? [];
    final List<dynamic> tratteList = tratte is List ? tratte : [];
    final legs = tratteList.map((t) => BariRouteLeg.fromJson(t)).toList();

    return BariRouteSolution(
      id: json['IdSoluzione']?.toString() ?? '',
      legs: legs,
      departureTime: json['OraPartenza'] ?? '',
      arrivalTime: json['OraArrivo'] ?? '',
      totalDuration: json['DurataTotale'] ?? 0,
      transfers: json['NumeroCambi'] ?? 0,
      price: json['Prezzo']?['Valore']?.toString(),
      currency: json['Prezzo']?['Valuta'],
    );
  }
}

/// Modello per il percorso geografico di un bus
class BusRoutePath {
  final String tripId;
  final String routeId;
  final String destination;
  final int totalStops;
  final int waypointsUsed;
  final List<String> stopIds; // Aggiunto: lista degli stopId del percorso
  final List<LatLng> pathCoordinates;
  final double? distance; // in meters
  final double? duration; // in seconds

  BusRoutePath({
    required this.tripId,
    required this.routeId,
    required this.destination,
    required this.totalStops,
    required this.waypointsUsed,
    required this.stopIds, // Aggiunto
    required this.pathCoordinates,
    this.distance,
    this.duration,
  });

  factory BusRoutePath.fromJson(Map<String, dynamic> json) {
    final coordinates = json['pathCoordinates'] as List<dynamic>? ?? [];
    final pathCoordinates = coordinates.map((coord) {
      return LatLng(
        (coord['lat'] as num?)?.toDouble() ?? 0.0,
        (coord['lng'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    final stopIds = (json['stopIds'] as List<dynamic>?)?.map((id) => id.toString()).toList() ?? [];

    return BusRoutePath(
      tripId: json['tripId']?.toString() ?? '',
      routeId: json['routeId']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      totalStops: json['totalStops'] ?? 0,
      waypointsUsed: json['waypointsUsed'] ?? 0,
      stopIds: stopIds, // Aggiunto
      pathCoordinates: pathCoordinates,
      distance: json['distance']?.toDouble(),
      duration: json['duration']?.toDouble(),
    );
  }
}

class StopDeparture {
  final String line;
  final String tripId;
  final String vehicleId;
  final String vehicleLabel;
  final double time; // timestamp (cambiato da int a double per supportare decimali)
  final bool isRealtime;
  final bool isScheduled;
  final bool isLivePosition; // nuovo campo per indicare se è basato su posizione GPS
  final int delay;
  final String destination;
  final double? distance; // nuovo campo per la distanza in km (solo per live position)
  final List<TripStop>? stops; // optional list of stops (for Turin realtime and scheduled)

  StopDeparture({
    required this.line,
    required this.tripId,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.time,
    required this.isRealtime,
    required this.isScheduled,
    required this.isLivePosition,
    required this.delay,
    required this.destination,
    this.distance,
    this.stops,
  });

  factory StopDeparture.fromJson(Map<String, dynamic> json) {
    return StopDeparture(
      line: json['line']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      vehicleId: json['vehicleId']?.toString() ?? '',
      vehicleLabel: json['vehicleLabel']?.toString() ?? '',
      time: (json['time'] as num?)?.toDouble() ?? 0.0, // cambiato da int a double
      isRealtime: json['isRealtime'] ?? false,
      isScheduled: json['isScheduled'] ?? false,
      isLivePosition: json['isLivePosition'] ?? false, // nuovo campo
      delay: json['delay'] ?? 0,
      destination: json['destination'] ?? '',
      distance: (json['distance'] as num?)?.toDouble(), // nuovo campo
      stops: (json['stops'] as List?)
          ?.map((s) => TripStop.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  String get formattedTime {
    final dateTime = DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt()); // convertito a int per fromMillisecondsSinceEpoch
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String get delayText {
    if (delay == 0) return '';
    if (delay > 0) return ' (+${delay}min)';
    return ' (${delay}min)';
  }
}

/// Represents the payload returned by `/stops` or `/stops-updates`.
/// Mirrors the server response which includes summary counts.
class StopUpdates {
  final String stopId;
  final String stopName;
  final int totalDepartures;
  final int realtimeDepartures;
  final int livePositionDepartures;
  final int scheduledDepartures;
  final List<StopDeparture> departures;

  StopUpdates({
    required this.stopId,
    required this.stopName,
    required this.totalDepartures,
    required this.realtimeDepartures,
    required this.livePositionDepartures,
    required this.scheduledDepartures,
    required this.departures,
  });

  factory StopUpdates.fromJson(Map<String, dynamic> json) {
    final deps = (json['departures'] as List<dynamic>?)
            ?.map((e) => StopDeparture.fromJson(e))
            .toList() ?? [];
    return StopUpdates(
      stopId: json['stopId']?.toString() ?? '',
      stopName: json['stopName'] ?? '',
      totalDepartures: json['totalDepartures'] ?? deps.length,
      realtimeDepartures: json['realtimeDepartures'] ??
          deps.where((d) => d.isRealtime && !d.isLivePosition).length,
      livePositionDepartures: json['livePositionDepartures'] ??
          deps.where((d) => d.isLivePosition).length,
      scheduledDepartures: json['scheduledDepartures'] ??
          deps.where((d) => d.isScheduled).length,
      departures: deps,
    );
  }
}

/// Modello per i dati delle fermate di un trip specifico
class TripStopsData {
  final String tripId;
  final BusVehicle vehicle;
  final Map<String, dynamic> filter;
  final List<TripStop> stops;

  TripStopsData({
    required this.tripId,
    required this.vehicle,
    required this.filter,
    required this.stops,
  });

  factory TripStopsData.fromJson(Map<String, dynamic> json) {
    final vehicleJson = json['vehicle'] ?? {};
    final stopsJson = json['stops'] as List<dynamic>? ?? [];

    return TripStopsData(
      tripId: json['tripId']?.toString() ?? '',
      vehicle: BusVehicle(
        id: vehicleJson['id']?.toString() ?? '',
        line: '', // Will be filled from trip data
        latitude: (vehicleJson['lat'] as num?)?.toDouble() ?? 0.0,
        longitude: (vehicleJson['lng'] as num?)?.toDouble() ?? 0.0,
        heading: vehicleJson['bearing']?.toString(),
        speed: vehicleJson['speed']?.toString(),
        provider: 'Bari',
        tripId: json['tripId']?.toString(),
        isLivePosition: vehicleJson['isRealtime'] ?? false,
      ),
      filter: json['filter'] is Map
          ? Map<String, dynamic>.from(json['filter'])
          : <String, dynamic>{},
      stops: stopsJson.map((s) {
        if (s is Map) return TripStop.fromJson(Map<String, dynamic>.from(s));
        return TripStop.fromJson(<String, dynamic>{});
      }).toList(),
    );
  }
}

/// Modello per una singola fermata in un trip
class TripStop {
  final String stopId;
  final String stopName;
  final int sequence;
  final String status; // 'passed', 'current', 'future'
  final String scheduledTime;
  final int? estimatedArrivalUnix;
  final int delay;
  final bool isRealtime;

  TripStop({
    required this.stopId,
    required this.stopName,
    required this.sequence,
    required this.status,
    required this.scheduledTime,
    this.estimatedArrivalUnix,
    required this.delay,
    required this.isRealtime,
  });

  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      stopId: json['stopId']?.toString() ?? '',
      stopName: json['stopName'] ?? '',
      sequence: json['sequence'] ?? 0,
      status: json['status'] ?? 'future',
      scheduledTime: json['scheduledTime'] ?? '',
      estimatedArrivalUnix: json['estimatedArrivalUnix'],
      delay: json['delay'] ?? 0,
      isRealtime: json['isRealtime'] ?? false,
    );
  }

  String get delayText {
    if (delay == 0) return '';
    if (delay > 0) return ' (+${delay}min)';
    return ' (${delay}min)';
  }

  DateTime? get estimatedArrivalTime {
    if (estimatedArrivalUnix == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(estimatedArrivalUnix! * 1000);
  }
}

class BusProviderConfig {
  final String name;
  final String provider;
  final String? solutionsUrl;
  final String? gpsUrl;
  final String? tripsUrl;
  final String? gtfsUrl;
  final String? dataPath;
  final String? apiPrefix;
  final String? country;
  final Map<String, bool> endpoints;
  final double? latitude;
  final double? longitude;
  final double? zoom;

  BusProviderConfig({
    required this.name,
    required this.provider,
    this.solutionsUrl,
    this.gpsUrl,
    this.tripsUrl,
    this.gtfsUrl,
    this.dataPath,
    this.apiPrefix,
    this.country,
    required this.endpoints,
    this.latitude,
    this.longitude,
    this.zoom,
  });

  factory BusProviderConfig.fromJson(Map<String, dynamic> json) {
    final coordinates = json['coordinates'] as Map<String, dynamic>?;
    return BusProviderConfig(
      name: json['name'],
      provider: json['provider'],
      solutionsUrl: json['solutions_url'],
      gpsUrl: json['gps_url'],
      tripsUrl: json['trips_url'],
      gtfsUrl: json['gtfs_url'],
      dataPath: json['data_path'],
      apiPrefix: json['api_prefix'],
      country: json['country'],
      endpoints: Map<String, bool>.from(json['endpoints'] ?? {}),
      latitude: coordinates?['latitude']?.toDouble(),
      longitude: coordinates?['longitude']?.toDouble(),
      zoom: coordinates?['zoom']?.toDouble(),
    );
  }

  bool get supportsSolutions => endpoints['solutions'] == true;
  
  /// Restituisce il prefisso dell'API per questo provider, es. "it/bus/bari"
  String get apiPathPrefix {
    if (apiPrefix != null && apiPrefix!.isNotEmpty) return apiPrefix!;
    final c = country ?? 'it';
    final pname = name.toLowerCase();
    return '$c/bus/$pname';
  }
}

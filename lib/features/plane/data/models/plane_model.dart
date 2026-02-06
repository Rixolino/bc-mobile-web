class Flight {
  final String id;
  final String flightNumber;
  final String callsign;
  final String airline;
  final String origin;
  final String? originId;
  final String destination;
  final String? destinationId;
  final String status;
  final String? statusLocalized;
  final DateTime? scheduledTime;
  final DateTime? estimatedTime;
  
  // Specific timetable fields
  final DateTime? scheduledDeparture;
  final DateTime? estimatedDeparture;
  final DateTime? scheduledArrival;
  final DateTime? estimatedArrival;
  final String? type; // 'arrival' or 'departure'
  final String? terminal;
  final String? gate;
  
  // Real-time tracking data (FlightRadar)
  final double? latitude;
  final double? longitude;
  final double? heading;
  final double? altitude;
  final double? speed;

  int get delayMinutes {
    if (scheduledTime == null || estimatedTime == null) return 0;
    return estimatedTime!.difference(scheduledTime!).inMinutes;
  }
  
  Flight({
    required this.id,
    required this.flightNumber,
    required this.callsign,
    required this.airline,
    required this.origin,
    this.originId,
    required this.destination,
    this.destinationId,
    this.status = '',
    this.statusLocalized,
    this.scheduledTime,
    this.estimatedTime,
    this.scheduledDeparture,
    this.estimatedDeparture,
    this.scheduledArrival,
    this.estimatedArrival,
    this.type,
    this.terminal,
    this.gate,
    this.latitude,
    this.longitude,
    this.heading,
    this.altitude,
    this.speed,
  });

  factory Flight.fromSkyscanner(Map<String, dynamic> json, String type) {
    final isArrival = type == 'arrival';
    
    final scheduledStr = isArrival 
      ? (json['scheduledArrivalTime'] ?? json['scheduledTime'] ?? json['scheduledArrival'])
      : (json['scheduledDepartureTime'] ?? json['scheduledTime'] ?? json['scheduledDeparture']);
      
    final estimatedStr = isArrival
      ? (json['estimatedArrivalTime'] ?? json['estimatedTime'] ?? json['estimatedArrival'])
      : (json['estimatedDepartureTime'] ?? json['estimatedTime'] ?? json['estimatedDeparture']);

    // Map specific fields for departures/arrivals
    final schDepStr = isArrival ? (json['scheduledDepartureTime'] ?? json['scheduledDeparture']) : scheduledStr;
    final schArrStr = isArrival ? scheduledStr : (json['scheduledArrivalTime'] ?? json['scheduledArrival']);
    
    final estDepStr = isArrival ? (json['estimatedDepartureTime'] ?? json['estimatedDeparture']) : estimatedStr;
    final estArrStr = isArrival ? estimatedStr : (json['estimatedArrivalTime'] ?? json['estimatedArrival']);

    return Flight(
      id: json['flightId']?.toString() ?? json['id']?.toString() ?? 
          "${json['flightNumber']}_${scheduledStr ?? ''}",
      flightNumber: json['flightNumber'] ?? '',
      callsign: json['callsign'] ?? json['flightNumber'] ?? '',
      airline: json['airlineName'] ?? json['airline'] ?? '',
      destination: json['arrivalAirportName'] ?? json['destination'] ?? '',
      destinationId: json['arrivalAirportCode'] ?? json['arrivalCode'],
      origin: json['departureAirportName'] ?? json['origin'] ?? '',
      originId: json['departureAirportCode'] ?? json['departureCode'],
      status: json['status'] ?? '',
      statusLocalized: json['statusLocalised'] ?? json['statusLocalized'],
      scheduledTime: scheduledStr != null ? DateTime.tryParse(scheduledStr) : null,
      estimatedTime: estimatedStr != null ? DateTime.tryParse(estimatedStr) : null,
      scheduledDeparture: schDepStr != null ? DateTime.tryParse(schDepStr) : null,
      estimatedDeparture: estDepStr != null ? DateTime.tryParse(estDepStr) : null,
      scheduledArrival: schArrStr != null ? DateTime.tryParse(schArrStr) : null,
      estimatedArrival: estArrStr != null ? DateTime.tryParse(estArrStr) : null,
      type: type,
      terminal: isArrival ? json['arrivalTerminal'] : json['departureTerminal'],
      gate: json['gate'],
    );
  }

  factory Flight.fromFlightRadar(Map<String, dynamic> json) {
    return Flight(
      id: json['id'] ?? '',
      flightNumber: json['flight'] ?? json['id'] ?? '',
      callsign: json['callsign'] ?? 'UNK',
      airline: json['airline'] ?? '',
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      heading: (json['heading'] ?? 0).toDouble(),
      altitude: (json['altitude'] ?? 0).toDouble(),
      speed: (json['speed'] ?? 0).toDouble(),
    );
  }
}

class Airport {
  final String iata;
  final String name;
  final String city;
  final String country;
  final double lat;
  final double lng;

  Airport({
    required this.iata,
    required this.name,
    required this.city,
    required this.country,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory Airport.fromJson(Map<String, dynamic> json) {
    double latitude = 0.0;
    double longitude = 0.0;

    // Handle Skyscanner format "41.141111,16.788333"
    if (json['Location'] is String) {
      final parts = (json['Location'] as String).split(',');
      if (parts.length == 2) {
        latitude = double.tryParse(parts[0]) ?? 0.0;
        longitude = double.tryParse(parts[1]) ?? 0.0;
      }
    } else if (json['Location'] is Map) {
      latitude = (json['Location']['lat'] ?? 0.0).toDouble();
      longitude = (json['Location']['lng'] ?? 0.0).toDouble();
    } else {
      latitude = (json['lat'] ?? 0.0).toDouble();
      longitude = (json['lng'] ?? 0.0).toDouble();
    }

    return Airport(
      iata: json['iata'] ?? json['id'] ?? json['PlaceId'] ?? '',
      name: json['name'] ?? json['PlaceName'] ?? '',
      city: json['city'] ?? json['CityName'] ?? '',
      country: json['country'] ?? json['CountryName'] ?? '',
      lat: latitude,
      lng: longitude,
    );
  }
}


class TrainStation {
  final String id;
  final String name;
  final String country;
  final String? type; // 'train', 'bus' for FAL

  TrainStation({
    required this.id, 
    required this.name, 
    required this.country,
    this.type
  });

  factory TrainStation.fromJson(Map<String, dynamic> json) {
    return TrainStation(
      id: json['id']?.toString() ?? json['stationId']?.toString() ?? json['codStazione']?.toString() ?? '',
      name: json['name'] ?? json['stationName'] ?? json['nomestazione'] ?? '',
      country: json['country'] ?? '',
      type: json['type'],
    );
  }

  factory TrainStation.fromDynamicJson(Map<String, dynamic> json, Map<String, dynamic> config) {
    final fields = config['fields'] as Map<String, dynamic>? ?? {};
    
    dynamic getValue(dynamic obj, String path) {
      if (obj == null) return null;
      final keys = path.split('.');
      dynamic current = obj;
      for (final key in keys) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return null;
        }
      }
      return current;
    }

    return TrainStation(
      id: getValue(json, fields['id'] ?? 'id')?.toString() ?? '',
      name: getValue(json, fields['name'] ?? 'name')?.toString() ?? '',
      country: getValue(json, fields['country'] ?? 'country')?.toString() ?? '',
      type: getValue(json, fields['type'] ?? 'type')?.toString(),
    );
  }
}

class TrainDeparture {
/* ... */
  factory TrainDeparture.fromDynamicJson(Map<String, dynamic> json, Map<String, dynamic> config) {
    final fields = config['fields'] as Map<String, dynamic>? ?? {};
    
    dynamic getValue(dynamic obj, String path) {
      if (obj == null) return null;
      final keys = path.split('.');
      dynamic current = obj;
      for (final key in keys) {
        if (current is Map && current.containsKey(key)) {
          current = current[key];
        } else {
          return null;
        }
      }
      return current;
    }

    return TrainDeparture(
      trainNumber: getValue(json, fields['trainNumber'] ?? 'trainNumber')?.toString(),
      category: getValue(json, fields['category'] ?? 'category')?.toString(),
      destination: getValue(json, fields['destination'] ?? 'destination')?.toString(),
      origin: getValue(json, fields['origin'] ?? 'origin')?.toString(),
      scheduledTime: _parseTime(getValue(json, fields['scheduledTime'] ?? 'scheduledTime')),
      estimatedTime: _parseTime(getValue(json, fields['estimatedTime'] ?? 'estimatedTime')),
      platform: getValue(json, fields['platform'] ?? 'platform')?.toString(),
      delayMinutes: int.tryParse(getValue(json, fields['delay'] ?? 'delay')?.toString() ?? '0'),
      status: getValue(json, fields['status'] ?? 'status')?.toString(),
      tripId: getValue(json, fields['tripId'] ?? 'tripId')?.toString(),
    );
  }
  final String? trainNumber;
  final String? category;
  final String? destination;
  final String? origin;
  final DateTime? scheduledTime;
  final DateTime? estimatedTime;
  final String? platform;
  final int? delayMinutes;
  final String? status;
  final String? tripId;
  final List<TrainStop>? stops;
  final String country;
  final Map<String, dynamic>? metadata;

  TrainDeparture({
    this.trainNumber,
    this.category,
    this.destination,
    this.origin,
    this.scheduledTime,
    this.estimatedTime,
    this.platform,
    this.delayMinutes,
    this.status,
    this.tripId,
    this.stops,
    this.country = '',
    this.metadata,
  });

  factory TrainDeparture.fromJson(Map<String, dynamic> json, {bool isDeparture = true}) {
    // Check for nested 'data' or 'trip' fields which are common in TB API
    final Map<String, dynamic> actualData = (json['data'] is Map<String, dynamic>) 
        ? json['data'] 
        : (json['trip'] is Map<String, dynamic> ? json['trip'] : json);

    String? rawLine = _getStringValue(actualData['line'] ?? actualData['tripNumber'] ?? actualData['trainNumber']);
    String? num;
    
    if (rawLine != null) {
      String s = rawLine;
      final zugMatch = RegExp(r'Zug-?Nr\.?\s*(\d+)', caseSensitive: false).firstMatch(s);
      if (zugMatch != null) {
        num = zugMatch.group(1);
      } else {
        final m = RegExp(r'\d+').firstMatch(s);
        num = m != null ? m.group(0) : s;
      }
    }

    String? dest = isDeparture 
        ? _getStringValue(actualData['destination'] ?? actualData['stationName']) 
        : _getStringValue(actualData['stationName'] ?? actualData['destination']);
        
    String? orig = isDeparture 
        ? _getStringValue(actualData['stationName'] ?? actualData['origin']) 
        : _getStringValue(actualData['origin'] ?? actualData['stationName']);

    // For Trainboard stops can be in 'stops' or 'stopovers'
    var rawStops = actualData['stops'] ?? actualData['stopovers'];
    List<TrainStop>? stops;
    if (rawStops is List) {
      stops = rawStops.map((s) => TrainStop.fromJson(s as Map<String, dynamic>)).toList();
    }

    return TrainDeparture(
      trainNumber: num,
      category: _getStringValue(actualData['category'] ?? actualData['type'] ?? actualData['operator']),
      destination: dest,
      origin: orig,
      scheduledTime: _parseTime(actualData['scheduledTime'] ?? actualData['time'] ?? actualData['departureTime'] ?? actualData['arrivalTime']),
      estimatedTime: _parseTime(actualData['estimatedTime'] ?? actualData['actualTime'] ?? actualData['prognosis']?['time']),
      platform: _getStringValue(actualData['platform'] ?? actualData['plannedPlatform']),
      delayMinutes: actualData['delay'] is int ? actualData['delay'] : (actualData['delayMinutes'] ?? 0),
      status: _getStringValue(actualData['status']),
      tripId: actualData['tripId']?.toString() ?? actualData['id']?.toString(),
      stops: stops,
      country: actualData['country']?.toString() ?? '',
      metadata: actualData['metadata'] as Map<String, dynamic>?,
    );
  }

  static String? _getStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      return value['name']?.toString() ?? 
             value['text']?.toString() ?? 
             value['id']?.toString() ?? 
             value['stationName']?.toString();
    }
    return value.toString();
  }

  static DateTime? _parseTime(dynamic time) {
    if (time == null) return null;
    if (time is int) {
      return (time < 100000000000) ? DateTime.fromMillisecondsSinceEpoch(time * 1000) : DateTime.fromMillisecondsSinceEpoch(time);
    }
    if (time is String) {
      final s = time.trim();
      final n = double.tryParse(s);
      if (n != null) {
        final ms = (n < 1e11) ? (n * 1000).toInt() : n.toInt();
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return DateTime.tryParse(s);
    }
    return null;
  }
  
  bool get isDelayed => (delayMinutes ?? 0) > 0;

  TrainDeparture copyWith({
    List<TrainStop>? stops,
    String? country,
    Map<String, dynamic>? metadata,
  }) {
    return TrainDeparture(
      trainNumber: trainNumber,
      category: category,
      destination: destination,
      origin: origin,
      scheduledTime: scheduledTime,
      estimatedTime: estimatedTime,
      platform: platform,
      delayMinutes: delayMinutes,
      status: status,
      tripId: tripId,
      stops: stops ?? this.stops,
      country: country ?? this.country,
      metadata: metadata ?? this.metadata,
    );
  }
}

class TrainStop {
  final String stationName;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? estimatedArrival;
  final DateTime? estimatedDeparture;
  final int? delay;
  final int? arrivalDelay;
  final int? departureDelay;
  final String? platform;
  final String country; // Country code (IT, FR, DE, CH, AT, etc.)
  final bool cancelled; // whether this stop was cancelled (API: 'cancelled'/'canceled'/'status')

  TrainStop({
    required this.stationName,
    this.arrival,
    this.departure,
    this.estimatedArrival,
    this.estimatedDeparture,
    this.delay,
    this.arrivalDelay,
    this.departureDelay,
    this.platform,
    this.country = '',
    this.cancelled = false,
  });

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory TrainStop.fromJson(Map<String, dynamic> json) {
    return TrainStop(
      stationName: TrainDeparture._getStringValue(json['station'] ?? json['stop'] ?? json['stationName'] ?? json['name']) ?? '',
      arrival: _parse(json['scheduledArrival'] ?? json['arrival'] ?? json['arrivalTime'] ?? json['time']),
      departure: _parse(json['scheduledDeparture'] ?? json['departure'] ?? json['departureTime'] ?? json['time']),
      estimatedArrival: _parse(json['estimatedArrival'] ?? json['actualArrival'] ?? json['prognosis']?['arrival']),
      estimatedDeparture: _parse(json['estimatedDeparture'] ?? json['actualDeparture'] ?? json['prognosis']?['departure']),
      delay: _parseInt(json['delay'] ?? json['arrivalDelay'] ?? json['departureDelay'] ?? 0),
      arrivalDelay: _parseInt(json['arrivalDelay']),
      departureDelay: _parseInt(json['departureDelay']),
      platform: TrainDeparture._getStringValue(json['platform'] ?? json['actualPlatform'] ?? json['plannedPlatform']),
      country: TrainDeparture._getStringValue(json['country']) ?? '',
      cancelled: _parseBool(json['cancelled'] ?? json['canceled'] ?? json['isCancelled'] ?? json['cancel'] ?? json['status']),
    );
  }

  static bool _parseBool(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toString().toLowerCase();
      return s == '1' || s == 'true' || s == 'yes' || s == 'cancelled' || s == 'canceled' || s == 'annullata' || s == 'annullato' || s == 'cancel';
    }
    return false;
  }

  static DateTime? _parse(dynamic t) {
    if (t == null) return null;
    // Integer timestamps (seconds or milliseconds)
    if (t is int) {
      // Heuristic: values < 1e11 are seconds
      return (t < 100000000000) ? DateTime.fromMillisecondsSinceEpoch(t * 1000) : DateTime.fromMillisecondsSinceEpoch(t);
    }
    if (t is String) {
      final s = t.trim();
      // Numeric strings (epoch seconds or millis)
      final n = double.tryParse(s);
      if (n != null) {
        final ms = (n < 1e11) ? (n * 1000).toInt() : n.toInt();
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
      return DateTime.tryParse(s);
    }
    return null;
  }
}

class FALWarning {
  final String title;
  final String date;
  final String link;

  FALWarning({required this.title, required this.date, required this.link});

  factory FALWarning.fromJson(Map<String, dynamic> json) {
    return FALWarning(
      title: json['title'] ?? '',
      date: json['date'] ?? '',
      link: json['link'] ?? '',
    );
  }
}


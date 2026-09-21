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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'country': country,
      'type': type,
    };
  }
}

class TrainDeparture {
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
  final List<Map<String, dynamic>>? messages;
  final Map<String, dynamic>? polyline;
  final String? error;
  final String? operator;

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
    this.messages,
    this.polyline,
    this.error,
    this.operator,
  });

  factory TrainDeparture.fromJson(Map<String, dynamic> json, {bool isDeparture = true}) {
    // Check for nested 'data' or 'trip' fields which are common in TB API
    final Map<String, dynamic> actualData = (json['data'] is Map<String, dynamic>) 
        ? json['data'] 
        : (json['trip'] is Map<String, dynamic> ? json['trip'] : json);

    final String? lineStr = _getStringValue(actualData['line']);
    final String? numStr = _getStringValue(actualData['tripNumber'] ?? actualData['trainNumber']);
    String? num;

    // Il numero si ricava da 'tripNumber'/'trainNumber' tenendo solo le cifre
    // (es. line "S4" + tripNumber "5171" -> numero "5171", non "4").
    if (numStr != null) {
      final digitsOnly = numStr.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.isNotEmpty) num = digitsOnly;
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

    // parse trip-level messages if present
    List<Map<String, dynamic>>? tripMessages;
    final rawTripMsgs = actualData['messages'];
    if (rawTripMsgs is List && rawTripMsgs.isNotEmpty) {
      tripMessages = rawTripMsgs.map<Map<String, dynamic>>((e) => e is Map<String, dynamic> ? e : (e is Map ? Map<String, dynamic>.from(e) : {'text': e?.toString()})).toList();
    }

    Map<String, dynamic>? polylineData;
    if (actualData['polyline'] is Map<String, dynamic>) {
      polylineData = actualData['polyline'];
    }

    // La categoria si ricava dal primo token di 'line' tenendo solo le
    // lettere (es. "REG 4449" -> "REG"), tranne per le linee S-Bahn in
    // formato S{numero} dove il numero fa parte della linea e si tiene
    // (es. "S4" -> "S4"). Se non ci sono lettere (es. "8807") si ripiega
    // su 'category'/'type'.
    String? category;
    if (lineStr != null) {
      final firstToken = lineStr.trim().split(RegExp(r'\s+')).firstOrNull ?? '';
      final cleaned = firstToken.replaceAll(RegExp(r'[^A-Za-z0-9\-]'), '');
      final isSLine = RegExp(r'^S\d+$').hasMatch(cleaned);
      final picked = isSLine ? cleaned : cleaned.replaceAll(RegExp(r'\d'), '');
      if (picked.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(picked)) {
        category = picked;
      }
    }
    category ??= _getStringValue(actualData['category'] ?? actualData['type']);

    return TrainDeparture(
      trainNumber: num,
      category: category,
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
      messages: tripMessages,
      polyline: polylineData,
      operator: _getStringValue(actualData['operator']),
    );
  }

  static String? _getStringValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      if (value['name'] is String) return value['name'];
      if (value['text'] is String) return value['text'];
      if (value['id'] is String) return value['id'];
      if (value['stationName'] is String) return value['stationName'];
      
      // Fallback for nested maps or objects inside 'stop'
      return value.toString();
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

  Map<String, dynamic> toJson() {
    return {
      'trainNumber': trainNumber,
      'category': category,
      'destination': destination,
      'origin': origin,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'estimatedTime': estimatedTime?.toIso8601String(),
      'platform': platform,
      'delayMinutes': delayMinutes,
      'status': status,
      'tripId': tripId,
      'stops': stops?.map((stop) => stop.toJson()).toList(),
      'country': country,
      'metadata': metadata,
      'messages': messages,
      'polyline': polyline,
      'error': error,
      'operator': operator,
    };
  }

  TrainDeparture copyWith({
    String? origin,
    String? destination,
    List<TrainStop>? stops,
    String? country,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? polyline,
    String? error,
    bool clearError = false,
    int? delayMinutes,
    String? operator,
  }) {
    return TrainDeparture(
      trainNumber: trainNumber,
      category: category,
      destination: destination ?? this.destination,
      origin: origin ?? this.origin,
      scheduledTime: scheduledTime,
      estimatedTime: estimatedTime,
      platform: platform,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      status: status,
      tripId: tripId,
      stops: stops ?? this.stops,
      country: country ?? this.country,
      metadata: metadata ?? this.metadata,
      messages: messages,
      polyline: polyline ?? this.polyline,
      error: clearError ? null : (error ?? this.error),
      operator: operator ?? this.operator,
    );
  }
}

class TrainStop {
  final String? id; // Station ID for API calls
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
  final List<Map<String, dynamic>>? messages; // optional messages/alerts for this stop

  TrainStop({
    this.id,
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
    this.messages,
  });

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  factory TrainStop.fromJson(Map<String, dynamic> json) {
    return TrainStop(
      id: TrainDeparture._getStringValue(json['stationId'] ?? json['id'] ?? json['stop']?['id'] ?? json['stopId']),
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
      // Only treat explicit cancel flags as true. Avoid using generic 'status' or 'cancel' fields
      // which may contain unrelated status codes that would incorrectly mark stops as cancelled.
      cancelled: _parseBool(json['cancelled'] ?? json['canceled'] ?? json['isCancelled']),
      messages: (json['messages'] is List) ? (json['messages'] as List).map<Map<String, dynamic>>((e) => e is Map<String, dynamic> ? e : (e is Map ? Map<String, dynamic>.from(e) : {'text': e?.toString()})).toList() : null,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stationName': stationName,
      'arrival': arrival?.toIso8601String(),
      'departure': departure?.toIso8601String(),
      'estimatedArrival': estimatedArrival?.toIso8601String(),
      'estimatedDeparture': estimatedDeparture?.toIso8601String(),
      'delay': delay,
      'arrivalDelay': arrivalDelay,
      'departureDelay': departureDelay,
      'platform': platform,
      'country': country,
      'cancelled': cancelled,
      'messages': messages,
    };
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

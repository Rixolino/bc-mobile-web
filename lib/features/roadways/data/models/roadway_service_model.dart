class RoadwayOpeningHours {
  final bool allClosed;
  final bool singleOpening;
  final bool monoHour;
  final List<RoadwayDayOpening> days;

  RoadwayOpeningHours({
    required this.allClosed,
    required this.singleOpening,
    required this.monoHour,
    required this.days,
  });

  factory RoadwayOpeningHours.fromJson(Map<String, dynamic> json) {
    final daysJson = json['days'] as List? ?? [];
    return RoadwayOpeningHours(
      allClosed: json['allClosed'] == true,
      singleOpening: json['singleOpening'] == true,
      monoHour: json['monoHour'] == true || json['monohour'] == true,
      days: daysJson.map((d) => RoadwayDayOpening.fromJson(d as Map<String, dynamic>)).toList(),
    );
  }
}

class RoadwayDayOpening {
  final int day;
  final String dayName;
  final bool closed;
  final List<RoadwayTimeSlot> openings;

  RoadwayDayOpening({
    required this.day,
    required this.dayName,
    required this.closed,
    required this.openings,
  });

  factory RoadwayDayOpening.fromJson(Map<String, dynamic> json) {
    final openingsJson = json['openings'] as List? ?? [];
    // Support both adapted format (openings[]) and raw Italian format (startHour1/endHour1)
    if (openingsJson.isNotEmpty) {
      return RoadwayDayOpening(
        day: (json['day'] as num?)?.toInt() ?? 0,
        dayName: json['dayName']?.toString() ?? '',
        closed: json['closed'] == true,
        openings: openingsJson
            .map((o) => RoadwayTimeSlot.fromJson(o as Map<String, dynamic>))
            .toList(),
      );
    }
    final slots = <RoadwayTimeSlot>[];
    final s1 = json['startHour1']?.toString() ?? '';
    final e1 = json['endHour1']?.toString() ?? '';
    if (s1.isNotEmpty && e1.isNotEmpty) {
      slots.add(RoadwayTimeSlot(start: s1, end: e1));
    }
    final s2 = json['startHour2']?.toString() ?? '';
    final e2 = json['endHour2']?.toString() ?? '';
    if (s2.isNotEmpty && e2.isNotEmpty && (s2 != '00:00' || e2 != '00:00')) {
      slots.add(RoadwayTimeSlot(start: s2, end: e2));
    }
    return RoadwayDayOpening(
      day: (json['day'] as num?)?.toInt() ?? 0,
      dayName: json['dayName']?.toString() ?? '',
      closed: json['closed'] == true,
      openings: slots,
    );
  }
}

class RoadwayTimeSlot {
  final String start;
  final String end;

  RoadwayTimeSlot({required this.start, required this.end});

  factory RoadwayTimeSlot.fromJson(Map<String, dynamic> json) {
    return RoadwayTimeSlot(
      start: json['start']?.toString() ?? '',
      end: json['end']?.toString() ?? '',
    );
  }
}

class RoadwayServiceItem {
  final String code;
  final String name;
  final String nameEn;
  final int? total;
  final int? available;
  final int? unavailable;
  final int? order;
  final String? unavailableSince;
  final String? type;

  RoadwayServiceItem({
    required this.code,
    required this.name,
    required this.nameEn,
    this.total,
    this.available,
    this.unavailable,
    this.order,
    this.unavailableSince,
    this.type,
  });

  factory RoadwayServiceItem.fromJson(Map<String, dynamic> json) {
    return RoadwayServiceItem(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameEn: json['nameEn']?.toString() ?? '',
      total: (json['total'] as num?)?.toInt(),
      available: (json['available'] as num?)?.toInt(),
      unavailable: (json['unavailable'] as num?)?.toInt(),
      order: (json['order'] as num?)?.toInt(),
      unavailableSince: json['unavailableSince']?.toString(),
      type: json['type']?.toString(),
    );
  }
}

class RoadwayFuelPrice {
  final double price;
  final String? lastUpdate;

  RoadwayFuelPrice({
    required this.price,
    this.lastUpdate,
  });

  factory RoadwayFuelPrice.fromJson(Map<String, dynamic> json) {
    return RoadwayFuelPrice(
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      lastUpdate: json['lastUpdate']?.toString(),
    );
  }
}

class RoadwayBrand {
  final String type;
  final String source;
  final String name;
  final String nameSecond;
  final String id;
  final RoadwayOpeningHours? hours;
  final List<RoadwayServiceItem> services;

  RoadwayBrand({
    required this.type,
    required this.source,
    required this.name,
    required this.nameSecond,
    required this.id,
    this.hours,
    required this.services,
  });

  factory RoadwayBrand.fromJson(Map<String, dynamic> json) {
    final servicesJson = json['services'] as List? ?? [];
    return RoadwayBrand(
      type: json['type']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameSecond: json['nameSecond']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      hours: json['hours'] != null
          ? RoadwayOpeningHours.fromJson(json['hours'] as Map<String, dynamic>)
          : null,
      services: servicesJson
          .map((s) => RoadwayServiceItem.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class RoadwayParking {
  final int? carSpaces;
  final int? truckSpaces;
  final bool? isBlocked;

  RoadwayParking({
    this.carSpaces,
    this.truckSpaces,
    this.isBlocked,
  });

  factory RoadwayParking.fromJson(Map<String, dynamic> json) {
    return RoadwayParking(
      carSpaces: (json['carSpaces'] as num?)?.toInt(),
      truckSpaces: (json['truckSpaces'] as num?)?.toInt(),
      isBlocked: json['isBlocked'] == true,
    );
  }
}

/// Evento collegato a un'area di servizio (struttura adattata dal backend Node)
class RoadwayEvent {
  final String id;
  final String type;
  final int severity;
  final String title;
  final String titleEn;
  final String description;
  final String descriptionEn;
  final String cause;
  final String causeEn;
  final String? createdAt;
  final double latitude;
  final double longitude;

  RoadwayEvent({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.titleEn,
    required this.description,
    required this.descriptionEn,
    required this.cause,
    required this.causeEn,
    this.createdAt,
    required this.latitude,
    required this.longitude,
  });

  factory RoadwayEvent.fromJson(Map<String, dynamic> json) {
    // Supporta sia il formato adattato dal backend Node sia il raw italiano
    return RoadwayEvent(
      id: json['id']?.toString() ?? json['c_ele']?.toString() ?? '',
      type: json['type']?.toString() ?? json['f_eve_pre']?.toString() ?? '',
      severity: (json['severity'] as num?)?.toInt() ?? (json['n_wei'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? json['t_des_fra_it']?.toString() ?? '',
      titleEn: json['titleEn']?.toString() ?? json['t_des_fra_en']?.toString() ?? '',
      description: json['description']?.toString() ?? json['t_des_it']?.toString() ?? '',
      descriptionEn: json['descriptionEn']?.toString() ?? json['t_des_en']?.toString() ?? '',
      cause: json['cause']?.toString() ?? json['t_des_fra_cau_it']?.toString() ?? '',
      causeEn: json['causeEn']?.toString() ?? json['t_des_fra_cau_en']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ??
          (json['d_agg'] != null ? json['d_agg'].toString() : null),
      latitude: (json['latitude'] as num?)?.toDouble() ??
          (json['n_crd_lat'] as num?)?.toDouble() ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          (json['n_crd_lon'] as num?)?.toDouble() ??
          0.0,
    );
  }
}

class RoadwayAreaService {
  final String id;
  final String code;
  final String name;
  final double lat;
  final double lon;
  final String highway;
  final String highwayDescription;
  final String direction;
  final String directionCode;
  final String from;
  final String to;
  final double km;
  final String type;
  final bool aspi;
  final String region;
  final List<String> availableFuels;
  final Map<String, RoadwayFuelPrice> fuelPrices;
  final RoadwayParking? parking;
  final List<RoadwayServiceItem> services;
  final List<RoadwayBrand> brands;
  final List<RoadwayEvent> events;
  final String descriptionAdsPmr;

  RoadwayAreaService({
    required this.id,
    required this.code,
    required this.name,
    required this.lat,
    required this.lon,
    required this.highway,
    required this.highwayDescription,
    required this.direction,
    required this.directionCode,
    required this.from,
    required this.to,
    required this.km,
    required this.type,
    required this.aspi,
    required this.region,
    required this.availableFuels,
    required this.fuelPrices,
    this.parking,
    required this.services,
    required this.brands,
    required this.events,
    required this.descriptionAdsPmr,
  });

  /// Brand carburante (type OIL / simili)
  String get fuelBrand {
    final oil = brands.where((b) {
      final t = b.type.toUpperCase();
      return t == 'OIL' || t.contains('FUEL') || t.contains('CARB');
    });
    if (oil.isEmpty) return '';
    return oil.first.name;
  }

  /// Brand ristorazione / food
  List<String> get foodBrands {
    return brands
        .where((b) {
          final t = b.type.toUpperCase();
          return t == 'FOOD' ||
              t.contains('RIST') ||
              t.contains('FOOD') ||
              t.contains('BAR') ||
              t.contains('RESTAURANT');
        })
        .map((b) => b.name)
        .where((n) => n.isNotEmpty)
        .toList();
  }

  factory RoadwayAreaService.fromJson(Map<String, dynamic> json) {
    final fuelPricesJson = json['fuelPrices'] as Map<String, dynamic>? ?? {};
    final servicesJson = json['services'] as List? ?? [];
    final brandsJson = json['brands'] as List? ?? [];
    final eventsJson = json['events'] as List? ?? [];

    return RoadwayAreaService(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      highway: json['highway']?.toString() ?? '',
      highwayDescription: json['highwayDescription']?.toString() ?? '',
      direction: json['direction']?.toString() ?? '',
      directionCode: json['directionCode']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      km: (json['km'] as num?)?.toDouble() ?? 0.0,
      type: json['type']?.toString() ?? 'ADS',
      aspi: json['aspi'] == true,
      region: json['region']?.toString() ?? '',
      availableFuels:
          (json['availableFuels'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      fuelPrices: fuelPricesJson.map(
        (key, value) => MapEntry(
          key,
          RoadwayFuelPrice.fromJson(value as Map<String, dynamic>),
        ),
      ),
      parking: json['parking'] != null
          ? RoadwayParking.fromJson(json['parking'] as Map<String, dynamic>)
          : null,
      services: servicesJson
          .map((s) => RoadwayServiceItem.fromJson(s as Map<String, dynamic>))
          .toList(),
      brands: brandsJson
          .map((b) => RoadwayBrand.fromJson(b as Map<String, dynamic>))
          .toList(),
      events: eventsJson
          .map((e) => RoadwayEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      descriptionAdsPmr: json['descriptionAdsPmr']?.toString() ?? '',
    );
  }
}
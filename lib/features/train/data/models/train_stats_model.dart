class TrainGeneralStats {
  final String stationName;
  final int totalTrains;
  final int averageDelay;
  final int onTimePercentage;
  final List<dynamic> hourlyDistribution;

  TrainGeneralStats({
    required this.stationName,
    required this.totalTrains,
    required this.averageDelay,
    required this.onTimePercentage,
    required this.hourlyDistribution,
  });

  factory TrainGeneralStats.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] ?? {};
    return TrainGeneralStats(
      stationName: json['stationName'] ?? 'Stazione',
      totalTrains: stats['totalTrains'] ?? 0,
      averageDelay: stats['averageDelay'] ?? 0,
      onTimePercentage: stats['onTimePercentage'] ?? 0,
      hourlyDistribution: stats['hourlyDistribution'] ?? [],
    );
  }
}

// ============================================================================
// NUOVI MODELLI: STATISTICHE DEL SINGOLO TRENO (REPORT COMPORTAMENTALE)
// ============================================================================

class TrainBehavioralReport {
  final String category;
  final String tripNumber;
  final RevolutionaryMetrics metrics;
  final OperationalInsights insights;
  final List<DailyBreakdown> dailyBreakdown;
  final CommonRoute? commonRoute;
  final List<StopAnalytics> stopsAnalytics;

  TrainBehavioralReport({
    required this.category,
    required this.tripNumber,
    required this.metrics,
    required this.insights,
    required this.dailyBreakdown,
    this.commonRoute,
    this.stopsAnalytics = const [],
  });

  factory TrainBehavioralReport.fromJson(Map<String, dynamic> json) {
    final trainData = json['train'] ?? {};
    return TrainBehavioralReport(
      category: trainData['category'] ?? '',
      tripNumber: trainData['tripNumber'] ?? '',
      metrics: RevolutionaryMetrics.fromJson(json['revolutionaryMetrics'] ?? {}),
      insights: OperationalInsights.fromJson(json['operational_insights'] ?? {}),
      dailyBreakdown: (json['dailyBreakdown'] as List?)
              ?.map((e) => DailyBreakdown.fromJson(e))
              .toList() ??
          [],
      commonRoute: json['commonRoute'] != null ? CommonRoute.fromJson(json['commonRoute']) : null,
      stopsAnalytics: (json['stopsAnalytics'] as List?)?.map((e) => StopAnalytics.fromJson(e)).toList() ?? [],
    );
  }
}

class RevolutionaryMetrics {
  final int reliabilityScore; // Estratto da "73/100" a 73
  final String behaviorTrend;
  final int averageNetDelayChangeMinutes;
  final int maxAbsoluteDelayMinutes;
  final String criticalStation;
  final String criticalDate;
  final int cancellationRatePercentage;
  final int totalTripsAnalyzed;

  RevolutionaryMetrics({
    required this.reliabilityScore,
    required this.behaviorTrend,
    required this.averageNetDelayChangeMinutes,
    required this.maxAbsoluteDelayMinutes,
    required this.criticalStation,
    required this.criticalDate,
    required this.cancellationRatePercentage,
    required this.totalTripsAnalyzed,
  });

  factory RevolutionaryMetrics.fromJson(Map<String, dynamic> json) {
    int parsedScore = 100;
    if (json['reliabilityScore'] != null) {
      final parts = json['reliabilityScore'].toString().split('/');
      if (parts.isNotEmpty) {
        parsedScore = int.tryParse(parts[0]) ?? 100;
      }
    }

    final hist = json['historicalRecords'] ?? {};
    return RevolutionaryMetrics(
      reliabilityScore: parsedScore,
      behaviorTrend: json['behaviorTrend'] ?? 'N/D',
      averageNetDelayChangeMinutes: json['averageNetDelayChangeMinutes'] ?? 0,
      maxAbsoluteDelayMinutes: hist['maxAbsoluteDelayMinutes'] ?? 0,
      criticalStation: hist['criticalStation'] ?? 'N/D',
      criticalDate: hist['criticalDate'] ?? 'N/D',
      cancellationRatePercentage: json['cancellationRatePercentage'] ?? 0,
      totalTripsAnalyzed: json['totalTripsAnalyzed'] ?? 0,
    );
  }
}

class OperationalInsights {
  final String worstDayOfWeek;
  final String criticalBottleneckStation;
  final String recentPerformanceTrend;
  final int currentDelayStreakDays;

  OperationalInsights({
    required this.worstDayOfWeek,
    required this.criticalBottleneckStation,
    required this.recentPerformanceTrend,
    required this.currentDelayStreakDays,
  });

  factory OperationalInsights.fromJson(Map<String, dynamic> json) {
    return OperationalInsights(
      worstDayOfWeek: json['worst_day_of_week'] ?? 'N/D',
      criticalBottleneckStation: json['critical_bottleneck_station'] ?? 'N/D',
      recentPerformanceTrend: json['recent_performance_trend'] ?? 'N/D',
      currentDelayStreakDays: json['current_delay_streak_days'] ?? 0,
    );
  }
}

class DailyBreakdown {
  final String date;
  final String status;
  final int averageDelayMinutes;
  final int maxDelayReached;
  final int netDelayChangeMinutes;
  final String behaviorDescription;
  final List<StationItinerary> itinerary;

  DailyBreakdown({
    required this.date,
    required this.status,
    required this.averageDelayMinutes,
    required this.maxDelayReached,
    required this.netDelayChangeMinutes,
    required this.behaviorDescription,
    required this.itinerary,
  });

  factory DailyBreakdown.fromJson(Map<String, dynamic> json) {
    final analytics = json['analytics'] ?? {};
    return DailyBreakdown(
      date: json['date'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      averageDelayMinutes: analytics['averageDelayMinutes'] ?? 0,
      maxDelayReached: analytics['maxDelayReached'] ?? 0,
      netDelayChangeMinutes: analytics['netDelayChangeMinutes'] ?? 0,
      behaviorDescription: analytics['behaviorDescription'] ?? '',
      itinerary: (json['itinerary'] as List?)
              ?.map((e) => StationItinerary.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class StationItinerary {
  final String stationId;
  final String stationName;
  final TrainEvent? arrival;
  final TrainEvent? departure;

  StationItinerary({
    required this.stationId,
    required this.stationName,
    this.arrival,
    this.departure,
  });

  factory StationItinerary.fromJson(Map<String, dynamic> json) {
    return StationItinerary(
      stationId: json['stationId'] ?? '',
      stationName: json['stationName'] ?? '',
      arrival: json['arrival'] != null ? TrainEvent.fromJson(json['arrival']) : null,
      departure: json['departure'] != null ? TrainEvent.fromJson(json['departure']) : null,
    );
  }
}

class TrainEvent {
  final String scheduledTime;
  final int delay;
  final String platform;
  final bool platformChanged;
  final String status;

  TrainEvent({
    required this.scheduledTime,
    required this.delay,
    required this.platform,
    required this.platformChanged,
    required this.status,
  });

  factory TrainEvent.fromJson(Map<String, dynamic> json) {
    return TrainEvent(
      scheduledTime: json['scheduledTime'] ?? '',
      delay: json['delay'] ?? 0,
      platform: json['platform'] ?? '',
      platformChanged: json['platformChanged'] ?? false,
      status: json['status'] ?? '',
    );
  }
}
class CommonRoute {
  final Map<String, dynamic>? polyline;
  final List<dynamic>? stops;

  CommonRoute({this.polyline, this.stops});

  factory CommonRoute.fromJson(Map<String, dynamic>? json) {
    if (json == null) return CommonRoute();
    return CommonRoute(
      polyline: json['polyline'],
      stops: json['stops'],
    );
  }
}

class StopAnalytics {
  final String stationName;
  final String stationId;
  final int totalLogs;
  final int cancellationRate;
  final int averageDelay;

  StopAnalytics({
    required this.stationName,
    required this.stationId,
    required this.totalLogs,
    required this.cancellationRate,
    required this.averageDelay,
  });

  factory StopAnalytics.fromJson(Map<String, dynamic> json) {
    return StopAnalytics(
      stationName: json['stationName'] ?? '',
      stationId: json['stationId'] ?? '',
      totalLogs: json['totalLogs'] ?? 0,
      cancellationRate: json['cancellationRate'] ?? 0,
      averageDelay: json['averageDelay'] ?? 0,
    );
  }
}

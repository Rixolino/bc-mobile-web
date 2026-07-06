class TrainGeneralStats {
  final String stationName; // <-- Ora è definito
  final int totalTrains;
  final int averageDelay;
  final int onTimePercentage;
  final List<dynamic> hourlyDistribution; // <-- Ora è definito

  TrainGeneralStats({
    required this.stationName,
    required this.totalTrains,
    required this.averageDelay,
    required this.onTimePercentage,
    required this.hourlyDistribution,
  });

  factory TrainGeneralStats.fromJson(Map<String, dynamic> json) {
    // Gestione sicura dei dati
    final stats = json['stats'] ?? {};
    return TrainGeneralStats(
      stationName: json['stationName'] ?? 'Stazione Sconosciuta',
      totalTrains: stats['totalTrains'] ?? 0,
      averageDelay: stats['averageDelay'] ?? 0,
      onTimePercentage: stats['onTimePercentage'] ?? 0,
      hourlyDistribution: stats['hourlyDistribution'] ?? [],
    );
  }
}
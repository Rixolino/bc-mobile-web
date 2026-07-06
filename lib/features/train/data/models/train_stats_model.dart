class TrainGeneralStats {
  final String stationName;
  final int totalTrains;
  final int averageDelay;
  final int onTimePercentage;
  final List<dynamic> hourlyDistribution; // AGGIUNTO

  TrainGeneralStats({
    required this.stationName,
    required this.totalTrains,
    required this.averageDelay,
    required this.onTimePercentage,
    required this.hourlyDistribution, // AGGIUNTO
  });

  factory TrainGeneralStats.fromJson(Map<String, dynamic> json) {
    // Nota: Assicurati che 'stats' contenga questi campi come da server.js
    final stats = json['stats'] ?? {};
    return TrainGeneralStats(
      stationName: json['stationName'] ?? 'Stazione',
      totalTrains: stats['totalTrains'] ?? 0,
      averageDelay: stats['averageDelay'] ?? 0,
      onTimePercentage: stats['onTimePercentage'] ?? 0,
      hourlyDistribution: stats['hourlyDistribution'] ?? [], // AGGIUNTO
    );
  }
}
class RoadwayToll {
  final String companyName;
  final String category;
  final double rate;

  RoadwayToll({
    required this.companyName,
    required this.category,
    required this.rate,
  });

  factory RoadwayToll.fromJson(Map<String, dynamic> json) {
    return RoadwayToll(
      companyName: json['nome'] ?? '',
      category: json['tDesCla'] ?? '',
      rate: (json['tarP'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

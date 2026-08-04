class RoadwayNews {
  final String date;
  final String location;
  final String title;
  final String direction;
  final String description;

  RoadwayNews({
    required this.date,
    required this.location,
    required this.title,
    required this.direction,
    required this.description,
  });

  factory RoadwayNews.fromJson(Map<String, dynamic> json) {
    return RoadwayNews(
      date: json['date'] ?? '',
      location: json['location'] ?? '',
      title: json['title'] ?? '',
      direction: json['direction'] ?? '',
      description: json['description'] ?? '',
    );
  }
}

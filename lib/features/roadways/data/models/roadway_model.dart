class RoadwayModel {
  final String id;
  final String name;
  final String description;
  final bool isOpen;

  RoadwayModel({
    required this.id,
    required this.name,
    required this.description,
    required this.isOpen,
  });

  factory RoadwayModel.fromJson(Map<String, dynamic> json) {
    return RoadwayModel(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      isOpen: json['isOpen'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'isOpen': isOpen,
    };
  }
}

import 'package:flutter/material.dart';

class RoadwayListItem extends StatelessWidget {
  final String name;
  final String description;
  final bool isOpen;

  const RoadwayListItem({
    super.key,
    required this.name,
    required this.description,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(name),
      subtitle: Text(description),
      trailing: Icon(
        isOpen ? Icons.check_circle : Icons.error,
        color: isOpen ? Colors.green : Colors.red,
      ),
      onTap: () {
        // Azione al click
      },
    );
  }
}

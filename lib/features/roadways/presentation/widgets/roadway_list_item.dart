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
    // Solo layout responsive: in landscape rende la riga più densa
    // per sfruttare la larghezza senza alterare logica o navigazione.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 900 : double.infinity,
        ),
        child: ListTile(
          dense: isLandscape,
          visualDensity: isLandscape
              ? VisualDensity.compact
              : VisualDensity.standard,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isLandscape ? 12 : 16,
            vertical: isLandscape ? 2 : 4,
          ),
          title: Text(
            name,
            maxLines: isLandscape ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            description,
            maxLines: isLandscape ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
      trailing: Icon(
        isOpen ? Icons.check_circle : Icons.error,
        color: isOpen ? Colors.green : Colors.red,
      ),
      onTap: () {
        // Azione al click
      },
        ),
      ),
    );
  }
}

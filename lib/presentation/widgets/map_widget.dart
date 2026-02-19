import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/map_state_provider.dart';
import '../providers/theme_provider.dart';
import 'map_background.dart';

class MapWidget extends StatefulWidget {
  final bool showControls; // Mostra controlli zoom, location, etc.
  final bool interactive; // Se la mappa è interattiva
  final double? height; // Altezza specifica, null = fullscreen
  final EdgeInsets? margin; // Margini attorno alla mappa

  const MapWidget({
    super.key,
    this.showControls = true,
    this.interactive = true,
    this.height,
    this.margin,
  });

  @override
  State<MapWidget> createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final mapState = Provider.of<MapStateProvider>(context);

    Widget mapContent = MapBackground();

    // Se non è fullscreen, wrappa in un container con altezza specifica
    if (widget.height != null) {
      mapContent = SizedBox(
        height: widget.height,
        child: mapContent,
      );
    }

    // Aggiungi controlli se richiesti
    if (widget.showControls && widget.interactive) {
      mapContent = Stack(
        children: [
          mapContent,
          // Controlli mappa (zoom, location, etc.)
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsante zoom in
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.surfaceColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.add, size: 20, color: theme.textColor),
                    onPressed: () {
                      // Implementa zoom in usando flyTo con posizione corrente
                      final newZoom = (mapState.zoom + 1).clamp(1.0, 20.0);
                      mapState.flyTo(mapState.lat, mapState.lng, zoom: newZoom);
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                // Pulsante zoom out
                Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: theme.surfaceColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.remove, size: 20, color: theme.textColor),
                    onPressed: () {
                      // Implementa zoom out usando flyTo con posizione corrente
                      final newZoom = (mapState.zoom - 1).clamp(1.0, 20.0);
                      mapState.flyTo(mapState.lat, mapState.lng, zoom: newZoom);
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
                // Pulsante location
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.surfaceColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.my_location, size: 20, color: theme.textColor),
                    onPressed: () {
                      // Implementa center on location
                      // Questo richiederebbe accesso alla posizione GPS
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Aggiungi margini se specificati
    if (widget.margin != null) {
      mapContent = Padding(
        padding: widget.margin!,
        child: mapContent,
      );
    }

    return mapContent;
  }
}
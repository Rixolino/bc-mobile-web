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
    // Solo layout: adatta densità e safe-area in landscape.
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;
    final safeRight = media.padding.right;
    final safeBottom = media.padding.bottom;
    final buttonSize = isLandscape ? 40.0 : 44.0;
    final controlsOffsetRight = isLandscape ? 8.0 + safeRight : 16.0;
    final controlsOffsetBottom = isLandscape ? 8.0 + safeBottom : 16.0;

    Widget mapContent = MapBackground();

    // Se non è fullscreen, wrappa in un container con altezza specifica
    // In landscape vincola l'altezza alla viewport per evitare overflow.
    if (widget.height != null) {
      mapContent = LayoutBuilder(
        builder: (context, constraints) {
          final maxH = MediaQuery.of(context).size.height;
          final targetH = isLandscape
              ? widget.height!.clamp(0.0, (maxH * 0.85).clamp(200.0, 600.0))
              : widget.height!;
          return SizedBox(
            height: targetH,
            child: mapContent,
          );
        },
      );
    }

    // Aggiungi controlli se richiesti
    if (widget.showControls && widget.interactive) {
      mapContent = Stack(
        children: [
          mapContent,
          // Controlli mappa (zoom, location, etc.)
          // In landscape: compatti, con safe-area e layout orizzontale salvaspazio.
          Positioned(
            right: controlsOffsetRight,
            bottom: controlsOffsetBottom,
            child: isLandscape
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _mapControlButton(
                        theme: theme,
                        size: buttonSize,
                        icon: Icons.add,
                        onPressed: () {
                          final newZoom = (mapState.zoom + 1).clamp(1.0, 20.0);
                          mapState.flyTo(mapState.lat, mapState.lng, zoom: newZoom);
                        },
                      ),
                      const SizedBox(width: 8),
                      _mapControlButton(
                        theme: theme,
                        size: buttonSize,
                        icon: Icons.remove,
                        onPressed: () {
                          final newZoom = (mapState.zoom - 1).clamp(1.0, 20.0);
                          mapState.flyTo(mapState.lat, mapState.lng, zoom: newZoom);
                        },
                      ),
                      const SizedBox(width: 8),
                      _mapControlButton(
                        theme: theme,
                        size: buttonSize,
                        icon: Icons.my_location,
                        onPressed: () {},
                      ),
                    ],
                  )
                : Column(
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

    return SafeArea(
      left: isLandscape,
      right: isLandscape,
      top: false,
      bottom: false,
      child: mapContent,
    );
  }

  // Solo layout: bottone compatto riusabile per i controlli in landscape.
  Widget _mapControlButton({
    required ThemeProvider theme,
    required double size,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18, color: theme.textColor),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
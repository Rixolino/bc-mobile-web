import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../features/bus/presentation/providers/bus_provider.dart';
import '../../features/plane/presentation/providers/plane_provider.dart';
import '../providers/map_state_provider.dart';
import '../providers/theme_provider.dart';

/// Widget che gestisce la visualizzazione della mappa con salvataggio automatico della posizione.
///
/// Funzionalità:
/// - ✅ Salvataggio automatico durante il movimento della mappa (onPositionChanged)
/// - ✅ Salvataggio quando l'app cambia orientamento o viene distrutta
/// - ✅ Marker dinamici per bus e aerei con colori e rotazione
/// - ✅ Posizione caricata dall'ultimo accesso all'app
class MapBackground extends StatefulWidget {
  const MapBackground({super.key});

  @override
  State<MapBackground> createState() => _MapBackgroundState();
}

class _MapBackgroundState extends State<MapBackground> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final MapController _mapController;
  MapStateProvider? _mapStateProvider;
  bool _initialPositionSet = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    // Aggiungi observer per il lifecycle
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapStateProvider = Provider.of<MapStateProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // Rimuovi observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Forza il salvataggio della posizione corrente prima di distruggere il widget
    _mapStateProvider?.saveCurrentPosition();
    _mapController.dispose();
    super.dispose();
  }

  Color _stringToColor(String str) {
    int hash = 0;
    for (int i = 0; i < str.length; i++) {
      hash = str.codeUnitAt(i) + ((hash << 5) - hash);
    }
    final int colorInt = (hash & 0x00FFFFFF) + 0xFF000000;
    return Color(colorInt);
  }

  @override
  Widget build(BuildContext context) {
    final mapState = context.watch<MapStateProvider>();
    final busProvider = context.watch<BusProvider>();
    final planeProvider = context.watch<PlaneProvider>();

    // Gestione posizione iniziale dopo il caricamento delle preferenze
    if (mapState.isLoaded && !_initialPositionSet) {
      _initialPositionSet = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(mapState.lat, mapState.lng),
          mapState.zoom
        );
      });
    }

    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(mapState.lat, mapState.lng),
        initialZoom: mapState.zoom,
        backgroundColor: theme.surfaceColor,
        onPositionChanged: (position, hasGesture) {
          // Salva sempre la posizione, sia per gesture manuali che cambiamenti programmatici
          mapState.updatePosition(
            position.center.latitude, 
            position.center.longitude, 
            position.zoom
          );
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/${mapState.mapStyle}/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiY3V6aW1tYXJ0aW4iLCJhIjoiY204dGRyb3AxMDgxcDJrc2VjeXVwNXN3NyJ9.VR8xzsuQJ_-0h95CN_UD8g',
          userAgentPackageName: 'dev.iscool.bctransporter',
        ),
        // Bus Markers
        if (mapState.activeCategory == 1)
          MarkerLayer(
            markers: busProvider.vehicles.map((v) {
              final color = _stringToColor(v.line);
              return Marker(
                point: LatLng(v.latitude, v.longitude),
                width: 32,
                height: 32,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.surfaceColor, width: 2),
                    boxShadow: [
                      BoxShadow(color: theme.textColor.withOpacity(0.12), blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      v.line,
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: theme.textColor.withOpacity(0.18), blurRadius: 1, offset: Offset(1, 1))],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        // Plane Markers
        if (mapState.activeCategory == 2)
          MarkerLayer(
            markers: planeProvider.flights.where((f) => f.latitude != null && f.longitude != null).map((f) {
              final heading = f.heading ?? 0.0;
              return Marker(
                point: LatLng(f.latitude!, f.longitude!),
                width: 36,
                height: 36,
                child: Transform.rotate(
                  angle: (heading * 3.14159265359 / 180), // Convert degrees to radians
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.surfaceColor, width: 2),
                      boxShadow: [
                        BoxShadow(color: theme.textColor.withOpacity(0.12), blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Center(
                      child: Icon(Icons.flight, color: theme.textColor, size: 18),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

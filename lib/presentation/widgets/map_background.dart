import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../features/bus/presentation/providers/bus_provider.dart';
import '../../features/bus/data/models/bus_model.dart';
import '../../features/bus/presentation/widgets/bus_details_sheet.dart';
import '../../features/bus/presentation/widgets/bus_stop_details_sheet.dart';
import '../../features/plane/presentation/providers/plane_provider.dart';
import '../providers/map_state_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/settings_provider.dart';

/// Widget che gestisce la visualizzazione della mappa con salvataggio automatico della posizione.
///
/// Funzionalità:
/// - ✅ Salvataggio automatico durante il movimento della mappa (onPositionChanged)
/// - ✅ Salvataggio quando l'app cambia orientamento o viene distrutta
/// - ✅ Marker dinamici per bus e aerei con colori e rotazione
/// - ✅ Posizione caricata dall'ultimo accesso all'app
class MapBackground extends StatefulWidget {
  final BusVehicle? selectedBus; // Optional: show only this bus
  
  const MapBackground({super.key, this.selectedBus});

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

  void _showStopInfo(BuildContext context, BariStop stop) {
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    busProvider.selectStop(stop);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BusStopDetailsSheet(stop: stop)),
    );
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
    // Lo stile viene dal SettingsProvider (URL completo) convertito in
    // style-id corto per i tile raster; il watch lo riapplica dal vivo.

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

    // Gestione flyTo quando richiesto
    if (mapState.shouldFlyTo) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(
          LatLng(mapState.lat, mapState.lng),
          mapState.zoom
        );
        // Reset the flyTo flag
        mapState.resetFlyTo();
      });
    }

    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final mapStyleId = context.watch<SettingsProvider>().shortMapStyleId;
    // Solo layout/responsive: in landscape marker più compatti per evitare clutter.
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final busMarkerSize = isLandscape ? 28.0 : 32.0;
    final stopMarkerSize = isLandscape ? 20.0 : 24.0;
    final planeMarkerSize = isLandscape ? 32.0 : 36.0;
    final planeIconSize = isLandscape ? 16.0 : 18.0;
    
    // Build the map widget
    final mapWidget = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(mapState.lat, mapState.lng),
        initialZoom: mapState.zoom,
        backgroundColor: theme.surfaceColor,
        // Tastiera disabilitata: le frecce restano al cursore TV,
        // la mappa si muove con tap/drag del cursore.
        interactionOptions: const InteractionOptions(
          keyboardOptions: KeyboardOptions.disabled(),
        ),
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
          urlTemplate: 'https://api.mapbox.com/styles/v1/mapbox/$mapStyleId/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiY3V6aW1tYXJ0aW4iLCJhIjoiY204dGRyb3AxMDgxcDJrc2VjeXVwNXN3NyJ9.VR8xzsuQJ_-0h95CN_UD8g',
          userAgentPackageName: 'dev.iscool.bctransporter',
        ),
        // Bus Route Path - show when a bus is selected and route path is available
        if (mapState.activeCategory == 1 && (widget.selectedBus != null || busProvider.selectedBus != null) && busProvider.selectedBusRoutePath != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: busProvider.selectedBusRoutePath!.pathCoordinates,
                color: _stringToColor((widget.selectedBus ?? busProvider.selectedBus)!.line),
                strokeWidth: 4.0,
                borderColor: theme.surfaceColor,
                borderStrokeWidth: 2.0,
              ),
            ],
          ),
        // Bus Markers
        if (mapState.activeCategory == 1) ...[
          Consumer<SettingsProvider>(
            builder: (context, settings, child) {
              // Create bus markers list
              final busMarkers = busProvider.vehicles.where((v) {
                final selectedBus = widget.selectedBus ?? busProvider.selectedBus;
                return selectedBus == null || v.id == selectedBus.id;
              }).map((v) {
                final color = _stringToColor(v.line);
                return Marker(
                  point: LatLng(v.latitude, v.longitude),
                  width: busMarkerSize,
                  height: busMarkerSize,
                  child: GestureDetector(
                    onTap: () async {
                      // Solo gli autobus live position possono essere selezionati per aprire i dettagli
                      if (busProvider.selectedStop != null) {
                        final mapState = Provider.of<MapStateProvider>(context, listen: false);
                        mapState.flyTo(v.latitude, v.longitude, zoom: 15);
                        await busProvider.selectBus(v);
                        if (context.mounted) {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => BusDetailsSheet(bus: v)),
                          );
                        }
                      }
                      // Se non c'è fermata selezionata, non fare nulla (autobus non selezionabile)
                    },
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
                  ),
                );
              }).toList();

              // Create stop markers list (for all providers that support stops)
              final stopMarkers = busProvider.stops.where((stop) {
                // In focus mode (selected bus with route path), show only stops belonging to the route
                final selectedBus = widget.selectedBus ?? busProvider.selectedBus;
                if (selectedBus != null && busProvider.selectedBusRoutePath != null) {
                  return busProvider.selectedBusRoutePath!.stopIds.contains(stop.stopId);
                }
                // Otherwise show all stops
                return true;
              }).map((stop) {
                return Marker(
                  point: LatLng(stop.latitude, stop.longitude),
                  width: stopMarkerSize,
                  height: stopMarkerSize,
                  child: GestureDetector(
                    onTap: () => _showStopInfo(context, stop),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.8),
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.surfaceColor, width: 2),
                        boxShadow: [
                          BoxShadow(color: theme.textColor.withOpacity(0.12), blurRadius: 2, offset: Offset(0, 1)),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.location_on,
                          color: theme.textColor,
                          size: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList();

              // Create separate layers for buses and stops with independent clustering
              final layers = <Widget>[];

              // Stop markers layer (added first, rendered below)
              if (stopMarkers.isNotEmpty) {
                if (settings.stopsClusteringEnabled) {
                  layers.add(MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      markers: stopMarkers,
                      builder: (context, markers) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.surfaceColor, width: 2),
                            boxShadow: [
                              BoxShadow(color: theme.textColor.withOpacity(0.12), blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              markers.length.toString(),
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ));
                } else {
                  layers.add(MarkerLayer(markers: stopMarkers));
                }
              }

              // Bus markers layer (added last, rendered on top)
              if (busMarkers.isNotEmpty) {
                if (settings.busClusteringEnabled) {
                  layers.add(MarkerClusterLayerWidget(
                    options: MarkerClusterLayerOptions(
                      markers: busMarkers,
                      builder: (context, markers) {
                        return Container(
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.8),
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.surfaceColor, width: 2),
                            boxShadow: [
                              BoxShadow(color: theme.textColor.withOpacity(0.12), blurRadius: 4, offset: Offset(0, 2)),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              markers.length.toString(),
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ));
                } else {
                  layers.add(MarkerLayer(markers: busMarkers));
                }
              }

              return Stack(children: layers);
            },
          ),
        ],
        // Plane Markers
        if (mapState.activeCategory == 2)
          MarkerLayer(
            markers: planeProvider.flights.where((f) => f.latitude != null && f.longitude != null).map((f) {
              final heading = f.heading ?? 0.0;
              return Marker(
                point: LatLng(f.latitude!, f.longitude!),
                width: planeMarkerSize,
                height: planeMarkerSize,
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
                      child: Icon(Icons.flight, color: theme.textColor, size: planeIconSize),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );

    // Return Stack with map and optional details sheet
    return Stack(
      children: [
        // Map
        mapWidget,
        
        // Bus Details - navigate to full screen when a bus is selected
        if (busProvider.selectedBus != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.shrink(),
              ),
            ),
          ),

        // Stop Details - navigate to full screen when a stop is selected AND no bus is selected
        if (busProvider.selectedStop != null && busProvider.selectedBus == null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                color: Colors.transparent,
                child: const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}

import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../data/models/train_model.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../providers/train_provider.dart';

const String _kMapboxAccessToken = 'pk.eyJ1IjoiY3V6aW1tYXJ0aW4iLCJhIjoiY204dGRyb3AxMDgxcDJrc2VjeXVwNXN3NyJ9.VR8xzsuQJ_-0h95CN_UD8g';

class TrainMapPage extends StatefulWidget {
  final TrainDeparture departure;
  final bool isArrivalMode;
  final int currentDelay;

  const TrainMapPage({
    super.key, 
    required this.departure,
    this.isArrivalMode = false,
    this.currentDelay = 0,
  });

  @override
  State<TrainMapPage> createState() => _TrainMapPageState();
}

class _TrainMapPageState extends State<TrainMapPage> {
  late final WebViewController _webViewController;
  
  // MultiLineString for Mapbox: List<List<[lng, lat]>>
  List<List<List<double>>> _processedMultiLine = [];
  
  // Stops logic map for interpolation
  List<Map<String, dynamic>> _stopLogics = [];
  
  LatLng? _currentTrainPos;
  
  bool _isLoading = true;
  bool _isMapReady = false;
  String _statusMessage = 'Caricamento mappa...';
  
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadData();
    _setupAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    // remove listener to avoid leaks
    Provider.of<SettingsProvider>(context, listen: false).removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _initWebView() {
    // Listener invoked when settings change (for map style).
    // defined here so it can access _webViewController and _isMapReady.
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    // Map style comes directly from settings (a Mapbox style URL).
    // provider may still contain an old string, normalize it explicitly in case
    // the value hasn't been rewritten yet. log for debugging.
    String mapStyleUrl = SettingsProvider.normalizeStyleUrl(settings.mapStyle);
    if (mapStyleUrl.isEmpty) {
      mapStyleUrl = 'mapbox://styles/mapbox/dark-v11';
    }
    debugPrint('TrainMapPage using styleUrl: $mapStyleUrl');

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(theme.backgroundColor)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
             _isMapReady = true;
             _redrawMap();
          },
        ),
      )
      ..addJavaScriptChannel(
        'flutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'map_ready') {
             _isMapReady = true;
             _redrawMap();
          }
        },
      )
      ..loadHtmlString(_getHtmlContent(mapStyleUrl));

    // apply future style changes if user updates settings while page open
    settings.addListener(_onSettingsChanged);
  }

  /// Loads Trip Polyline and Details from Backend
  Future<void> _loadData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _isLoading = true);
    
    try {
      final tripId = widget.departure.tripId;
      if (tripId == null) throw Exception("Trip ID mancante");
      
      // NEW SERVER-SIDE API
      final url = Uri.parse('http://betacloud-transporter.is-cool.dev/api/track-trip/${Uri.encodeComponent(tripId)}');
      debugPrint("Fetching trip track: $url");
      
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _parseProcessedTripResponse(data);
        if (mounted) setState(() => _statusMessage = "Posizione aggiornata");
      } else {
        debugPrint("API fetch failed: ${response.statusCode}");
      }

    } catch (e) {
      debugPrint("Error loading map data: $e");
      if (!silent) setState(() => _statusMessage = "Errore caricamento percorso");
    } finally {
      if (!silent && mounted) setState(() => _isLoading = false);
      _redrawMap();
      _updateMarkerPosition();
    }
  }
  
  void _parseProcessedTripResponse(Map<String, dynamic> data) {
      // 1. Process Polyline (MultiLineString from API -> Mapbox format)
      // API: polyline = [[{lat,lng},...], ...]
      final rawPolyline = data['polyline'];
      if (rawPolyline != null && rawPolyline is List) {
          final List<List<List<double>>> multiLine = [];
          for (var segment in rawPolyline) {
              if (segment is List) {
                  final List<List<double>> line = [];
                  for (var point in segment) {
                      final lat = point['lat'];
                      final lng = point['lng'];
                      if (lat != null && lng != null) {
                          line.add([(lng as num).toDouble(), (lat as num).toDouble()]);
                      }
                  }
                  if (line.isNotEmpty) multiLine.add(line);
              }
          }
          _processedMultiLine = multiLine;
      }

      // 2. Process Stops
      final stops = data['stops'] as List?;
      _stopLogics.clear();
      if (stops != null) {
          for (var s in stops) {
              final loc = s['location'];
              if (loc != null) {
                   _stopLogics.add({
                       'name': s['name'] ?? 'Station',
                       'coords': LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
                   });
              }
          }
      }

      // 3. Process Position
      final trainPos = data['trainPosition'];
      if (trainPos != null) {
           _currentTrainPos = LatLng(
               (trainPos['lat'] as num).toDouble(),
               (trainPos['lng'] as num).toDouble()
           );
      }
  }

  void _redrawMap() {
    if (!_isMapReady) return;
    
    // 1. Draw Polyline (MultiLineString)
    if (_processedMultiLine.isNotEmpty) {
        final coordsJson = jsonEncode(_processedMultiLine);
        // Pass MultiLineString geometry
        _webViewController.runJavaScript('if(window.addRouteLayer) window.addRouteLayer($coordsJson);');
    }
    
    // 2. Draw Stations
    if (_stopLogics.isNotEmpty) {
        final markers = _stopLogics.map((s) => {
            'lat': (s['coords'] as LatLng).latitude,
            'lng': (s['coords'] as LatLng).longitude,
            'name': s['name']
        }).toList();
        _webViewController.runJavaScript('if(window.updateStationMarkers) window.updateStationMarkers(${jsonEncode(markers)});');
    }
  }
  
  void _setupAutoRefresh() {
    // Poll API every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData(silent: true));
  }
  
  void _updateMarkerPosition() {
    if (_currentTrainPos != null && _isMapReady) {
       _webViewController.runJavaScript('if(window.updateTrainMarker) window.updateTrainMarker(${_currentTrainPos!.latitude}, ${_currentTrainPos!.longitude});');
    }
  }

  // called when SettingsProvider notifies; we care only about map style
  void _onSettingsChanged() {
    final raw = Provider.of<SettingsProvider>(context, listen: false).mapStyle;
    final style = SettingsProvider.normalizeStyleUrl(raw);
    if (_isMapReady && style.isNotEmpty) {
      _webViewController.runJavaScript("if(window.setMapStyle) window.setMapStyle('$style');");
    }
  }
  
  // Clean up unused methods
  void _parsePolyline(Map<String, dynamic>? polylineData) {}
  void _parseMakeStops(List stopsJson) {}
  void _mapStopsToPolyline() {}
  void _refreshTrainPosition() {}
  void _interpolateOnPolyline(int idxA, int idxB, double progress) {}
  void _updateMarker(LatLng pos) {} // Replaced by _updateMarkerPosition

  String _getHtmlContent(String styleUrl) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src='https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.js'></script>
    <link href='https://api.mapbox.com/mapbox-gl-js/v3.0.1/mapbox-gl.css' rel='stylesheet' />
    <style>
        body { margin: 0; padding: 0; }
        #map { position: absolute; top: 0; bottom: 0; width: 100%; }
        .mapboxgl-ctrl-logo { display: none !important; }
        
        .station-marker-inner {
            background-color: white;
            border-radius: 50%;
            width: 12px;
            height: 12px;
            border: 3px solid #334155;
            box-shadow: 0 2px 4px rgba(0,0,0,0.3);
            cursor: pointer;
        }
        
        .train-marker {
            width: 24px;
            height: 24px;
            background-color: #ef4444; 
            border: 3px solid #ffffff; 
            border-radius: 50%; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.4);
            cursor: default;
        }
    </style>
</head>
<body>
    <div id="map"></div>
    <script>
        mapboxgl.accessToken = '$_kMapboxAccessToken';
        const map = new mapboxgl.Map({
            container: 'map',
            style: '$styleUrl',
            // Default center, will be updated by fitBounds
            center: [12.56, 41.89],
            zoom: 5,
            attributionControl: true
        });

        // allow Dart code to request a style change after load
        window.setMapStyle = function(styleUrl) {
            try {
                map.setStyle(styleUrl);
            } catch (e) {
                console.error('Failed to set map style:', e);
            }
        };

        let trainMarker = null;
        let stationMarkers = [];

        map.on('load', function () {
           // Add OpenRailwayMap Source (RASTER)
           map.addSource('openrailwaymap', {
                type: 'raster',
                tiles: [
                    'https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png'
                ],
                tileSize: 256,
                attribution: '&copy; OpenStreetMap contributors, &copy; OpenRailwayMap'
           });
           
           map.addLayer({
                id: 'openrailwaymap-layer',
                type: 'raster',
                source: 'openrailwaymap',
                minzoom: 2,
                maxzoom: 19,
                paint: { 'raster-opacity': 0.8 }
           });

           if(window.flutterChannel) window.flutterChannel.postMessage('map_ready');
        });

        window.updateStationMarkers = function(markers) {
            // Clear existing
            stationMarkers.forEach(m => m.remove());
            stationMarkers = [];

            markers.forEach(m => {
                 const el = document.createElement('div');
                 el.className = 'station-marker-inner';
                 
                 const popup = new mapboxgl.Popup({ offset: 10, closeButton: false })
                    .setText(m.name);
                 
                 el.addEventListener('click', () => popup.addTo(map));

                 const marker = new mapboxgl.Marker({element: el})
                    .setLngLat([m.lng, m.lat])
                    .setPopup(popup)
                    .addTo(map);
                 
                 stationMarkers.push(marker);
            });
        };

        window.addRouteLayer = function(coordinates) {
            // coordinates is now multi-line string structure: [[[lng, lat], ...], ...]
            
            if (map.getLayer('route')) map.removeLayer('route');
            if (map.getSource('route')) map.removeSource('route');
            
            if (!coordinates || coordinates.length === 0) return;

            map.addSource('route', {
                type: 'geojson',
                data: {
                    type: 'Feature',
                    geometry: {
                        type: 'MultiLineString',
                        coordinates: coordinates
                    }
                }
            });
            
            map.addLayer({
                id: 'route',
                type: 'line',
                source: 'route',
                layout: { 'line-join': 'round', 'line-cap': 'round' },
                paint: {
                    'line-color': '#0EA5E9', 
                    'line-width': 4,
                    'line-opacity': 0.8 
                }
            });
            
            // Fit bounds
            const bounds = new mapboxgl.LngLatBounds();
            coordinates.forEach(line => {
                line.forEach(coord => bounds.extend(coord));
            });
            
            // Should verify valid bounds
            if (!bounds.isEmpty()) {
                 map.fitBounds(bounds, { padding: 50 });
            }
        };

        window.updateTrainMarker = function(lat, lng) {
             // "ovviamente la posizione comparirà soltanto dopo aver comparso il la linea"
             // Safety check: Do not show marker if route is missing
             if (!map.getLayer('route')) {
                 if (trainMarker) {
                     trainMarker.remove();
                     trainMarker = null;
                 }
                 return;
             }

             if (trainMarker) {
                 trainMarker.setLngLat([lng, lat]);
             } else {
                 const el = document.createElement('div');
                 el.className = 'train-marker';
                 // Entrance animation or just appear
                 
                 trainMarker = new mapboxgl.Marker({element: el})
                    .setLngLat([lng, lat])
                    .addTo(map);
             }
        };
    </script>
</body>
</html>
    ''';
  }

  // --- UI Build ---
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final dep = widget.departure;
    final currentDelay = widget.currentDelay;
    
    return Scaffold(
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          
          // Header Card
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Card(
              color: theme.surfaceColor.withOpacity(0.95),
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    IconButton(
                        icon: Icon(Icons.arrow_back, color: theme.textColor), 
                        onPressed: () => Navigator.pop(context)
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "${dep.category ?? 'Treno'} ${dep.trainNumber ?? ''}".trim(), 
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor)
                          ),
                          Flexible(
                            child: Text(
                              _statusMessage, 
                              style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isLoading) 
                      SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
              ),
            ),
          ),
          
          if (!_isLoading)
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Card(
                color: theme.surfaceColor.withOpacity(0.95),
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Delay
                       Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Ritardo", style: TextStyle(fontSize: 12, color: theme.secondaryTextColor)),
                            const SizedBox(height: 4),
                            Text("$currentDelay min", style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold, 
                                color: currentDelay > 0 ? Colors.red : Colors.green)),
                          ],
                        ),
                      
                      // Origin
                      Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Origine", style: TextStyle(fontSize: 12, color: theme.secondaryTextColor)),
                              const SizedBox(height: 4),
                              Text(dep.origin ?? "?", 
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textColor)),
                            ],
                          )
                      ),

                      // Dest
                      Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Destinazione", style: TextStyle(fontSize: 12, color: theme.secondaryTextColor)),
                              const SizedBox(height: 4),
                              Text(dep.destination ?? "?", 
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textColor)),
                            ],
                          )
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

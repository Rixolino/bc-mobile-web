import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../data/models/train_model.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';

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
  WebViewController? _webViewController;
  
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
    if (kIsWeb) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Anteprima mappa non disponibile su web';
      });
      return;
    }

    // Listener invoked when settings change (for map style).
    // defined here so it can access _webViewController and _isMapReady.
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    // Map style comes directly from settings (a Mapbox style URL).
    // provider may still contain an old string, normalize it explicitly in case
    // the value hasn't been rewritten yet. log for debugging.
    String mapStyleUrl = settings.mapStyle ?? '';
    mapStyleUrl = mapStyleUrl.isEmpty ? 'mapbox://styles/mapbox/dark-v11' : mapStyleUrl;
    
    // Ensure mapStyleUrl is a valid Mapbox URL format
    if (!mapStyleUrl.startsWith('mapbox://') && !mapStyleUrl.startsWith('http')) {
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
      // 1. Process Polyline (FeatureCollection from API -> Mapbox format)
      // API: polyline = { type: "FeatureCollection", features: [{geometry: {type: "Point", coordinates: [lng, lat]}, ...}] }
      final rawPolyline = data['polyline'];
      if (rawPolyline != null) {
          final List<List<List<double>>> multiLine = [];
          
          if (rawPolyline is Map && rawPolyline['type'] == 'FeatureCollection') {
              // FeatureCollection: extract Point coordinates and build a single LineString
              final List<List<double>> line = [];
              final features = rawPolyline['features'];
              if (features is List) {
                  for (var feature in features) {
                      if (feature is Map && feature['geometry'] is Map) {
                          final geometry = feature['geometry'] as Map;
                          if (geometry['type'] == 'Point' && geometry['coordinates'] is List) {
                              final coords = geometry['coordinates'] as List;
                              if (coords.length >= 2) {
                                  line.add([
                                      (coords[0] as num).toDouble(),  // lng
                                      (coords[1] as num).toDouble()   // lat
                                  ]);
                              }
                          }
                      }
                  }
              }
              if (line.isNotEmpty) multiLine.add(line);
          } else if (rawPolyline is List) {
              // Fallback: support old format with List of segments
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
          }
          _processedMultiLine = multiLine;
      }

      // 2. Process Stops
      final stops = data['stops'] as List?;
      _stopLogics.clear();
        if (stops != null) {
          for (var s in stops) {
            final loc = s['location'];
            // prefer 'stationName' from API, fall back to 'name'
            final stationLabel = (s['stationName'] ?? s['name']) as String? ?? 'Station';
            if (loc != null) {
               _stopLogics.add({
                 'name': stationLabel,
                 'coords': LatLng((loc['lat'] as num).toDouble(), (loc['lng'] as num).toDouble()),
               });
            } else {
               // Keep station entry even if location missing so labels appear (will be skipped in marker placement)
               _stopLogics.add({
                 'name': stationLabel,
                 'coords': null,
               });
            }
          }
          debugPrint('Parsed ${_stopLogics.length} stops: ' + _stopLogics.map((s) => s['name']).join(', '));
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
    final controller = _webViewController;
    if (!_isMapReady || controller == null) {
        debugPrint('Map not ready, skipping redraw');
        return;
    }
    
    // 1. Draw Polyline (MultiLineString)
    if (_processedMultiLine.isNotEmpty) {
        debugPrint('Drawing polyline with ${_processedMultiLine.length} segments');
        final coordsJson = jsonEncode(_processedMultiLine);
        debugPrint('Polyline JSON length: ${coordsJson.length}');
        // Pass MultiLineString geometry
        controller.runJavaScript('if(window.addRouteLayer) window.addRouteLayer($coordsJson);');
    } else {
        debugPrint('No polyline data to draw');
    }
    
    // 2. Draw Stations
    if (_stopLogics.isNotEmpty) {
      // Only include markers that have coordinates
      final validMarkers = <Map<String, dynamic>>[];
      for (var s in _stopLogics) {
        final coords = s['coords'] as LatLng?;
        if (coords != null) {
          validMarkers.add({
            'lat': coords.latitude,
            'lng': coords.longitude,
            'name': s['name']
          });
        }
      }
      debugPrint('Drawing ${validMarkers.length} station markers');
      controller.runJavaScript('if(window.updateStationMarkers) window.updateStationMarkers(${jsonEncode(validMarkers)});');
    } else {
      debugPrint('No station data to draw');
    }
  }
  
  void _setupAutoRefresh() {
    // Poll API every 15 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadData(silent: true));
  }

  void _updateMarkerPosition() {
     final controller = _webViewController;
     if (_currentTrainPos != null && _isMapReady && controller != null) {
       controller.runJavaScript('if(window.updateTrainMarker) window.updateTrainMarker(${_currentTrainPos!.latitude}, ${_currentTrainPos!.longitude});');
    }
  }

  // called when SettingsProvider notifies; we care only about map style
  void _onSettingsChanged() {
    final raw = Provider.of<SettingsProvider>(context, listen: false).mapStyle;
    final style = SettingsProvider.normalizeStyleUrl(raw);
    final controller = _webViewController;
    if (_isMapReady && style.isNotEmpty && controller != null) {
      controller.runJavaScript("if(window.setMapStyle) window.setMapStyle('$style');");
    }
  }

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
        body { margin: 0; padding: 0; background-color: #e5e7eb; }
        #map { position: absolute; top: 0; bottom: 0; width: 100%; background-color: #e5e7eb; }
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
        .station-marker {
          display: flex;
          flex-direction: column;
          align-items: center;
          transform: translateY(-6px); /* lift so label sits below */
          pointer-events: auto;
        }
        .station-label {
          font-size: 12px;
          color: #0f172a;
          background: rgba(255,255,255,0.9);
          padding: 2px 6px;
          border-radius: 6px;
          margin-top: 6px;
          white-space: nowrap;
          box-shadow: 0 1px 2px rgba(0,0,0,0.15);
          pointer-events: none;
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
        
        // Validate styleUrl and provide fallback
        let styleUrl = '$styleUrl';
        if (!styleUrl || styleUrl === 'null' || styleUrl === '') {
            console.warn('Invalid styleUrl:', styleUrl, '-> using dark-v11');
            styleUrl = 'mapbox://styles/mapbox/dark-v11';
        }
        
        console.log('Creating map with style:', styleUrl);
        
        const map = new mapboxgl.Map({
            container: 'map',
            style: styleUrl,
            // Default center, will be updated by fitBounds
            center: [12.56, 41.89],
            zoom: 5,
            attributionControl: true
        });
        
        // Handle style load errors
        map.on('style.load', function () {
            console.log('Style loaded successfully');
        });
        
        map.on('error', function (e) {
            console.error('Mapbox error:', e);
            if (e && e.error && e.error.message && e.error.message.includes('401')) {
                console.error('Unauthorized - Mapbox token may be invalid');
                // Try fallback to streets-v12
                if (styleUrl !== 'mapbox://styles/mapbox/streets-v12') {
                    console.log('Attempting fallback to streets-v12');
                    map.setStyle('mapbox://styles/mapbox/streets-v12');
                }
            }
        });

        // allow Dart code to request a style change after load
        window.setMapStyle = function(styleUrl) {
            try {
                console.log('Setting map style to:', styleUrl);
                map.setStyle(styleUrl);
            } catch (e) {
                console.error('Failed to set map style:', e);
            }
        };

        let trainMarker = null;
        let stationMarkers = [];

        map.on('load', function () {
           console.log('Map loaded, style url:', map.getStyle().name);
           
           // Add OpenRailwayMap Source (RASTER)
           if (!map.getSource('openrailwaymap')) {
               map.addSource('openrailwaymap', {
                    type: 'raster',
                    tiles: [
                        'https://tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png'
                    ],
                    tileSize: 256,
                    attribution: '&copy; OpenStreetMap contributors, &copy; OpenRailwayMap'
               });
           }
           
           if (!map.getLayer('openrailwaymap-layer')) {
               map.addLayer({
                    id: 'openrailwaymap-layer',
                    type: 'raster',
                    source: 'openrailwaymap',
                    minzoom: 0,
                    maxzoom: 22,
                    paint: { 'raster-opacity': 0.6 }
               });
           }
           
           console.log('Map setup complete');

           if(window.flutterChannel) window.flutterChannel.postMessage('map_ready');
        });

          window.updateStationMarkers = function(markers) {
            // Clear existing
            stationMarkers.forEach(m => m.remove());
            stationMarkers = [];

            markers.forEach(m => {
                // container holds the dot and the label below it
                const container = document.createElement('div');
                container.className = 'station-marker';

                const inner = document.createElement('div');
                inner.className = 'station-marker-inner';

                const label = document.createElement('div');
                label.className = 'station-label';
                label.textContent = m.name || '';

                container.appendChild(inner);
                container.appendChild(label);

                const popup = new mapboxgl.Popup({ offset: 10, closeButton: false })
                  .setText(m.name);

                inner.addEventListener('click', () => popup.addTo(map));

                const marker = new mapboxgl.Marker({element: container})
                  .setLngLat([m.lng, m.lat])
                  .setPopup(popup)
                  .addTo(map);

                stationMarkers.push(marker);
            });
          };

        window.addRouteLayer = function(coordinates) {
            // coordinates is MultiLineString structure: [[[lng, lat], ...], ...]
            console.log('addRouteLayer called with', coordinates ? coordinates.length : 0, 'segments');
            
            if (map.getLayer('route')) map.removeLayer('route');
            if (map.getSource('route')) map.removeSource('route');
            
            if (!coordinates || coordinates.length === 0) {
                console.warn('No coordinates provided to addRouteLayer');
                return;
            }

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
            
            if (!bounds.isEmpty()) {
                 console.log('Fitting bounds to route');
                 map.fitBounds(bounds, { padding: 50 });
            } else {
                 console.warn('Route bounds are empty');
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
          if (!kIsWeb && _webViewController != null)
            WebViewWidget(controller: _webViewController!)
          else
            Container(
              color: theme.backgroundColor,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.map_outlined, size: 56, color: theme.primaryColor),
                      const SizedBox(height: 16),
                      Text(
                        'Mappa interattiva non disponibile su web',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Apri questa schermata su Android o iOS per vedere il tracciamento completo del treno.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: theme.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
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

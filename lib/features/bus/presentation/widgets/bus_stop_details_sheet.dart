import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../../presentation/constants/notification_channels.dart';
import '../../../favorites/models/favorite_stop.dart';
import '../../../auth/providers/auth_provider.dart';
import 'bus_details_sheet.dart';

class BusStopDetailsSheet extends StatefulWidget {
  final BariStop stop;
  final ScrollController? scrollController;
  const BusStopDetailsSheet({super.key, required this.stop, this.scrollController});

  @override
  State<BusStopDetailsSheet> createState() => _BusStopDetailsSheetState();
}

class _BusStopDetailsSheetState extends State<BusStopDetailsSheet> {
  Timer? _timer;
  List<StopDeparture> _departures = [];
  bool _isLoadingDepartures = false;

  // Notification state for this stop (initialized on open)
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _fetchDepartures(showLoading: true);

    // Verify whether notifications are enabled for this stop so UI reflects current state
    AndroidBackgroundService.isStopMonitored(widget.stop.stopId).then((v) {
      if (mounted) setState(() => _notificationsEnabled = v);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final settings = Provider.of<SettingsProvider>(context);
    if (settings.busRefreshSeconds > 0 && _timer == null) {
      _startAutoRefresh();
    } else if (settings.busRefreshSeconds == 0 && _timer != null) {
      _stopAutoRefresh();
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settings.busRefreshSeconds;

    if (interval > 0) {
      _timer = Timer.periodic(Duration(seconds: interval), (_) {
        if (mounted) {
          _fetchDepartures(showLoading: false);
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }



  Future<void> _fetchDepartures({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoadingDepartures = true);
    }
    try {
      final provider = Provider.of<BusProvider>(context, listen: false);
      final departures = await provider.fetchStopUpdates(widget.stop.stopId);
      print('Fetched ${departures.length} departures for stop ${widget.stop.stopId}');
      if (departures.isNotEmpty) {
        print('First departure: ${departures[0].toString()}');
      }
      setState(() => _departures = departures);
    } catch (e) {
      print('Error fetching stop departures: $e');
    } finally {
      if (showLoading) {
        setState(() => _isLoadingDepartures = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BusProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  controller: widget.scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with close button and auto-refresh toggle
                      Container(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: theme.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primaryColor.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on, color: theme.textColor, size: 24),
                                  const SizedBox(width: 12),
                                  Flexible(
                                    fit: FlexFit.loose,
                                    child: Text(
                                      widget.stop.stopName,
                                      style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: theme.secondaryTextColor),
                              onPressed: () {
                                if (widget.scrollController == null) {
                                  // If opened as modal, close the modal sheet
                                  Navigator.of(context).pop();
                                } else {
                                  // If embedded in map, just clear the selection
                                  provider.clearStopSelection();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Fermata Bus ${_capitalizeFirst(provider.selectedProvider?.name ?? 'N/A')}', style: TextStyle(color: theme.secondaryTextColor)),
                      const SizedBox(height: 8),

                      // Material-styled rounded buttons (Wrap to avoid overflow)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // City / Provider info (outlined)
                          if ((provider.selectedProvider?.name ?? '').isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: null,
                              icon: const Icon(Icons.location_city, size: 16),
                              label: Text('Città • ${_capitalizeFirst(provider.selectedProvider?.name)}'),
                              style: OutlinedButton.styleFrom(
                                shape: const StadiumBorder(),
                                foregroundColor: theme.textColor,
                                side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.12)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),

                          // Stop ID (copy)
                          ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: widget.stop.stopId));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID fermata copiato')));
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            label: Text('ID • ${widget.stop.stopId}'),
                            style: ElevatedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          ),

                          // Position (copy coordinates)
                          ElevatedButton.icon(
                            onPressed: () {
                              final coords = '${widget.stop.latitude.toStringAsFixed(6)}, ${widget.stop.longitude.toStringAsFixed(6)}';
                              Clipboard.setData(ClipboardData(text: coords));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinate copiate')));
                            },
                            icon: const Icon(Icons.my_location, size: 16),
                            label: Text('Posizione • ${widget.stop.latitude.toStringAsFixed(6)}, ${widget.stop.longitude.toStringAsFixed(6)}'),
                            style: ElevatedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                          ),

                          // Favorite toggle as button (requires auth)
                          Consumer2<FavoritesProvider, AuthProvider>(
                            builder: (context, favoritesProvider, authProvider, child) {
                              if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                              final isFavorite = favoritesProvider.isStopFavorite(widget.stop.stopId, StopType.busStop);
                              return ElevatedButton.icon(
                                onPressed: () async {
                                  final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                                  if (isFavorite) {
                                    await favoritesProvider.removeStopFavorite(widget.stop.stopId, StopType.busStop);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fermata rimossa dai preferiti')));
                                  } else {
                                    final favoriteStop = favoritesProvider.createFavoriteStop(
                                      userId: userId,
                                      name: widget.stop.stopName,
                                      code: widget.stop.stopId,
                                      stopType: StopType.busStop,
                                      latitude: widget.stop.latitude,
                                      longitude: widget.stop.longitude,
                                      city: null,
                                      region: null,
                                      provider: provider.selectedProvider?.name,
                                      country: null,
                                    );
                                    await favoritesProvider.addStopFavorite(favoriteStop);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fermata aggiunta ai preferiti')));
                                  }
                                },
                                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: isFavorite ? Colors.red : null),
                                label: Text(isFavorite ? 'Preferito' : 'Aggiungi ai preferiti'),
                                style: ElevatedButton.styleFrom(shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                              );
                            },
                          ),

                          // Notifications toggle as stateful button (icon + label reflect current state)
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                await AndroidBackgroundService.requestPermission();
                                final providerName = provider.selectedProvider?.name ?? '';
                                final providerParam = providerName.isNotEmpty ? providerName.toLowerCase() : null;
                                final settings = Provider.of<SettingsProvider>(context, listen: false);

                                if (!_notificationsEnabled) {
                                  // enable monitoring
                                  await AndroidBackgroundService.scheduleBusesWorker(provider: providerParam, intervalSeconds: settings.busRefreshSeconds, stopId: widget.stop.stopId, stopName: widget.stop.stopName);
                                  // optionally show a small notification immediately
                                  final title = '${widget.stop.stopName} (${widget.stop.stopId})';
                                  final items = _departures.take(3).map((d) => '${d.line} ${d.formattedTime}').join(', ');
                                  final body = items.isEmpty ? 'Nessuna partenza disponibile al momento' : 'Prossime partenze: $items';
                                  await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: title, body: body, key: 'stop:${widget.stop.stopId}');

                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifiche attivate per ${providerName.isNotEmpty ? providerName : 'questa fermata'}')));
                                } else {
                                  // disable monitoring
                                  await AndroidBackgroundService.removeMonitoredStop(widget.stop.stopId);
                                  await AndroidBackgroundService.cancelNotification(key: 'stop:${widget.stop.stopId}');
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifiche disattivate per questa fermata')));
                                }

                                setState(() => _notificationsEnabled = !_notificationsEnabled);
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore notifiche: $e')));
                              }
                            },
                            icon: Icon(_notificationsEnabled ? Icons.notifications_active : Icons.notifications_none, size: 16, color: _notificationsEnabled ? Theme.of(context).primaryColor : null),
                            label: Text(_notificationsEnabled ? 'Disattiva notifiche' : 'Notifiche'),
                            style: ElevatedButton.styleFrom(
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              backgroundColor: _notificationsEnabled ? Theme.of(context).primaryColor.withOpacity(0.12) : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // Basic info
                      _buildInfoRow("ID Fermata", widget.stop.stopId, theme),
                      _buildInfoRow("Nome", widget.stop.stopName, theme),

                      const SizedBox(height: 20),

                      // Position info
                      Text("Posizione", style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surfaceColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: theme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${widget.stop.latitude.toStringAsFixed(6)}, ${widget.stop.longitude.toStringAsFixed(6)}",
                                    style: TextStyle(color: theme.textColor, fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Departures
                      Text("Prossime Partenze", style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 400, // Fixed height for departures list
                        child: _isLoadingDepartures
                            ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                            : _departures.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text("Nessuna partenza disponibile", style: TextStyle(color: theme.secondaryTextColor)),
                                        const SizedBox(height: 8),
                                        Text("Stop ID: ${widget.stop.stopId}", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                                      ],
                                    ),
                                  )
                                : _buildDeparturesList(_departures, theme),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDeparturesList(List<StopDeparture> departures, ThemeProvider theme) {
    return ListView.builder(
      itemCount: departures.length,
      itemBuilder: (context, index) {
        final departure = departures[index];
        return Card(
          key: ValueKey('${departure.line}_${departure.destination}_${index}'),
          margin: const EdgeInsets.symmetric(vertical: 4),
          color: theme.surfaceColor.withOpacity(0.05),
          child: ListTile(
            onTap: () async {
              final provider = Provider.of<BusProvider>(context, listen: false);
              final selectedProvider = provider.selectedProvider;
              if (selectedProvider == null) return;

              // Controlla se tripId e line sono disponibili
              if (departure.tripId.isEmpty || departure.line.isEmpty) {
                print('TripId o lineCode mancanti per la partenza');
                return;
              }

              try {
                final url = 'https://betacloud-transporter.is-cool.dev/api/it/bus/${selectedProvider.name.toLowerCase()}/realtime?tripId=${departure.tripId}&lineCode=${departure.line}';
                print('Richiamando URL: $url');
                final response = await http.get(Uri.parse(url));
                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  final destination = data['destination'] as String?;
                  final stops = (data['stops'] as List<dynamic>?)?.map((stop) => BusTripUpdate.fromJson(stop)).toList() ?? [];

                  // Cerca il bus esistente
                  BusVehicle? existingBus;
                  try {
                    existingBus = provider.vehicles.firstWhere((v) => v.id == departure.vehicleId);
                  } catch (e) {
                    // Bus non trovato
                  }

                  if (existingBus != null) {
                    // Aggiorna il bus esistente
                    provider.updateBusDestination(existingBus.id, destination ?? '');
                    provider.setApiTripUpdates(stops);
                    await provider.selectBus(existingBus);

                    // Se questo sheet è stato aperto come modal (es. dai Preferiti), chiudi il modal della fermata e apri il dettaglio bus come modal
                    if (widget.scrollController == null) {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      if (!mounted) return;
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => BusDetailsSheet(bus: existingBus!, page: 'favorites'),
                      );
                    }
                  } else if (departure.vehicleId.isNotEmpty) {
                    // Crea un nuovo bus temporaneo con coordinate dal provider
                    final newBus = BusVehicle(
                      id: departure.vehicleId,
                      line: departure.line,
                      destination: destination ?? departure.destination,
                      latitude: selectedProvider.latitude ?? 0.0,
                      longitude: selectedProvider.longitude ?? 0.0,
                      tripId: departure.tripId,
                      provider: selectedProvider.provider,
                    );
                    provider.setApiTripUpdates(stops);
                    await provider.selectBus(newBus);

                    if (widget.scrollController == null) {
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      if (!mounted) return;
                      await showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (context) => BusDetailsSheet(bus: newBus, page: 'favorites'),
                      );
                    }
                  }
                } else {
                  print('Errore nel recupero dei dettagli del bus: ${response.statusCode}');
                }
              } catch (e) {
                print('Errore nel recupero dei dettagli del bus: $e');
              }
            },
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                departure.line,
                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              departure.destination ?? 'N/A',
              style: TextStyle(color: theme.textColor, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${departure.formattedTime}${departure.delayText}",
                  style: TextStyle(color: theme.secondaryTextColor),
                ),
                if (departure.isRealtime)
                  Text("Tempo reale", style: TextStyle(color: theme.successColor, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: _buildTimeDisplay(departure, theme),
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay(StopDeparture departure, ThemeProvider theme) {
    final now = DateTime.now();
    final departureTime = DateTime.fromMillisecondsSinceEpoch((departure.time * 1000).toInt());
    final difference = departureTime.difference(now);
    final minutesRemaining = difference.inMinutes;

    // Determina il colore basato sui minuti restanti
    Color textColor;
    if (minutesRemaining < 0) {
      textColor = theme.errorColor; // Già passato
    } else if (minutesRemaining <= 5) {
      textColor = theme.warningColor; // Molto presto
    } else {
      textColor = departure.isRealtime ? theme.successColor : theme.secondaryTextColor;
    }

    // Formatta il testo
    String timeText;
    if (minutesRemaining < 0) {
      timeText = "${minutesRemaining.abs()}min fa";
    } else if (minutesRemaining == 0) {
      timeText = "Ora";
    } else {
      timeText = "${minutesRemaining}min";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        timeText,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 14))),
          Expanded(child: Text(value, style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _capitalizeFirst(String? s) {
    if (s == null) return '';
    final t = s.trim();
    if (t.isEmpty) return '';
    return t[0].toUpperCase() + t.substring(1);
  }
}



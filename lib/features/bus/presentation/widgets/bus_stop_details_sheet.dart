import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _fetchDepartures(showLoading: true);
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

  void _toggleAutoRefresh() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settings.busRefreshSeconds;
    if (_timer != null) {
      _stopAutoRefresh();
    } else if (interval > 0) {
      _startAutoRefresh();
    }
    setState(() {});
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
                            Row(
                              children: [
                                Consumer2<FavoritesProvider, AuthProvider>(
                                  builder: (context, favoritesProvider, authProvider, child) {
                                    if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                                    
                                    final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                                    final isFavorite = favoritesProvider.isStopFavorite(widget.stop.stopId, StopType.busStop);
                                    return IconButton.filledTonal(
                                      icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                                      onPressed: () async {
                                        if (isFavorite) {
                                          await favoritesProvider.removeStopFavorite(widget.stop.stopId, StopType.busStop);
                                        } else {
                                          final favoriteStop = favoritesProvider.createFavoriteStop(
                                            userId: userId,
                                            name: widget.stop.stopName,
                                            code: widget.stop.stopId,
                                            stopType: StopType.busStop,
                                            latitude: widget.stop.latitude,
                                            longitude: widget.stop.longitude,
                                            city: null, // Non disponibile nel BariStop
                                            region: null, // Non disponibile nel BariStop
                                            provider: provider.selectedProvider?.name?.toString(),
                                            country: null,
                                          );
                                          await favoritesProvider.addStopFavorite(favoriteStop);
                                        }
                                      },
                                      style: IconButton.styleFrom(
                                        backgroundColor: theme.surfaceColor.withOpacity(0.05),
                                        foregroundColor: isFavorite ? Colors.red : theme.secondaryTextColor,
                                      ),
                                    );
                                  },
                                ),
                                Consumer<SettingsProvider>(
                                  builder: (context, settings, child) {
                                    final canAutoRefresh = settings.busRefreshSeconds > 0;
                                    return Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton.filledTonal(
                                          icon: Icon(_timer != null ? Icons.timer : Icons.timer_off),
                                          onPressed: canAutoRefresh ? _toggleAutoRefresh : null,
                                          style: IconButton.styleFrom(
                                            backgroundColor: theme.surfaceColor.withOpacity(0.05),
                                            foregroundColor: _timer != null ? theme.primaryColor : theme.secondaryTextColor,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _BusNotificationsButton(stop: widget.stop),
                                      ],
                                    );
                                  },
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Fermata Bus ${provider.selectedProvider?.name ?? 'N/A'}', style: TextStyle(color: theme.secondaryTextColor)),
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
              if (departure.tripId == null || departure.tripId.isEmpty || departure.line == null || departure.line.isEmpty) {
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
                  } else if (departure.vehicleId != null && departure.vehicleId.isNotEmpty) {
                    // Crea un nuovo bus temporaneo con coordinate dal provider
                    final newBus = BusVehicle(
                      id: departure.vehicleId,
                      line: departure.line,
                      destination: destination ?? departure.destination ?? '',
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
                departure.line ?? 'N/A',
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
                  "${departure.formattedTime ?? 'N/A'}${departure.delayText ?? ''}",
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
}

// Notifications button for a specific bus stop/trip
class _BusNotificationsButton extends StatefulWidget {
  final BariStop stop;
  const _BusNotificationsButton({required this.stop});

  @override
  State<_BusNotificationsButton> createState() => _BusNotificationsButtonState();
}

class _BusNotificationsButtonState extends State<_BusNotificationsButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    // Initialize enabled state based on monitored stops stored in native prefs
    AndroidBackgroundService.isStopMonitored(widget.stop.stopId).then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<void> _toggle() async {
    final providerName = Provider.of<BusProvider>(context, listen: false).selectedProvider?.name ?? '';
    final providerParam = providerName.isNotEmpty ? providerName.toLowerCase() : null;

    try {
      await AndroidBackgroundService.requestPermission();
      if (!_enabled) {
        // Fetch immediate data for this stop and notify user with summary
        final provider = Provider.of<BusProvider>(context, listen: false);
        List<StopDeparture> departures = [];
        try {
          departures = await provider.fetchStopUpdates(widget.stop.stopId);
        } catch (e) {
          print('Errore fetching stop updates on enable: $e');
        }

        String body;
        if (departures.isEmpty) {
          body = 'Nessuna partenza disponibile al momento per la fermata ${widget.stop.stopId}';
        } else {
          final items = departures.take(3).map((d) => '${d.line} ${d.formattedTime}').join(', ');
          body = 'Prossime partenze: $items';
        }

        final settings = Provider.of<SettingsProvider>(context, listen: false);
        await AndroidBackgroundService.scheduleBusesWorker(provider: providerParam, intervalSeconds: settings.busRefreshSeconds, stopId: widget.stop.stopId, stopName: widget.stop.stopName);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifiche autobus attivate per ${providerName.isNotEmpty ? providerName : 'provider'}')));
        // Use stop name and id as notification title when enabling notifications for this stop
        final title = '${widget.stop.stopName} (${widget.stop.stopId})';
        final key = 'stop:${widget.stop.stopId}';
        await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: title, body: body, key: key);
      } else {
        // Remove only this monitored stop instead of cancelling all bus monitoring
        await AndroidBackgroundService.removeMonitoredStop(widget.stop.stopId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifiche autobus disattivate per questa fermata')));
        final key = 'stop:${widget.stop.stopId}';
        await AndroidBackgroundService.cancelNotification(key: key);
        await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: 'Notifiche bus disattivate', body: 'Hai disattivato le notifiche per questa fermata');
      }
      setState(() => _enabled = !_enabled);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore notifiche: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(_enabled ? Icons.notifications_active : Icons.notifications_none),
      onPressed: _toggle,
    );
  }
}

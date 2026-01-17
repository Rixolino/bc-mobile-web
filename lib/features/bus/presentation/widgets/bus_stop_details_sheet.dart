import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';

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
                                Consumer<SettingsProvider>(
                                  builder: (context, settings, child) {
                                    final canAutoRefresh = settings.busRefreshSeconds > 0;
                                    return IconButton.filledTonal(
                                      icon: Icon(_timer != null ? Icons.timer : Icons.timer_off),
                                      onPressed: canAutoRefresh ? _toggleAutoRefresh : null,
                                      style: IconButton.styleFrom(
                                        backgroundColor: theme.surfaceColor.withOpacity(0.05),
                                        foregroundColor: _timer != null ? theme.primaryColor : theme.secondaryTextColor,
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, color: theme.secondaryTextColor),
                                  onPressed: () {
                                    provider.clearStopSelection();
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
              // Apri i dettagli del bus se è disponibile il vehicleId
              if (departure.vehicleId != null && departure.vehicleId!.isNotEmpty && departure.vehicleId != 'scheduled-' + departure.tripId) {
                final provider = Provider.of<BusProvider>(context, listen: false);
                // Cerca il bus nella lista dei veicoli attivi
                try {
                  final bus = provider.vehicles.firstWhere((v) => v.id == departure.vehicleId);
                  await provider.selectBus(bus);
                } catch (e) {
                  // Bus non trovato, ignora
                }
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
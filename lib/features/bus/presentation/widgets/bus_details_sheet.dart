import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_bus_line.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../../presentation/constants/notification_channels.dart';
import '../../../../core/services/android_background_service.dart';

class BusDetailsSheet extends StatefulWidget {
  final BusVehicle bus;
  final ScrollController? scrollController;
  final String? page; // 'home', 'favorites', etc. Used to adjust closing behavior
  const BusDetailsSheet({super.key, required this.bus, this.scrollController, this.page});

  @override
  State<BusDetailsSheet> createState() => _BusDetailsSheetState();
}

class _BusDetailsSheetState extends State<BusDetailsSheet> {
  Timer? _timer;
  List<BusTripUpdate> _tripUpdates = [];
  bool _isLoadingUpdates = false;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToCurrent = false; // Flag per evitare scroll multipli

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _fetchTripUpdates(showLoading: true); // Caricamento iniziale con loading
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Riavvia il timer se le impostazioni sono cambiate
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
    _scrollController.dispose();
    // Clear API trip updates when closing the sheet
    final provider = Provider.of<BusProvider>(context, listen: false);
    provider.clearApiTripUpdates();
    super.dispose();
  }

  void _startAutoRefresh() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settings.busRefreshSeconds;

    if (interval > 0) {
      _timer = Timer.periodic(Duration(seconds: interval), (_) {
        if (mounted) {
          _fetchTripUpdates(
              showLoading: false); // Aggiornamenti automatici senza loading
        }
      });
    }
  }

  void _stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  void _scrollToCurrentStop(List<BusTripUpdate> updates) {
    // Trova l'indice della fermata corrente
    final currentStopIndex =
        updates.indexWhere((update) => update.status == 'current');

    if (currentStopIndex != -1) {
      // Scroll alla fermata corrente con un piccolo delay per assicurarsi che la ListView sia renderizzata
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Calcola la posizione approssimativa (ogni item è circa 80px)
          final itemHeight = 80.0;
          final targetOffset = currentStopIndex * itemHeight;

          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
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

  Future<void> _fetchTripUpdates({bool showLoading = false}) async {
    final provider = Provider.of<BusProvider>(context, listen: false);
    if (provider.selectedProvider?.name != 'bari') return;

    if (showLoading) {
      setState(() => _isLoadingUpdates = true);
    }
    try {

      // Check if we have API trip updates available
      if (provider.apiTripUpdates.isNotEmpty) {
        setState(() => _tripUpdates = provider.apiTripUpdates);

        // Scroll alla fermata corrente solo al primo caricamento
        if (showLoading && !_hasScrolledToCurrent && _tripUpdates.isNotEmpty) {
          _scrollToCurrentStop(_tripUpdates);
          _hasScrolledToCurrent = true;
        }
        return;
      }

      // Fallback to fetching trip updates for this specific bus using the provider method
      print('Fetching trip updates for bus ${widget.bus.id}, line ${widget.bus.line}');
      final updates =
          await provider.fetchBariTripUpdates(widget.bus.id, widget.bus.line);
      setState(() => _tripUpdates = updates);

      // Scroll alla fermata corrente solo al primo caricamento
      if (showLoading && !_hasScrolledToCurrent && updates.isNotEmpty) {
        _scrollToCurrentStop(updates);
        _hasScrolledToCurrent = true;
      }
    } catch (e) {
      print('Error fetching trip updates: $e');
    } finally {
      if (showLoading) {
        setState(() => _isLoadingUpdates = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BusProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final BusVehicle bus = provider.selectedBus ?? widget.bus;

    // Use trip stops data if available, otherwise fall back to trip updates
    final tripStopsData = provider.selectedTripStops;
    final hasTripStopsData = tripStopsData != null && tripStopsData.stops.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Details section - takes up all available space
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
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
                      // Header with back button, bus info and auto-refresh toggle
                      Row(
                        children: [
                          // Back button and bus info together on the left
                          Row(
                            children: [
                              // Back button (freccia indietro)
                              IconButton(
                                icon: Icon(
                                  provider.selectedStop != null ? Icons.arrow_back : Icons.close,
                                  color: theme.secondaryTextColor
                                ),
                                onPressed: () {
                                  if (provider.selectedStop != null) {
                                    // Se c'è una fermata selezionata, deseleziona solo il bus per tornare alla vista fermata
                                    provider.clearBusSelection();
                                  } else {
                                    // Altrimenti deseleziona il bus e chiudi il modal solo se questo sheet è stato aperto come modal
                                    provider.clearBusSelection();
                                    if (widget.scrollController == null) {
                                      Navigator.of(context).pop();
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              // Bus info container (solo numero linea)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
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
                                    Icon(Icons.directions_bus,
                                        color: theme.textColor,
                                        size: 24),
                                    const SizedBox(width: 12),
                                    Text(bus.line,
                                        style: TextStyle(
                                            color: theme.textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              // Destinazione fuori dal blocco del numero
                              if (bus.destination != null) ...[
                                const SizedBox(width: 12),
                                Text(bus.destination!,
                                    style: TextStyle(
                                        color: theme.secondaryTextColor,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ],
                          ),
                          // Spacer to push timer to the right
                          const Spacer(),
                          // Favorites button (only if authenticated)
                          Consumer2<FavoritesProvider, AuthProvider>(
                            builder: (context, favoritesProvider, authProvider, child) {
                              if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                              
                              final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                              final isFavorite = favoritesProvider.isBusLineFavorite(bus.line, bus.provider ?? '');
                              return IconButton.filledTonal(
                                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                                onPressed: () async {
                                  if (isFavorite) {
                                    await favoritesProvider.removeBusLineFavorite(bus.line, bus.provider?.toString() ?? '');
                                  } else {
                                    final favoriteBusLine = FavoriteBusLine(
                                      id: '${bus.provider}_${bus.line}',
                                      addedAt: DateTime.now(),
                                      userId: userId,
                                      lineCode: bus.line,
                                      lineName: bus.destination ?? bus.line,
                                      provider: bus.provider?.toString() ?? '',
                                      routeId: bus.tripId?.toString(),
                                    );
                                    await favoritesProvider.addBusLineFavorite(favoriteBusLine);
                                  }
                                },
                                style: IconButton.styleFrom(
                                  backgroundColor: theme.surfaceColor.withOpacity(0.05),
                                  foregroundColor: isFavorite ? Colors.red : theme.secondaryTextColor,
                                ),
                              );
                            },
                          ),
                          // Auto-refresh toggle button
                          Consumer<SettingsProvider>(
                            builder: (context, settings, child) {
                              final canAutoRefresh =
                                  settings.busRefreshSeconds > 0;
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
                                  _BusLineNotificationsButton(bus: bus),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(bus.provider ?? 'Operatore sconosciuto',
                          style: TextStyle(color: theme.secondaryTextColor)),
                      const SizedBox(height: 18),

                      // Basic info - compacted into expandable row
                      InkWell(
                        onTap: () => _showVehicleDetailsDialog(context, bus, theme),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, 
                                  color: theme.primaryColor, size: 20),
                              const SizedBox(width: 8),
                              Text("Dettagli veicolo",
                                  style: TextStyle(
                                      color: theme.textColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Icon(Icons.chevron_right, 
                                  color: theme.secondaryTextColor, size: 20),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Position info
                      Text("Posizione",
                          style: TextStyle(
                              color: theme.textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
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
                                Icon(Icons.location_on,
                                    color: theme.primaryColor, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      "${bus.latitude.toStringAsFixed(6)}, ${bus.longitude.toStringAsFixed(6)}",
                                      style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 14)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Trip updates for Bari buses
                      if (provider.selectedProvider?.name == 'bari') ...[
                        Text("Fermate del Viaggio",
                            style: TextStyle(
                                color: theme.textColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        SizedBox(
                          height:
                              300, // Fixed height for timeline in bottom section
                          child: provider.isLoadingTripStops
                              ? Center(
                                  child: CircularProgressIndicator(
                                      color: theme.primaryColor))
                              : hasTripStopsData
                                  ? _buildTripStopsTimeline(tripStopsData.stops, theme)
                                  : _isLoadingUpdates
                                      ? Center(
                                          child: CircularProgressIndicator(
                                              color: theme.primaryColor))
                                      : _tripUpdates.isEmpty
                                          ? Center(
                                              child: Text(
                                                  "Nessun aggiornamento disponibile",
                                                  style: TextStyle(
                                                      color: theme.secondaryTextColor)),
                                            )
                                          : _buildBusTimeline(_tripUpdates, theme),
                        ),
                      ] else ...[
                        // For other providers, show a message
                        SizedBox(
                          height: 200,
                          child: Center(
                            child: Text(
                              "Dettagli aggiuntivi non disponibili per ${provider.selectedProvider?.name ?? 'provider sconosciuto'}",
                              style: TextStyle(color: theme.secondaryTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildBusTimeline(List<BusTripUpdate> updates, ThemeProvider theme) {
    // Le fermate dovrebbero già essere ordinate dal server, non riordinare per evitare errori
    return ListView.builder(
      controller: _scrollController,
      itemCount: updates.length,
      itemBuilder: (context, index) {
        final update = updates[index];
        final isLast = index == updates.length - 1;
        final isCompleted = update.status == 'passed';
        final isActive = update.status == 'current';

        // Calcola progresso solo se stiamo attraversando tra fermate
        double progress = 0.0;
        bool isTraversing = false;

        // Se abbiamo una fermata attiva e non è l'ultima, e la successiva è futura,
        // allora stiamo attraversando
        if (isActive && !isLast && index + 1 < updates.length) {
          final nextUpdate = updates[index + 1];
          if (nextUpdate.status == 'future') {
            // Calcola progresso basato sui tempi se disponibili
            final now = DateTime.now();
            final timeParts = update.expectedTime.split(':');
            if (timeParts.length == 2) {
              final expectedHour = int.tryParse(timeParts[0]) ?? 0;
              final expectedMinute = int.tryParse(timeParts[1]) ?? 0;
              final expectedTime = DateTime(
                  now.year, now.month, now.day, expectedHour, expectedMinute);
              final actualTime =
                  expectedTime.add(Duration(minutes: update.delayMinutes));

              final nextTimeParts = nextUpdate.expectedTime.split(':');
              if (nextTimeParts.length == 2) {
                final nextHour = int.tryParse(nextTimeParts[0]) ?? 0;
                final nextMinute = int.tryParse(nextTimeParts[1]) ?? 0;
                final nextTime = DateTime(
                    now.year, now.month, now.day, nextHour, nextMinute);
                final nextActualTime =
                    nextTime.add(Duration(minutes: nextUpdate.delayMinutes));

                final totalDuration =
                    nextActualTime.difference(actualTime).inMinutes;
                final elapsed = now.difference(actualTime).inMinutes;
                progress = totalDuration > 0
                    ? (elapsed / totalDuration).clamp(0.0, 1.0)
                    : 0.0;
                isTraversing = progress > 0 && progress < 1;
              }
            }
          }
        }

        return _BusTimelineRow(
          update: update,
          index: index,
          isLast: isLast,
          isCompleted: isCompleted,
          isActiveStop: isCompleted && !isTraversing,
          isTraversing: isTraversing,
          progress: progress,
          theme: theme,
        );
      },
    );
  }

  void _showVehicleDetailsDialog(BuildContext context, BusVehicle bus, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.surfaceColor,
          title: Row(
            children: [
              Icon(Icons.directions_bus, color: theme.primaryColor),
              const SizedBox(width: 8),
              Text("Dettagli Veicolo", 
                  style: TextStyle(color: theme.textColor)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogInfoRow("ID Veicolo", bus.id, theme),
              _buildDialogInfoRow("Linea", bus.line, theme),
              if (bus.destination != null)
                _buildDialogInfoRow("Destinazione", bus.destination!, theme),
              if (bus.speed != null)
                _buildDialogInfoRow("Velocità", "${bus.speed} km/h", theme),
              if (bus.heading != null)
                _buildDialogInfoRow("Direzione", "${bus.heading}°", theme),
              if (bus.provider != null)
                _buildDialogInfoRow("Operatore", bus.provider!, theme),
              if (bus.tripId != null)
                _buildDialogInfoRow("ID Viaggio", bus.tripId!, theme),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Chiudi", 
                  style: TextStyle(color: theme.primaryColor)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogInfoRow(String label, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    color: theme.secondaryTextColor, 
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStopsTimeline(List<TripStop> stops, ThemeProvider theme) {
    return ListView.builder(
      controller: _scrollController,
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isLast = index == stops.length - 1;
        final isCompleted = stop.status == 'passed';
        final isActive = stop.status == 'current';

        // Scroll to current stop on first load
        if (isActive && !_hasScrolledToCurrent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentStopFromTripStops(stops);
            _hasScrolledToCurrent = true;
          });
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTripStopVisualTimeline(stop, isLast, index, theme),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Text(stop.stopName,
                          style: TextStyle(
                              color: isCompleted
                                  ? theme.secondaryTextColor.withOpacity(0.6)
                                  : theme.textColor,
                              fontSize: 16,
                              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600)),
                      Text(stop.scheduledTime + stop.delayText,
                          style: TextStyle(
                              color: isCompleted
                                  ? theme.secondaryTextColor.withOpacity(0.4)
                                  : theme.secondaryTextColor,
                              fontSize: 12)),
                      if (stop.isRealtime)
                        Text("Tempo reale",
                            style: TextStyle(
                                color: theme.successColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripStopVisualTimeline(TripStop stop, bool isLast, int index, ThemeProvider theme) {
    final isCompleted = stop.status == 'passed';
    final isActive = stop.status == 'current';
    final highlighted = isActive || (!isCompleted && stop.status == 'future');

    return SizedBox(
      width: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (index > 0)
            Positioned(
                top: 0,
                height: 17,
                width: 3,
                child: Container(
                    color: highlighted
                        ? theme.primaryColor
                        : theme.surfaceColor.withOpacity(0.05))),
          if (!isLast)
            Positioned(
                top: 17,
                bottom: 0,
                width: 3,
                child: Container(
                    color: isCompleted
                        ? theme.primaryColor
                        : theme.surfaceColor.withOpacity(0.05))),
          Positioned(
              top: 17,
              child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: isCompleted
                          ? theme.primaryColor
                          : isActive
                              ? theme.primaryColor
                              : theme.surfaceColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: highlighted
                              ? theme.primaryColor
                              : theme.secondaryTextColor.withOpacity(0.24),
                          width: 2)))),
          if (isActive)
            Positioned(top: 12, child: _BusIcon(size: 20)),
        ],
      ),
    );
  }

  void _scrollToCurrentStopFromTripStops(List<TripStop> stops) {
    final currentStopIndex = stops.indexWhere((stop) => stop.status == 'current');

    if (currentStopIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final itemHeight = 80.0;
          final targetOffset = currentStopIndex * itemHeight;

          _scrollController.animateTo(
            targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
}

class _BusTimelineRow extends StatelessWidget {
  final BusTripUpdate update;
  final int index;
  final bool isLast;
  final bool isCompleted;
  final bool isTraversing;
  final bool isActiveStop;
  final double progress;
  final ThemeProvider theme;

  const _BusTimelineRow({
    required this.update,
    required this.index,
    required this.isLast,
    required this.isCompleted,
    required this.isTraversing,
    required this.isActiveStop,
    required this.progress,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bool highlighted = isCompleted || isActiveStop || isTraversing;

    String timeString = update.expectedTime;
    if (update.delayMinutes > 0) {
      timeString += " (+${update.delayMinutes}min)";
    } else if (update.delayMinutes < 0) {
      timeString += " (${update.delayMinutes}min)";
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          const SizedBox(width: 16),
          _buildVisualTimeline(highlighted),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(update.stopName,
                      style: TextStyle(
                          color: isCompleted
                              ? theme.secondaryTextColor.withOpacity(0.6)
                              : theme.textColor,
                          fontSize: 16,
                          fontWeight:
                              highlighted ? FontWeight.w800 : FontWeight.w600)),
                  Text(timeString,
                      style: TextStyle(
                          color: isCompleted
                              ? theme.secondaryTextColor.withOpacity(0.4)
                              : theme.secondaryTextColor,
                          fontSize: 12)),
                  if (update.arrivalEstimate != null &&
                      update.arrivalEstimate!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: update.arrivalEstimate == 'In arrivo'
                            ? theme.primaryColor.withOpacity(0.1)
                            : theme.surfaceColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: update.arrivalEstimate == 'In arrivo'
                                ? theme.primaryColor.withOpacity(0.3)
                                : theme.secondaryTextColor.withOpacity(0.2),
                            width: 1),
                      ),
                      child: Text(update.arrivalEstimate!,
                          style: TextStyle(
                              color: update.arrivalEstimate == 'In arrivo'
                                  ? theme.primaryColor
                                  : theme.secondaryTextColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ),
                  if (update.isRealtime)
                    Text("Tempo reale",
                        style: TextStyle(
                            color: theme.successColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualTimeline(bool highlighted) {
    return SizedBox(
      width: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (index > 0)
            Positioned(
                top: 0,
                height: 17,
                width: 3,
                child: Container(
                    color: highlighted
                        ? theme.primaryColor
                        : theme.surfaceColor.withOpacity(0.05))),
          if (!isLast)
            Positioned(
                top: 17,
                bottom: 0,
                width: 3,
                child: Stack(children: [
                  Container(color: theme.surfaceColor.withOpacity(0.05)),
                  if (isCompleted) Container(color: theme.primaryColor),
                  if (isTraversing)
                    LayoutBuilder(
                        builder: (c, ct) => Container(
                            height: ct.maxHeight * progress,
                            decoration: BoxDecoration(
                                gradient: theme.progressGradient))),
                ])),
          Positioned(
              top: 17,
              child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: highlighted
                          ? theme.primaryColor
                          : theme.surfaceColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: highlighted
                              ? theme.primaryColor
                              : theme.secondaryTextColor.withOpacity(0.24),
                          width: 2)))),
          if (isTraversing)
            Positioned.fill(
                child: LayoutBuilder(
                    builder: (c, ct) =>
                        Stack(alignment: Alignment.topCenter, children: [
                          Positioned(
                              top: 17 + ((ct.maxHeight - 17) * progress) - 10,
                              child: const _BusIcon(size: 20))
                        ])))
          else if (isActiveStop)
            Positioned(top: 12, child: _BusIcon(size: 20)),
        ],
      ),
    );
  }
}

class _BusIcon extends StatelessWidget {
  final double size;
  const _BusIcon({required this.size});
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: theme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: theme.primaryColor.withOpacity(0.4), blurRadius: 10)
          ]),
      child: Icon(Icons.directions_bus, color: theme.textColor, size: size - 8),
    );
  }
}

class _BusLineNotificationsButton extends StatefulWidget {
  final BusVehicle bus;
  const _BusLineNotificationsButton({required this.bus});

  @override
  State<_BusLineNotificationsButton> createState() => _BusLineNotificationsButtonState();
}

class _BusLineNotificationsButtonState extends State<_BusLineNotificationsButton> {
  bool _enabled = false;

  Future<void> _toggle() async {
    final providerName = widget.bus.provider ?? '';
    final providerParam = providerName.isNotEmpty ? providerName.toLowerCase() : null;
    final tripId = widget.bus.tripId;

    try {
      await AndroidBackgroundService.requestPermission();
      if (!_enabled) {
        if (tripId != null && tripId.isNotEmpty) {
          final endpoint = 'https://betacloud-transporter.is-cool.dev/api/it/bus/${providerParam ?? 'bari'}/realtime?tripId=${Uri.encodeComponent(tripId)}';
          await AndroidBackgroundService.scheduleBusesWorker(provider: providerParam, endpoint: endpoint);
        } else {
          await AndroidBackgroundService.scheduleBusesWorker(provider: providerParam);
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifiche linea ${widget.bus.line} attivate')));
        await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: 'Notifiche linea attivate', body: 'Riceverai aggiornamenti per la linea ${widget.bus.line}');
      } else {
        await AndroidBackgroundService.cancelBusesWorker();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifiche linea ${widget.bus.line} disattivate')));
        await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: 'Notifiche linea disattivate', body: 'Hai disattivato le notifiche per la linea ${widget.bus.line}');
      }
      setState(() => _enabled = !_enabled);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore notifiche: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return IconButton.filledTonal(
      icon: Icon(_enabled ? Icons.notifications_active : Icons.notifications_none),
      onPressed: _toggle,
      style: IconButton.styleFrom(
        backgroundColor: theme.surfaceColor.withOpacity(0.05),
        foregroundColor: theme.secondaryTextColor,
      ),
    );
  }
}

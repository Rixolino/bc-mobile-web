import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_bus_line.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../../presentation/constants/notification_channels.dart';

class BusDetailsSheet extends StatefulWidget {
  final BusVehicle bus;
  final ScrollController? scrollController;
  final DraggableScrollableController? sheetController;
  final String? page; 
  const BusDetailsSheet({super.key, required this.bus, this.scrollController, this.page, this.sheetController});

  @override
  State<BusDetailsSheet> createState() => _BusDetailsSheetState();
}

class _BusDetailsSheetState extends State<BusDetailsSheet> {
  Timer? _timer;
  List<BusTripUpdate> _tripUpdates = [];
  bool _isLoadingUpdates = false;
  final ScrollController _internalScrollController = ScrollController();
  bool _hasScrolledToCurrent = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _fetchTripUpdates(showLoading: true); 
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
    _internalScrollController.dispose();
    final provider = Provider.of<BusProvider>(context, listen: false);
    provider.clearApiTripUpdates();
    super.dispose();
  }

  void _startAutoRefresh() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settings.busRefreshSeconds;

    if (interval > 0) {
      _timer = Timer.periodic(Duration(seconds: interval), (_) {
        if (mounted) _fetchTripUpdates(showLoading: false); 
      });
    }
  }

  void _stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  void _scrollToCurrentStop(List<BusTripUpdate> updates) {
    final currentStopIndex = updates.indexWhere((update) => update.status == 'current');
    if (currentStopIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_internalScrollController.hasClients) {
          final itemHeight = 85.0; // Adeguato alla nuova altezza visuale
          final targetOffset = currentStopIndex * itemHeight;
          _internalScrollController.animateTo(
            targetOffset.clamp(0.0, _internalScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
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
    if (showLoading) setState(() => _isLoadingUpdates = true);
    
    try {
      if (provider.apiTripUpdates.isNotEmpty) {
        setState(() => _tripUpdates = provider.apiTripUpdates);
        if (showLoading && !_hasScrolledToCurrent && _tripUpdates.isNotEmpty) {
          _scrollToCurrentStop(_tripUpdates);
          _hasScrolledToCurrent = true;
        }
        return;
      }

      if (provider.selectedProvider?.name != 'bari') return;

      final updates = await provider.fetchBariTripUpdates(widget.bus.id, widget.bus.line);
      setState(() => _tripUpdates = updates);

      if (showLoading && !_hasScrolledToCurrent && updates.isNotEmpty) {
        _scrollToCurrentStop(updates);
        _hasScrolledToCurrent = true;
      }
    } catch (e) {
      debugPrint('Error fetching trip updates: $e');
    } finally {
      if (showLoading) setState(() => _isLoadingUpdates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BusProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final BusVehicle bus = provider.selectedBus ?? widget.bus;

    final tripStopsData = provider.selectedTripStops;
    final hasTripStopsData = tripStopsData != null && tripStopsData.stops.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 45, height: 5,
              decoration: BoxDecoration(color: theme.secondaryTextColor.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              controller: widget.scrollController, // Controller esterno per il drag dello sheet
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(theme, bus, provider),
                  const SizedBox(height: 20),
                  _buildActionRow(theme, bus),
                  const SizedBox(height: 24),
                  _buildVehicleInfoCard(theme, bus),
                  const SizedBox(height: 24),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text("Fermate del Viaggio", style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 12),
                  
                  // Sezione Timeline
                  if (provider.selectedProvider?.name == 'bari') ...[
                    SizedBox(
                      height: 380, // Altezza maggiorata per UX migliore
                      child: provider.isLoadingTripStops
                          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                          : hasTripStopsData
                              ? _buildTripStopsTimeline(tripStopsData.stops, theme)
                              : _isLoadingUpdates
                                  ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                                  : _tripUpdates.isEmpty
                                      ? Center(child: Text("Nessun aggiornamento", style: TextStyle(color: theme.secondaryTextColor)))
                                      : _buildBusTimeline(_tripUpdates, theme),
                    ),
                  ] else ...[
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          "Dettagli fermate non disponibili per ${provider.selectedProvider?.name ?? 'questo operatore'}",
                          style: TextStyle(color: theme.secondaryTextColor),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme, BusVehicle bus, BusProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassmorphicContainer(
            width: 65, height: 65,
            borderRadius: 20, blur: 10, alignment: Alignment.center,
            border: 2, linearGradient: LinearGradient(colors: [theme.primaryColor.withOpacity(0.6), theme.primaryColor.withOpacity(0.2)]),
            borderGradient: LinearGradient(colors: [Colors.white24, Colors.white10]),
            child: Text(bus.line, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text((bus.provider ?? 'BUS').toUpperCase(), style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(width: 8),
                    if (_timer != null) _buildLiveBadge(theme),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  bus.destination ?? 'Destinazione N/A',
                  style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.w900, height: 1.1),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: theme.secondaryTextColor),
            onPressed: () {
              provider.clearBusSelection();
              if (widget.scrollController == null) Navigator.of(context).pop();
            },
          )
        ],
      ),
    );
  }

  Widget _buildLiveBadge(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: theme.successColor.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: theme.successColor.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulseDot(color: theme.successColor),
          const SizedBox(width: 4),
          Text("LIVE", style: TextStyle(color: theme.successColor, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActionRow(ThemeProvider theme, BusVehicle bus) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _FavoriteBusButton(bus: bus, theme: theme)),
          const SizedBox(width: 12),
          Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              final canRefresh = settings.busRefreshSeconds > 0;
              return _buildSquareButton(
                icon: _timer != null ? Icons.timer_rounded : Icons.timer_off_rounded,
                color: _timer != null ? theme.primaryColor : theme.secondaryTextColor,
                theme: theme,
                onTap: canRefresh ? _toggleAutoRefresh : null,
              );
            },
          ),
          const SizedBox(width: 12),
          _BusLineNotificationsButton(bus: bus),
        ],
      ),
    );
  }

  Widget _buildSquareButton({required IconData icon, required Color color, required ThemeProvider theme, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52, width: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _buildVehicleInfoCard(ThemeProvider theme, BusVehicle bus) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryTextColor.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.08)),
        ),
        child: Column(
          children: [
            ListTile(
              onTap: () => _showVehicleDetailsDialog(context, bus, theme),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.info_outline_rounded, color: theme.primaryColor, size: 20),
              ),
              title: Text("Dettagli e Posizione", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 15)),
              subtitle: Text("ID: ${bus.id} • Premi per info", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
              trailing: Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.my_location_rounded, color: theme.secondaryTextColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${bus.latitude.toStringAsFixed(5)}, ${bus.longitude.toStringAsFixed(5)}", style: TextStyle(color: theme.textColor, fontSize: 13, fontFamily: 'monospace')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MANTENUTA LA LOGICA TIMELINE ORIGINALE ---

  Widget _buildBusTimeline(List<BusTripUpdate> updates, ThemeProvider theme) {
    return ListView.builder(
      controller: _internalScrollController, // Controller interno per lo scroll della lista
      itemCount: updates.length,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final update = updates[index];
        final isLast = index == updates.length - 1;
        final isCompleted = update.status == 'passed';
        final isActive = update.status == 'current';

        double progress = 0.0;
        bool isTraversing = false;

        if (isActive && !isLast && index + 1 < updates.length) {
          final nextUpdate = updates[index + 1];
          if (nextUpdate.status == 'future') {
            final now = DateTime.now();
            final timeParts = update.expectedTime.split(':');
            if (timeParts.length == 2) {
              final expectedHour = int.tryParse(timeParts[0]) ?? 0;
              final expectedMinute = int.tryParse(timeParts[1]) ?? 0;
              final expectedTime = DateTime(now.year, now.month, now.day, expectedHour, expectedMinute);
              final actualTime = expectedTime.add(Duration(minutes: update.delayMinutes));

              final nextTimeParts = nextUpdate.expectedTime.split(':');
              if (nextTimeParts.length == 2) {
                final nextHour = int.tryParse(nextTimeParts[0]) ?? 0;
                final nextMinute = int.tryParse(nextTimeParts[1]) ?? 0;
                final nextTime = DateTime(now.year, now.month, now.day, nextHour, nextMinute);
                final nextActualTime = nextTime.add(Duration(minutes: nextUpdate.delayMinutes));

                final totalDuration = nextActualTime.difference(actualTime).inMinutes;
                final elapsed = now.difference(actualTime).inMinutes;
                progress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;
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

  Widget _buildTripStopsTimeline(List<TripStop> stops, ThemeProvider theme) {
    return ListView.builder(
      controller: _internalScrollController,
      itemCount: stops.length,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        final stop = stops[index];
        final isLast = index == stops.length - 1;
        final isCompleted = stop.status == 'passed';
        final isActive = stop.status == 'current';

        if (isActive && !_hasScrolledToCurrent) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentStopFromTripStops(stops);
            _hasScrolledToCurrent = true;
          });
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTripStopVisualTimeline(stop, isLast, index, theme),
              const SizedBox(width: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(stop.stopName,
                          style: TextStyle(
                              color: isCompleted ? theme.secondaryTextColor.withOpacity(0.6) : theme.textColor,
                              fontSize: 15,
                              fontWeight: isActive ? FontWeight.w900 : FontWeight.w600)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(stop.scheduledTime + stop.delayText,
                              style: TextStyle(
                                  color: isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor,
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          if (stop.isRealtime) ...[
                            const SizedBox(width: 6),
                            Text("• LIVE", style: TextStyle(color: theme.successColor, fontSize: 10, fontWeight: FontWeight.w900)),
                          ]
                        ],
                      ),
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
            Positioned(top: 0, height: 20, width: 3, child: Container(color: highlighted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.05))),
          if (!isLast)
            Positioned(top: 20, bottom: 0, width: 3, child: Container(color: isCompleted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.05))),
          Positioned(
              top: 17,
              child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: isCompleted ? theme.primaryColor : (isActive ? theme.primaryColor : theme.surfaceColor.withOpacity(0.08)),
                      shape: BoxShape.circle,
                      border: Border.all(color: highlighted ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.24), width: 2)))),
          if (isActive)
            Positioned(top: 10, child: _BusIcon(size: 24)),
        ],
      ),
    );
  }

  void _scrollToCurrentStopFromTripStops(List<TripStop> stops) {
    final currentStopIndex = stops.indexWhere((stop) => stop.status == 'current');
    if (currentStopIndex != -1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_internalScrollController.hasClients) {
          final itemHeight = 85.0;
          final targetOffset = currentStopIndex * itemHeight;
          _internalScrollController.animateTo(
            targetOffset.clamp(0.0, _internalScrollController.position.maxScrollExtent),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    }
  }

  void _showVehicleDetailsDialog(BuildContext context, BusVehicle bus, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: theme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.directions_bus, color: theme.primaryColor)),
              const SizedBox(width: 12),
              Text("Info Veicolo", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogInfoRow("ID Veicolo", bus.id, theme),
              _buildDialogInfoRow("Linea", bus.line, theme),
              if (bus.destination != null) _buildDialogInfoRow("Destinazione", bus.destination!, theme),
              if (bus.speed != null) _buildDialogInfoRow("Velocità", "${bus.speed} km/h", theme),
              if (bus.heading != null) _buildDialogInfoRow("Direzione", "${bus.heading}°", theme),
              if (bus.provider != null) _buildDialogInfoRow("Operatore", bus.provider!, theme),
              if (bus.tripId != null) _buildDialogInfoRow("ID Viaggio", bus.tripId!, theme),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Chiudi", style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDialogInfoRow(String label, String value, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: TextStyle(color: theme.textColor, fontSize: 13, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}

// --- CLASSI DI SUPPORTO (Grafica Timeline) ---

class _BusTimelineRow extends StatelessWidget {
  final BusTripUpdate update;
  final int index;
  final bool isLast;
  final bool isCompleted;
  final bool isTraversing;
  final bool isActiveStop;
  final double progress;
  final ThemeProvider theme;

  const _BusTimelineRow({required this.update, required this.index, required this.isLast, required this.isCompleted, required this.isTraversing, required this.isActiveStop, required this.progress, required this.theme});

  @override
  Widget build(BuildContext context) {
    final bool highlighted = isCompleted || isActiveStop || isTraversing;
    String timeString = update.expectedTime;
    if (update.delayMinutes > 0) timeString += " (+${update.delayMinutes}min)";
    else if (update.delayMinutes < 0) timeString += " (${update.delayMinutes}min)";

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVisualTimeline(highlighted),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(update.stopName, style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.6) : theme.textColor, fontSize: 15, fontWeight: highlighted ? FontWeight.w900 : FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(timeString, style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      if (update.isRealtime) ...[
                        const SizedBox(width: 6),
                        Text("• LIVE", style: TextStyle(color: theme.successColor, fontSize: 10, fontWeight: FontWeight.w900)),
                      ]
                    ],
                  ),
                  if (update.arrivalEstimate != null && update.arrivalEstimate!.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: update.arrivalEstimate == 'In arrivo' ? theme.primaryColor.withOpacity(0.1) : theme.surfaceColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: update.arrivalEstimate == 'In arrivo' ? theme.primaryColor.withOpacity(0.3) : theme.secondaryTextColor.withOpacity(0.1)),
                      ),
                      child: Text(update.arrivalEstimate!, style: TextStyle(color: update.arrivalEstimate == 'In arrivo' ? theme.primaryColor : theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
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
          if (index > 0) Positioned(top: 0, height: 20, width: 3, child: Container(color: highlighted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.05))),
          if (!isLast)
            Positioned(
              top: 20, bottom: 0, width: 3,
              child: Stack(children: [
                Container(color: theme.surfaceColor.withOpacity(0.05)),
                if (isCompleted) Container(color: theme.primaryColor),
                if (isTraversing)
                  LayoutBuilder(builder: (c, ct) => Container(height: ct.maxHeight * progress, decoration: BoxDecoration(color: theme.primaryColor))), // Sostituito progressGradient per compatibilità
              ])
            ),
          Positioned(
              top: 17,
              child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                      color: highlighted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.08),
                      shape: BoxShape.circle,
                      border: Border.all(color: highlighted ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.24), width: 2)))),
          if (isTraversing)
            Positioned.fill(
                child: LayoutBuilder(builder: (c, ct) => Stack(alignment: Alignment.topCenter, children: [Positioned(top: 17 + ((ct.maxHeight - 17) * progress) - 12, child: const _BusIcon(size: 24))]))
            )
          else if (isActiveStop)
            Positioned(top: 10, child: _BusIcon(size: 24)),
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
      decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)]),
      child: Icon(Icons.directions_bus, color: Colors.white, size: size - 8),
    );
  }
}

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _controller, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle)));
  }
}

// --- LOGICA BOTTONI (MANTENUTA INTATTA) ---

class _FavoriteBusButton extends StatelessWidget {
  final BusVehicle bus;
  final ThemeProvider theme;
  const _FavoriteBusButton({required this.bus, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer2<FavoritesProvider, AuthProvider>(
      builder: (context, favs, auth, _) {
        final isFav = favs.isBusLineFavorite(bus.line, bus.provider ?? '');
        return InkWell(
          onTap: () async {
            if (!auth.isAuthenticated) return;
            if (isFav) await favs.removeBusLineFavorite(bus.line, bus.provider?.toString() ?? '');
            else await favs.addBusLineFavorite(FavoriteBusLine(id: '${bus.provider}_${bus.line}', addedAt: DateTime.now(), userId: auth.currentUser?.id?.toString() ?? 'guest', lineCode: bus.line, lineName: bus.destination ?? bus.line, provider: bus.provider?.toString() ?? '', routeId: bus.tripId?.toString()));
          },
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: isFav ? Colors.redAccent.withOpacity(0.1) : theme.secondaryTextColor.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: isFav ? Colors.redAccent.withOpacity(0.3) : Colors.transparent)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded, size: 20, color: isFav ? Colors.redAccent : theme.secondaryTextColor),
                const SizedBox(width: 8),
                Text(isFav ? "Salvata" : "Salva Linea", style: TextStyle(color: isFav ? Colors.redAccent : theme.textColor, fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ),
        );
      },
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
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (tripId != null && tripId.isNotEmpty) {
          final endpoint = 'https://betacloud-transporter.is-cool.dev/api/it/bus/${providerParam ?? 'bari'}/realtime?tripId=${Uri.encodeComponent(tripId)}';
          await AndroidBackgroundService.scheduleBusesWorker(provider: providerParam, endpoint: endpoint, intervalSeconds: settings.busRefreshSeconds);
        } else {
          await AndroidBackgroundService.scheduleBusesWorker(provider: providerParam, intervalSeconds: settings.busRefreshSeconds);
        }

        String body = 'Riceverai aggiornamenti per la linea ${widget.bus.line}';
        try {
          final provider = Provider.of<BusProvider>(context, listen: false);
          final List<BusTripUpdate> updates = await provider.fetchBariTripUpdates(widget.bus.id, widget.bus.line);
          if (updates.isNotEmpty) {
            final now = DateTime.now();
            final next = updates.firstWhere((u) => u.status != 'passed', orElse: () => updates.first);
            final nextStop = next.stopName;
            int? minutes;
            final eta = (next.arrivalEstimate ?? '').trim();
            if (eta.isNotEmpty) {
              if (eta.toLowerCase().contains('arriv')) minutes = 0;
              else {
                final m = RegExp(r'~?(\d+)').firstMatch(eta);
                if (m != null) minutes = int.tryParse(m.group(1)!);
              }
            }
            final expected = next.expectedTime;
            if (minutes == null && expected.contains(':')) {
              try {
                final parts = expected.split(':');
                final h = int.tryParse(parts[0]) ?? 0;
                final mm = int.tryParse(parts[1]) ?? 0;
                var dt = DateTime(now.year, now.month, now.day, h, mm);
                if (dt.isBefore(now.subtract(const Duration(hours: 1)))) dt = dt.add(const Duration(days: 1));
                minutes = dt.difference(now).inMinutes;
              } catch (_) {}
            }
            final etaText = minutes == null ? (eta.isNotEmpty ? eta : '') : (minutes <= 0 ? 'In arrivo' : '${minutes} min');
            body = 'Prossima fermata: $nextStop — $etaText';
          }
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Notifiche linea ${widget.bus.line} attivate')));
        await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: 'Notifiche linea attivate', body: body);
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
    return InkWell(
      onTap: _toggle,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 52, width: 52,
        decoration: BoxDecoration(
          color: _enabled ? theme.primaryColor.withOpacity(0.1) : theme.secondaryTextColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _enabled ? theme.primaryColor.withOpacity(0.3) : Colors.transparent),
        ),
        child: Icon(_enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, color: _enabled ? theme.primaryColor : theme.secondaryTextColor, size: 22),
      ),
    );
  }
}
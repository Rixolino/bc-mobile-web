import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/design_system.dart';
import '../../../../core/services/runtime_localizations.dart';

/// Schermata intera con pulsante indietro per il dettaglio di una corsa
/// Flixbus (`GET /api/flixbus/trip?tripId={tripId}`).
class FlixbusTripDetailsSheet extends StatefulWidget {
  final String tripId;

  const FlixbusTripDetailsSheet({super.key, required this.tripId});

  @override
  State<FlixbusTripDetailsSheet> createState() =>
      _FlixbusTripDetailsSheetState();
}

class _FlixbusTripDetailsSheetState extends State<FlixbusTripDetailsSheet> {
  final ScrollController _scrollController = ScrollController();
  final MapController _mapController = MapController();
  Timer? _timer;
  BusProvider? _busProvider;
  bool _mapFitted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BusProvider>(context, listen: false)
          .selectFlixbusTrip(widget.tripId);
    });
    _startAutoRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _busProvider = Provider.of<BusProvider>(context, listen: false);

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
    _mapController.dispose();
    super.dispose();
  }

  /// Auto-refresh della corsa basato sulle impostazioni
  /// (stesso intervallo degli altri bus: `busRefreshSeconds`).
  void _startAutoRefresh() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settings.busRefreshSeconds;
    if (interval > 0 && mounted) {
      _timer?.cancel();
      _timer = Timer.periodic(Duration(seconds: interval), (_) {
        if (mounted) _refreshTrip(silent: true);
      });
    }
  }

  void _stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _refreshTrip({bool silent = false}) async {
    final provider =
        _busProvider ?? Provider.of<BusProvider>(context, listen: false);
    await provider.selectFlixbusTrip(widget.tripId, silent: silent);
    if (mounted) setState(() {});
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '--:--';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  /// Stato fermata rispetto all'ora attuale: passed / current / future.
  String _stopStatus(FlixbusTripStop s, DateTime now) {
    final arr = s.estimatedArrival ?? s.scheduledArrival;
    final dep = s.estimatedDeparture ?? s.scheduledDeparture;
    if (dep != null && now.isAfter(dep)) return 'passed';
    if (arr != null &&
        dep != null &&
        !now.isBefore(arr) &&
        !now.isAfter(dep)) {
      return 'current';
    }
    if (arr != null && dep == null && now.isAfter(arr)) return 'passed';
    return 'future';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Consumer<BusProvider>(
        builder: (context, provider, _) {
          final trip = provider.selectedFlixbusTrip;

          if (provider.isLoadingFlixbusTrip) {
            return const Center(child: CircularProgressIndicator());
          }

          if (trip == null) {
            return SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _BackButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.of(context).pop(),
                        theme: theme,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bus_alert_rounded,
                                size: 48,
                                color: theme.secondaryTextColor
                                    .withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text(
                              RuntimeLocalizations.t(
                                      context, 'trip_details_unavailable') ??
                                  'Dettagli corsa non disponibili',
                              textAlign: TextAlign.center,
                              style: AppTextStyle.titleMedium(
                                  color: theme.textColor),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => provider
                                  .selectFlixbusTrip(widget.tripId),
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(
                                  RuntimeLocalizations.t(
                                          context, 'retry') ??
                                      'Riprova'),
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

          if (!_mapFitted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitMapToTrip(trip);
            });
          }

          return Column(
            children: [
              _buildHeroHeader(theme, trip),
              _buildMapCard(theme, trip),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: trip.stops.length,
                  itemBuilder: (context, index) {
                    final stop = trip.stops[index];
                    return _buildStopRow(theme, trip, stop, index);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Una coordinata è valida solo se finita e non (0,0).
  bool _hasValidCoords(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        (lat != 0.0 || lng != 0.0);
  }

  /// Punti del percorso (fermate con coordinate valide).
  List<LatLng> _tripPoints(FlixbusTrip trip) {
    return trip.stops
        .where((s) => _hasValidCoords(s.latitude, s.longitude))
        .map((s) => LatLng(s.latitude, s.longitude))
        .toList();
  }

  /// Punti della polyline reale, con fallback alle fermate.
  List<LatLng> _routePoints(FlixbusTrip trip) {
    final route = trip.routePoints;
    return route.length >= 2 ? route : _tripPoints(trip);
  }

  void _fitMapToTrip(FlixbusTrip trip) {
    final points = _routePoints(trip);
    if (points.isEmpty) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          padding: const EdgeInsets.all(40),
        ),
      );
      _mapFitted = true;
    } catch (_) {}
  }

  void _centerOnBus(FlixbusTrip trip) {
    final lat = trip.currentLatitude;
    final lng = trip.currentLongitude;
    if (lat == null || lng == null || !lat.isFinite || !lng.isFinite) {
      return;
    }
    try {
      _mapController.move(
        LatLng(lat, lng),
        10.0,
      );
    } catch (_) {}
  }

  bool _hasBusPos(FlixbusTrip trip) {
    final lat = trip.currentLatitude;
    final lng = trip.currentLongitude;
    return lat != null && lng != null && lat.isFinite && lng.isFinite;
  }

  Widget _buildMapCard(ThemeProvider theme, FlixbusTrip trip) {
    final mapState = Provider.of<MapStateProvider>(context);
    final points = _tripPoints(trip);
    final hasBusPos = _hasBusPos(trip);

    final initialCenter = points.isNotEmpty
        ? points.first
        : const LatLng(41.9, 12.5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        child: SizedBox(
          height: 220,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: initialCenter,
                  initialZoom: 5.0,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://api.mapbox.com/styles/v1/mapbox/${mapState.mapStyle}/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoiY3V6aW1tYXJ0aW4iLCJhIjoiY204dGRyb3AxMDgxcDJrc2VjeXVwNXN3NyJ9.VR8xzsuQJ_-0h95CN_UD8g',
                    userAgentPackageName: 'dev.iscool.bctransporter',
                  ),
                  if (_routePoints(trip).length > 1)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints(trip),
                          color: Colors.lightGreen,
                          strokeWidth: 4.0,
                          borderColor: theme.surfaceColor,
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      for (int i = 0; i < trip.stops.length; i++)
                        if (_hasValidCoords(trip.stops[i].latitude,
                            trip.stops[i].longitude))
                          Marker(
                            point: LatLng(trip.stops[i].latitude,
                                trip.stops[i].longitude),
                            width: 18,
                            height: 18,
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == 0
                                    ? Colors.green
                                    : (i == trip.stops.length - 1
                                        ? Colors.red
                                        : theme.primaryColor),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      if (hasBusPos)
                        Marker(
                          point: LatLng(trip.currentLatitude!,
                              trip.currentLongitude!),
                          width: 40,
                          height: 40,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.lightGreen,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.lightGreen
                                      .withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: const Icon(
                                Icons.directions_bus_rounded,
                                color: Colors.white,
                                size: 18),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              // Pulsanti mappa
              Positioned(
                right: 10,
                bottom: 10,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _mapFitted = false;
                        _fitMapToTrip(trip);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color:
                              theme.surfaceColor.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: theme.secondaryTextColor
                                  .withValues(alpha: 0.15)),
                        ),
                        child: Icon(Icons.route_rounded,
                            size: 18, color: theme.textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasBusPos)
                      GestureDetector(
                        onTap: () => _centerOnBus(trip),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.lightGreen.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.my_location_rounded,
                              size: 18,
                              color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(ThemeProvider theme, FlixbusTrip trip) {
    final delay = trip.delayMinutes;
    final Color statusColor;
    final String statusText;
    if (delay > 0) {
      statusColor = theme.warningColor;
      statusText = '+$delay min';
    } else {
      statusColor = theme.successColor;
      statusText =
          RuntimeLocalizations.t(context, 'on_time') ?? 'In orario';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.lightGreen.withValues(alpha: theme.isDark ? 0.25 : 0.12),
            theme.backgroundColor,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            children: [
              Row(
                children: [
                  _BackButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    theme: theme,
                  ),
                  const Spacer(),
                  if (_timer != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.successColor
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              AppTokens.radiusFull),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: theme.successColor,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('LIVE',
                                style: TextStyle(
                                    color: theme.successColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _refreshTrip(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: theme.surfaceColor.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.borderColor
                                .withValues(alpha: 0.2)),
                      ),
                      child: Icon(Icons.refresh_rounded,
                          color: theme.textColor, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppTokens.radiusFull),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(statusText,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Linea + destinazione
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.lightGreen,
                    Colors.lightGreen.withValues(alpha: 0.7)
                  ]),
                  borderRadius:
                      BorderRadius.circular(AppTokens.radiusLg),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.lightGreen.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_bus_rounded,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        trip.line.isNotEmpty ? trip.line : 'FLX',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                trip.destination?.stationName ?? '',
                style:
                    AppTextStyle.titleMedium(color: theme.textColor),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (trip.origin != null)
                Text(
                  '${trip.origin!.stationName} → ${trip.destination?.stationName ?? ''}',
                  style: AppTextStyle.bodySmall(
                      color: theme.secondaryTextColor),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (trip.currentLatitude != null &&
                  trip.currentLongitude != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.surfaceColor,
                    borderRadius:
                        BorderRadius.circular(AppTokens.radiusFull),
                    border: Border.all(
                        color:
                            theme.borderColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location_rounded,
                          size: 13, color: theme.secondaryTextColor),
                      const SizedBox(width: 6),
                      Text(
                        '${RuntimeLocalizations.t(context, 'live') ?? 'LIVE'} • ${trip.currentLatitude!.toStringAsFixed(4)}, ${trip.currentLongitude!.toStringAsFixed(4)}',
                        style: AppTextStyle.bodySmall(
                            color: theme.secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopRow(ThemeProvider theme, FlixbusTrip trip,
      FlixbusTripStop stop, int index) {
    final now = DateTime.now();
    final status = _stopStatus(stop, now);
    final isLast = index == trip.stops.length - 1;
    final isCompleted = status == 'passed';
    final isActive = status == 'current';
    final stopDelay = stop.delay;

    final arr = stop.estimatedArrival ?? stop.scheduledArrival;
    final dep = stop.estimatedDeparture ?? stop.scheduledDeparture;
    final showEstimatedArr = stop.estimatedArrival != null &&
        stop.scheduledArrival != null &&
        stop.estimatedArrival != stop.scheduledArrival;
    final showEstimatedDep = stop.estimatedDeparture != null &&
        stop.scheduledDeparture != null &&
        stop.estimatedDeparture != stop.scheduledDeparture;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline
          SizedBox(
            width: 30,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (index > 0)
                  Positioned(
                      top: 0,
                      height: 20,
                      width: 3,
                      child: Container(
                          color: isCompleted
                              ? Colors.lightGreen
                              : theme.surfaceColor
                                  .withValues(alpha: 0.08))),
                if (!isLast)
                  Positioned(
                      top: 20,
                      bottom: 0,
                      width: 3,
                      child: Container(
                          color: isCompleted
                              ? Colors.lightGreen
                              : theme.surfaceColor
                                  .withValues(alpha: 0.08))),
                Positioned(
                    top: 17,
                    child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                            color: isCompleted || isActive
                                ? Colors.lightGreen
                                : theme.surfaceColor
                                    .withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isCompleted || isActive
                                    ? Colors.lightGreen
                                    : theme.secondaryTextColor
                                        .withValues(alpha: 0.24),
                                width: 2)))),
                if (isActive)
                  Positioned(
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: Colors.lightGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.lightGreen
                                    .withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2)
                          ]),
                      child: const Icon(Icons.directions_bus,
                          color: Colors.white, size: 14),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Info fermata
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          stop.stationName,
                          style: TextStyle(
                              color: isCompleted
                                  ? theme.secondaryTextColor
                                      .withValues(alpha: 0.6)
                                  : theme.textColor,
                              fontSize: 15,
                              fontWeight: isActive
                                  ? FontWeight.w900
                                  : FontWeight.w600),
                        ),
                      ),
                      if (stop.platform != null)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: theme.primaryColor
                                    .withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            stop.platform!,
                            style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (arr != null)
                    _buildTimeRow(
                      theme,
                      label:
                          '${RuntimeLocalizations.t(context, 'arrival') ?? 'Arrivo'}: ',
                      scheduled: stop.scheduledArrival,
                      estimated: stop.estimatedArrival,
                      showEstimated: showEstimatedArr,
                      isCompleted: isCompleted,
                    ),
                  if (dep != null && (index != trip.stops.length - 1 || arr == null))
                    _buildTimeRow(
                      theme,
                      label:
                          '${RuntimeLocalizations.t(context, 'departure') ?? 'Partenza'}: ',
                      scheduled: stop.scheduledDeparture,
                      estimated:
                          showEstimatedDep ? stop.estimatedDeparture : null,
                      showEstimated: showEstimatedDep,
                      isCompleted: isCompleted,
                    ),
                  if (stopDelay > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '+$stopDelay min',
                        style: TextStyle(
                            color: theme.warningColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRow(
    ThemeProvider theme, {
    required String label,
    required DateTime? scheduled,
    required DateTime? estimated,
    required bool showEstimated,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
                color: isCompleted
                    ? theme.secondaryTextColor.withValues(alpha: 0.4)
                    : theme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold),
          ),
          Text(
            _fmtTime(scheduled),
            style: TextStyle(
                color: isCompleted
                    ? theme.secondaryTextColor.withValues(alpha: 0.4)
                    : theme.secondaryTextColor,
                fontSize: 12),
          ),
          if (showEstimated && estimated != null) ...[
            Text(
              ' (${RuntimeLocalizations.t(context, 'scheduled_label') ?? 'Previsto'}: ${_fmtTime(estimated)})',
              style:
                  TextStyle(color: theme.warningColor, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Back button widget
// ─────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeProvider theme;

  const _BackButton(
      {required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.surfaceColor.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border:
              Border.all(color: theme.borderColor.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: theme.textColor, size: 18),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/design_system.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../favorites/models/favorite_stop.dart';
import '../../../auth/providers/auth_provider.dart';
import 'bus_details_sheet.dart';

class BusStopDetailsSheet extends StatefulWidget {
  final BariStop stop;
  final ScrollController? scrollController; // Controller dello Sheet
  const BusStopDetailsSheet({super.key, required this.stop, this.scrollController});

  @override
  State<BusStopDetailsSheet> createState() => _BusStopDetailsSheetState();
}

class _BusStopDetailsSheetState extends State<BusStopDetailsSheet> {
  Timer? _timer;
  List<StopDeparture> _departures = [];
  bool _isLoadingDepartures = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _fetchDepartures(showLoading: true);
    AndroidBackgroundService.isStopMonitored(widget.stop.stopId).then((v) {
      if (mounted) setState(() => _notificationsEnabled = v);
    });
  }

  // Quando si clicca su una linea, proviamo a trovare una departure con tripId
  // e apriamo il BusDetailsSheet con quella corsa. Se non trovata, mostriamo un messaggio.
  Future<void> _onLineTap(String line, BusProvider provider) async {
    StopDeparture? dep;
    try {
      dep = _departures.firstWhere((d) => d.line == line && d.tripId.isNotEmpty);
    } catch (_) {
      try {
        dep = _departures.firstWhere((d) => d.line == line);
      } catch (_) {
        dep = null;
      }
    }

    if (dep == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(context, 'no_route_for_line', params: {'line': line}))));
      return;
    }

    await _navigateToBusDetails(dep, provider);
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    super.dispose();
  }

  void _startAutoRefresh() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (settings.busRefreshSeconds > 0) {
      _timer = Timer.periodic(Duration(seconds: settings.busRefreshSeconds), (_) {
        if (mounted) _fetchDepartures(showLoading: false);
      });
    }
  }

  void _stopAutoRefresh() => _timer?.cancel();

  Future<void> _fetchDepartures({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoadingDepartures = true);
    try {
      final provider = Provider.of<BusProvider>(context, listen: false);
      final departures = await provider.fetchStopUpdates(widget.stop.stopId);
      if (mounted) setState(() => _departures = departures);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (showLoading && mounted) setState(() => _isLoadingDepartures = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<BusProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);

    // Landscape: header e azioni a sinistra, partenze a destra.
    final isLandscapeStop =
        MediaQuery.of(context).orientation == Orientation.landscape;
    // ── HERO HEADER ──
    final stopHero = Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTokens.busColor.withValues(alpha: theme.isDark ? 0.25 : 0.12),
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
                        _BackButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop(), theme: theme),
                        Expanded(
                          child: Text(
                            widget.stop.stopName,
                            style: AppTextStyle.headlineSmall(color: theme.textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Stop ID badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.surfaceColor,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(color: theme.borderColor.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tag_rounded, size: 14, color: theme.secondaryTextColor),
                          const SizedBox(width: 6),
                          Text('ID: ${widget.stop.stopId}', style: AppTextStyle.bodySmall(color: theme.secondaryTextColor).copyWith(fontFamily: 'monospace')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // ── ACTIONS ──
          final stopActions = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _buildMainActions(theme, provider),
          );

          // ── DEPARTURES TITLE ──
          final departuresTitle = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(RuntimeLocalizations.t(context, 'upcoming_departures') ?? 'Prossime partenze', style: AppTextStyle.titleMedium(color: theme.textColor)),
                if (_isLoadingDepartures)
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)),
              ],
            ),
          );

          // ── DEPARTURES LIST ──
          final departuresList = _departures.isEmpty && !_isLoadingDepartures
              ? _buildEmptyState(theme)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  itemCount: _departures.length,
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) => _buildDepartureCard(_departures[index], theme, provider),
                );

          if (isLandscapeStop) {
            // Landscape: info fermata a sinistra, partenze a destra.
            return Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.34 < 360
                          ? MediaQuery.of(context).size.width * 0.34
                          : 360,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            stopHero,
                            stopActions,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    color: theme.secondaryTextColor.withValues(alpha: 0.1),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, MediaQuery.of(context).padding.top + 8, 0, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          departuresTitle,
                          Expanded(child: departuresList),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return Scaffold(
            backgroundColor: theme.backgroundColor,
            body: Column(
              children: [
                stopHero,
                stopActions,
                departuresTitle,
                Expanded(child: departuresList),
              ],
            ),
          );
  }

  // --- COMPONENTI UI ---

  Widget _buildMainActions(ThemeProvider theme, BusProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Consumer2<FavoritesProvider, AuthProvider>(
            builder: (ctx, favs, auth, _) {
              final isFav = favs.isStopFavorite(widget.stop.stopId, StopType.busStop);
                return _buildActionButton(
                label: isFav ? RuntimeLocalizations.t(context, 'saved') : RuntimeLocalizations.t(context, 'favorite_action'),
                icon: isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                active: isFav, color: Colors.redAccent, theme: theme,
                onTap: () async {
                  if (!auth.isAuthenticated) return;
                  if (isFav) {
                    await favs.removeStopFavorite(widget.stop.stopId, StopType.busStop);
                  } else {
                    await favs.addStopFavorite(favs.createFavoriteStop(
                      userId: auth.currentUser?.id?.toString() ?? '',
                      name: widget.stop.stopName, code: widget.stop.stopId,
                      stopType: StopType.busStop, latitude: widget.stop.latitude,
                      longitude: widget.stop.longitude, provider: provider.selectedProvider?.name,
                    ));
                  }
                },
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            label: _notificationsEnabled ? "Attive" : "Notifiche",
            icon: _notificationsEnabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
            active: _notificationsEnabled, color: theme.primaryColor, theme: theme,
            onTap: _toggleNotifications,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required bool active, required Color color, required ThemeProvider theme, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.1) : theme.secondaryTextColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? color.withOpacity(0.3) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: active ? color : theme.secondaryTextColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: active ? color : theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalInfoChips(ThemeProvider theme, BusProvider provider) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _buildInfoChip(Icons.tag, "ID: ${widget.stop.stopId}", theme, () => Clipboard.setData(ClipboardData(text: widget.stop.stopId))),
          _buildInfoChip(Icons.location_city_rounded, _capitalizeFirst(provider.selectedProvider?.name ?? 'Città'), theme, null),
          _buildInfoChip(Icons.my_location_rounded, "${widget.stop.latitude.toStringAsFixed(4)}, ${widget.stop.longitude.toStringAsFixed(4)}", theme, () => Clipboard.setData(ClipboardData(text: '${widget.stop.latitude},${widget.stop.longitude}'))),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, ThemeProvider theme, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: theme.surfaceColor,
        side: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        avatar: Icon(icon, size: 14, color: theme.primaryColor),
        label: Text(label, style: TextStyle(color: theme.textColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildDepartureCard(StopDeparture dep, ThemeProvider theme, BusProvider provider) {
    final diff = DateTime.fromMillisecondsSinceEpoch((dep.time * 1000).toInt()).difference(DateTime.now()).inMinutes;
    Color statusColor = dep.isRealtime ? theme.successColor : theme.secondaryTextColor;
    if (diff <= 3) statusColor = Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => _navigateToBusDetails(dep, provider),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: theme.primaryColor, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(dep.line, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dep.destination ?? 'N/A', style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w800, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(dep.formattedTime, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(diff <= 0 ? "Adesso" : "$diff min", style: TextStyle(color: statusColor, fontWeight: FontWeight.w900, fontSize: 16)),
                if (dep.isRealtime) Text("• ${RuntimeLocalizations.t(context, 'live')}", style: TextStyle(color: theme.successColor, fontSize: 9, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bus_alert_rounded, size: 40, color: theme.secondaryTextColor.withOpacity(0.2)),
          const SizedBox(height: 8),
          Text(RuntimeLocalizations.t(context, 'no_bus_scheduled'), style: TextStyle(color: theme.secondaryTextColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // --- LOGICA ---

  Future<void> _toggleNotifications() async {
    await AndroidBackgroundService.requestPermission();
    final provider = Provider.of<BusProvider>(context, listen: false);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!_notificationsEnabled) {
      final provName = provider.selectedProvider == null ? null : provider.selectedProvider!.name.toLowerCase();
      await AndroidBackgroundService.scheduleBusesWorker(
        provider: provName,
        intervalSeconds: settings.busRefreshSeconds,
        stopId: widget.stop.stopId, stopName: widget.stop.stopName
      );
    } else {
      await AndroidBackgroundService.removeMonitoredStop(widget.stop.stopId);
    }
    setState(() => _notificationsEnabled = !_notificationsEnabled);
  }

  Future<void> _navigateToBusDetails(StopDeparture dep, BusProvider provider) async {
    final selProv = provider.selectedProvider;
    if (selProv == null || dep.tripId.isEmpty) return;

    // If the departure object already carries a detailed stops list (e.g. Turin
    // stops-updates now includes them), we can skip the extra API call.
    List<BusTripUpdate> stops = [];
    if (dep.stops != null && dep.stops!.isNotEmpty) {
      stops = dep.stops!
          .map((s) => BusTripUpdate(
                stopId: s.stopId,
                stopName: s.stopName,
                expectedTime: s.scheduledTime,
                delay: s.delay,
                isRealtime: s.isRealtime,
                status: s.status,
                arrivalEstimate: s.estimatedArrivalUnix?.toString(),
              ))
          .toList();
    } else {
      // Endpoint realtime generico, valido per tutti i provider:
      // `realtime?vehicleId={id}&tripId={trip}&vehicles=true`.
      final trip = await provider.fetchVehicleTripDetails(
        vehicleId: dep.vehicleId,
        tripId: dep.tripId,
        providerName: selProv.name,
      );
      if (trip != null) {
        stops = trip.stops;
      }
    }

    final bus = BusVehicle(id: dep.vehicleId, line: dep.line, destination: dep.destination, latitude: 0, longitude: 0, tripId: dep.tripId, provider: selProv.provider);
    provider.setApiTripUpdates(stops);
    await provider.selectBus(bus);
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => BusDetailsSheet(bus: bus, page: 'details')),
      );
    }
  }
}

// Helper: capitalize first letter (used in this file)
String _capitalizeFirst(String? s) => (s == null || s.isEmpty) ? '' : s[0].toUpperCase() + s.substring(1).toLowerCase();

// ─────────────────────────────────────────────────────────
// Back button widget
// ─────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeProvider theme;

  const _BackButton({required this.icon, required this.onTap, required this.theme});

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
          border: Border.all(color: theme.borderColor.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, color: theme.textColor, size: 18),
      ),
    );
  }
}
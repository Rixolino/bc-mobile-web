import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/api_constants.dart';
import '../../data/models/bus_model.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nessun percorso disponibile per la linea $line')));
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

    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          // --- PARTE 1: AREA DI TRASCINAMENTO (Header + Azioni + Chips) ---
          // Usiamo SingleChildScrollView con il controller dello sheet solo qui
          // in modo che trascinando questa parte si muova lo sheet.
          SingleChildScrollView(
            controller: widget.scrollController,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                _buildHandle(theme),
                _buildHeader(theme, provider),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildMainActions(theme, provider),
                      const SizedBox(height: 16),
                      _buildHorizontalInfoChips(theme, provider),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- PARTE 2: TITOLO LISTA (Fisso) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Prossime Partenze", 
                  style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                if (_isLoadingDepartures) 
                  SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)),
              ],
            ),
          ),

          // --- PARTE 3: LISTA BUS (Indipendente) ---
          // Usando Expanded + ListView senza il controller dello sheet,
          // la lista scorrerà liberamente.
          Expanded(
            child: _departures.isEmpty && !_isLoadingDepartures
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    itemCount: _departures.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) => _buildDepartureCard(_departures[index], theme, provider),
                  ),
          ),
        ],
      ),
    );
  }

  // --- COMPONENTI UI ---

  Widget _buildHandle(ThemeProvider theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 40, height: 4,
        decoration: BoxDecoration(color: theme.secondaryTextColor.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
      ),
    );
  }

  Widget _buildHeader(ThemeProvider theme, BusProvider provider) {
    // raccogliamo le linee uniche dalle partenze per mostrarle accanto al nome
    final lines = _departures.map((d) => d.line).where((l) => l.trim().isNotEmpty).toSet().toList()
      ..sort((a, b) => a.compareTo(b));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.stop.stopName,
                  style: TextStyle(color: theme.textColor, fontSize: 22, fontWeight: FontWeight.w900, height: 1.1)),
                const SizedBox(height: 6),
                // mostriamo le linee come piccoli badge se sono presenti
                if (lines.isNotEmpty)
                  SizedBox(
                    height: 28,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: lines.map((ln) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: () => _onLineTap(ln, provider),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: theme.surfaceColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.secondaryTextColor.withOpacity(0.08)),
                            ),
                            child: Text(ln, style: TextStyle(color: theme.textColor, fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                const SizedBox(height: 6),
                Text('Fermata di ${_capitalizeFirst(provider.selectedProvider?.name ?? 'Bus')}', 
                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: theme.secondaryTextColor),
            onPressed: () => widget.scrollController == null ? Navigator.pop(context) : provider.clearStopSelection(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActions(ThemeProvider theme, BusProvider provider) {
    return Row(
      children: [
        Expanded(
          child: Consumer2<FavoritesProvider, AuthProvider>(
            builder: (ctx, favs, auth, _) {
              final isFav = favs.isStopFavorite(widget.stop.stopId, StopType.busStop);
              return _buildActionButton(
                label: isFav ? "Salvato" : "Preferito",
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
                if (dep.isRealtime) Text("• LIVE", style: TextStyle(color: theme.successColor, fontSize: 9, fontWeight: FontWeight.w900)),
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
          Text("Nessun bus previsto", style: TextStyle(color: theme.secondaryTextColor, fontWeight: FontWeight.w600)),
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
    final url = '${ApiConstants.baseUrl}/api/${selProv.country ?? 'it'}/bus/${selProv.name.toLowerCase()}/realtime?tripId=${dep.tripId}&lineCode=${dep.line}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final stops = (data['stops'] as List?)?.map((s) => BusTripUpdate.fromJson(s)).toList() ?? [];
      final bus = BusVehicle(id: dep.vehicleId, line: dep.line, destination: data['destination'] ?? dep.destination, latitude: 0, longitude: 0, tripId: dep.tripId, provider: selProv.provider);
      provider.setApiTripUpdates(stops);
      await provider.selectBus(bus);
      if (mounted) {
        showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => BusDetailsSheet(bus: bus, page: 'details'));
      }
    }
  }
}

// Helper: capitalize first letter (used in this file)
String _capitalizeFirst(String? s) => (s == null || s.isEmpty) ? '' : s[0].toUpperCase() + s.substring(1).toLowerCase();
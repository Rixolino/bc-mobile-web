import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../providers/plane_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import 'flight_details_sheet.dart';

class PlanePanelContent extends StatefulWidget {
  final VoidCallback onRefresh;

  const PlanePanelContent({super.key, required this.onRefresh});

  @override
  State<PlanePanelContent> createState() => _PlanePanelContentState();
}

class _PlanePanelContentState extends State<PlanePanelContent> {
  final TextEditingController _airportController = TextEditingController();
  bool _showSkyscanner = false;

  @override
  void dispose() {
    _airportController.dispose();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final planeProvider = Provider.of<PlaneProvider>(context);
    final mapState = Provider.of<MapStateProvider>(context, listen: false);

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Mode Selector (Glass Tabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GlassmorphicContainer(
                width: double.infinity,
                height: 56,
                borderRadius: 20,
                blur: 15,
                alignment: Alignment.center,
                border: 1.0,
                linearGradient: LinearGradient(
                   begin: Alignment.topLeft,
                   end: Alignment.bottomRight,
                   colors: [theme.surfaceColor.withOpacity(0.7), theme.surfaceColor.withOpacity(0.5)],
                ),
                borderGradient: LinearGradient(colors: [theme.secondaryTextColor.withOpacity(0.1), theme.secondaryTextColor.withOpacity(0.05)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildGlassTab(context, "Radar Live", Icons.radar, !_showSkyscanner, () => setState(() => _showSkyscanner = false)),
                    Container(width: 1, height: 20, color: theme.secondaryTextColor.withOpacity(0.2)),
                    _buildGlassTab(context, "Orari Aeroporti", Icons.schedule, _showSkyscanner, () => setState(() => _showSkyscanner = true)),
                  ],
                ),
              ),
            ),

            // 2. Main Content
            if (!_showSkyscanner) ...[
              // Realtime Radar View
              _buildRealtimeHeader(context, planeProvider),
              const SizedBox(height: 10),
              Expanded(child: _buildRealtimeList(planeProvider, mapState)),
            ] else ...[
              // Airport Boards View
              _buildAirportSearch(planeProvider),
              const SizedBox(height: 16),
              Expanded(child: _buildSkyscannerResults(planeProvider, mapState)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGlassTab(BuildContext context, String label, IconData icon, bool active, VoidCallback onTap) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: active ? theme.primaryColor : theme.secondaryTextColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? theme.primaryColor : theme.secondaryTextColor,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeHeader(BuildContext context, PlaneProvider planeProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return GlassmorphicContainer(
      width: double.infinity,
      height: 90,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 1.5,
      linearGradient: LinearGradient(
         begin: Alignment.topLeft,
         end: Alignment.bottomRight,
         colors: [theme.primaryColor.withOpacity(0.15), theme.primaryColor.withOpacity(0.05)],
      ),
      borderGradient: LinearGradient(colors: [theme.primaryColor.withOpacity(0.3), theme.primaryColor.withOpacity(0.1)]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.2), shape: BoxShape.circle),
               child: Icon(Icons.radar, color: theme.primaryColor, size: 28),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text("Radar Live", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 18)),
                   Text("Monitoraggio traffico aereo", style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.7), fontSize: 13)),
                 ],
               )
             ),
             GestureDetector(
               onTap: planeProvider.isLoading ? null : widget.onRefresh,
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                 decoration: BoxDecoration(
                   gradient: LinearGradient(colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.8)]),
                   borderRadius: BorderRadius.circular(12),
                   boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                 ),
                 child: planeProvider.isLoading 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(
                        children: [
                          Icon(Icons.refresh, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text("Scan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildAirportSearch(PlaneProvider planeProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      children: [
        GlassmorphicContainer(
          width: double.infinity,
          height: 60,
          borderRadius: 16,
          blur: 15,
          alignment: Alignment.center,
          border: 1.0,
          linearGradient: LinearGradient(colors: [theme.surfaceColor.withOpacity(0.8), theme.surfaceColor.withOpacity(0.5)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderGradient: LinearGradient(colors: [theme.secondaryTextColor.withOpacity(0.2), theme.secondaryTextColor.withOpacity(0.05)]),
          child: TextField(
            controller: _airportController,
            decoration: InputDecoration(
              hintText: "Cerca aeroporto (e.g. Fiumicino)...",
              hintStyle: TextStyle(color: theme.secondaryTextColor.withOpacity(0.7)),
              prefixIcon: Icon(Icons.flight_takeoff, color: theme.primaryColor),
              suffixIcon: planeProvider.selectedAirport != null 
                ? IconButton(
                    icon: Icon(Icons.clear, color: theme.secondaryTextColor),
                    onPressed: () {
                      _airportController.clear();
                      planeProvider.clearAirportSelection();
                    },
                  )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w500),
            onChanged: (val) {
              if (val.length > 2) planeProvider.searchAirports(val);
            },
          ),
        ),
        if (planeProvider.selectedAirport != null) ...[
          const SizedBox(height: 16),
          GlassmorphicContainer(
             width: double.infinity,
             height: 48,
             borderRadius: 12,
             blur: 15,
             alignment: Alignment.center,
             border: 1.0,
             linearGradient: LinearGradient(colors: [theme.surfaceColor.withOpacity(0.6), theme.surfaceColor.withOpacity(0.3)]),
             borderGradient: LinearGradient(colors: [theme.secondaryTextColor.withOpacity(0.1), theme.secondaryTextColor.withOpacity(0.05)]),
             child: Row(
               children: [
                  _buildFilterChip("Partenze", !planeProvider.isArrivalMode, () => planeProvider.setArrivalMode(false)),
                  Container(width: 1, height: 20, color: theme.secondaryTextColor.withOpacity(0.1)),
                  _buildFilterChip("Arrivi", planeProvider.isArrivalMode, () => planeProvider.setArrivalMode(true)),
               ],
             ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            color: Colors.transparent,
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildSkyscannerResults(PlaneProvider planeProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (planeProvider.isLoadingAirports) {
      return Center(child: CircularProgressIndicator(color: theme.primaryColor));
    }

    // Show suggestions if we are typing and haven't selected an airport yet
    if (planeProvider.airportSuggestions.isNotEmpty) {
      return ListView.separated(
        itemCount: planeProvider.airportSuggestions.length,
        separatorBuilder: (ctx, i) => Divider(height: 1, color: theme.secondaryTextColor.withOpacity(0.1)),
        itemBuilder: (context, index) {
          final a = planeProvider.airportSuggestions[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              child: Icon(Icons.location_city, color: theme.primaryColor, size: 20),
            ),
            title: Text(a.name, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
            subtitle: Text("${a.iata} - ${a.country}", style: TextStyle(color: theme.secondaryTextColor)),
            onTap: () {
               planeProvider.selectAirport(a);
               _airportController.text = a.name;
               // Focus map on airport (MapState internally handles flyTo)
               mapState.flyTo(a.lat, a.lng, zoom: 12);
            },
          );
        },
      );
    }

    if (planeProvider.selectedAirport != null) {
      if (planeProvider.scheduledFlights.isEmpty) {
        return Center(
          child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(Icons.search_off, size: 48, color: theme.secondaryTextColor.withOpacity(0.3)),
               const SizedBox(height: 12),
               Text("Nessun volo in programma", style: TextStyle(color: theme.secondaryTextColor, fontWeight: FontWeight.w500)),
             ],
          )
        );
      }
      return ListView.builder(
        itemCount: planeProvider.scheduledFlights.length,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final f = planeProvider.scheduledFlights[index];
          final isDeparture = !planeProvider.isArrivalMode;
          // Build refined glass flight card
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              // Using a subtle gradient/glass effect instead of plain surface color
              gradient: LinearGradient(
                colors: [theme.surfaceColor.withOpacity(0.9), theme.surfaceColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.secondaryTextColor.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                   color: Colors.black.withOpacity(0.04),
                   blurRadius: 10, 
                   offset: const Offset(0, 4)
                )
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                   final target = f;
                   planeProvider.selectFlight(f);
                   showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      barrierColor: Colors.black54,
                      builder: (ctx) => FractionallySizedBox(heightFactor: 0.85, child: FlightDetailsSheet(flight: target)),
                   );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                       // Time Pill
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.surfaceColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4)]
                        ),
                        child: Column(
                          children: [
                            Text(
                               _formatTime(isDeparture ? f.scheduledDeparture : f.scheduledArrival),
                               style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w900, fontSize: 16),
                            ),
                            if ((f.delayMinutes ?? 0) > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  "+${f.delayMinutes}'",
                                  style: TextStyle(color: theme.errorColor, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              )
                          ],
                        ),
                       ),
                      const SizedBox(width: 16),
                      // Flight Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Icon(isDeparture ? Icons.flight_takeoff : Icons.flight_land, size: 16, color: theme.primaryColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isDeparture ? f.destination : f.origin, 
                                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.3),
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  f.airline, 
                                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w600)
                                ),
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  width: 4, height: 4, 
                                  decoration: BoxDecoration(color: theme.secondaryTextColor.withOpacity(0.5), shape: BoxShape.circle)
                                ),
                                Text(
                                  f.flightNumber, 
                                  style: TextStyle(color: theme.textColor.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          // Glassy badge
                          gradient: LinearGradient(
                            colors: [
                               _getStatusColor(f.statusLocalized, theme).withOpacity(0.15),
                               _getStatusColor(f.statusLocalized, theme).withOpacity(0.05),
                            ]
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(f.statusLocalized, theme).withOpacity(0.2))
                        ),
                        child: Text(
                          (f.statusLocalized ?? 'Programmato').toUpperCase(),
                          style: TextStyle(color: _getStatusColor(f.statusLocalized, theme), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flight_takeoff, size: 48, color: theme.secondaryTextColor.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            "Cerca un aeroporto per vedere il tabellone orari", 
            style: TextStyle(color: theme.secondaryTextColor)
          ),
        ],
      )
    );
  }

  Color _getStatusColor(String? status, ThemeProvider theme) {
      if (status == null) return theme.secondaryTextColor;
      final s = status.toLowerCase();
      if (s.contains('delay') || s.contains('ritardo')) return theme.errorColor;
      if (s.contains('landed') || s.contains('atterrato')) return theme.successColor;
      if (s.contains('cancel') || s.contains('cancellato')) return theme.errorColor;
      return theme.primaryColor;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--:--";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildRealtimeList(PlaneProvider planeProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    if (planeProvider.flights.isEmpty) {
       return Center(child: Text("Nessun aereo in volo nell'area", style: TextStyle(color: theme.secondaryTextColor)));
    }
    
    return ListView.separated(
      itemCount: planeProvider.flights.length,
      separatorBuilder: (ctx, i) => Divider(height: 1, color: theme.secondaryTextColor.withOpacity(0.1)),
      itemBuilder: (context, index) {
        final f = planeProvider.flights[index];
        return ListTile(
          leading: CircleAvatar(
             backgroundColor: theme.surfaceColor.withOpacity(0.1),
             child: Icon(Icons.flight, color: theme.primaryColor, size: 20),
          ),
          title: Text(f.callsign, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
          subtitle: Text("${f.origin} -> ${f.destination}", style: TextStyle(color: theme.secondaryTextColor)),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
               Text("${(f.altitude ?? 0).toInt()} ft", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 13)),
               Text("${(f.speed ?? 0).toInt()} km/h", style: TextStyle(color: theme.secondaryTextColor, fontSize: 11)),
            ],
          ),
          onTap: () {
            if (f.latitude != null && f.longitude != null) {
              mapState.flyTo(f.latitude!, f.longitude!, zoom: 10);
            }
            final target = f;
            planeProvider.selectFlight(f);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Theme.of(context).disabledColor.withOpacity(0.5),
              builder: (ctx) => Consumer<PlaneProvider>(
                builder: (context, provider, child) {
                  final updated = provider.selectedFlight ?? target;
                  return FractionallySizedBox(heightFactor: 0.85, child: FlightDetailsSheet(flight: updated));
                },
              ),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
            // 1. Mode Selector (Tabs)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.surfaceColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton(context, "Radar Live", !_showSkyscanner, () => setState(() => _showSkyscanner = false))),
                  Expanded(child: _buildTabButton(context, "Orari Aeroporti", _showSkyscanner, () => setState(() => _showSkyscanner = true))),
                ],
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

  Widget _buildTabButton(BuildContext context, String label, bool active, VoidCallback onTap) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? theme.surfaceColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? theme.textColor : theme.secondaryTextColor,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildRealtimeHeader(BuildContext context, PlaneProvider planeProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1))
      ),
      child: Row(
        children: [
           Icon(Icons.radar, color: theme.primaryColor, size: 32),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text("Monitoraggio Aereo", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                 Text("Scansiona l'area visibile", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
               ],
             )
           ),
           FilledButton(
             onPressed: planeProvider.isLoading ? null : widget.onRefresh,
             style: FilledButton.styleFrom(
               shape: const StadiumBorder(),
               backgroundColor: theme.primaryColor
             ),
             child: planeProvider.isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text("Scan"),
           )
        ],
      ),
    );
  }

  Widget _buildAirportSearch(PlaneProvider planeProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: TextField(
            controller: _airportController,
            decoration: InputDecoration(
              hintText: "Cerca aeroporto (e.g. Fiumicino)...",
              hintStyle: TextStyle(color: theme.secondaryTextColor),
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
              contentPadding: const EdgeInsets.all(16),
            ),
            style: TextStyle(color: theme.textColor),
            onChanged: (val) {
              if (val.length > 2) planeProvider.searchAirports(val);
            },
          ),
        ),
        if (planeProvider.selectedAirport != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
               _buildFilterChip("Partenze", !planeProvider.isArrivalMode, () => planeProvider.setArrivalMode(false)),
               const SizedBox(width: 10),
               _buildFilterChip("Arrivi", planeProvider.isArrivalMode, () => planeProvider.setArrivalMode(true)),
            ],
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
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.surfaceColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? theme.primaryColor : Colors.transparent),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600
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
        return Center(child: Text("Nessun volo trovato", style: TextStyle(color: theme.secondaryTextColor)));
      }
      return ListView.builder(
        itemCount: planeProvider.scheduledFlights.length,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemBuilder: (context, index) {
          final f = planeProvider.scheduledFlights[index];
          final isDeparture = !planeProvider.isArrivalMode;
          // Build refined flight card
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                   color: Colors.black.withOpacity(0.04),
                   blurRadius: 8, 
                   offset: const Offset(0, 3)
                )
              ],
              border: Border.all(color: theme.secondaryTextColor.withOpacity(0.05)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                   // ... sheet logic ...
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
                       Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: theme.surfaceColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                           _formatTime(isDeparture ? f.scheduledDeparture : f.scheduledArrival),
                           style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w800, fontSize: 18),
                        ),
                       ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(isDeparture ? Icons.flight_takeoff : Icons.flight_land, size: 14, color: theme.secondaryTextColor),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isDeparture ? f.destination : f.origin, 
                                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                                    maxLines: 1, 
                                    overflow: TextOverflow.ellipsis
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${f.airline} • ${f.flightNumber}", 
                              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getStatusColor(f.statusLocalized, theme).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(f.statusLocalized, theme).withOpacity(0.2))
                        ),
                        child: Text(
                          (f.statusLocalized ?? 'Schedulato').toUpperCase(),
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

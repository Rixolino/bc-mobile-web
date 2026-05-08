import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../data/models/plane_model.dart';
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
    final theme = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER & MODE SELECTOR
        _buildHeader(theme, planeProvider),

        // 2. CONTENT AREA
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _showSkyscanner 
                ? _buildAirportSearch(theme, planeProvider, mapState)
                : _buildRealtimeFlights(theme, planeProvider, mapState),
          ),
        ),
      ],
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader(ThemeProvider theme, PlaneProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Radar Voli", 
                style: TextStyle(color: theme.textColor, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1)
              ),
              _buildModernToggle(theme),
            ],
          ),
          if (_showSkyscanner) ...[
            const SizedBox(height: 16),
            _buildSearchField(theme, provider),
          ]
        ],
      ),
    );
  }

  Widget _buildModernToggle(ThemeProvider theme) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildToggleItem("LIVE", !_showSkyscanner, theme, () => setState(() => _showSkyscanner = false)),
          _buildToggleItem("AEROPORTI", _showSkyscanner, theme, () => setState(() => _showSkyscanner = true)),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool active, ThemeProvider theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active ? [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 8)] : [],
        ),
        child: Text(label, 
          style: TextStyle(
            color: active ? Colors.white : theme.secondaryTextColor,
            fontSize: 10,
            fontWeight: FontWeight.w900
          )
        ),
      ),
    );
  }

  Widget _buildSearchField(ThemeProvider theme, PlaneProvider provider) {
    return GlassmorphicContainer(
      width: double.infinity, height: 50, borderRadius: 15, blur: 10, alignment: Alignment.center, border: 1,
      linearGradient: LinearGradient(colors: [theme.surfaceColor.withOpacity(0.5), theme.surfaceColor.withOpacity(0.2)]),
      borderGradient: LinearGradient(colors: [theme.primaryColor.withOpacity(0.2), Colors.transparent]),
      child: TextField(
        controller: _airportController,
        style: TextStyle(color: theme.textColor),
        decoration: InputDecoration(
          hintText: "Cerca aeroporto (ICAO/IATA)...",
          hintStyle: TextStyle(color: theme.secondaryTextColor.withOpacity(0.5)),
          prefixIcon: Icon(Icons.flight_takeoff_rounded, color: theme.primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onSubmitted: (val) {
          if (val.isNotEmpty) provider.searchAirports(val);
        },
      ),
    );
  }

  Widget _buildRealtimeFlights(ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    if (provider.flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.airplanemode_active_rounded, size: 64, color: theme.secondaryTextColor.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text("Nessun volo nel raggio radar", style: TextStyle(color: theme.secondaryTextColor)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: provider.flights.length,
      itemBuilder: (context, index) {
        final f = provider.flights[index];
        return _buildFlightCard(f, theme, provider, mapState);
      },
    );
  }

  Widget _buildFlightCard(dynamic f, ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (f.latitude != null && f.longitude != null) {
              mapState.flyTo(f.latitude!, f.longitude!, zoom: 10);
            }
            provider.selectFlight(f);
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => FractionallySizedBox(heightFactor: 0.85, child: FlightDetailsSheet(flight: f)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(Icons.airplanemode_active_rounded, color: theme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.callsign ?? "UNKNOWN", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1)),
                          Text("${f.origin ?? '???'} ➔ ${f.destination ?? '???'}", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    _buildInstrumentTag("${(f.speed ?? 0).toInt()} km/h", Icons.speed, Colors.orange, theme),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTechInfo("ALTITUDINE", "${(f.altitude ?? 0).toInt()} ft", theme),
                    _buildTechInfo("ROTTA", "${(f.heading ?? 0).toInt()}°", theme),
                    _buildTechInfo("SQUAWK", f.squawk ?? "----", theme),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstrumentTag(String label, IconData icon, Color color, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTechInfo(String title, String value, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: theme.secondaryTextColor, fontSize: 9, fontWeight: FontWeight.w800)),
        Text(value, style: TextStyle(color: theme.textColor, fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAirportSearch(ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (provider.selectedAirport != null) ...[
          Text("RISULTATO RICERCA", style: TextStyle(color: theme.secondaryTextColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 12),
          _buildAirportCard(provider.selectedAirport!, theme, mapState),
          const SizedBox(height: 16),
          _buildArrivalDepartureToggle(theme, provider),
          const SizedBox(height: 16),
          _buildAirportFlightsSection(theme, provider, mapState),
          const SizedBox(height: 24),
        ],
        Text("AEROPORTI VICINI", style: TextStyle(color: theme.secondaryTextColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...provider.airportSuggestions.map((a) => _buildAirportCard(a, theme, mapState)),
      ],
    );
  }

  Widget _buildAirportCard(dynamic a, ThemeProvider theme, MapStateProvider mapState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.location_city_rounded, color: theme.primaryColor),
        ),
        title: Text(a.name ?? "Aeroporto", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        subtitle: Text(a.iata.isNotEmpty ? a.iata : a.city, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor),
        onTap: () {
          final airport = a as Airport;
          Provider.of<PlaneProvider>(context, listen: false).selectAirport(airport);
          if (a.lat != 0 && a.lng != 0) {
            mapState.flyTo(a.lat, a.lng, zoom: 13);
          }
        },
      ),
    );
  }

  Widget _buildArrivalDepartureToggle(ThemeProvider theme, PlaneProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => provider.setArrivalMode(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: provider.isArrivalMode ? theme.surfaceColor : theme.primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Partenze',
                  style: TextStyle(
                    color: provider.isArrivalMode ? theme.textColor : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => provider.setArrivalMode(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: provider.isArrivalMode ? theme.primaryColor : theme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Arrivi',
                  style: TextStyle(
                    color: provider.isArrivalMode ? Colors.white : theme.textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAirportFlightsSection(ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    if (provider.isLoadingAirports) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: CircularProgressIndicator(),
      ));
    }

    if (provider.scheduledFlights.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Nessun volo disponibile per questo aeroporto.',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          provider.isArrivalMode ? 'ARRIVI' : 'PARTENZE',
          style: TextStyle(
            color: theme.secondaryTextColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        ...provider.scheduledFlights.map((f) => _buildScheduledFlightCard(f, theme, provider, mapState)),
      ],
    );
  }

  Widget _buildScheduledFlightCard(Flight f, ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    String fmt(DateTime? d) {
      if (d == null) return '--:--';
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final scheduled = provider.isArrivalMode ? f.scheduledArrival : f.scheduledDeparture;
    final estimated = provider.isArrivalMode ? f.estimatedArrival : f.estimatedDeparture;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.08)),
      ),
      child: ListTile(
        leading: Icon(
          provider.isArrivalMode ? Icons.flight_land_rounded : Icons.flight_takeoff_rounded,
          color: theme.primaryColor,
        ),
        title: Text(
          '${f.flightNumber} • ${f.airline}',
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          provider.isArrivalMode ? f.origin : f.destination,
          style: TextStyle(color: theme.secondaryTextColor),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(fmt(scheduled), style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700)),
            if (estimated != null && estimated != scheduled)
              Text('Est ${fmt(estimated)}', style: TextStyle(color: theme.warningColor, fontSize: 12)),
          ],
        ),
        onTap: () {
          provider.selectFlight(f);

          if (f.latitude != null && f.longitude != null) {
            mapState.flyTo(f.latitude!, f.longitude!, zoom: 10);
          }

          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => FractionallySizedBox(
              heightFactor: 0.85,
              child: FlightDetailsSheet(flight: f),
            ),
          );
        },
      ),
    );
  }
}
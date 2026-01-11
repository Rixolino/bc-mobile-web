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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _showSkyscanner ? "Ricerca Aeroporti" : "Traffico Aereo",
                  style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: _showSkyscanner,
                  onChanged: (val) => setState(() => _showSkyscanner = val),
                  activeColor: theme.primaryColor,
                ),
          ],
        ),
        const SizedBox(height: 10),
        if (!_showSkyscanner) ...[
          Text(
            "Monitora i voli in tempo reale nell'area visibile.",
            style: TextStyle(color: theme.secondaryTextColor),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: planeProvider.isLoading ? null : widget.onRefresh,
            icon: planeProvider.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.radar),
            label: const Text("Scansiona Area"),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.textColor,
            ),
          ),
        ] else ...[
          _buildAirportSearch(planeProvider),
        ],
        const SizedBox(height: 20),
        Expanded(
          child: _showSkyscanner ? _buildSkyscannerResults(planeProvider, mapState) : _buildRealtimeList(planeProvider, mapState),
        ),
      ],
    );
      },
    );
  }




  Widget _buildAirportSearch(PlaneProvider planeProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      children: [
        TextField(
          controller: _airportController,
          decoration: InputDecoration(
            hintText: "Cerca aeroporto (es. Roma, LHR)...",
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            prefixIcon: Icon(Icons.flight_takeoff, color: theme.secondaryTextColor),
            suffixIcon: planeProvider.selectedAirport != null 
              ? IconButton(
                  icon: Icon(Icons.clear, color: theme.secondaryTextColor),
                  onPressed: () {
                    _airportController.clear();
                    planeProvider.clearAirportSelection();
                  },
                )
              : null,
            filled: true,
            fillColor: theme.surfaceColor.withOpacity(0.06),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          style: TextStyle(color: theme.textColor),
          onChanged: (val) {
            if (val.length > 2) planeProvider.searchAirports(val);
          },
        ),
        if (planeProvider.selectedAirport != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text("Partenze"),
                  selected: !planeProvider.isArrivalMode,
                  onSelected: (val) => planeProvider.setArrivalMode(false),
                  backgroundColor: theme.surfaceColor.withOpacity(0.06),
                  selectedColor: theme.primaryColor,
                  labelStyle: TextStyle(color: theme.textColor),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Text("Arrivi"),
                  selected: planeProvider.isArrivalMode,
                  onSelected: (val) => planeProvider.setArrivalMode(true),
                  backgroundColor: theme.surfaceColor.withOpacity(0.06),
                  selectedColor: theme.primaryColor,
                  labelStyle: TextStyle(color: theme.textColor),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSkyscannerResults(PlaneProvider planeProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (planeProvider.isLoadingAirports) {
      return Center(child: CircularProgressIndicator(color: theme.primaryColor));
    }

    // Show suggestions if we are typing and haven't selected an airport yet
    if (planeProvider.airportSuggestions.isNotEmpty) {
      return ListView.builder(
        itemCount: planeProvider.airportSuggestions.length,
        itemBuilder: (context, index) {
          final a = planeProvider.airportSuggestions[index];
          return ListTile(
            leading: Icon(Icons.location_city, color: theme.primaryColor),
            title: Text(a.name, style: TextStyle(color: theme.textColor)),
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
        itemBuilder: (context, index) {
          final f = planeProvider.scheduledFlights[index];
          final isDeparture = !planeProvider.isArrivalMode;
          return ListTile(
            leading: Icon(Icons.event, color: theme.warningColor),
            title: Text(
              f.airline.isEmpty ? f.callsign : f.airline,
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)
            ),
            subtitle: Text(
              "${isDeparture ? "Per: ${f.destination}" : "Da: ${f.origin}"}\n${f.flightNumber} | ${f.statusLocalized ?? 'Programmato'}", 
              style: TextStyle(color: theme.secondaryTextColor)
            ),
            isThreeLine: true,
            trailing: Text(
              _formatTime(isDeparture ? f.scheduledDeparture : f.scheduledArrival),
              style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
            ),
            onTap: () {
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

    return Center(
      child: Text(
        "Cerca un aeroporto per vedere il tabellone orari", 
        style: TextStyle(color: theme.secondaryTextColor)
      )
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return "--:--";
    return "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildRealtimeList(PlaneProvider planeProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return ListView.builder(
      itemCount: planeProvider.flights.length,
      itemBuilder: (context, index) {
        final f = planeProvider.flights[index];
        return ListTile(
          leading: Icon(Icons.flight, color: theme.primaryColor),
          title: Text(f.callsign, style: TextStyle(color: theme.textColor)),
          subtitle: Text("${f.origin} -> ${f.destination}", style: TextStyle(color: theme.secondaryTextColor)),
          trailing: Text("${(f.altitude ?? 0).toInt()} ft", style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
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

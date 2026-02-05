import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../data/models/bus_model.dart';

class BusPanelContent extends StatefulWidget {
  const BusPanelContent({super.key});

  @override
  State<BusPanelContent> createState() => _BusPanelContentState();
}

class _BusPanelContentState extends State<BusPanelContent> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final busProvider = Provider.of<BusProvider>(context);
    final mapState = Provider.of<MapStateProvider>(context, listen: false);

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        final selectedProvider = _getSelectedProvider(busProvider);
        final supportsSolutions = selectedProvider?.supportsSolutions == true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Operator Selection (Horizontal Scroll)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                "Operatore",
                style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: busProvider.providers.map((provider) {
                  final isSelected = busProvider.selectedCity == provider.name;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(provider.name),
                      selected: isSelected,
                      onSelected: (_) {
                        busProvider.selectCity(provider.name);
                        final p = busProvider.providers.firstWhere(
                          (p) => p.name == provider.name,
                          orElse: () => BusProviderConfig(name: provider.name, provider: '', endpoints: {}),
                        );
                        if (p.latitude != null && p.longitude != null) {
                          mapState.flyTo(p.latitude!, p.longitude!, zoom: p.zoom ?? 12.0);
                        }
                      },
                      backgroundColor: theme.surfaceColor.withOpacity(0.05),
                      selectedColor: theme.primaryColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? theme.primaryColor : theme.textColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: isSelected ? theme.primaryColor : Colors.transparent),
                      ),
                      showCheckmark: false,
                      avatar: CircleAvatar(
                        backgroundColor: isSelected ? theme.primaryColor : theme.surfaceColor.withOpacity(0.2),
                        child: Icon(Icons.directions_bus, size: 12, color: isSelected ? theme.textColor : theme.secondaryTextColor),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 20),

            // 2. Action Area (Planning / Search / Refresh)
            if (busProvider.selectedCity == "Flixbus") 
              _buildFlixbusSearch(busProvider)
            else if (supportsSolutions) 
              _buildBariRouting(busProvider)
            else
              // Standard Realtime View Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Veicoli in tempo reale", style: TextStyle(color: theme.secondaryTextColor, fontWeight: FontWeight.w600)),
                  TextButton.icon(
                    onPressed: busProvider.isLoading ? null : () => busProvider.fetchVehicles(),
                    icon: busProvider.isLoading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text("Aggiorna"),
                  ),
                ],
              ),
              
            const SizedBox(height: 10),

            // 3. Results Area
            Expanded(
              child: _buildResultsList(busProvider, mapState),
            ),
          ],
        );
      },
    );
  }

  // Helper: Removed _buildExpandableSection as it is no longer used

  Widget _buildFlixbusSearch(BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Cerca fermata Flixbus...",
          hintStyle: TextStyle(color: theme.secondaryTextColor),
          prefixIcon: Icon(Icons.search, color: theme.primaryColor),
          suffixIcon: IconButton(
            icon: Icon(Icons.send, color: theme.primaryColor),
            onPressed: () => busProvider.searchFlixbus(_searchController.text),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
        style: TextStyle(color: theme.textColor),
        onSubmitted: (val) => busProvider.searchFlixbus(val),
      ),
    );
  }

  Widget _buildBariRouting(BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Card(
      elevation: 0,
      color: theme.surfaceColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1))),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.primaryColor),
                const SizedBox(width: 8),
                Text("Pianifica Viaggio", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            _buildStopSelector("Da", busProvider.selectedFromStop, (BariStop? stop) => busProvider.selectFromStop(stop), busProvider),
            const SizedBox(height: 12),
            _buildStopSelector("A", busProvider.selectedToStop, (BariStop? stop) => busProvider.selectToStop(stop), busProvider),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (busProvider.selectedFromStop != null && busProvider.selectedToStop != null && !busProvider.isLoadingSolutions)
                    ? () => busProvider.fetchBariSolutions()
                    : null,
                icon: busProvider.isLoadingSolutions
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search),
                label: const Text("Cerca Soluzioni"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopSelector(String label, BariStop? selectedStop, Function(BariStop?) onSelect, BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return InkWell(
      onTap: () => _showStopSelectionDialog(context, label, busProvider, onSelect),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(
              selectedStop != null ? Icons.my_location : Icons.circle_outlined, 
              color: selectedStop != null ? theme.primaryColor : theme.secondaryTextColor,
              size: 20
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                selectedStop?.stopName ?? "Seleziona $label...",
                style: TextStyle(
                  color: selectedStop != null ? theme.textColor : theme.secondaryTextColor,
                  fontWeight: selectedStop != null ? FontWeight.w500 : FontWeight.normal
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.unfold_more, color: theme.secondaryTextColor, size: 20),
          ],
        ),
      ),
    );
  }


  void _showStopSelectionDialog(BuildContext context, String label, BusProvider busProvider, Function(BariStop?) onSelect) {
    if (busProvider.stops.isEmpty && !busProvider.isLoadingStops) {
      busProvider.fetchStops();
    }

    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        final theme = Provider.of<ThemeProvider>(context, listen: false);
        return StatefulBuilder(
          builder: (context, setState) {
            final filteredStops = busProvider.stops.where((stop) =>
                stop.stopName.toLowerCase().contains(searchController.text.toLowerCase())).toList();
            return AlertDialog(
              backgroundColor: theme.surfaceColor,
              title: Text("Seleziona fermata $label", style: TextStyle(color: theme.textColor)),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: busProvider.isLoadingStops
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              hintText: "Cerca fermata...",
                              hintStyle: TextStyle(color: theme.secondaryTextColor),
                              prefixIcon: Icon(Icons.search, color: theme.secondaryTextColor),
                              filled: true,
                              fillColor: theme.surfaceColor.withOpacity(0.1),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            style: TextStyle(color: theme.textColor),
                            onChanged: (value) => setState(() {}),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredStops.length,
                              itemBuilder: (context, index) {
                                final stop = filteredStops[index];
                                return ListTile(
                                  title: Text(stop.stopName, style: TextStyle(color: theme.textColor)),
                                  onTap: () {
                                    onSelect(stop);
                                    Navigator.of(context).pop();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text("Annulla", style: TextStyle(color: theme.secondaryTextColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildResultsList(BusProvider busProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (busProvider.isLoading) {
      return Center(child: CircularProgressIndicator(color: theme.primaryColor));
    }

    // Show Bari solutions if available
    if (busProvider.selectedCity == "Bari" && busProvider.bariSolutions.isNotEmpty) {
      return _buildBariSolutionsList(busProvider, mapState);
    }

    if (busProvider.selectedCity == "Flixbus") {
      return ListView.builder(
        itemCount: busProvider.flixbusStations.length,
        itemBuilder: (context, index) {
          final station = busProvider.flixbusStations[index];
          return ListTile(
            leading: Icon(Icons.directions_bus, color: theme.primaryColor),
            title: Text(station['name'] ?? '', style: TextStyle(color: theme.textColor)),
            subtitle: Text(station['country_code'] ?? '', style: TextStyle(color: theme.secondaryTextColor)),
            onTap: () {
              final dynamic coords = station['coords'];
              if (coords != null && coords['lat'] != null && coords['lng'] != null) {
                mapState.flyTo(
                  (coords['lat'] as num).toDouble(), 
                  (coords['lng'] as num).toDouble(), 
                  zoom: 14
                );
              }
            },
          );
        },
      );
    }

    if (busProvider.vehicles.isEmpty) {
      return Center(
        child: Text(
          "Nessun autobus trovato per ${busProvider.selectedCity}",
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      );
    }

    return ListView.builder(
      itemCount: busProvider.vehicles.length,
      padding: const EdgeInsets.only(bottom: 80, top: 4),
      itemBuilder: (context, index) {
        final v = busProvider.vehicles[index];
        final cityColor = _getCityColor(busProvider.selectedCity);
        
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
              onTap: () async {
                if (v.latitude != 0) {
                  mapState.flyTo(v.latitude, v.longitude, zoom: 15);
                }
                // Fetch bus details from API and show details sheet
                try {
                  final tripId = v.tripId ?? '';
                  final lineCode = v.line;
                  final provider = busProvider.selectedProvider!.name.toLowerCase();
                  final url = 'https://betacloud-transporter.is-cool.dev/api/it/bus/$provider/realtime?tripId=$tripId&lineCode=$lineCode';
                  print('Fetching bus details from URL: $url');
    
                  final response = await http.get(Uri.parse(url));
                  if (response.statusCode == 200) {
                    final jsonData = jsonDecode(response.body);
                    if (jsonData['vehicles'] != null && jsonData['vehicles'].isNotEmpty) {
                      final vehicleData = jsonData['vehicles'][0];
                      final stops = vehicleData['stops'] as List<dynamic>? ?? [];
    
                      // Update bus destination if available
                      final destination = vehicleData['destination'] as String?;
                      if (destination != null && destination.isNotEmpty) {
                        busProvider.updateBusDestination(v.id, destination);
                      }
    
                      // Convert stops to BusTripUpdate
                      final tripUpdates = stops.map((stop) {
                        return BusTripUpdate(
                          stopId: stop['stopId']?.toString() ?? '',
                          stopName: stop['stopName'] ?? '',
                          expectedTime: stop['scheduledTime'] ?? '',
                          delay: stop['delay'] ?? 0,
                          isRealtime: stop['isRealtime'] ?? false,
                          status: stop['status'] ?? 'future',
                          arrivalEstimate: stop['estimatedArrivalUnix']?.toString(),
                        );
                      }).toList();
    
                      // Set the trip updates in the provider
                      busProvider.setApiTripUpdates(tripUpdates);
                    }
                  }
                  // Select the bus to show details sheet
                  await busProvider.selectBus(v);
                } catch (e) {
                  print('Error fetching bus details: $e');
                  // On error, fallback to just selecting the bus
                  await busProvider.selectBus(v);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Line Number Box
                    Container(
                      width: 50,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cityColor.withOpacity(0.3), width: 1.5)
                      ),
                      child: Text(
                        "${v.line}",
                        style: TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.w900, 
                          color: cityColor
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Destination Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.destination ?? 'Destinazione non disponibile',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8, 
                                height: 8, 
                                decoration: BoxDecoration(color: theme.successColor, shape: BoxShape.circle)
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "In viaggio", // Placeholder for status
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.successColor),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                    
                    // Action Icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBariSolutionsList(BusProvider busProvider, MapStateProvider mapState) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return ListView.builder(
      itemCount: busProvider.bariSolutions.length,
      itemBuilder: (context, index) {
        final solution = busProvider.bariSolutions[index];
        return Card(
          color: theme.surfaceColor.withOpacity(0.1),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: ExpansionTile(
            title: Text(
              "${solution.departureTime} - ${solution.arrivalTime}",
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "${solution.totalDuration} min, ${solution.transfers} cambi",
              style: TextStyle(color: theme.secondaryTextColor),
            ),
            children: solution.legs.map((leg) => ListTile(
              leading: Icon(Icons.directions_bus, color: theme.primaryColor),
              title: Text("${leg.fromStop} → ${leg.toStop}", style: TextStyle(color: theme.textColor)),
              subtitle: Text("Linea ${leg.lineCode} - ${leg.duration} min", style: TextStyle(color: theme.secondaryTextColor)),
              onTap: () {
                // Could show route on map
              },
            )).toList(),
          ),
        );
      },
    );
  }

  Color _getCityColor(String city) {
    switch (city) {
      case "Roma": return Provider.of<ThemeProvider>(context, listen: false).errorColor;
      case "Bari": return Provider.of<ThemeProvider>(context, listen: false).primaryColor;
      case "Emilia-Romagna": return Provider.of<ThemeProvider>(context, listen: false).warningColor;
      default: return Provider.of<ThemeProvider>(context, listen: false).primaryColor;
    }
  }

  BusProviderConfig? _getSelectedProvider(BusProvider busProvider) {
    return busProvider.providers.firstWhere(
      (p) => p.name == busProvider.selectedCity,
      orElse: () => BusProviderConfig(
        name: busProvider.selectedCity,
        provider: '',
        solutionsUrl: null,
        endpoints: {},
      ),
    );
  }
}

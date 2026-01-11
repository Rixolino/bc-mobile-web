import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  bool _expandedCitySelector = true;
  bool _expandedOptions = true;
  bool _expandedResults = true;

  @override
  Widget build(BuildContext context) {
    final busProvider = Provider.of<BusProvider>(context);
    final mapState = Provider.of<MapStateProvider>(context, listen: false);

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // City Selector - Expandable
              _buildExpandableSection(
                title: "Seleziona Città / Operatore",
                expanded: _expandedCitySelector,
                onExpanded: (value) => setState(() => _expandedCitySelector = value),
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildCityChip(context, "Roma", busProvider),
                    _buildCityChip(context, "Bari", busProvider),
                    _buildCityChip(context, "Emilia-Romagna", busProvider),
                    _buildCityChip(context, "Flixbus", busProvider),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Options Section - Expandable
              _buildExpandableSection(
                title: busProvider.selectedCity == "Bari" ? "Pianifica Viaggio" : "Opzioni",
                expanded: _expandedOptions,
                onExpanded: (value) => setState(() => _expandedOptions = value),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busProvider.selectedCity == "Flixbus") _buildFlixbusSearch(busProvider),
                if (busProvider.selectedCity == "Bari") _buildBariRouting(busProvider),
                if (busProvider.selectedCity != "Flixbus") ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: busProvider.isLoading ? null : () => busProvider.fetchVehicles(),
                      icon: busProvider.isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.refresh),
                      label: const Text("Aggiorna Posizioni"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: theme.textColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Results Section - Expandable
          _buildExpandableSection(
            title: "Risultati",
            expanded: _expandedResults,
            onExpanded: (value) => setState(() => _expandedResults = value),
            child: SizedBox(
              height: 300,
              child: _buildResultsList(busProvider, mapState),
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required bool expanded,
    required ValueChanged<bool> onExpanded,
    required Widget child,
  }) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        title: Text(
          title,
          style: TextStyle(
            color: theme.textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        initiallyExpanded: expanded,
        onExpansionChanged: onExpanded,
        collapsedIconColor: theme.secondaryTextColor,
        iconColor: theme.secondaryTextColor,
        backgroundColor: theme.surfaceColor.withOpacity(0.02),
        collapsedBackgroundColor: Colors.transparent,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildFlixbusSearch(BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "Cerca città Flixbus...",
        hintStyle: TextStyle(color: theme.secondaryTextColor),
        prefixIcon: Icon(Icons.search, color: theme.secondaryTextColor),
        suffixIcon: IconButton(
          icon: Icon(Icons.send, color: theme.successColor),
          onPressed: () => busProvider.searchFlixbus(_searchController.text),
        ),
        filled: true,
        fillColor: theme.surfaceColor.withOpacity(0.1),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      style: TextStyle(color: theme.textColor),
      onSubmitted: (val) => busProvider.searchFlixbus(val),
    );
  }

  Widget _buildBariRouting(BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Pianifica Viaggio",
          style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        _buildStopSelector("Da", busProvider.selectedFromStop, (BariStop? stop) => busProvider.selectFromStop(stop), busProvider),
        const SizedBox(height: 8),
        _buildStopSelector("A", busProvider.selectedToStop, (BariStop? stop) => busProvider.selectToStop(stop), busProvider),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: (busProvider.selectedFromStop != null && busProvider.selectedToStop != null && !busProvider.isLoadingSolutions)
              ? () => busProvider.fetchBariSolutions()
              : null,
          icon: busProvider.isLoadingSolutions
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.search),
          label: const Text("Cerca Soluzioni"),
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.successColor,
            foregroundColor: theme.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStopSelector(String label, BariStop? selectedStop, Function(BariStop?) onSelect, BusProvider busProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return InkWell(
      onTap: () => _showStopSelectionDialog(context, label, busProvider, onSelect),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: theme.surfaceColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(selectedStop != null ? Icons.location_on : Icons.location_searching, color: theme.secondaryTextColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedStop?.stopName ?? "Seleziona fermata $label",
                style: TextStyle(color: selectedStop != null ? theme.textColor : theme.secondaryTextColor),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: theme.secondaryTextColor),
          ],
        ),
      ),
    );
  }

  void _showStopSelectionDialog(BuildContext context, String label, BusProvider busProvider, Function(BariStop?) onSelect) {
    if (busProvider.bariStops.isEmpty && !busProvider.isLoadingStops) {
      busProvider.fetchBariStops();
    }

    showDialog(
      context: context,
      builder: (context) {
        final theme = Provider.of<ThemeProvider>(context, listen: false);
        return AlertDialog(
          backgroundColor: theme.surfaceColor,
          title: Text("Seleziona fermata $label", style: TextStyle(color: theme.textColor)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: busProvider.isLoadingStops
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: busProvider.bariStops.length,
                    itemBuilder: (context, index) {
                      final stop = busProvider.bariStops[index];
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Annulla", style: TextStyle(color: theme.secondaryTextColor)),
            ),
          ],
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
      itemBuilder: (context, index) {
        final v = busProvider.vehicles[index];
        return ListTile(
          leading: Icon(Icons.directions_bus, color: _getCityColor(busProvider.selectedCity)),
          title: Text("Linea ${v.line}", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
          subtitle: Text(v.destination ?? 'Destinazione non disponibile', style: TextStyle(color: theme.secondaryTextColor)),
          trailing: Icon(Icons.map, color: theme.secondaryTextColor.withOpacity(0.3)),
          onTap: () {
            if (v.latitude != 0) {
              mapState.flyTo(v.latitude, v.longitude, zoom: 15);
            }
          },
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

  Widget _buildCityChip(BuildContext context, String city, BusProvider provider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isSelected = provider.selectedCity == city;
    return FilterChip(
      label: Text(city),
      selected: isSelected,
      onSelected: (_) => provider.selectCity(city),
      backgroundColor: theme.surfaceColor.withOpacity(0.1),
      selectedColor: theme.primaryColor.withOpacity(0.5),
      labelStyle: TextStyle(color: theme.textColor),
      checkmarkColor: theme.textColor,
    );
  }
}

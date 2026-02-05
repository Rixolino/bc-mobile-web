import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/train_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import 'train_details_sheet.dart';
import 'package:intl/intl.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_stop.dart';
import '../../../auth/providers/auth_provider.dart';

class TrainPanelContent extends StatefulWidget {
  final bool showModeToggle; // Show Partenze / Arrivi toggle when used as modal from Favorites
  const TrainPanelContent({super.key, this.showModeToggle = false});

  @override
  State<TrainPanelContent> createState() => _TrainPanelContentState();
}

class _TrainPanelContentState extends State<TrainPanelContent> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCountry = '';

  // Mappa dei fusi orari (Offset rispetto a UTC)
  final Map<String, int> countryTimezoneOffsets = {
    'IT': 1, 'FR': 1, 'DE': 1, 'AT': 1, 'CH': 1, 'ES': 1,
    'GB': 0, 'NL': 1, 'BE': 1, 'LU': 1, 'CZ': 1, 'PL': 1,
    'HU': 1, 'RO': 2, 'GR': 2, 'SE': 1, 'NO': 1, 'DK': 1,
  };

  final List<Map<String, String>> _countries = [
    {'code': 'IT', 'name': 'Italia'},
    {'code': 'DE', 'name': 'Germania'},
    {'code': 'CH', 'name': 'Svizzera'},
    {'code': 'FR', 'name': 'Francia'},
    {'code': 'FAL', 'name': 'Puglia (FAL)'},
    {'code': 'EU', 'name': 'Continentale (Realtime)'},
    {'code': 'UK_LONDON', 'name': 'Regno Unito'},
    {'code': 'AT', 'name': 'Austria'},
  ];

  @override
  Widget build(BuildContext context) {
    final trainProvider = Provider.of<TrainProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    // Dynamic country list based on service
    List<Map<String, String>> displayedCountries = _countries;
    if (trainProvider.selectedService == 'direct') {
      displayedCountries = _countries.where((c) => ['IT', 'FAL', 'EU'].contains(c['code'])).toList();
      if (!['IT', 'FAL', 'EU'].contains(_selectedCountry)) {
         _selectedCountry = displayedCountries.first['code'] ?? '';
      }
    }

    final station = trainProvider.selectedStation;

    // View 1: Results (Timetable)
    if (station != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Professional Header Container
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              border: Border(bottom: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: theme.textColor),
                      onPressed: () => trainProvider.clearSelection(),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.surfaceColor.withOpacity(0.05),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            station.country,
                            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Consumer2<FavoritesProvider, AuthProvider>(
                      builder: (context, favoritesProvider, authProvider, child) {
                        if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                        final isFavorite = favoritesProvider.isStopFavorite(station.id, StopType.trainStation, country: station.country);
                        return IconButton(
                          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : theme.secondaryTextColor),
                          onPressed: () async {
                              // ... existing logic ...
                              try {
                                if (isFavorite) {
                                  await favoritesProvider.removeStopFavorite(station.id, StopType.trainStation, country: station.country);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stazione rimossa dai preferiti')));
                                } else {
                                  final fav = favoritesProvider.createFavoriteStop(
                                    userId: authProvider.currentUser?.id?.toString() ?? 'guest', // Fixed param name
                                    name: station.name,
                                    code: station.id,
                                    stopType: StopType.trainStation,
                                    latitude: null,
                                    longitude: null,
                                    city: null,
                                    region: null,
                                    provider: null,
                                    country: station.country,
                                  );
                                  await favoritesProvider.addStopFavorite(fav);
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stazione aggiunta ai preferiti')));
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore preferiti: $e')));
                              }
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Modern Segmented Toggle
                Container(
                  decoration: BoxDecoration(
                    color: theme.surfaceColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      Expanded(child: _buildSegmentButton(context, "Partenze", !trainProvider.isArrivalMode, () => trainProvider.setArrivalMode(false))),
                      Expanded(child: _buildSegmentButton(context, "Arrivi", trainProvider.isArrivalMode, () => trainProvider.setArrivalMode(true))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: trainProvider.isLoadingDepartures
                ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: trainProvider.departures.length,
                    itemBuilder: (context, index) {
                      final dep = trainProvider.departures[index];
                      // Use a cleaner, schedule-board style card
                      return _buildTrainCard(context, dep, theme);
                    },
                  ),
          ),
        ],
      );
    }

    // View 2: Search Form & Suggestions
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Service Selection
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Cerca Stazione",
                style: TextStyle(color: theme.textColor, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Container(
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: trainProvider.selectedService,
                    dropdownColor: theme.surfaceColor,
                    icon: Icon(Icons.tune, color: theme.primaryColor, size: 18),
                    style: TextStyle(color: theme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                    items: const [
                      DropdownMenuItem(value: 'direct', child: Text("BC. Transporter")),
                      DropdownMenuItem(value: 'trainboardeu', child: Text("Trainboard.eu")),
                    ],
                    onChanged: (val) {
                      if (val != null) trainProvider.setService(val);
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Search Input - Floating Material Style
          Container(
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Nome stazione o numero treno...",
                hintStyle: TextStyle(color: theme.secondaryTextColor),
                prefixIcon: Icon(Icons.search, color: theme.primaryColor),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              style: TextStyle(color: theme.textColor, fontSize: 16),
              onChanged: (val) {
                 if (_selectedCountry == 'EU') {
                   trainProvider.searchTrainByNumber(val);
                 } else if (_selectedCountry.isNotEmpty) {
                   trainProvider.searchStations(val, country: _selectedCountry);
                 } else {
                   trainProvider.searchStations(val);
                 }
              },
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Country Filter - Horizontal Scroll
          Text("Filtra per Paese", style: TextStyle(color: theme.secondaryTextColor, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: displayedCountries.map((c) {
                final isSelected = _selectedCountry == c['code'];
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(c['name']!),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      setState(() => _selectedCountry = selected ? c['code']! : '');
                    },
                    backgroundColor: theme.surfaceColor.withOpacity(0.05),
                    selectedColor: theme.primaryColor.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primaryColor : theme.textColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? theme.primaryColor : Colors.transparent, 
                        width: 1
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Toggle Partenze / Arrivi (Pre-Search)
          Container(
            decoration: BoxDecoration(
              color: theme.surfaceColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(child: _buildSegmentButton(context, "Partenze", !trainProvider.isArrivalMode, () => trainProvider.setArrivalMode(false))),
                Expanded(child: _buildSegmentButton(context, "Arrivi", trainProvider.isArrivalMode, () => trainProvider.setArrivalMode(true))),
              ],
            ),
          ),

          const SizedBox(height: 10),

          if (trainProvider.isSearchingByNumber || trainProvider.searchResults.isNotEmpty)
            SizedBox(
              height: 400, // Fixed height for list in scroll view
              child: _buildNumberSearchResults(trainProvider)
            )
          else if (trainProvider.isLoadingSuggestions || trainProvider.stationSuggestions.isNotEmpty)
            SizedBox(
               height: 400,
               child: _buildStationSuggestions(trainProvider)
            )
          else
            Container(
              padding: const EdgeInsets.only(top: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                   Icon(Icons.train_outlined, size: 48, color: theme.secondaryTextColor.withOpacity(0.3)),
                   const SizedBox(height: 16),
                   Text(
                    "Cerca una stazione per visualizzare il tabellone",
                    style: TextStyle(color: theme.secondaryTextColor, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildSegmentButton(BuildContext context, String label, bool active, VoidCallback onTap) {
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
            fontSize: 14
          ),
        ),
      ),
    );
  }

  Widget _buildTrainCard(BuildContext context, dynamic dep, ThemeProvider theme) {
     // Helper to parse time string safely
    final scheduleTime = dep.scheduledTime != null 
        ? DateFormat('HH:mm').format(dep.scheduledTime!.toUtc().add(Duration(hours: 1))) // Simple offset correction, adjust as needed
        : '--:--';
        
    final delayMin = dep.delayMinutes ?? 0;
    final isDelayed = delayMin > 0;
    final isCancelled = dep.status == 'CANCELED';
    final platform = dep.platform ?? '-';
    
    return Card(
      elevation: 0,
      color: theme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1), width: 0.5)
      ),
      margin: const EdgeInsets.only(bottom: 1),
      child: InkWell(
        onTap: () {
           // ... logic to open sheet ...
           final String? targetId = dep.tripId;
           final String? targetNum = dep.trainNumber;
           // Fetch details if empty (placeholder for existing logic)
           if (dep.stops == null) {} 
           
           showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              barrierColor: Theme.of(context).disabledColor.withOpacity(0.5),
              builder: (ctx) => FractionallySizedBox(
                heightFactor: 0.92,
                child: TrainDetailsSheet(
                  departure: dep,
                  isArrivalMode: Provider.of<TrainProvider>(context, listen: false).isArrivalMode,
                  selectedCountry: _selectedCountry,
                ),
              ),
           );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time Column
              SizedBox(
                width: 50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheduleTime,
                      style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isDelayed)
                       Text(
                        "+$delayMin'",
                        style: TextStyle(color: theme.errorColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Main Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.surfaceColor.withOpacity(0.1),
                            border: Border.all(color: theme.secondaryTextColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            dep.category ?? 'REG',
                            style: TextStyle(fontSize: 10, color: theme.secondaryTextColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                         Text(
                          dep.trainNumber ?? '',
                          style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dep.destination ?? 'Destinazione sconosciuta',
                      style: TextStyle(color: theme.textColor, fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isCancelled)
                      Text("CANCELLATO", style: TextStyle(color: theme.errorColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              // Platform Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text(
                    platform,
                    style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Binario",
                    style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStationSuggestions(TrainProvider provider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (provider.isLoadingSuggestions) {
      return Center(child: CircularProgressIndicator());
    }
    return Expanded(
      child: ListView.builder(
        itemCount: provider.stationSuggestions.length,
        itemBuilder: (context, index) {
          final s = provider.stationSuggestions[index];
          return ListTile(
            leading: Icon(Icons.location_city, color: theme.primaryColor),
            title: Text(s.name, style: TextStyle(color: theme.textColor)),
            subtitle: Text(s.country, style: TextStyle(color: theme.secondaryTextColor)),
            onTap: () => provider.selectStation(s),
            trailing: Consumer2<FavoritesProvider, AuthProvider>(
              builder: (context, favoritesProvider, authProvider, child) {
                if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                final isFavorite = favoritesProvider.isStopFavorite(s.id, StopType.trainStation, country: s.country);
                return IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : theme.secondaryTextColor),
                  onPressed: () async {
                    try {
                      if (isFavorite) {
                        await favoritesProvider.removeStopFavorite(s.id, StopType.trainStation, country: s.country);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stazione rimossa dai preferiti')));
                      } else {
                        final fav = favoritesProvider.createFavoriteStop(
                          userId: userId,
                          name: s.name,
                          code: s.id,
                          stopType: StopType.trainStation,
                          country: s.country,
                        );
                        await favoritesProvider.addStopFavorite(fav);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stazione aggiunta ai preferiti')));
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore preferiti: $e')));
                    }
                  },

                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNumberSearchResults(TrainProvider provider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (provider.isSearchingByNumber) {
      return Center(child: CircularProgressIndicator());
    }
    return Expanded(
      child: ListView.builder(
        itemCount: provider.searchResults.length,
        itemBuilder: (context, index) {
          final m = provider.searchResults[index];
          final line = m['line'] ?? {};
          return ListTile(
            leading: Icon(Icons.speed, color: theme.warningColor),
            title: Text("${line['name'] ?? '?'}", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
            subtitle: Text("Direzione: ${m['direction'] ?? 'N/A'}", style: TextStyle(color: theme.secondaryTextColor)),
            trailing: Icon(Icons.chevron_right, color: theme.secondaryTextColor.withOpacity(0.6)),
            onTap: () {
               final mapState = Provider.of<MapStateProvider>(context, listen: false);
               final lat = m['latitude'];
               final lng = m['longitude'];
               if (lat != null && lng != null) {
                 mapState.flyTo(lat.toDouble(), lng.toDouble(), zoom: 12);
               }
            },
          );
        },
      ),
    );
  }
}

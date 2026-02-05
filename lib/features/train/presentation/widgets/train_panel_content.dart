import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/train_provider.dart';
import '../../data/models/train_model.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import 'train_details_sheet.dart';
import 'package:intl/intl.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_stop.dart';
import '../../../auth/providers/auth_provider.dart';
import 'shimmer_and_toggle.dart';

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
    {'code': 'ES', 'name': 'Spagna'},
    {'code': 'GB', 'name': 'Regno Unito'},
    {'code': 'NL', 'name': 'Paesi Bassi'},
    {'code': 'BE', 'name': 'Belgio'},
    {'code': 'LU', 'name': 'Lussemburgo'},
    {'code': 'CZ', 'name': 'Repubblica Ceca'},
    {'code': 'PL', 'name': 'Polonia'},
    {'code': 'HU', 'name': 'Ungheria'},
    {'code': 'RO', 'name': 'Romania'},
    {'code': 'GR', 'name': 'Grecia'},
    {'code': 'SE', 'name': 'Svezia'},
    {'code': 'NO', 'name': 'Norvegia'},
    {'code': 'DK', 'name': 'Danimarca'},
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
                ? ShimmerLoading(baseColor: theme.secondaryTextColor)
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 80),
                    itemCount: trainProvider.departures.length,
                    itemBuilder: (context, index) {
                      final dep = trainProvider.departures[index];
                      // Use a cleaner, schedule-board style card
                      return _buildTrainCard(context, dep, index, theme);
                    },
                  ),
          ),
        ],
      );
    }

    // View 2: Search Form & Suggestions
    return Column(
      children: [
        // Material 3 Search Header Container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               // Search Bar
               TextField(
                 controller: _searchController,
                 style: TextStyle(fontSize: 18, color: theme.textColor),
                 decoration: InputDecoration(
                   hintText: "Cerca stazione...",
                   hintStyle: TextStyle(color: theme.secondaryTextColor, fontSize: 18),
                   prefixIcon: Padding(
                     padding: const EdgeInsets.only(left: 16, right: 12),
                     child: Icon(Icons.search, color: theme.textColor),
                   ),
                   suffixIcon: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.close, color: theme.secondaryTextColor),
                            onPressed: () {
                              _searchController.clear();
                              trainProvider.clearStationSuggestions();
                            },
                          ),
                       
                       // Service Filter Menu (replaces clunky dropdown)
                       PopupMenuButton<String>(
                         icon: Icon(Icons.tune_rounded, color: theme.primaryColor),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         color: theme.surfaceColor,
                         onSelected: (val) => trainProvider.setService(val),
                         itemBuilder: (context) => [
                           PopupMenuItem(
                             value: 'direct',
                             child: Row(
                               children: [
                                 Icon(Icons.check, color: trainProvider.selectedService == 'direct' ? theme.primaryColor : Colors.transparent, size: 18),
                                 const SizedBox(width: 8),
                                 Text("BC Transporter", style: TextStyle(color: theme.textColor)),
                               ],
                             ),
                           ),
                           PopupMenuItem(
                             value: 'trainboardeu',
                             child: Row(
                               children: [
                                 Icon(Icons.check, color: trainProvider.selectedService == 'trainboardeu' ? theme.primaryColor : Colors.transparent, size: 18),
                                 const SizedBox(width: 8),
                                 Text("Trainboard.eu", style: TextStyle(color: theme.textColor)),
                               ],
                             ),
                           ),
                         ],
                       ),
                       const SizedBox(width: 8),
                     ],
                   ),
                   border: InputBorder.none,
                   contentPadding: const EdgeInsets.symmetric(vertical: 16),
                 ),
                 onChanged: (val) {
                    setState(() {});
                     if (_selectedCountry == 'EU') {
                       trainProvider.searchTrainByNumber(val);
                     } else if (_selectedCountry.isNotEmpty) {
                       trainProvider.searchStations(val, country: _selectedCountry);
                     } else {
                       _searchStationsMultipleCountries(val, displayedCountries, trainProvider);
                     }
                 },
               ),
               
               // Filters Row (Chips)
               SizedBox(
                 height: 48,
                 child: ListView(
                   scrollDirection: Axis.horizontal,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                   physics: const BouncingScrollPhysics(),
                   children: [
                     // Optional: "All" or Reset chip
                     if (_selectedCountry.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                             avatar: Icon(Icons.close, size: 16, color: theme.errorColor),
                             label: Text("Reset", style: TextStyle(color: theme.errorColor)),
                             backgroundColor: theme.errorColor.withOpacity(0.1),
                             side: BorderSide.none,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                             onPressed: () {
                               setState(() => _selectedCountry = '');
                               _searchStationsMultipleCountries(_searchController.text, displayedCountries, trainProvider);
                             },
                          ),
                        ),

                     ...displayedCountries.map((c) {
                        final isSelected = _selectedCountry == c['code'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(c['name']!),
                            selected: isSelected, 
                            onSelected: (val) {
                               setState(() => _selectedCountry = val ? c['code']! : '');
                               final query = _searchController.text;
                               if (query.isNotEmpty) {
                                  if (val && c['code'] == 'EU') {
                                    trainProvider.searchTrainByNumber(query);
                                  } else if (val) {
                                    trainProvider.searchStations(query, country: c['code']!);
                                  } else {
                                    _searchStationsMultipleCountries(query, displayedCountries, trainProvider);
                                  }
                               }
                            },
                            showCheckmark: false, // Cleaner look
                            // Material 3 Style colors
                            backgroundColor: theme.surfaceColor,
                            selectedColor: theme.primaryColor.withOpacity(0.12),
                            side: isSelected 
                                ? BorderSide(color: theme.primaryColor, width: 1.5)
                                : BorderSide(color: theme.secondaryTextColor.withOpacity(0.2)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // M3 uses smaller radius for suggestion chips sometimes, but let's stick to rounded
                            labelStyle: TextStyle(
                              color: isSelected ? theme.primaryColor : theme.textColor,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                            elevation: isSelected ? 1 : 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          ),
                        );
                     }).toList(),
                   ],
                 ),
               ),
               const SizedBox(height: 12),
            ],
          ),
        ),
        
        // Mode Switcher (Pill)
        Center(
          child: SlidingTabToggle(
            isArrival: trainProvider.isArrivalMode,
            onChanged: (val) => trainProvider.setArrivalMode(val),
            theme: theme,
          ),
        ),

        // Results Area
        Expanded(
          child: Builder(
            builder: (context) {
              if (trainProvider.isSearchingByNumber || trainProvider.searchResults.isNotEmpty) {
                return _buildNumberSearchResults(trainProvider);
              } else if (trainProvider.isLoadingSuggestions || trainProvider.stationSuggestions.isNotEmpty) {
                return _buildStationSuggestions(trainProvider);
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.directions_railway_filled_rounded, size: 64, color: theme.secondaryTextColor.withOpacity(0.2)),
                       const SizedBox(height: 16),
                       Text(
                        "Inserisci una stazione",
                        style: TextStyle(color: theme.secondaryTextColor, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ],
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

  Widget _buildTrainCard(BuildContext context, dynamic dep, int index, ThemeProvider theme) {
     // Helper to parse time string safely
    final scheduleTime = dep.scheduledTime != null 
        ? DateFormat('HH:mm').format(dep.scheduledTime!.toUtc().add(Duration(hours: 1))) // Simple offset correction, adjust as needed
        : '--:--';
        
    final delayMin = dep.delayMinutes ?? 0;
    final isDelayed = delayMin > 0;
    final isCancelled = dep.status == 'CANCELED';
    final platform = dep.platform ?? '-';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
             // Fetch details if empty (placeholder for existing logic)
             if (dep.stops == null || dep.stops.isEmpty) {
                Provider.of<TrainProvider>(context, listen: false).expandTrainDetails(index);
             }
             
             showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                barrierColor: Colors.black54,
                builder: (ctx) => DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.96,
                  snap: true,
                  builder: (_, controller) {
                    return TrainDetailsSheet(
                      departure: dep,
                      isArrivalMode: Provider.of<TrainProvider>(context, listen: false).isArrivalMode,
                      selectedCountry: _selectedCountry,
                      scrollController: controller,
                    );
                  }
                ),
             );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Time Column (Big & Bold)
                Container(
                  padding: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: theme.secondaryTextColor.withOpacity(0.1)))
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        scheduleTime,
                        style: TextStyle(
                          fontSize: 22, 
                          fontWeight: FontWeight.w800, 
                          color: theme.textColor,
                          letterSpacing: -0.5
                        ),
                      ),
                      if (isCancelled)
                        Container(
                           margin: const EdgeInsets.only(top: 4),
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: theme.errorColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(4)
                           ),
                           child: Text("CANC", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.errorColor)),
                        )
                      else if (isDelayed)
                        Container(
                           margin: const EdgeInsets.only(top: 4),
                           padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                           decoration: BoxDecoration(
                             color: theme.warningColor.withOpacity(0.1),
                             borderRadius: BorderRadius.circular(4)
                           ),
                           child: Row(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(Icons.warning_amber_rounded, size: 10, color: theme.warningColor),
                               const SizedBox(width: 2),
                               Text("+$delayMin'", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: theme.warningColor)),
                             ],
                           ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text("On Time", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.successColor)),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // 2. Info Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          // Train Type Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: _getTrainColor(dep.category, theme).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "${dep.category ?? 'TRN'} ${dep.trainNumber ?? ''}",
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.w800, 
                                color: _getTrainColor(dep.category, theme)
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              dep.destination ?? 'Destinazione Sconosciuta',
                              style: TextStyle(
                                fontSize: 17, 
                                fontWeight: FontWeight.w700, 
                                color: theme.textColor
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 3. Platform Box
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.surfaceColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.1), width: 1.5)
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Text("BIN", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: theme.secondaryTextColor, letterSpacing: 0.5)),
                       const SizedBox(height: 2),
                       Text(platform, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textColor)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getTrainColor(String? type, ThemeProvider theme) {
    if (type == null) return theme.primaryColor;
    final t = type.toLowerCase();
    if (t.contains('fr') || t.contains('ic') || t.contains('ec') || t.contains('av')) return const Color(0xFFC62828); // Red for High Speed
    if (t.contains('rg') || t.contains('r')) return const Color(0xFF00695C); // Teal for Regional
    if (t.contains('intercity')) return Colors.blue.shade800;
    return theme.primaryColor;
  }

  Widget _buildStationSuggestions(TrainProvider provider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (provider.isLoadingSuggestions) {
      return ShimmerLoading(baseColor: theme.secondaryTextColor);
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: provider.stationSuggestions.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: theme.secondaryTextColor.withOpacity(0.08), indent: 72, endIndent: 24),
      itemBuilder: (context, index) {
          final s = provider.stationSuggestions[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: div(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset:const Offset(0, 2))],
              ),
              child: Icon(Icons.location_city_rounded, color: theme.primaryColor, size: 22),
            ),
            title: Text(
              s.name, 
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w600, fontSize: 16)
            ),
            subtitle: Row(
              children: [
                if (s.country.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4)
                    ),
                    child: Text(s.country, style: TextStyle(fontSize: 10, color: theme.textColor, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            onTap: () => provider.selectStation(s),
            trailing: Consumer2<FavoritesProvider, AuthProvider>(
              builder: (context, favoritesProvider, authProvider, child) {
                if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                final isFavorite = favoritesProvider.isStopFavorite(s.id, StopType.trainStation, country: s.country);
                return IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    color: isFavorite ? Colors.red : theme.secondaryTextColor.withOpacity(0.5)
                  ),
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
    );
  }

  // Define a Container alias for readability if needed, or just use Container directly in the code above.
  Widget div({required double width, required double height, required BoxDecoration decoration, required Widget child}) {
       return Container(width: width, height: height, decoration: decoration, alignment: Alignment.center, child: child);
  }

  Widget _buildNumberSearchResults(TrainProvider provider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (provider.isSearchingByNumber) {
      return ShimmerLoading(baseColor: theme.secondaryTextColor);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: provider.searchResults.length,
      itemBuilder: (context, index) {
        final m = provider.searchResults[index];
        final line = m['line'] ?? {};
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.secondaryTextColor.withOpacity(0.05)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.warningColor.withOpacity(0.15),
              child: Icon(Icons.speed_rounded, color: theme.warningColor, size: 20),
            ),
            title: Text("${line['name'] ?? '?'}", style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
            subtitle: Text("Direzione: ${m['direction'] ?? 'N/A'}", style: TextStyle(color: theme.secondaryTextColor)),
            trailing: Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor.withOpacity(0.5)),
            onTap: () {
              final mapState = Provider.of<MapStateProvider>(context, listen: false);
              final lat = m['latitude'];
              final lng = m['longitude'];
              if (lat != null && lng != null) {
                mapState.flyTo(lat.toDouble(), lng.toDouble(), zoom: 12);
              }
            },
          ),
        );
      },
    );
  }

  Future<void> _searchStationsMultipleCountries(
    String query,
    List<Map<String, String>> countries,
    TrainProvider trainProvider,
  ) async {
    if (query.length < 2) {
      trainProvider.clearStationSuggestions();
      return;
    }

    // Estrai tutti i codici di nazionalità disponibili
    final countryCodes = countries.map((c) => c['code']!).toList();

    // Esegui ricerche in parallelo per tutti i paesi
    final searchFutures = countryCodes.map((countryCode) {
      return trainProvider.searchStations(query, country: countryCode)
          .then((_) => trainProvider.stationSuggestions.toList())
          .catchError((_) => <TrainStation>[]);
    }).toList();

    // Raccogli i risultati di tutte le ricerche
    final allResultsList = await Future.wait(searchFutures);
    final allResults = <TrainStation>[];
    for (final results in allResultsList) {
      allResults.addAll(results);
    }

    // Rimuovi duplicati basandoti su ID e paese
    final seen = <String>{};
    final uniqueResults = <TrainStation>[];
    for (final station in allResults) {
      final key = '${station.id}-${station.country}';
      if (!seen.contains(key)) {
        seen.add(key);
        uniqueResults.add(station);
      }
    }

    // Aggiorna il provider con i risultati unici
    trainProvider.setStationSuggestions(uniqueResults);
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
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
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class TrainPanelContent extends StatefulWidget {
  final bool showModeToggle; // Show Partenze / Arrivi toggle when used as modal from Favorites
  const TrainPanelContent({super.key, this.showModeToggle = false});

  @override
  State<TrainPanelContent> createState() => _TrainPanelContentState();
}

class _TrainPanelContentState extends State<TrainPanelContent> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCountry = '';
  String _selectedCity = ''; // Città selezionata
  String _favoriteSortOrder = 'country'; // 'country', 'alphabetic', 'recent'
  final Map<String, int> _stationVisits = {}; // Traccia numero di visite per stazione
  
  // Variabili per paesi e città caricati da API
  List<Map<String, String>> _countries = [];
  Map<String, List<Map<String, String>>> _citiesByCountry = {}; // Mappa paese -> città
  List<String> _countryOrder = []; // Ordine personalizzato dei paesi
  bool _countriesLoaded = false;

  // Mappa dei fusi orari (Offset rispetto a UTC)
  final Map<String, int> countryTimezoneOffsets = {
    'IT': 1, 'FR': 1, 'DE': 1, 'AT': 1, 'CH': 1, 'ES': 1,
    'GB': 0, 'NL': 1, 'BE': 1, 'LU': 1, 'CZ': 1, 'PL': 1,
    'HU': 1, 'RO': 2, 'GR': 2, 'SE': 1, 'NO': 1, 'DK': 1,
  };

  // Mappa codici paese a nazionalità
  final Map<String, String> countryNames = {
    'AT': 'Austria',
    'BE': 'Belgio',
    'CH': 'Svizzera',
    'CZ': 'Repubblica Ceca',
    'DE': 'Germania',
    'DK': 'Danimarca',
    'EE': 'Estonia',
    'ES': 'Spagna',
    'FI': 'Finlandia',
    'FR': 'Francia',
    'GB': 'Regno Unito',
    'GR': 'Grecia',
    'HU': 'Ungheria',
    'IE': 'Irlanda',
    'IT': 'Italia',
    'LU': 'Lussemburgo',
    'NL': 'Paesi Bassi',
    'NO': 'Norvegia',
    'PL': 'Polonia',
    'RO': 'Romania',
    'SE': 'Svezia',
    'SI': 'Slovenia',
    'FAL': 'Puglia (FAL)',
    'EU': 'Continentale (Realtime)',
  };

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _saveCountryOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('country_order', _countryOrder);
    } catch (e) {
      print('Errore salvataggio ordinamento paesi: $e');
    }
  }

  Future<void> _loadCountryOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList('country_order') ?? [];
      if (mounted) {
        setState(() {
          _countryOrder = savedOrder;
        });
      }
    } catch (e) {
      print('Errore caricamento ordinamento paesi: $e');
    }
  }

  List<Map<String, String>> _getOrderedCountries(List<Map<String, String>> countries) {
    if (_countryOrder.isEmpty) {
      return countries;
    }
    
    // Ordina i paesi secondo l'ordine personalizzato
    List<Map<String, String>> ordered = [];
    
    // Aggiungi prima i paesi nell'ordine personalizzato
    for (final code in _countryOrder) {
      final country = countries.firstWhere((c) => c['code'] == code, orElse: () => {});
      if (country.isNotEmpty) {
        ordered.add(country);
      }
    }
    
    // Poi aggiungi i paesi non ancora ordinati
    for (final country in countries) {
      if (!ordered.any((c) => c['code'] == country['code'])) {
        ordered.add(country);
      }
    }
    
    return ordered;
  }

  Future<void> _loadCountries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCountries = prefs.getString('countries_cache');
      final cachedCities = prefs.getString('cities_cache');
      
      // Tenta di caricare da API
      final freshData = await _fetchProvidersFromAPI();
      
      if (freshData.isNotEmpty) {
        // Salva i nuovi dati nel cache
        await prefs.setString('countries_cache', jsonEncode(freshData));
        await prefs.setString('cities_cache', jsonEncode(_citiesByCountry));
        if (mounted) {
          setState(() {
            _countries = freshData;
            _countriesLoaded = true;
          });
        }
        await _loadCountryOrder();
      } else if (cachedCountries != null) {
        // Fallback al cache se l'API non risponde
        final cached = List<Map<String, String>>.from(
          (jsonDecode(cachedCountries) as List).map((item) => Map<String, String>.from(item as Map))
        );
        if (mounted) {
          setState(() {
            _countries = cached;
            _countriesLoaded = true;
          });
        }
        await _loadCountryOrder();
        
        // Carica anche le città dal cache
        if (cachedCities != null) {
          try {
            final cachedCitiesData = jsonDecode(cachedCities) as Map;
            final citiesData = <String, List<Map<String, String>>>{};
            cachedCitiesData.forEach((key, value) {
              citiesData[key] = List<Map<String, String>>.from(
                (value as List).map((item) => Map<String, String>.from(item as Map))
              );
            });
            if (mounted) {
              setState(() {
                _citiesByCountry = citiesData;
              });
            }
          } catch (e) {
            print('Errore caricamento città dal cache: $e');
          }
        }
      } else {
        // Se nessun dato disponibile, imposta liste vuote
        if (mounted) {
          setState(() {
            _countries = [];
            _countriesLoaded = true;
          });
        }
      }
    } catch (e) {
      print('Errore caricamento paesi: $e');
      if (mounted) {
        setState(() {
          _countries = [];
          _countriesLoaded = true;
        });
      }
    }
  }

  Future<List<Map<String, String>>> _fetchProvidersFromAPI() async {
    try {
      final response = await http
          .get(Uri.parse('https://prod.cuzimmartin.dev/api/providers'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          final providers = data['data']['providers'] as List;
          final grouped = data['data']['grouped'] as List? ?? [];
          
          // Carica TUTTI i provider (NATIONAL, CITY, INTERNATIONAL)
          final Map<String, Map<String, String>> countriesMap = {};
          final Map<String, List<Map<String, String>>> citiesMap = {};
          
          for (final provider in providers) {
            final countryCode = (provider['countryCode'] as String).toUpperCase();
            
            // Se il paese non è già presente, aggiungilo con la nazionalità
            if (!countriesMap.containsKey(countryCode)) {
              countriesMap[countryCode] = {
                'code': countryCode,
                'name': countryNames[countryCode] ?? countryCode,
              };
              citiesMap[countryCode] = [];
            }
          }
          
          // Estrai le città dal'array grouped
          for (final region in grouped) {
            final regionCode = region['regionCode'] as String?;
            final countryCode = region['providers']?.first?['countryCode'] as String?;
            
            if (regionCode != null && countryCode != null) {
              final countryCodeUpper = countryCode.toUpperCase();
              final providers = region['providers'] as List? ?? [];
              
              for (final provider in providers) {
                final scope = provider['scope'] as String?;
                final name = provider['name'] as String?;
                
                // Se è una città (CITY scope) e non è già stata aggiunta
                if (scope == 'CITY' && name != null && citiesMap.containsKey(countryCodeUpper)) {
                  final city = {
                    'code': regionCode,
                    'name': name,
                    'countryCode': countryCodeUpper,
                  };
                  
                  // Controlla se non è già nella lista
                  final exists = citiesMap[countryCodeUpper]!.any((c) => c['code'] == regionCode);
                  if (!exists) {
                    citiesMap[countryCodeUpper]!.add(city);
                  }
                }
              }
            }
          }
          
          // Aggiorna lo stato con le città
          if (mounted) {
            setState(() {
              _citiesByCountry = citiesMap;
            });
          }
          
          return countriesMap.values.toList();
        }
      }
    } catch (e) {
      print('Errore fetch API provider: $e');
    }
    return [];
  }

  void _showCountryReorderDialog(List<Map<String, String>> countries, ThemeProvider theme) {
    final orderedCountries = _getOrderedCountries(countries);
    final reorderableCountries = List<Map<String, String>>.from(orderedCountries);
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ordina Nazioni",
                    style: TextStyle(
                      color: theme.textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: theme.secondaryTextColor),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Divider(color: theme.secondaryTextColor.withOpacity(0.1), height: 1),
            // Reorderable List
            Expanded(
              child: StatefulBuilder(
                builder: (context, setState) {
                  return ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: reorderableCountries.length,
                    itemBuilder: (context, index) {
                      final country = reorderableCountries[index];
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(country['code']),
                        index: index,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.drag_handle, color: theme.primaryColor, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  country['name'] ?? country['code']!,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                country['code']!,
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = reorderableCountries.removeAt(oldIndex);
                        reorderableCountries.insert(newIndex, item);
                      });
                    },
                  );
                },
              ),
            ),
            Divider(color: theme.secondaryTextColor.withOpacity(0.1), height: 1),
            // Footer with Save Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(
                      "Annulla",
                      style: TextStyle(color: theme.secondaryTextColor),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      // Salva il nuovo ordine
                      final newOrder = reorderableCountries.map((c) => c['code']!).toList();
                      this.setState(() {
                        _countryOrder = newOrder;
                      });
                      await _saveCountryOrder();
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text("Ordine nazioni salvato"),
                            backgroundColor: theme.successColor,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Text(
                      "Salva",
                      style: TextStyle(color: theme.surfaceColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                          ScrollingText(
                            text: station.name,
                            style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold),
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
        // Professional Glass Search Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: _selectedCountry.isNotEmpty && (_citiesByCountry[_selectedCountry]?.isNotEmpty ?? false) ? 168 : 120,
            borderRadius: 24,
            blur: 20,
            alignment: Alignment.center,
            border: 1.5,
            linearGradient: LinearGradient(
               begin: Alignment.topLeft,
               end: Alignment.bottomRight,
                colors: [
                  theme.surfaceColor.withOpacity(0.8),
                  theme.surfaceColor.withOpacity(0.5),
                ],
            ),
            borderGradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.secondaryTextColor.withOpacity(0.2),
                theme.secondaryTextColor.withOpacity(0.05),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 // Search Bar
                 Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                   child: TextField(
                     controller: _searchController,
                     style: TextStyle(fontSize: 18, color: theme.textColor),
                     decoration: InputDecoration(
                       hintText: "Cerca stazione...",
                       hintStyle: TextStyle(color: theme.secondaryTextColor.withOpacity(0.7), fontSize: 18),
                       prefixIcon: Icon(Icons.search, color: theme.primaryColor),
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
                           
                           // Ordina Nazioni Button
                           IconButton(
                             icon: Icon(Icons.drag_handle, color: theme.primaryColor),
                             onPressed: () => _showCountryReorderDialog(displayedCountries, theme),
                             tooltip: "Ordina nazioni",
                           ),
                           
                           // Service Filter Menu
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
                       contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
                 ),
                 
                 // Filters Row (Chips) - ora scrollabile orizzontalmente
                 Expanded(
                   child: ListView(
                     scrollDirection: Axis.horizontal,
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     physics: const BouncingScrollPhysics(),
                     children: [
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
                                 setState(() {
                                   _selectedCountry = '';
                                   _selectedCity = '';
                                 });
                                 _searchStationsMultipleCountries(_searchController.text, displayedCountries, trainProvider);
                               },
                            ),
                          ),
                       

                       ..._getOrderedCountries(displayedCountries).map((c) {
                          final isSelected = _selectedCountry == c['code'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(c['name']!),
                              selected: isSelected, 
                              onSelected: (val) {
                                 setState(() {
                                   _selectedCountry = val ? c['code']! : '';
                                   _selectedCity = ''; // Reset città quando cambia paese
                                 });
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
                              showCheckmark: false,
                              backgroundColor: Colors.transparent,
                              selectedColor: theme.primaryColor.withOpacity(0.2),
                              side: BorderSide(
                                color: isSelected ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.2),
                                width: 1.0,
                              ),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), 
                              labelStyle: TextStyle(
                                color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 13,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                            ),
                          );
                       }).toList(),
                     ],
                   ),
                 ),

                 // Città (se disponibili) - seconda riga
                 if (_selectedCountry.isNotEmpty && (_citiesByCountry[_selectedCountry]?.isNotEmpty ?? false))
                   Expanded(
                     child: ListView(
                       scrollDirection: Axis.horizontal,
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                       physics: const BouncingScrollPhysics(),
                       children: [
                         if (_selectedCity.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                 avatar: Icon(Icons.close, size: 16, color: theme.warningColor),
                                 label: Text("Reset città", style: TextStyle(color: theme.warningColor, fontSize: 12)),
                                 backgroundColor: theme.warningColor.withOpacity(0.1),
                                 side: BorderSide.none,
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                 onPressed: () {
                                   setState(() => _selectedCity = '');
                                   final query = _searchController.text;
                                   if (query.isNotEmpty) {
                                     trainProvider.searchStations(query, country: _selectedCountry);
                                   }
                                 },
                              ),
                            ),
                         
                         ...((_citiesByCountry[_selectedCountry] ?? []).map((city) {
                            final isSelected = _selectedCity == city['code'];
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(city['name']!, style: TextStyle(fontSize: 12)),
                                selected: isSelected,
                                onSelected: (val) {
                                   setState(() => _selectedCity = val ? city['code']! : '');
                                   final query = _searchController.text;
                                   if (query.isNotEmpty) {
                                     trainProvider.searchStations(query, country: _selectedCountry);
                                   }
                                },
                                showCheckmark: false,
                                backgroundColor: Colors.transparent,
                                selectedColor: theme.warningColor.withOpacity(0.2),
                                side: BorderSide(
                                  color: isSelected ? theme.warningColor : theme.secondaryTextColor.withOpacity(0.2),
                                  width: 1.0,
                                ),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                labelStyle: TextStyle(
                                  color: isSelected ? theme.warningColor : theme.secondaryTextColor,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0),
                              ),
                            );
                         }).toList()),
                       ],
                     ),
                   ),
              ],
            ),
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

        // Stazioni Preferite Section
        Consumer2<FavoritesProvider, AuthProvider>(
          builder: (context, favoritesProvider, authProvider, child) {
            if (!authProvider.isAuthenticated) return const SizedBox.shrink();
            
            final favoriteStops = favoritesProvider.favoriteStops
                .where((fav) => fav.stopType == StopType.trainStation)
                .toList();
            
            if (favoriteStops.isEmpty) return const SizedBox.shrink();
            
            // Ordina le stazioni preferite
            List<dynamic> sortedStops = List.from(favoriteStops);
            if (_favoriteSortOrder == 'country') {
              sortedStops.sort((a, b) => (a.country ?? '').compareTo(b.country ?? ''));
            } else if (_favoriteSortOrder == 'alphabetic') {
              sortedStops.sort((a, b) => a.name.compareTo(b.name));
            } else if (_favoriteSortOrder == 'recent') {
              // I preferiti recenti vengono mantenuti nell'ordine di caricamento
            }
            
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header con titolo e menu ordinamento
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Stazioni Preferite",
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: Icon(Icons.sort_rounded, color: theme.primaryColor, size: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          color: theme.surfaceColor,
                          onSelected: (val) {
                            setState(() => _favoriteSortOrder = val);
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'country',
                              child: Row(
                                children: [
                                  Icon(Icons.public, color: _favoriteSortOrder == 'country' ? theme.primaryColor : Colors.transparent, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Per Paese", style: TextStyle(color: theme.textColor)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'alphabetic',
                              child: Row(
                                children: [
                                  Icon(Icons.sort_by_alpha, color: _favoriteSortOrder == 'alphabetic' ? theme.primaryColor : Colors.transparent, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Alfabetico", style: TextStyle(color: theme.textColor)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'recent',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule, color: _favoriteSortOrder == 'recent' ? theme.primaryColor : Colors.transparent, size: 18),
                                  const SizedBox(width: 8),
                                  Text("Recenti", style: TextStyle(color: theme.textColor)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Horizontal scroll delle stazioni preferite
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      physics: const BouncingScrollPhysics(),
                      itemCount: sortedStops.length,
                      itemBuilder: (context, index) {
                        final stop = sortedStops[index];
                        return _buildFavoriteStationCard(theme, trainProvider, stop);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
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

  // Traccia e incrementa le visite della stazione
  int _trackStationVisit(String stationId, String country) {
    final key = '$stationId-$country';
    _stationVisits[key] = (_stationVisits[key] ?? 0) + 1;
    return _stationVisits[key] ?? 1;
  }

  // --- Helper Widgets ---

  Widget _buildFavoriteStationCard(ThemeProvider theme, TrainProvider trainProvider, dynamic stop) {
    return GestureDetector(
      onTap: () {
        _trackStationVisit(stop.code, stop.country ?? 'Unknown');
        // Simula la selezione della stazione da favoriti
        final station = TrainStation(
          id: stop.code,
          name: stop.name,
          country: stop.country ?? 'Unknown',
          type: 'train',
        );
        trainProvider.selectStation(station);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.location_city_rounded, color: theme.primaryColor, size: 28),
            const SizedBox(height: 6),
            Text(
              stop.name.length > 12 ? '${stop.name.substring(0, 12)}.' : stop.name,
              style: TextStyle(
                color: theme.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                stop.country ?? 'Unknown',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
     // Always use estimated time (scheduled + delay), never just scheduled
    final displayTime = dep.estimatedTime ?? 
        (dep.scheduledTime != null && dep.delayMinutes != null 
            ? dep.scheduledTime!.add(Duration(minutes: dep.delayMinutes!))
            : dep.scheduledTime);
    
    final scheduleTime = displayTime != null 
        ? DateFormat('HH:mm').format(displayTime.toUtc().add(Duration(hours: 1)))
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
                            child: _SmartTrainRouteText(
                              departure: dep,
                              index: index,
                              theme: theme,
                              isArrivalMode: Provider.of<TrainProvider>(context, listen: false).isArrivalMode,
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
    if (t.contains('fr') || t.contains('ic') || t.contains('ec') || t.contains('av') || t.contains('rj')) return const Color(0xFFC62828); // Red for High Speed
    if (t.contains('rg') || t.contains('r') || t.contains('rb') || t.contains('re') || t.contains('regional') || t.contains('wb')  ) return const Color(0xFF00695C); // Teal for Regional
    if (t.contains('icn') || t.contains('nj')) return const Color.fromARGB(255, 124, 105, 124); // Green for S trains
    if (t.contains('intercity')) return Colors.blue.shade800;
    return theme.primaryColor;
  }

  Widget _buildStationSuggestions(TrainProvider provider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (provider.isLoadingSuggestions) {
      return ShimmerLoading(baseColor: theme.secondaryTextColor);
    }
    
    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        final suggestions = provider.stationSuggestions;
        final favoriteStations = <dynamic>[];
        final visitedStations = <dynamic>[];
        final otherStations = <dynamic>[];
        
        // Separa stazioni in tre categorie
        for (final station in suggestions) {
          final key = '${station.id}-${station.country}';
          final isFavorite = favoritesProvider.isStopFavorite(station.id, StopType.trainStation, country: station.country);
          
          if (isFavorite) {
            favoriteStations.add(station);
          } else if (_stationVisits.containsKey(key)) {
            visitedStations.add(station);
          } else {
            otherStations.add(station);
          }
        }
        
        // Ordina stazioni visitate per numero di visite (decrescente)
        visitedStations.sort((a, b) {
          final keyA = '${a.id}-${a.country}';
          final keyB = '${b.id}-${b.country}';
          return (_stationVisits[keyB] ?? 0).compareTo(_stationVisits[keyA] ?? 0);
        });
        
        // Combina: preferite, poi visitate, poi resto - SENZA DIVISORI
        final orderedStations = [...favoriteStations, ...visitedStations, ...otherStations];
        
        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: orderedStations.length,
          separatorBuilder: (context, index) => Divider(height: 1, color: theme.secondaryTextColor.withOpacity(0.08), indent: 72, endIndent: 24),
          itemBuilder: (context, index) {
            final s = orderedStations[index];
            
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: div(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
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
              onTap: () {
                _trackStationVisit(s.id, s.country);
                provider.selectStation(s);
              },
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

class _SmartTrainRouteText extends StatefulWidget {
  final dynamic departure; // TrainDeparture
  final int index;
  final ThemeProvider theme;
  final bool isArrivalMode;

  const _SmartTrainRouteText({
    required this.departure,
    required this.index,
    required this.theme,
    required this.isArrivalMode,
  });

  @override
  State<_SmartTrainRouteText> createState() => _SmartTrainRouteTextState();
}

class _SmartTrainRouteTextState extends State<_SmartTrainRouteText> {
  @override
  void initState() {
    super.initState();
    _checkAndFetch();
  }

  @override
  void didUpdateWidget(_SmartTrainRouteText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isArrivalMode != widget.isArrivalMode || 
        oldWidget.departure != widget.departure) {
      _checkAndFetch();
    }
  }

  void _checkAndFetch() {
    // If in Arrivi mode and Origin is missing, fetch details
    if (widget.isArrivalMode) {
      final origin = widget.departure.origin;
      // If origin is missing AND we haven't fetched stops yet (stops empty or null)
      if ((origin == null || origin.isEmpty) && 
          (widget.departure.stops == null || widget.departure.stops.isEmpty)) {
        
        // Prevent cycling if already error
        if (widget.departure.error != null) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Provider.of<TrainProvider>(context, listen: false).expandTrainDetails(widget.index);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String textVal;
    
    if (widget.isArrivalMode) {
       final origin = widget.departure.origin;
       if (origin != null && origin.isNotEmpty) {
         textVal = origin;
       } else if (widget.departure.stops != null && widget.departure.stops.isNotEmpty) {
         // Fallback to first stop if origin field is still null but stops loaded
         textVal = widget.departure.stops.first.stationName;
       } else {
         textVal = "Caricamento origine...";
       }
    } else {
      textVal = widget.departure.destination ?? 'Destinazione Sconosciuta';
    }

    return ScrollingText(
      text: textVal,
      style: TextStyle(
        fontSize: 17, 
        fontWeight: FontWeight.w700, 
        color: widget.theme.textColor
      ),
    );
  }
}

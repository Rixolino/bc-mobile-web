import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_page.dart';
import '../../features/auth/screens/dashboard_page.dart';
import '../../features/bus/presentation/providers/bus_provider.dart';
import '../../features/plane/presentation/providers/plane_provider.dart';
import '../../features/train/presentation/providers/train_provider.dart';
import '../providers/map_state_provider.dart';
import '../providers/theme_provider.dart';
import '../../features/bus/presentation/widgets/bus_panel_content.dart';
import '../../features/plane/presentation/widgets/plane_panel_content.dart';
import '../../features/train/presentation/widgets/train_panel_content.dart';
import '../widgets/map_background.dart';

import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PanelController _panelController = PanelController();
  final TextEditingController _searchController = TextEditingController();
  
  // 0: Trains, 1: Buses, 2: Planes
  int _selectedModeIndex = 0; 
  bool _searchByNumber = false;
  bool _showStopDropdown = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BusProvider>(context, listen: false).loadProviders();
    });
  }

  void _onSearchChanged() {
    if (_selectedModeIndex == 1) {
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      final query = _searchController.text;
      busProvider.searchStops(query);
      setState(() {
        _showStopDropdown = query.isNotEmpty && busProvider.stopSearchResults.isNotEmpty;
      });
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutQuart;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) return;

    if (_selectedModeIndex == 0) {
      final trainProvider = Provider.of<TrainProvider>(context, listen: false);
      if (_searchByNumber) {
        trainProvider.searchTrainByNumber(query);
      } else {
        trainProvider.searchStations(query);
      }
    } else if (_selectedModeIndex == 1) {
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      busProvider.searchStops(query);
      setState(() {
        _showStopDropdown = query.isNotEmpty && busProvider.stopSearchResults.isNotEmpty;
      });
    } else if (_selectedModeIndex == 2) {
      final planeProvider = Provider.of<PlaneProvider>(context, listen: false);
      planeProvider.searchAirports(query);
    }

    // Apri il pannello per mostrare i risultati
    if (!_panelController.isPanelOpen) {
      _panelController.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    final config = configProvider.config;

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Consumer<BusProvider>(
          builder: (context, busProvider, child) {
            // Quando c'è un bus o una fermata selezionati, nascondi il panel
            final hasSelectedBus = busProvider.selectedBus != null;
            final hasSelectedStop = busProvider.selectedStop != null;
            final shouldHidePanel = hasSelectedBus || hasSelectedStop;
            final panelMinHeight = shouldHidePanel ? 0.0 : 148.0;
            final panelMaxHeight = shouldHidePanel ? 0.0 : MediaQuery.of(context).size.height * 0.7;
            
            return Scaffold(
              body: SlidingUpPanel(
                controller: _panelController,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24.0),
                  topRight: Radius.circular(24.0),
                ),
                minHeight: panelMinHeight,
                maxHeight: panelMaxHeight,
                color: theme.backgroundColor.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 20.0,
                    color: theme.textColor.withOpacity(0.12),
                  ),
                ],
                // IL CONTENT DEL PANNELLO (SHEET)
                panel: shouldHidePanel ? const SizedBox() : _buildPanelContent(config),
                
                // LA MAPPA E L'UI DI SFONDO
                body: Stack(
                  children: [
                    // 1. Mappa a schermo intero
                    MapBackground(),

                    // 2. Barra di ricerca Floating
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 10,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                   Expanded(child: _buildSearchBar()),
                   const SizedBox(width: 8),
                   _buildMapStyleButton(),
                   const SizedBox(width: 8),
                   GestureDetector(
                     onTap: _openSettings,
                     child: Container(
                       padding: const EdgeInsets.all(12),
                       decoration: BoxDecoration(
                         color: theme.surfaceColor.withOpacity(0.9),
                         borderRadius: BorderRadius.circular(16),
                         border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                         boxShadow: [
                           BoxShadow(
                             color: theme.textColor.withOpacity(0.18),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           )
                         ]
                       ),
                       child: Icon(Icons.settings, color: theme.textColor),
                     ),
                   )
                ],
              ),
            ),

            // 3. Loading Indicator se necessario
            if (configProvider.isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),

            // 4. Indicatore di trascinamento (debug)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 20,
                color: theme.primaryColor.withOpacity(0.3),
                child: Center(
                  child: Text(
                    'Scorri verso l\'alto',
                    style: TextStyle(color: theme.textColor, fontSize: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
          },
        );
      },
    );
  }

  Widget _buildMapStyleButton() {
    final mapState = Provider.of<MapStateProvider>(context);
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    
    IconData styleIcon;
    String nextStyle;
    String toastMessage;

    if (mapState.mapStyle == 'streets-v12') {
      styleIcon = Icons.dark_mode;
      nextStyle = 'dark-v11';
      toastMessage = "Mappa Scura";
    } else if (mapState.mapStyle == 'dark-v11') {
      styleIcon = Icons.terrain;
      nextStyle = 'satellite-streets-v12';
      toastMessage = "Mappa 3D / Satellite";
    } else {
      styleIcon = Icons.map;
      nextStyle = 'streets-v12';
      toastMessage = "Mappa Normale";
    }

    return GestureDetector(
      onTap: () {
        mapState.setMapStyle(nextStyle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(toastMessage),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
            width: 200,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.surfaceColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: theme.textColor.withOpacity(0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ]
        ),
        child: Icon(styleIcon, color: theme.textColor),
      ),
    );
  }

  Widget _buildSearchBar() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final searchBar = GlassmorphicContainer(
      width: double.infinity,
      height: 60,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.surfaceColor.withOpacity(0.6),
          theme.surfaceColor.withOpacity(0.4),
        ],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.secondaryTextColor.withOpacity(0.3),
          theme.secondaryTextColor.withOpacity(0.1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            if (_selectedModeIndex == 0) // Solo per treni mostriamo il toggle numero
              IconButton(
                icon: Icon(
                  _searchByNumber ? Icons.pin : Icons.location_on,
                  color: _searchByNumber ? theme.primaryColor : theme.textColor,
                ),
                onPressed: () {
                  setState(() {
                    _searchByNumber = !_searchByNumber;
                  });
                },
                tooltip: _searchByNumber ? "Cerca per Numero" : "Cerca per Stazione",
              )
            else
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Icon(Icons.search, color: theme.textColor),
              ),
            const SizedBox(width: 5),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: theme.textColor),
                onSubmitted: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: _getSearchHint(),
                  hintStyle: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: InkWell(
                onTap: () {
                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                  if (authProvider.isAuthenticated) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const DashboardPage()),
                    );
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  }
                },
                child: Icon(Icons.person, color: theme.textColor),
              ),
            ),
          ],
        ),
      ),
    );

    // Add dropdown for bus stops if visible
    if (_showStopDropdown && _selectedModeIndex == 1) {
      final busProvider = Provider.of<BusProvider>(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          searchBar,
          const SizedBox(height: 4),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.surfaceColor.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.secondaryTextColor.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: theme.textColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: busProvider.stopSearchResults.length,
              itemBuilder: (context, index) {
                final stop = busProvider.stopSearchResults[index];
                return ListTile(
                  dense: true,
                  title: Text(
                    stop.stopName,
                    style: TextStyle(color: theme.textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    'ID: ${stop.stopId}',
                    style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                  ),
                  onTap: () {
                    // Center map on selected stop
                    final mapState = Provider.of<MapStateProvider>(context, listen: false);
                    mapState.flyTo(
                      stop.latitude,
                      stop.longitude,
                      zoom: 16.0,
                    );
                    // Clear search and hide dropdown
                    _searchController.clear();
                    setState(() {
                      _showStopDropdown = false;
                    });
                    busProvider.clearStopSearch();
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    return searchBar;
  }

  String _getSearchHint() {
    switch (_selectedModeIndex) {
      case 0: return _searchByNumber ? "N. Treno (es: 9610)" : "Stazione (es: Roma Termini)";
      case 1: return "Cerca fermata bus...";
      case 2: return "Cerca volo o aeroporto...";
      default: return "Cerca destinazione...";
    }
  }

  Widget _buildPanelContent(dynamic config) {
    if (config == null) return const SizedBox();
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    return Column(
      children: [
        const SizedBox(height: 12),
        // Handle per il drag
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.secondaryTextColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        
        // Selettore Modalità (Treni/Bus/Aerei)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildModeButton(0, Icons.train, "Treni", true),
            _buildModeButton(1, Icons.directions_bus, "Bus", true),
            _buildModeButton(2, Icons.flight, "Aerei", true),
          ],
        ),
        
        Divider(color: theme.secondaryTextColor.withOpacity(0.12), height: 40),

        // Contenuto dinamico in base alla selezione
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              bottom: MediaQuery.of(context).padding.top + 36, // Padding per evitare sovrapposizione con barra navigazione
            ),
            child: _buildDynamicList(),
          ),
        ),
      ],
    );
  }

  Widget _buildModeButton(int index, IconData icon, String label, bool enabled) {
    if (!enabled) return const SizedBox.shrink();
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isSelected = _selectedModeIndex == index;

    return GestureDetector(
      onTap: () {
        if (_selectedModeIndex != index) {
          // Cancella elementi dalla mappa quando si cambia trasporto
          Provider.of<TrainProvider>(context, listen: false).clearAll();
          Provider.of<BusProvider>(context, listen: false).clearAll();
          Provider.of<PlaneProvider>(context, listen: false).clearAll();
          _searchController.clear();
          // Nasconde il dropdown delle fermate quando si cambia modalità
          _showStopDropdown = false;
        }

        setState(() {
          _selectedModeIndex = index;
          // Apriamo leggermente il pannello se si cambia modalità
          _panelController.open(); 
        });
        
        // Notifichiamo il MapStateProvider per resettare la vista
        Provider.of<MapStateProvider>(context, listen: false).setCategory(index);
        
        // Carichiamo automaticamente le fermate quando si seleziona la categoria bus
        if (index == 1) { // Bus category
          final busProvider = Provider.of<BusProvider>(context, listen: false);
          if (busProvider.stops.isEmpty && !busProvider.isLoadingStops) {
            busProvider.fetchStops();
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.primaryColor : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? theme.textColor : theme.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicList() {
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    if (_selectedModeIndex == 0) {
      return const TrainPanelContent();
    }
    if (_selectedModeIndex == 1) {
      return const BusPanelContent();
    }
    if (_selectedModeIndex == 2) {
      return PlanePanelContent(
        onRefresh: () {
          final planeProvider = Provider.of<PlaneProvider>(context, listen: false);
          final mapState = Provider.of<MapStateProvider>(context, listen: false);
          // Scansiona l'area visibile sulla mappa
          planeProvider.scanAreaForFlights(mapState.lat, mapState.lng, mapState.zoom);
        },
      );
    }
  
    // Default / Recenti
    return ListView(
      children: [
        Text(
          "Recenti",
          style: TextStyle(
            color: theme.textColor.withOpacity(0.8),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildListItem(Icons.history, "Bari Centrale -> Roma Termini", "Treno • Ieri"),
        _buildListItem(Icons.history, "Piazza Moro -> Via Sparano", "Bus • Oggi"),
        const SizedBox(height: 24),
        Text(
          "Vicino a te",
          style: TextStyle(
            color: theme.textColor.withOpacity(0.8),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        _buildListItem(Icons.location_on, "Fermata Via Capruzzi", "200m • Bus"),
        _buildListItem(Icons.local_airport, "Aeroporto Karol Wojtyła", "10km • Aereo"),
      ],
    );
  }

  Widget _buildListItem(IconData icon, String title, String subtitle) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.surfaceColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: theme.secondaryTextColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.secondaryTextColor.withOpacity(0.5),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.secondaryTextColor.withOpacity(0.3)),
        ],
      ),
    );
  }
}

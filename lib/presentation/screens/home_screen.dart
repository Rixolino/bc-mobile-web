import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
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
import '../../features/train/presentation/screens/train_search_screen.dart';
import '../../features/bus/presentation/screens/bus_search_screen.dart';
import '../../features/plane/presentation/screens/plane_search_screen.dart';
import '../widgets/map_background.dart';

import 'settings_screen.dart';
import 'notifications_manager_screen.dart';
import '../../features/favorites/screens/favorites_page.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../core/services/android_background_service.dart';
import '../widgets/map_widget.dart';

class HomeScreen extends StatefulWidget {
  final int initialMode; // Modalità iniziale (0=Viaggio, 1=Treno, 2=Bus, 3=Aereo)

  const HomeScreen({
    super.key,
    this.initialMode = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // 0: Viaggio (mappa), 1: Trains, 2: Buses, 3: Planes
  late int _selectedModeIndex;
  late int _previousModeIndex;
  bool _searchByNumber = false;
  bool _showStopDropdown = false;
  bool _searchExpanded = true;

  @override
  void initState() {
    super.initState();
    _selectedModeIndex = widget.initialMode;
    _previousModeIndex = widget.initialMode;
    _searchController.addListener(_onSearchChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BusProvider>(context, listen: false).loadProviders();
      
      // Initialize favorites based on auth state
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthChange);
      // Trigger once in case already initialized
      _onAuthChange();
    });
  }

  void _onAuthChange() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final favs = Provider.of<FavoritesProvider>(context, listen: false);
    
    if (auth.isInitialized) {
      if (auth.isAuthenticated) {
         final userId = auth.currentUser!.id.toString();
         // Basic check to avoid redundant reloads, though a dedicated currentUserId check in provider would be better
         if (!favs.hasFavorites && !favs.isLoading) { 
             favs.loadFavorites(userId);
         }
      } else {
         if (favs.hasFavorites) {
             favs.clearFavorites();
         }
      }
    }
  }

  void _onSearchChanged() {
    if (_selectedModeIndex == 2) { // Bus (ora è index 2)
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      final query = _searchController.text;
      busProvider.searchStops(query);
      setState(() {
        _showStopDropdown = query.isNotEmpty && busProvider.stopSearchResults.isNotEmpty;
      });
    }
  }

  void _openSettings() {
    // Use MaterialPageRoute to keep the same default animation as Favorites
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    try {
      Provider.of<AuthProvider>(context, listen: false).removeListener(_onAuthChange);
    } catch (_) {} // Context might be invalid if unmounting
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) return;

    // Non navighiamo più, cambiamo solo il contenuto nella stessa schermata
    if (_selectedModeIndex == 1) { // Treno
      final trainProvider = Provider.of<TrainProvider>(context, listen: false);
      if (_searchByNumber) {
        trainProvider.searchTrainByNumber(query);
      } else {
        trainProvider.searchStations(query);
      }
    } else if (_selectedModeIndex == 2) { // Bus
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      busProvider.searchStops(query);
      setState(() {
        _showStopDropdown = query.isNotEmpty && busProvider.stopSearchResults.isNotEmpty;
      });
    } else if (_selectedModeIndex == 3) { // Aereo
      final planeProvider = Provider.of<PlaneProvider>(context, listen: false);
      planeProvider.searchAirports(query);
    }
  }

  void _setMode(int mode) {
    if (_selectedModeIndex != mode) {
      // Pulisce i provider quando si cambia modalità
      if (mode == 0) { // Viaggio - pulisce tutto
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<BusProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      } else if (mode == 1) { // Treno
        Provider.of<BusProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      } else if (mode == 2) { // Bus  
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      } else if (mode == 3) { // Aereo
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<BusProvider>(context, listen: false).clearAll();
      }
      
      setState(() {
        _previousModeIndex = _selectedModeIndex;
        _selectedModeIndex = mode;
      });
      Provider.of<MapStateProvider>(context, listen: false).setCategory(mode == 0 ? -1 : mode - 1);
    }
  }

  Future<int> _getMonitoredCount() async {
    try {
      final stops = await AndroidBackgroundService.getMonitoredStops();
      final stations = await AndroidBackgroundService.getMonitoredStations();
      return stops.length + stations.length;
    } catch (e) {
      return 0;
    }
  }

  // Responsive helpers: scale UI elements based on screen width
  double _scaleForWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    const base = 390.0; // reference width (typical phone)
    // Allow modest scaling and clamp to reasonable bounds
    return (w / base).clamp(0.75, 1.25);
  }

  EdgeInsets _buttonPadding(BuildContext context) {
    final s = _scaleForWidth(context);
    // Base padding increased to 10 for slightly larger buttons
    final p = (10 * s).clamp(7.0, 18.0);
    return EdgeInsets.all(p);
  }

  double _iconSize(BuildContext context) {
    final s = _scaleForWidth(context);
    return (18 * s).clamp(14.0, 26.0);
  }

  // Scaled helpers for selectively larger buttons
  EdgeInsets _scaledButtonPadding(BuildContext context, {double factor = 1.0}) {
    final s = _scaleForWidth(context);
    final p = (10 * s * factor).clamp(7.0, 26.0);
    return EdgeInsets.all(p);
  }

  double _scaledIconSize(BuildContext context, {double factor = 1.0}) {
    final s = _scaleForWidth(context);
    return (18 * s * factor).clamp(14.0, 40.0);
  }

  void _showLogoMenuSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Provider.of<ThemeProvider>(ctx, listen: false);
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.28,
          minChildSize: 0.18,
          maxChildSize: 0.75,
          builder: (context, sc) {
            // Page control for internal sheet paging (kept here for lifecycle scope)
            final pageController = PageController();
            final pageNotifier = ValueNotifier<int>(0);

            return Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: theme.surfaceColor.withOpacity(0.98),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.secondaryTextColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header with accent subtitle and back button when on inner page

                    Row(
                      children: [
                        // back button (visible on page 1)
                        ValueListenableBuilder<int>(
                          valueListenable: pageNotifier,
                          builder: (context, page, _) {
                            if (page == 1) {
                              return IconButton(
                                icon: Icon(Icons.arrow_back, color: theme.primaryColor),
                                onPressed: () => pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                              );
                            }
                            return const SizedBox(width: 48);
                          },
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ValueListenableBuilder<int>(
                                valueListenable: pageNotifier,
                                builder: (context, page, _) {
                                  return Text(page == 0 ? 'Azioni rapide' : 'Stili mappa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textColor));
                                },
                              ),
                              const SizedBox(height: 4),
                              ValueListenableBuilder<int>(
                                valueListenable: pageNotifier,
                                builder: (context, page, _) {
                                  return Text(page == 0 ? 'Strumenti e scorciatoie' : 'Scegli lo stile della mappa', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12));
                                },
                              ),
                            ],
                          ),
                        ),

                        IconButton(
                          icon: Icon(Icons.close, color: theme.secondaryTextColor),
                          onPressed: () => Navigator.of(ctx).pop(),
                        )
                      ],
                    ),

                    const SizedBox(height: 8),

                    // PageView: 0 = quick actions, 1 = map styles
                    Expanded(
                      child: PageView(
                        controller: pageController,
                        onPageChanged: (i) => pageNotifier.value = i,
                        children: [
                          // Page 0: original quick actions list
                          ListView(
                            controller: sc,
                            children: [
                              Card(
                                color: theme.backgroundColor.withOpacity(0.02),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: theme.primaryColor,
                                    child: Icon(Icons.map, color: Colors.white, size: 18),
                                  ),
                                  title: const Text('Cambia stile mappa'),
                                  subtitle: const Text('Alterna tra Mappa Normale, Scura e Satellite'),
                                  trailing: Icon(Icons.chevron_right, color: theme.secondaryTextColor),
                                  onTap: () {
                                    // slide to the map styles page
                                    pageController.animateToPage(1, duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
                                  },
                                ),
                              ),

                              const SizedBox(height: 8),

                              Consumer<FavoritesProvider>(
                                builder: (c, fav, _) {
                                  final count = ((fav?.favoriteTrains.length ?? 0) + (fav?.favoriteStops.length ?? 0) + (fav?.favoriteBusLines.length ?? 0));
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      leading: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: theme.secondaryTextColor.withOpacity(0.12),
                                        child: Icon(Icons.star, color: theme.textColor, size: 18),
                                      ),
                                      title: const Text('Preferiti'),
                                      subtitle: const Text('Apri la lista dei preferiti'),
                                      trailing: Wrap(
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        children: [
                                          if (count > 0) Chip(label: Text('$count'), backgroundColor: theme.primaryColor.withOpacity(0.12)),
                                          Icon(Icons.chevron_right, color: theme.secondaryTextColor),
                                        ],
                                      ),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
                                      },
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 8),

                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: theme.secondaryTextColor.withOpacity(0.12),
                                    child: Icon(Icons.settings, color: theme.textColor, size: 18),
                                  ),
                                  title: const Text('Impostazioni'),
                                  subtitle: const Text('Preferenze app e notifiche'),
                                  trailing: Icon(Icons.chevron_right, color: theme.secondaryTextColor),
                                  onTap: () {
                                    Navigator.of(ctx).pop();
                                    _openSettings();
                                  },
                                ),
                              ),

                              const SizedBox(height: 8),

                              Consumer<AuthProvider>(
                                builder: (c, authProvider, child) {
                                  final title = authProvider.isAuthenticated ? 'Dashboard' : 'Accedi';
                                  final subtitle = authProvider.isAuthenticated ? 'Gestisci il tuo account' : 'Accedi o registrati';
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      leading: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: theme.primaryColor.withOpacity(0.16),
                                        child: Icon(Icons.person, color: theme.primaryColor, size: 18),
                                      ),
                                      title: Text(title),
                                      subtitle: Text(subtitle),
                                      trailing: Icon(Icons.chevron_right, color: theme.secondaryTextColor),
                                      onTap: () {
                                        Navigator.of(ctx).pop();
                                        if (authProvider.isAuthenticated) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage()));
                                        else Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                                      },
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 12),

                              // Footer quick actions
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: theme.primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          // example quick action: open notifications manager
                                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsManagerScreen()));
                                        },
                                        icon: const Icon(Icons.notifications),
                                        label: const Text('Notifiche'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: theme.textColor,
                                          side: BorderSide(color: theme.secondaryTextColor.withOpacity(0.14)),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        onPressed: () {
                                          Navigator.of(ctx).pop();
                                          // example: report issue (placeholder)
                                        },
                                        child: const Text('Segnala'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),
                            ],
                          ),

                          // Page 1: Map styles selection
                          Consumer<MapStateProvider>(
                            builder: (c, mapState, child) {
                              final styles = [
                                {'id': 'streets-v12', 'label': 'Normale'},
                                {'id': 'dark-v11', 'label': 'Scuro'},
                                {'id': 'satellite-streets-v12', 'label': 'Satellite'},
                              ];

                              return ListView.builder(
                                controller: sc,
                                itemCount: styles.length + 1,
                                itemBuilder: (context, idx) {
                                  if (idx == 0) return const SizedBox(height: 8);
                                  final s = styles[idx - 1];
                                  final isSelected = mapState.mapStyle == s['id'];
                                  return Card(
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      leading: CircleAvatar(
                                        radius: 20,
                                        backgroundColor: theme.secondaryTextColor.withOpacity(0.08),
                                        child: Icon(Icons.map, color: theme.primaryColor, size: 18),
                                      ),
                                      title: Text(s['label']!),
                                      trailing: isSelected ? Icon(Icons.check, color: theme.primaryColor) : null,
                                      onTap: () {
                                        mapState.setMapStyle(s['id']!);
                                        // animate back to quick actions after selection
                                        pageController.animateToPage(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                      },
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
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

  void _showAccountOverlay(AuthProvider authProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final user = authProvider.currentUser;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isAuth = authProvider.isAuthenticated;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.primaryColor,
                      child: Text(
                        (user?.nickname != null && user!.nickname!.isNotEmpty)
                            ? user.nickname![0].toUpperCase()
                            : (user?.email != null ? user!.email![0].toUpperCase() : '?'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.nickname ?? user?.email ?? 'Utente', style: TextStyle(fontWeight: FontWeight.w700, color: theme.textColor, fontSize: 16)),
                          if (user?.email != null) ...[
                            const SizedBox(height: 4),
                            Text(user!.email!, style: TextStyle(color: theme.secondaryTextColor, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: theme.secondaryTextColor),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Divider(height: 8),

                ListTile(
                  leading: Icon(Icons.star, color: theme.primaryColor),
                  title: Text('Preferiti', style: TextStyle(color: theme.textColor)),
                  subtitle: Text('Gestisci i tuoi elementi preferiti', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
                  },
                ),

                ListTile(
                  leading: Icon(Icons.person, color: theme.primaryColor),
                  title: Text(isAuth ? 'Dashboard' : 'Accedi', style: TextStyle(color: theme.textColor)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    if (isAuth) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage()));
                    else Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                  },
                ),

                if (isAuth)
                  ListTile(
                    leading: Icon(Icons.logout, color: theme.primaryColor),
                    title: Text('Logout', style: TextStyle(color: theme.textColor)),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      await authProvider.logout();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout eseguito')));
                    },
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPanelForMode(int mode) {
    switch (mode) {
      case 1:
        return const TrainSearchScreen();
      case 2:
        return const BusSearchScreen();
      case 3:
        return const PlaneSearchScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final configProvider = Provider.of<ConfigProvider>(context);
    // final config = configProvider.config; // Unused

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Consumer<BusProvider>(
          builder: (context, busProvider, child) {
            // Quando c'è un bus o una fermata selezionati, nascondi il panel (non più usato, ma manteniamo la logica di pulizia se serve)
            // final hasSelectedBus = busProvider.selectedBus != null;
            // final hasSelectedStop = busProvider.selectedStop != null;
            
            return Scaffold(
              resizeToAvoidBottomInset: false, // Prevents map from squeezing when keyboard opens
              body: Stack(
                children: [
                  // 1. Mappa a schermo intero usando il nuovo componente
                  const MapWidget(),

                  // 2. Logo e Bottoni Top Right
                  // Logo BC.T - positioned above the search bar at top-left; map/style & settings on the right
                  Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Glass container around logo only
                  GlassmorphicContainer(
                    width: 150,
                    height: 56,
                    borderRadius: 16,
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFFFF6B35), Color(0xFF43AA8B)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ).createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
                            child: Text(
                              'BC',
                              style: GoogleFonts.syne(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showLogoMenuSheet,
                            child: Row(
                              children: [
                                Text(
                                  '.',
                                  style: GoogleFonts.syne(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF3b82f6),
                                  ),
                                ),
                                Text(
                                  'T',
                                  style: GoogleFonts.syne(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: theme.textColor,
                                    shadows: [BoxShadow(color: theme.textColor.withOpacity(0.15), blurRadius: 8)],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchExpanded = !_searchExpanded;
                              });
                            },
                            child: Icon(
                              _searchExpanded ? Icons.expand_less : Icons.expand_more,
                              color: theme.textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      // More button to open the sheet (three dots)
                      GestureDetector(
                        onTap: _showLogoMenuSheet,
                        child: Container(
                          padding: _buttonPadding(context),
                          decoration: BoxDecoration(
                            color: theme.surfaceColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                          ),
                          child: Icon(Icons.more_horiz, size: _iconSize(context), color: theme.textColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Favorites button
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()));
                        },
                        child: Container(
                          padding: _buttonPadding(context),
                          decoration: BoxDecoration(
                            color: theme.surfaceColor.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                          ),
                          child: Icon(Icons.star, size: _iconSize(context), color: theme.textColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FutureBuilder<int>(
                        future: _getMonitoredCount(),
                        builder: (context, snap) {
                          final cnt = snap.data ?? 0;
                          return Stack(
                            alignment: Alignment.topRight,
                            children: [
                              GestureDetector(
                                onTap: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsManagerScreen())); },
                                child: Container(
                                  padding: _buttonPadding(context),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceColor.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                                  ),
                                  child: Icon(Icons.notifications, size: _iconSize(context), color: theme.textColor),
                                ),
                              ),
                              if (cnt > 0)
                                Positioned(
                                  right: 2,
                                  top: 2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                    child: Center(child: Text('$cnt', style: const TextStyle(color: Colors.white, fontSize: 10))),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Compact account button (tap -> Dashboard/Login, long-press -> overlay)
                      Consumer<AuthProvider>(
                        builder: (context, authProvider, child) {
                          final isAuth = authProvider.isAuthenticated;
                          return GestureDetector(
                            onTap: () {
                              if (isAuth) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardPage()));
                              else Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginPage()));
                            },
                            onLongPress: () => _showAccountOverlay(authProvider),
                            child: Container(
                              padding: _buttonPadding(context),
                              decoration: BoxDecoration(
                                color: theme.surfaceColor.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                              ),
                              child: Icon(Icons.person, size: _scaledIconSize(context, factor: 0.9), color: theme.textColor),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search bar - visibile in tutte le modalità quando espanso
            if (_searchExpanded)
              Positioned(
                // Added extra top margin to avoid overlap with status bar / logo
                top: MediaQuery.of(context).padding.top + 10 + 36 + 12 + 12,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                     Expanded(child: _buildSearchBar()),
                  ],
                ),
              ),

            // Widget Fermata Selezionata (Bus)
            if (busProvider.selectedStop != null)
               Positioned(
                 top: MediaQuery.of(context).padding.top + 60 + (_searchExpanded ? 80 : 0),
                 left: 16,
                 right: 16,
                 child: _buildSelectedStopBanner(busProvider, theme),
               ),

            // Pannelli di ricerca per i trasporti - occupano lo schermo intero con animazione elegante
            if (_selectedModeIndex > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    // Animazione elegante con fade + slide dal basso (stile Preferiti)
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_selectedModeIndex),
                    child: _buildPanelForMode(_selectedModeIndex),
                  ),
                ),
              ),

            // 3. Loading Indicator se necessario
            if (configProvider.isLoading)
              const Center(
                child: CircularProgressIndicator(),
              ),

             // 4. Mode Buttons (Floating at bottom center)
             Positioned(
               bottom: 24,
               left: 16,
               right: 16,
               child: Center(
                 child: GlassmorphicContainer(
                   width: double.infinity,
                   height: 76,
                   borderRadius: 38,
                   blur: 30,
                   alignment: Alignment.center,
                   border: 1.5,
                   linearGradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF222831).withOpacity(0.85),
                        const Color(0xFF15191E).withOpacity(0.95),
                      ],
                   ),
                   borderGradient: LinearGradient(
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                     colors: [
                       Colors.white.withOpacity(0.15),
                       Colors.white.withOpacity(0.05),
                     ],
                   ),
                   child: Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         _buildRoundModeButton(Icons.map, "Viaggio", 0, theme),
                         _buildRoundModeButton(Icons.train, "Treno", 1, theme),
                         _buildRoundModeButton(Icons.directions_bus, "Bus", 2, theme),
                         _buildRoundModeButton(Icons.flight, "Aereo", 3, theme),
                         Container(width: 1, height: 24, color: Colors.white.withOpacity(0.1)),
                         _buildActionButton(Icons.star_outline, () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FavoritesPage()))),
                         _buildActionButton(Icons.settings_outlined, _openSettings),
                       ],
                     ),
                   ),
                 ),
               ),
             ),
          ],
        ),
      );
          },
        );
      },
    );
  }

  Widget _buildRoundModeButton(IconData icon, String label, int index, ThemeProvider theme) {
     final isSelected = _selectedModeIndex == index;
     // Colore azzurro acceso per lo stato attivo, simile a un neon
     final activeColor = const Color(0xFF00E5FF); 

     return GestureDetector(
       onTap: () => _setMode(index),
       child: GlassmorphicContainer(
         width: 52, 
         height: 52,
         borderRadius: 20,
         blur: 20,
         alignment: Alignment.center,
         border: 1.0,
         linearGradient: isSelected
             ? LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: [
                   activeColor.withOpacity(0.5),
                   activeColor.withOpacity(0.2),
                 ],
               )
             : LinearGradient(
                 begin: Alignment.topLeft,
                 end: Alignment.bottomRight,
                 colors: [
                   Colors.white.withOpacity(0.0), 
                   Colors.white.withOpacity(0.0),
                 ],
               ),
         borderGradient: LinearGradient(
           begin: Alignment.topLeft,
           end: Alignment.bottomRight,
           colors: isSelected 
             ? [activeColor.withOpacity(0.6), activeColor.withOpacity(0.1)]
             : [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)],
         ),
         child: Icon(
           icon, 
           color: isSelected ? Colors.white : Colors.grey.shade400,
           size: 26,
           shadows: isSelected 
             ? [BoxShadow(color: activeColor.withOpacity(0.8), blurRadius: 8)] 
             : null,
         ),
       ),
     );
  }

  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.grey.shade400, size: 26),
      ),
    );
  }

  Widget _buildSelectedStopBanner(BusProvider busProvider, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: theme.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(
               color: theme.primaryColor.withOpacity(0.1),
               shape: BoxShape.circle,
             ),
             child: Icon(Icons.place, color: theme.primaryColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Fermata Selezionata",
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  busProvider.selectedStop?.stopName ?? "Fermata",
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
               busProvider.clearStopSelection();
               // Se avevamo salvato una ricerca, naviga alla modalità bus
               if (busProvider.savedStopSearchQuery.isNotEmpty) {
                 _setMode(2); // Passa alla modalità Bus
               } else {
                 // Se non c'è ricerca salvata, resta in modalità mappa
                 _setMode(0);
               }
            },
            icon: const Icon(Icons.arrow_upward_rounded, size: 18),
            label: const Text("Apri"),
            style: TextButton.styleFrom(
              foregroundColor: theme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: theme.primaryColor.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
          )
        ],
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
            if (_selectedModeIndex == 1) // Solo per treni mostriamo il toggle numero
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


          ],
        ),
      ),
    );

    // Add dropdown for bus stops if visible
    if (_showStopDropdown && _selectedModeIndex == 2) {
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
      case 1: return _searchByNumber ? "N. Treno (es: 9610)" : "Stazione (es: Roma Termini)";
      case 2: return "Cerca fermata bus...";
      case 3: return "Cerca volo o aeroporto...";
      default: return "Cerca destinazione...";
    }
  }








}

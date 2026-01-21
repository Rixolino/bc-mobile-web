import 'package:flutter/material.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
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
import '../../features/bus/presentation/widgets/bus_panel_content.dart';
import '../../features/plane/presentation/widgets/plane_panel_content.dart';
import '../../features/train/presentation/widgets/train_panel_content.dart';
import '../widgets/map_background.dart';

import 'settings_screen.dart';
import 'notifications_manager_screen.dart';
import '../../features/favorites/screens/favorites_page.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../core/services/android_background_service.dart';

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
  bool _searchExpanded = true;

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
    // Use MaterialPageRoute to keep the same default animation as Favorites
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
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

            // Search bar moved down below the logo
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
        padding: _scaledButtonPadding(context, factor: 1.25),
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
        child: Icon(styleIcon, size: _scaledIconSize(context, factor: 1.25), color: theme.textColor),
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
        
        // Selettore Modalità (Treni/Bus/Aerei) - Material segmented style
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            color: theme.surfaceColor,
            child: Padding(
              padding: const EdgeInsets.all(6.0),
              child: Row(
                children: [
                  _buildModeButton(0, Icons.train, "Treni", true),
                  const SizedBox(width: 8),
                  _buildModeButton(1, Icons.directions_bus, "Bus", true),
                  const SizedBox(width: 8),
                  _buildModeButton(2, Icons.flight, "Aerei", true),
                ],
              ),
            ),
          ),
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

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        // Slight elevation/scale effect when selected
        transform: Matrix4.identity()..scale(isSelected ? 1.02 : 1.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0.0),
          child: ElevatedButton.icon(
            onPressed: () {
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
              if (index == 1) {
                final busProvider = Provider.of<BusProvider>(context, listen: false);
                if (busProvider.stops.isEmpty && !busProvider.isLoadingStops) {
                  busProvider.fetchStops();
                }
              }
            },
            icon: Icon(
              icon,
              color: isSelected ? Colors.white : theme.primaryColor,
              size: 20,
            ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : theme.primaryColor,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            style: ElevatedButton.styleFrom(
              elevation: isSelected ? 4 : 0,
              backgroundColor: isSelected ? theme.primaryColor : theme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? theme.primaryColor : Colors.transparent),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
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

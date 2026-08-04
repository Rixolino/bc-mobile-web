import 'dart:ui';
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
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../core/services/runtime_localizations.dart';

import 'settings_screen.dart';
import 'notifications_manager_screen.dart';
import '../../features/favorites/screens/favorites_page.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../core/services/android_background_service.dart';
import '../../features/roadways/presentation/pages/roadways_page.dart';
import '../widgets/map_widget.dart';
import 'map_screen.dart';
import '../widgets/dashboard_feed.dart';

class HomeScreen extends StatefulWidget {
  final int initialMode;

  const HomeScreen({
    super.key,
    this.initialMode = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  // 0: Home, 1: Treni, 2: Bus, 3: Aerei, 4: Autostrade
  late int _selectedModeIndex;
  late int _previousModeIndex;
  bool _searchByNumber = false;
  bool _showStopDropdown = false;
  bool _searchExpanded = false;

  // --- LIQUID GLASS DOCK: stato del drag ---
  bool _isDockDragging = false;
  double? _dockDragX; // posizione live della "goccia" mentre si trascina
  double _dockSegmentWidth = 0; // larghezza di uno slot icona, calcolata a runtime

  @override
  void initState() {
    super.initState();
    _selectedModeIndex = widget.initialMode;
    _previousModeIndex = widget.initialMode;
    _searchController.addListener(_onSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<BusProvider>(context, listen: false).loadProviders();
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      authProvider.addListener(_onAuthChange);
      _onAuthChange();
    });
  }

  // --- LOGICA ORIGINALE PRESERVATA ---

  void _onAuthChange() {
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final favs = Provider.of<FavoritesProvider>(context, listen: false);
    if (auth.isInitialized) {
      if (auth.isAuthenticated) {
        final userId = auth.currentUser!.id.toString();
        if (!favs.hasFavorites && !favs.isLoading) favs.loadFavorites(userId);
      } else if (favs.hasFavorites) {
        favs.clearFavorites();
      }
    }
  }

  void _onSearchChanged() {
    if (_selectedModeIndex == 2) {
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      final query = _searchController.text;
      busProvider.searchStops(query);
      setState(() {
        _showStopDropdown =
            query.isNotEmpty && busProvider.stopSearchResults.isNotEmpty;
      });
    }
  }

  void _openSettings() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    try {
      Provider.of<AuthProvider>(context, listen: false)
          .removeListener(_onAuthChange);
    } catch (_) {}
    super.dispose();
  }

  void _onSearch(String query) {
    if (query.isEmpty) return;
    if (_selectedModeIndex == 1) {
      final trainProvider = Provider.of<TrainProvider>(context, listen: false);
      _searchByNumber
          ? trainProvider.searchTrainByNumber(query)
          : trainProvider.searchStations(query);
    } else if (_selectedModeIndex == 2) {
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      busProvider.searchStops(query);
      setState(() {
        _showStopDropdown =
            query.isNotEmpty && busProvider.stopSearchResults.isNotEmpty;
      });
    } else if (_selectedModeIndex == 3) {
      Provider.of<PlaneProvider>(context, listen: false).searchAirports(query);
    }
  }

  void _setMode(int mode) {
    if (_selectedModeIndex != mode) {
      // Clear providers on switch
      if (mode == 0) {
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<BusProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      } else if (mode == 1) {
        Provider.of<BusProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      } else if (mode == 2) {
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      } else if (mode == 3) {
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<BusProvider>(context, listen: false).clearAll();
      } else if (mode == 4) {
        Provider.of<TrainProvider>(context, listen: false).clearAll();
        Provider.of<BusProvider>(context, listen: false).clearAll();
        Provider.of<PlaneProvider>(context, listen: false).clearAll();
      }

      setState(() {
        _previousModeIndex = _selectedModeIndex;
        _selectedModeIndex = mode;
      });

      int mapCategory = mode > 0 ? mode - 1 : -1;
      Provider.of<MapStateProvider>(context, listen: false)
          .setCategory(mapCategory);
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

  // --- HELPER DI STILE ---

  Color _getAccentColor(int index) {
    switch (index) {
      case 1:
        return Colors.orangeAccent;
      case 2:
        return Colors.tealAccent;
      case 3:
        return Colors.blueAccent;
      case 4:
        return Colors.greenAccent;
      default:
        return const Color(0xFF00E5FF);
    }
  }

  Future<void> _refresh() async {
    try {
      // Aggiorna TUTTI i provider
      final trainProvider = Provider.of<TrainProvider>(context, listen: false);
      final busProvider = Provider.of<BusProvider>(context, listen: false);
      final planeProvider = Provider.of<PlaneProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final favoritesProvider =
          Provider.of<FavoritesProvider>(context, listen: false);

      // Ricarica i dati
      trainProvider.clearAll();
      busProvider.clearAll();
      planeProvider.clearAll();

      // Ricarica i provider bus
      busProvider.loadProviders();

      // Ricarica i favoriti se autenticato
      if (authProvider.isAuthenticated) {
        final userId = authProvider.currentUser!.id.toString();
        favoritesProvider.loadFavorites(userId);
      }

      // Aggiungi un piccolo delay per evitare refresh troppo veloce
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Errore durante il refresh: $e');
    }
  }

  // --- WIDGETS BUILDER ---

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final configProvider = Provider.of<ConfigProvider>(context);
    final busProvider = Provider.of<BusProvider>(context);
    final accentColor = _getAccentColor(_selectedModeIndex);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: theme.backgroundColor,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: Stack(
          children: [
            // 1. BACKGROUND / PANELS CON TRANSIZIONE MODERNA
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutExpo,
                switchOutCurve: Curves.easeInExpo,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _selectedModeIndex == 0
                    ? DashboardFeed(
                        key: const ValueKey('Dashboard'),
                        onOpenMap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    const MapScreen(initialCategory: -1))))
                    : _buildTransportPanel(_selectedModeIndex, theme),
              ),
            ),

            // 2. TOP HEADER (Logo + Actions)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLogoWidget(theme),
                      _buildTopActionIcons(theme),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCirc,
                    child: (_selectedModeIndex > 0 && _searchExpanded)
                        ? Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _buildSearchBar(theme, accentColor, busProvider),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
            ),

            // 3. BUS STOP BANNER (Se presente)
            if (_selectedModeIndex == 2 && busProvider.selectedStop != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                top: MediaQuery.of(context).padding.top +
                    140 +
                    (_searchExpanded ? 60 : 0),
                left: 16,
                right: 16,
                child: _buildSelectedStopBanner(busProvider, theme),
              ),

            if (configProvider.isLoading)
              const Center(child: CircularProgressIndicator()),

            // 4. FLOATING BOTTOM DOCK
            _buildBottomDock(theme, accentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoWidget(ThemeProvider theme) {
    return GlassmorphicContainer(
      width: 145,
      height: 52,
      borderRadius: 16,
      blur: 20,
      alignment: Alignment.center,
      border: 1.5,
      linearGradient: LinearGradient(colors: [
        theme.surfaceColor.withOpacity(0.7),
        theme.surfaceColor.withOpacity(0.4)
      ]),
      borderGradient: LinearGradient(colors: [
        theme.textColor.withOpacity(0.1),
        theme.textColor.withOpacity(0.05)
      ]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFF43AA8B)])
                  .createShader(bounds),
              child: Text('BC',
                  style: GoogleFonts.syne(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            GestureDetector(
              onTap: _showLogoMenuSheet,
              child: Row(
                children: [
                  Text('.',
                      style: GoogleFonts.syne(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF3b82f6))),
                  Text('T',
                      style: GoogleFonts.syne(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: theme.textColor)),
                ],
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _searchExpanded = !_searchExpanded),
              child: Icon(
                  _searchExpanded
                      ? Icons.unfold_less_rounded
                      : Icons.unfold_more_rounded,
                  size: 18,
                  color: theme.secondaryTextColor),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionIcons(ThemeProvider theme) {
    return Row(
      children: [
        _buildCircleAction(
            Icons.star_rounded,
            () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FavoritesPage())),
            theme),
        const SizedBox(width: 8),
        _buildNotificationButton(theme),
        const SizedBox(width: 8),
        _buildUserAvatar(theme),
      ],
    );
  }

  Widget _buildCircleAction(
      IconData icon, VoidCallback onTap, ThemeProvider theme) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: theme.surfaceColor.withOpacity(0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
            ),
            child: Icon(icon, size: 22, color: theme.textColor),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationButton(ThemeProvider theme) {
    return FutureBuilder<int>(
      future: _getMonitoredCount(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _buildCircleAction(
                Icons.notifications_none_rounded,
                () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationsManagerScreen())),
                theme),
            if (count > 0)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.redAccent, shape: BoxShape.circle),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text('$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUserAvatar(ThemeProvider theme) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) => GestureDetector(
        onTap: () => auth.isAuthenticated
            ? Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const DashboardPage()))
            : Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const LoginPage())),
        onLongPress: () => _showAccountOverlay(auth),
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF3b82f6)]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3b82f6).withOpacity(0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                )
              ]),
          child: CircleAvatar(
              radius: 19,
              backgroundColor: theme.surfaceColor,
              child: Icon(Icons.person_outline_rounded,
                  size: 20, color: theme.textColor)),
        ),
      ),
    );
  }

  Widget _buildSearchBar(
      ThemeProvider theme, Color accentColor, BusProvider busProvider) {
    return Column(
      children: [
        GlassmorphicContainer(
          width: double.infinity,
          height: 56,
          borderRadius: 18,
          blur: 20,
          alignment: Alignment.center,
          border: 1.5,
          linearGradient: LinearGradient(colors: [
            theme.surfaceColor.withOpacity(0.8),
            theme.surfaceColor.withOpacity(0.6)
          ]),
          borderGradient: LinearGradient(colors: [
            accentColor.withOpacity(0.4),
            accentColor.withOpacity(0.1)
          ]),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                if (_selectedModeIndex == 1)
                  IconButton(
                    icon: Icon(
                        _searchByNumber ? Icons.tag : Icons.location_on_rounded,
                        color: accentColor),
                    onPressed: () =>
                        setState(() => _searchByNumber = !_searchByNumber),
                  )
                else
                  Icon(Icons.search_rounded, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: _onSearch,
                    style: TextStyle(color: theme.textColor, fontSize: 15),
                    decoration: InputDecoration(
                        hintText: _getSearchHint(),
                        hintStyle: TextStyle(
                            color: theme.secondaryTextColor.withOpacity(0.5),
                            fontSize: 14),
                        border: InputBorder.none),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: theme.secondaryTextColor),
                      onPressed: () => _searchController.clear()),
              ],
            ),
          ),
        ),
        if (_showStopDropdown && _selectedModeIndex == 2)
          _buildBusDropdown(theme, busProvider),
      ],
    );
  }

  Widget _buildBusDropdown(ThemeProvider theme, BusProvider busProvider) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
          color: theme.surfaceColor.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)]),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: busProvider.stopSearchResults.length.clamp(0, 5),
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: theme.textColor.withOpacity(0.05)),
        itemBuilder: (context, i) {
          final stop = busProvider.stopSearchResults[i];
          return ListTile(
            dense: true,
            title: Text(stop.stopName,
                style: TextStyle(
                    color: theme.textColor, fontWeight: FontWeight.w500)),
            subtitle: Text('ID: ${stop.stopId}',
                style:
                    TextStyle(color: theme.secondaryTextColor, fontSize: 11)),
            onTap: () {
              Provider.of<MapStateProvider>(context, listen: false)
                  .flyTo(stop.latitude, stop.longitude, zoom: 16.0);
              _searchController.clear();
              setState(() => _showStopDropdown = false);
              busProvider.clearStopSearch();
            },
          );
        },
      ),
    );
  }

  static const List<IconData> _dockIcons = [
    Icons.grid_view_rounded,
    Icons.train_rounded,
    Icons.directions_bus_rounded,
    Icons.flight_takeoff_rounded,
    Icons.route,
  ];

  void _handleDockDrag(double localDx) {
    if (_dockSegmentWidth <= 0) return;
    final maxLeft = _dockSegmentWidth * (_dockIcons.length - 1);
    final rawLeft = (localDx - _dockSegmentWidth / 2)
        .clamp(0.0, maxLeft);
    final index =
        (localDx / _dockSegmentWidth).floor().clamp(0, _dockIcons.length - 1);

    setState(() {
      _isDockDragging = true;
      _dockDragX = rawLeft;
    });

    if (index != _selectedModeIndex) {
      _setMode(index);
    }
  }

  void _endDockDrag() {
    setState(() {
      _isDockDragging = false;
      _dockDragX = null;
    });
  }

  Widget _buildBottomDock(ThemeProvider theme, Color accentColor) {
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: SizedBox(
          width: 300, // LARGHEZZA FISSA: capsula ristretta
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.black.withOpacity(0.35),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.14), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 8)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0.5,
                      left: 18,
                      right: 18,
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.35),
                            Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _dockSegmentWidth =
                                  constraints.maxWidth / _dockIcons.length;
                              final indicatorLeft = _isDockDragging &&
                                      _dockDragX != null
                                  ? _dockDragX!
                                  : _dockSegmentWidth * _selectedModeIndex;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanDown: (d) =>
                                    _handleDockDrag(d.localPosition.dx),
                                onPanUpdate: (d) =>
                                    _handleDockDrag(d.localPosition.dx),
                                onPanEnd: (_) => _endDockDrag(),
                                onPanCancel: _endDockDrag,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Row(
                                      children: List.generate(
                                        _dockIcons.length,
                                        (i) => Expanded(
                                          child: _buildDockIcon(
                                              _dockIcons[i], i, theme),
                                        ),
                                      ),
                                    ),
                                    AnimatedPositioned(
                                      duration: _isDockDragging
                                          ? Duration.zero
                                          : const Duration(milliseconds: 280),
                                      curve: Curves.easeOutBack,
                                      left: indicatorLeft,
                                      top: 6,
                                      child: SizedBox(
                                        width: _dockSegmentWidth,
                                        height: 44,
                                        child: Center(
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            curve: Curves.easeOut,
                                            width: 34,
                                            height: 34,
                                            clipBehavior: Clip.antiAlias,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(17),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withOpacity(0.22),
                                                  Colors.white.withOpacity(0.10),
                                                  Colors.white.withOpacity(0.03),
                                                ],
                                                stops: const [0.0, 0.5, 1.0],
                                              ),
                                              border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.55),
                                                  width: 1),
                                              boxShadow: [
                                                BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.25),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3)),
                                                BoxShadow(
                                                    color: Colors.white
                                                        .withOpacity(0.15),
                                                    blurRadius: 4,
                                                    spreadRadius: -2,
                                                    offset: const Offset(0, -1)),
                                              ],
                                            ),
                                            child: Stack(
                                              children: [
                                                Positioned(
                                                  top: 3,
                                                  left: 6,
                                                  right: 6,
                                                  child: Container(
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.white
                                                              .withOpacity(0.0),
                                                          Colors.white
                                                              .withOpacity(0.55),
                                                          Colors.white
                                                              .withOpacity(0.0),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
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
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          color: Colors.white.withOpacity(0.14),
                        ),
                        _buildActionDockIcon(
                            Icons.settings_suggest_rounded, _openSettings),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDockIcon(IconData icon, int index, ThemeProvider theme) {
    bool isSelected = _selectedModeIndex == index;
    Color color = isSelected
        ? Colors.white
        : Colors.white.withOpacity(0.55);
    return GestureDetector(
      onTap: () => _setMode(index),
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: AnimatedScale(
          scale: isSelected ? 1.05 : 1.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Icon(icon, color: color, size: 22),
        ),
      ),
    );
  }

  Widget _buildActionDockIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 56,
        child: Center(
          child: Icon(icon, color: Colors.white.withOpacity(0.55), size: 22),
        ),
      ),
    );
  }

  Widget _buildTransportPanel(int mode, ThemeProvider theme) {
    return Container(
      key: ValueKey('Panel_$mode'),
      color: theme.backgroundColor,
      padding: EdgeInsets.only(top: _searchExpanded ? 140 : 80),
      child: mode == 1
          ? const TrainSearchScreen()
          : mode == 2
              ? const BusSearchScreen()
              : mode == 3
                  ? const PlaneSearchScreen()
                  : const RoadwaysPage(),
    );
  }

  Widget _buildSelectedStopBanner(
      BusProvider busProvider, ThemeProvider theme) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 70,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(colors: [
        theme.surfaceColor.withOpacity(0.9),
        theme.surfaceColor.withOpacity(0.8)
      ]),
      borderGradient: LinearGradient(colors: [
        theme.primaryColor.withOpacity(0.5),
        theme.primaryColor.withOpacity(0.1)
      ]),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            CircleAvatar(
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                child: Icon(Icons.location_on, color: theme.primaryColor)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      AppLocalizations.of(context)?.selectedStop ??
                          "Fermata Selezionata",
                      style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                  Text(
                      busProvider.selectedStop?.stopName ??
                          AppLocalizations.of(context)?.stop ??
                          "Fermata",
                      style: TextStyle(
                          color: theme.textColor, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                busProvider.clearStopSelection();
                busProvider.savedStopSearchQuery.isNotEmpty
                    ? _setMode(2)
                    : _setMode(0);
              },
              style: TextButton.styleFrom(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Text(AppLocalizations.of(context)?.close ?? "Chiudi",
                  style: TextStyle(
                      color: theme.primaryColor, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  String _getSearchHint() {
    final loc = AppLocalizations.of(context);
    switch (_selectedModeIndex) {
      case 1:
        return _searchByNumber
            ? (loc?.searchTrainNumberHint ?? "Numero Treno (es: 9610)")
            : (loc?.searchStationHint ?? "Stazione (es: Roma Termini)");
      case 2:
        return loc?.searchBusStopHint ?? "Cerca fermata bus...";
      case 3:
        return loc?.searchAirportHint ?? "Cerca volo o aeroporto...";
      default:
        return loc?.searchDestinationHint ?? "Cerca destinazione...";
    }
  }

  // --- MODALS ---

  void _showLogoMenuSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        final theme = Provider.of<ThemeProvider>(ctx, listen: false);
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(
                color: theme.backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, -5))
                ]
            ),
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                Center(
                    child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                            color: theme.secondaryTextColor.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 24),
                Text(AppLocalizations.of(ctx)?.quickActions ?? "Azioni Rapide",
                    style: GoogleFonts.syne(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: theme.textColor)),
                const SizedBox(height: 16),
                _buildModalTile(
                  Icons.map_rounded,
                  AppLocalizations.of(ctx)?.mapStyle ?? "Stile Mappa",
                  AppLocalizations.of(ctx)?.mapStyleDesc ??
                    "Cambia l'aspetto della cartina",
                  theme,
                  () {}),
                _buildModalTile(
                    Icons.star_rounded,
                    AppLocalizations.of(ctx)?.favorites ?? "Preferiti",
                    AppLocalizations.of(ctx)?.favoritesDesc ??
                        "I tuoi treni e bus salvati",
                    theme, () {
                  Navigator.pop(ctx);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const FavoritesPage()));
                }),
                _buildModalTile(
                    Icons.notifications_active_rounded,
                    AppLocalizations.of(ctx)?.notifications ?? "Notifiche",
                    AppLocalizations.of(ctx)?.notificationsDesc ??
                        "Gestisci i monitoraggi",
                    theme, () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationsManagerScreen()));
                }),
                _buildModalTile(
                    Icons.settings_rounded,
                    AppLocalizations.of(ctx)?.settingsTitle ?? "Impostazioni",
                    AppLocalizations.of(ctx)?.settingsDesc ??
                        "Configura l'applicazione",
                    theme, () {
                  Navigator.pop(ctx);
                  _openSettings();
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalTile(IconData icon, String title, String sub,
      ThemeProvider theme, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: theme.primaryColor),
      title: Text(title,
          style:
              TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
      subtitle: Text(sub,
          style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
      onTap: onTap,
    );
  }

  void _showAccountOverlay(AuthProvider authProvider) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final user = authProvider.currentUser;
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
                radius: 35,
                backgroundColor: theme.primaryColor,
                child: Text(user?.nickname?[0].toUpperCase() ?? "?",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold))),
            const SizedBox(height: 16),
            Text(user?.nickname ?? AppLocalizations.of(ctx)?.user ?? "Utente",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textColor)),
            Text(user?.email ?? "",
                style: TextStyle(color: theme.secondaryTextColor)),
            const Divider(height: 32),
            ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: Text(AppLocalizations.of(ctx)?.logout ?? "Logout"),
                onTap: () {
                  Navigator.pop(ctx);
                  authProvider.logout();
                }),
          ],
        ),
      ),
    );
  }
}
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../core/services/runtime_localizations.dart';
import '../../core/services/weather_service.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_page.dart';
import '../providers/theme_provider.dart';
import '../../features/favorites/providers/favorites_provider.dart';
import '../../features/favorites/screens/favorites_page.dart';

// ─────────────────────────────────────────────────────────────
//  DashboardFeed
// ─────────────────────────────────────────────────────────────

class DashboardFeed extends StatefulWidget {
  final VoidCallback onOpenMap;

  const DashboardFeed({
    super.key,
    required this.onOpenMap,
  });

  @override
  State<DashboardFeed> createState() => _DashboardFeedState();
}

class _DashboardFeedState extends State<DashboardFeed>
    with SingleTickerProviderStateMixin {
  WeatherData? _weather;
  bool _weatherLoading = true;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    if (mounted) setState(() => _weatherLoading = true);
    final data = await WeatherService.fetchCurrentWeather();
    if (mounted) setState(() { _weather = data; _weatherLoading = false; });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buongiorno';
    if (hour < 18) return 'Buon pomeriggio';
    return 'Buonasera';
  }

  // ── apre il bottom sheet per selezionare la città ──
  Future<void> _openCityPicker() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final selected = await showModalBottomSheet<CityResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CityPickerSheet(theme: theme),
    );
    if (selected == null) return;

    if (selected.id == -1) {
      // Sentinel GPS: usa le coordinate già rilevate, non salvare come città fissa
      await CityResult.clearSaved();
      if (mounted) setState(() => _weatherLoading = true);
      final data = await WeatherService.fetchWeatherForCoords(
        lat: selected.latitude,
        lon: selected.longitude,
        cityName: 'La tua posizione',
      );
      if (mounted) setState(() { _weather = data; _weatherLoading = false; });
    } else {
      await selected.save();
      _loadWeather();
    }
  }

  // ── reset a GPS / posizione automatica ──
  Future<void> _resetToGps() async {
    await CityResult.clearSaved();
    _loadWeather();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final userName = (user?.nickname != null)
        ? user!.nickname!
        : (user?.email != null ? user!.email.split('@')[0] : 'Ospite');
    final isDark = theme.resolvedThemeMode == ThemeMode.dark;

    return Container(
      color: theme.backgroundColor,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 76)),

          // ── 1. HEADER ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: theme.secondaryTextColor,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark
                                ? [Colors.white, Colors.white70]
                                : [const Color(0xFF1A1A2E), theme.primaryColor],
                          ).createShader(bounds),
                          child: Text(
                            authProvider.isAuthenticated ? userName : RuntimeLocalizations.t(context, 'guest'),
                            style: GoogleFonts.syne(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [theme.primaryColor, theme.primaryColor.withValues(alpha: 0.6)],
                      ),
                      boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: Center(
                      child: Text(
                        authProvider.isAuthenticated ? userName.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── 2. WEATHER CARD ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: _weatherLoading
                  ? _buildWeatherSkeleton(theme)
                  : _weather == null
                      ? _buildWeatherError(theme)
                      : _buildWeatherCard(theme),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 28)),

          // ── 3. QUICK ACTIONS ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Azioni rapide',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.secondaryTextColor, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickAction(Icons.map_rounded, 'Mappa', theme, widget.onOpenMap, color: const Color(0xFF4361EE)),
                      _buildQuickAction(Icons.confirmation_num_rounded, 'Ticket', theme, () {}, color: const Color(0xFF3A0CA3)),
                      _buildQuickAction(Icons.alt_route_rounded, 'Percorsi', theme, () {}, color: const Color(0xFF7209B7)),
                      _buildQuickAction(Icons.campaign_rounded, 'Avvisi', theme, () {}, color: const Color(0xFFF72585)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── 4. HERO MAP CARD ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: GestureDetector(
                onTap: widget.onOpenMap,
                child: Container(
                  height: 185,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: theme.primaryColor.withValues(alpha: 0.35), blurRadius: 28, offset: const Offset(0, 14))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF4361EE), Color(0xFF3A0CA3)],
                            ),
                          ),
                        ),
                        Positioned(
                          top: -60, left: -40,
                          child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08))),
                        ),
                        Positioned(
                          bottom: -70, right: -30,
                          child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF7209B7).withValues(alpha: 0.5))),
                        ),
                        BackdropFilter(filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40), child: Container(color: Colors.transparent)),
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  AnimatedBuilder(
                                    animation: _pulseAnim,
                                    builder: (_, __) => Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.greenAccent,
                                        boxShadow: [BoxShadow(color: Colors.greenAccent.withValues(alpha: _pulseAnim.value), blurRadius: 8, spreadRadius: 2)],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                    ),
                                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(RuntimeLocalizations.t(context, 'explore_map'), style: GoogleFonts.syne(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1)),
                                        const SizedBox(height: 4),
                                        Text(RuntimeLocalizations.t(context, 'explore_map_desc'), style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 50, height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
                                    ),
                                    child: Icon(Icons.arrow_forward_rounded, color: theme.primaryColor, size: 22),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── 5. PREFERITI ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(RuntimeLocalizations.t(context, 'your_favorites'), style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textColor)),
                      if (authProvider.isAuthenticated)
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                            child: Text(RuntimeLocalizations.t(context, 'see_all'), style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildFavoritesSection(context, authProvider, theme),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),

          // ── 6. STATO SERVIZI ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(RuntimeLocalizations.t(context, 'service_status'), style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w700, color: theme.textColor)),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildStatusPill(theme, AppLocalizations.of(context)?.trains ?? 'Treni', RuntimeLocalizations.t(context, 'status_regular'), Icons.train_rounded, const Color(0xFF43AA8B)),
                        const SizedBox(width: 10),
                        _buildStatusPill(theme, AppLocalizations.of(context)?.buses ?? 'Bus', RuntimeLocalizations.t(context, 'status_delays'), Icons.directions_bus_rounded, const Color(0xFFFF9F1C)),
                        const SizedBox(width: 10),
                        _buildStatusPill(theme, 'Aerei', 'Regolare', Icons.flight_takeoff_rounded, const Color(0xFF43AA8B)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  WEATHER CARD
  // ─────────────────────────────────────────────────────────

  Widget _buildWeatherCard(ThemeProvider theme) {
    final w = _weather!;
    final gradColors = w.gradientColors.map((c) => Color(c)).toList();

    return GestureDetector(
      onTap: _openCityPicker,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradColors,
          ),
          boxShadow: [BoxShadow(color: gradColors.first.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Decorazioni blob
              Positioned(
                top: -40, right: -20,
                child: Container(width: 160, height: 160, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1))),
              ),
              Positioned(
                bottom: -50, left: 60,
                child: Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07))),
              ),
              // Contenuto
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Riga superiore: OGGI badge + città + cambia
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Text('OGGI', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.location_on_rounded, color: Colors.white.withValues(alpha: 0.85), size: 13),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  w.cityName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Tasto "Cambia città"
                        GestureDetector(
                          onTap: _openCityPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.edit_location_alt_rounded, color: Colors.white, size: 12),
                                SizedBox(width: 4),
                                Text('Cambia', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Riga inferiore: condizione + dati + temp + emoji
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                w.condition,
                                style: GoogleFonts.syne(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white, height: 1.1),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _weatherPill(Icons.air_rounded, '${w.windspeed.toStringAsFixed(0)} km/h'),
                                  if (w.precipitationProbability != null) ...[
                                    const SizedBox(width: 8),
                                    _weatherPill(Icons.water_drop_rounded, '${w.precipitationProbability!.toStringAsFixed(0)}%'),
                                  ],
                                  const SizedBox(width: 8),
                                  // Reset a GPS
                                  GestureDetector(
                                    onTap: _resetToGps,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(w.icon, style: const TextStyle(fontSize: 36)),
                            Text(
                              '${w.temperature.toStringAsFixed(0)}°',
                              style: GoogleFonts.syne(fontSize: 30, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weatherPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildWeatherSkeleton(ThemeProvider theme) {
    return Container(
      height: 180,
      decoration: BoxDecoration(color: theme.surfaceColor, borderRadius: BorderRadius.circular(28)),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _buildWeatherError(ThemeProvider theme) {
    return Container(
      height: 80,
      decoration: BoxDecoration(color: theme.surfaceColor, borderRadius: BorderRadius.circular(28), border: Border.all(color: theme.textColor.withValues(alpha: 0.06))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, color: theme.secondaryTextColor),
          const SizedBox(width: 10),
          Text('Meteo non disponibile', style: TextStyle(color: theme.secondaryTextColor)),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () { setState(() => _weatherLoading = true); _loadWeather(); },
            child: Icon(Icons.refresh_rounded, color: theme.primaryColor, size: 20),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  QUICK ACTIONS
  // ─────────────────────────────────────────────────────────

  Widget _buildQuickAction(IconData icon, String label, ThemeProvider theme, VoidCallback onTap, {required Color color}) {
    return _TapScaleButton(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  PREFERITI
  // ─────────────────────────────────────────────────────────

  Widget _buildFavoritesSection(BuildContext context, AuthProvider auth, ThemeProvider theme) {
    if (!auth.isAuthenticated) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22.0),
        child: GlassmorphicContainer(
          width: double.infinity, height: 140, borderRadius: 24, blur: 15,
          alignment: Alignment.center, border: 1,
          linearGradient: LinearGradient(colors: [theme.surfaceColor.withValues(alpha: 0.6), theme.surfaceColor.withValues(alpha: 0.2)]),
          borderGradient: LinearGradient(colors: [theme.textColor.withValues(alpha: 0.08), Colors.transparent]),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.lock_outline_rounded, color: theme.primaryColor, size: 26)),
              const SizedBox(height: 10),
              Text(RuntimeLocalizations.t(context, 'login_to_see_favorites'), style: TextStyle(color: theme.secondaryTextColor, fontSize: 13)),
              const SizedBox(height: 14),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), elevation: 0),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                child: Text(RuntimeLocalizations.t(context, 'login'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: Consumer<FavoritesProvider>(
        builder: (context, favorites, _) {
          final items = favorites.favoriteStops.take(5).toList();
          if (items.isEmpty) {
            return Center(child: Text(RuntimeLocalizations.t(context, 'no_favorites_saved'), style: TextStyle(color: theme.secondaryTextColor)));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final isBus = item.stopType.name == 'busStop';
              final color = isBus ? const Color(0xFF43AA8B) : const Color(0xFF4361EE);
              return Container(
                width: 230,
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, color.withValues(alpha: 0.4)]),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)), child: Icon(isBus ? Icons.directions_bus_rounded : Icons.train_rounded, color: color, size: 12)),
                                const SizedBox(width: 6),
                                Text(isBus ? 'Fermata Bus' : 'Stazione', style: TextStyle(color: theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const Spacer(),
                            Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textColor)),
                            Text(item.country ?? 'Locale', style: TextStyle(fontSize: 12, color: theme.secondaryTextColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  //  STATUS PILLS
  // ─────────────────────────────────────────────────────────

  Widget _buildStatusPill(ThemeProvider theme, String title, String status, IconData icon, Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.textColor.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(icon, color: statusColor, size: 15)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: theme.secondaryTextColor, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 1),
              Row(
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(status, style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  CITY PICKER BOTTOM SHEET
// ─────────────────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final ThemeProvider theme;
  const _CityPickerSheet({required this.theme});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<CityResult> _results = [];
  bool _searching = false;
  bool _gpsLoading = false;
  Timer? _debounce;

  ThemeProvider get theme => widget.theme;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _results = []; _searching = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final res = await GeocodingService.searchCity(q);
      if (mounted) setState(() { _results = res; _searching = false; });
    });
  }

  Future<void> _useGpsLocation() async {
    setState(() => _gpsLoading = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _gpsLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Permesso posizione negato. Abilitalo nelle impostazioni.'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      if (mounted) {
        // id = -1 è il sentinel che dice al parent di usare GPS
        Navigator.pop(context, CityResult(
          id: -1,
          name: 'La tua posizione',
          latitude: pos.latitude,
          longitude: pos.longitude,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _gpsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Impossibile rilevare la posizione GPS'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = theme.resolvedThemeMode == ThemeMode.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      snap: true,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 40, offset: const Offset(0, -8))],
        ),
        child: Column(
          children: [
            // ── Handle ──
            const SizedBox(height: 12),
            Container(
              width: 44, height: 5,
              decoration: BoxDecoration(color: theme.secondaryTextColor.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(height: 20),

            // ── Titolo ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFF4361EE).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.location_city_rounded, color: Color(0xFF4361EE), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Seleziona città', style: GoogleFonts.syne(fontSize: 20, fontWeight: FontWeight.w800, color: theme.textColor)),
                        Text('Cerca la tua città per il meteo', style: TextStyle(fontSize: 13, color: theme.secondaryTextColor)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: theme.secondaryTextColor),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.surfaceColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: theme.textColor.withValues(alpha: 0.07)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12)],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: theme.textColor, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'es. Milano, Parigi, London…',
                    hintStyle: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
                    prefixIcon: Icon(Icons.search_rounded, color: theme.secondaryTextColor),
                    suffixIcon: _searching
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor)),
                          )
                        : _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: theme.secondaryTextColor, size: 20),
                                onPressed: () { _searchCtrl.clear(); _onSearchChanged(''); },
                              )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Tile GPS (sempre visibile) ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _TapScaleButton(
                onTap: _gpsLoading ? () {} : _useGpsLocation,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF43AA8B), Color(0xFF2D6A4F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF43AA8B).withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _gpsLoading
                            ? const Padding(
                                padding: EdgeInsets.all(11),
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Usa la mia posizione', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                            Text(
                              _gpsLoading ? 'Rilevamento in corso…' : 'Rileva automaticamente via GPS',
                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Divider con label ──
            if (_results.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: theme.textColor.withValues(alpha: 0.08))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('Risultati ricerca', style: TextStyle(fontSize: 11, color: theme.secondaryTextColor, fontWeight: FontWeight.w600)),
                    ),
                    Expanded(child: Divider(color: theme.textColor.withValues(alpha: 0.08))),
                  ],
                ),
              ),

            if (_results.isNotEmpty) const SizedBox(height: 10),

            // ── Lista risultati ──
            Expanded(
              child: _results.isEmpty && !_searching
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _results.length,
                      itemBuilder: (_, i) => _buildCityTile(_results[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasQuery = _searchCtrl.text.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hasQuery ? '🔍' : '🌍', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text(
            hasQuery ? 'Nessuna città trovata' : 'Inizia a digitare il nome\ndella città',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCityTile(CityResult city) {
    return _TapScaleButton(
      onTap: () => Navigator.pop(context, city),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.textColor.withValues(alpha: 0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF4361EE).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Icon(Icons.location_on_rounded, color: Color(0xFF4361EE), size: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(city.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.textColor)),
                  if (city.region != null || city.country != null)
                    Text(
                      [if (city.region != null) city.region!, if (city.country != null) city.country!].join(', '),
                      style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor.withValues(alpha: 0.5), size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper: bottone con animazione di scala al tap
// ─────────────────────────────────────────────────────────────

class _TapScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _TapScaleButton({required this.child, required this.onTap});

  @override
  State<_TapScaleButton> createState() => _TapScaleButtonState();
}

class _TapScaleButtonState extends State<_TapScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 100), reverseDuration: const Duration(milliseconds: 150));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.88).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}
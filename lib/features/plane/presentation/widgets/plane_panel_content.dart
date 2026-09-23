import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import '../../data/models/plane_model.dart';
import '../providers/plane_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../../../core/design_system.dart';
import '../../../../core/responsive.dart';
import 'flight_details_sheet.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';

class PlanePanelContent extends StatefulWidget {
  final VoidCallback onRefresh;

  const PlanePanelContent({super.key, required this.onRefresh});

  @override
  State<PlanePanelContent> createState() => _PlanePanelContentState();
}

class _PlanePanelContentState extends State<PlanePanelContent> {
  final TextEditingController _airportController = TextEditingController();
  bool _showSkyscanner = false;

  @override
  void dispose() {
    _airportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final planeProvider = Provider.of<PlaneProvider>(context);
    final mapState = Provider.of<MapStateProvider>(context, listen: false);
    final theme = Provider.of<ThemeProvider>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. HEADER & MODE SELECTOR
        _buildHeader(theme, planeProvider),

        // 2. CONTENT AREA
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _showSkyscanner
                ? _buildAirportSearch(theme, planeProvider, mapState)
                : _buildRealtimeFlights(theme, planeProvider, mapState),
          ),
        ),
      ],
    );
  }

  // --- UI COMPONENTS ---

  bool _isLandscape(BuildContext context) =>
      MediaQuery.of(context).orientation == Orientation.landscape;

  Widget _buildHeader(ThemeProvider theme, PlaneProvider provider) {
    // Solo layout: in landscape header più compatto ed evita overflow
    // su larghezze ridotte in altezza.
    final isLandscape = _isLandscape(context);
    return Container(
      padding: EdgeInsets.all(isLandscape ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTokens.radius3Xl)),
        boxShadow: theme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(AppLocalizations.of(context)?.flightRadar ?? "Radar Voli",
                    style: TextStyle(
                        color: theme.textColor,
                        fontSize: isLandscape ? 20 : 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 12),
              Flexible(child: _buildModernToggle(theme)),
            ],
          ),
          if (_showSkyscanner) ...[
            SizedBox(height: isLandscape ? 10 : 16),
            _buildSearchField(theme, provider),
          ]
        ],
      ),
    );
  }

  Widget _buildModernToggle(ThemeProvider theme) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          _buildToggleItem(
              AppLocalizations.of(context)?.airports ?? "AEROPORTI",
              _showSkyscanner,
              theme,
              () => setState(() => _showSkyscanner = true)),
          _buildToggleItem("LIVE", !_showSkyscanner, theme,
              () => setState(() => _showSkyscanner = false)),
        ],
      ),
    );
  }

  Widget _buildToggleItem(
      String label, bool active, ThemeProvider theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: active
              ? [
                  BoxShadow(
                      color: theme.primaryColor.withOpacity(0.4), blurRadius: 8)
                ]
              : [],
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.white : theme.secondaryTextColor,
                fontSize: 10,
                fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildSearchField(ThemeProvider theme, PlaneProvider provider) {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 50,
      borderRadius: 15,
      blur: 10,
      alignment: Alignment.center,
      border: 1,
      linearGradient: LinearGradient(colors: [
        theme.surfaceColor.withOpacity(0.5),
        theme.surfaceColor.withOpacity(0.2)
      ]),
      borderGradient: LinearGradient(
          colors: [theme.primaryColor.withOpacity(0.2), Colors.transparent]),
      child: TextField(
        controller: _airportController,
        style: TextStyle(color: theme.textColor),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)?.searchAirportIcaoHint ??
              "Cerca aeroporto (ICAO/IATA)...",
          hintStyle:
              TextStyle(color: theme.secondaryTextColor.withOpacity(0.5)),
          prefixIcon:
              Icon(Icons.flight_takeoff_rounded, color: theme.primaryColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onSubmitted: (val) {
          if (val.isNotEmpty) provider.searchAirports(val);
        },
      ),
    );
  }

  Widget _buildRealtimeFlights(
      ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    if (provider.flights.isEmpty) {      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.airplanemode_active_rounded,
                size: 64, color: theme.secondaryTextColor.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text(
                AppLocalizations.of(context)?.noFlightsInRadar ??
                    "Nessun volo nel raggio radar",
                style: TextStyle(color: theme.secondaryTextColor)),
          ],
        ),
      );
    }

    // Solo layout: in landscape due colonne per sfruttare la larghezza.
    final isLandscape = _isLandscape(context);
    if (isLandscape) {
      return GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 0,
          childAspectRatio: 1.6,
        ),
        itemCount: provider.flights.length,
        itemBuilder: (context, index) {
          final f = provider.flights[index];
          return _buildFlightCard(f, theme, provider, mapState);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: provider.flights.length,
      itemBuilder: (context, index) {
        final f = provider.flights[index];
        return _buildFlightCard(f, theme, provider, mapState);
      },
    );
  }

  Widget _buildFlightCard(dynamic f, ThemeProvider theme,
      PlaneProvider provider, MapStateProvider mapState) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space12),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.08)),
        boxShadow: theme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (f.latitude != null && f.longitude != null) {
              mapState.flyTo(f.latitude!, f.longitude!, zoom: 10);
            }
            provider.selectFlight(f);
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FlightDetailsSheet(flight: f)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.airplanemode_active_rounded,
                          color: theme.primaryColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.callsign ?? "UNKNOWN",
                              style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                  letterSpacing: 1)),
                          Text(
                              "${f.origin ?? '???'} ➔ ${f.destination ?? '???'}",
                              style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    _buildInstrumentTag("${(f.speed ?? 0).toInt()} km/h",
                        Icons.speed, Colors.orange, theme),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTechInfo(
                        "ALTITUDINE", "${(f.altitude ?? 0).toInt()} ft", theme),
                    _buildTechInfo(
                        "ROTTA", "${(f.heading ?? 0).toInt()}°", theme),
                    _buildTechInfo("SQUAWK", f.squawk ?? "----", theme),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstrumentTag(
      String label, IconData icon, Color color, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildTechInfo(String title, String value, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 9,
                fontWeight: FontWeight.w800)),
        Text(value,
            style: TextStyle(
                color: theme.textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAirportSearch(
      ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    // Solo layout: in landscape affianca card aeroporto e toggle partenze/arrivi.
    final isLandscape = _isLandscape(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(16, isLandscape ? 12 : 16, 16, 100),
      children: [
        if (provider.selectedAirport != null && isLandscape) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildSelectedAirportCard(theme, provider, mapState),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildArrivalDepartureToggle(theme, provider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Flights section
          _buildAirportFlightsSection(theme, provider, mapState),
          const SizedBox(height: 24),
        ],
        if (provider.selectedAirport != null && !isLandscape) ...[
          // Selected airport card
          _buildSelectedAirportCard(theme, provider, mapState),
          const SizedBox(height: 16),
          // Arrival/Departure toggle
          _buildArrivalDepartureToggle(theme, provider),
          const SizedBox(height: 16),
          // Flights section
          _buildAirportFlightsSection(theme, provider, mapState),
          const SizedBox(height: 24),
        ],
        // Nearby airports
        _buildNearbyAirportsSection(theme, provider, mapState),
      ],
    );
  }

  Widget _buildSelectedAirportCard(
      ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    final airport = provider.selectedAirport!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTokens.brandBlue.withValues(alpha: theme.isDark ? 0.3 : 0.15),
            AppTokens.brandPurple.withValues(alpha: theme.isDark ? 0.2 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        border: Border.all(color: AppTokens.brandBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
                child: const Icon(Icons.flight_takeoff_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      airport.iata.isNotEmpty ? airport.iata : '---',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      airport.name ?? RuntimeLocalizations.t(context, 'airport') ?? 'Aeroporto',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (airport.city.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        airport.city,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyAirportsSection(
      ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    // Solo layout: in landscape griglia a due colonne più densa.
    final isLandscape = _isLandscape(context);
    final cards = provider.airportSuggestions
        .map((a) => _buildAirportCard(a, theme, mapState))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.near_me_rounded, size: 16, color: theme.secondaryTextColor),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)?.nearbyAirports ?? RuntimeLocalizations.t(context, 'nearby_airports') ?? "AEROPORTI VICINI",
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLandscape)
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 0,
            childAspectRatio: 3.2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: cards,
          )
        else
          ...cards,
      ],
    );
  }

  Widget _buildAirportCard(
      dynamic a, ThemeProvider theme, MapStateProvider mapState) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          onTap: () {
            final airport = a as Airport;
            Provider.of<PlaneProvider>(context, listen: false)
                .selectAirport(airport);
            if (a.lat != 0 && a.lng != 0) {
              mapState.flyTo(a.lat, a.lng, zoom: 13);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(Icons.location_city_rounded, color: AppTokens.brandBlue, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.name ?? AppLocalizations.of(context)?.airport ?? "Aeroporto",
                        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (a.iata.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a.iata,
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            a.city,
                            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor.withValues(alpha: 0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArrivalDepartureToggle(
      ThemeProvider theme, PlaneProvider provider) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => provider.setArrivalMode(false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !provider.isArrivalMode
                      ? AppTokens.brandBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  boxShadow: !provider.isArrivalMode
                      ? [BoxShadow(color: AppTokens.brandBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flight_takeoff_rounded, size: 16, color: !provider.isArrivalMode ? Colors.white : theme.secondaryTextColor),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)?.departures2 ?? RuntimeLocalizations.t(context, 'departures') ?? 'Partenze',
                        style: TextStyle(
                          color: !provider.isArrivalMode ? Colors.white : theme.secondaryTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => provider.setArrivalMode(true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: provider.isArrivalMode
                      ? AppTokens.brandBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  boxShadow: provider.isArrivalMode
                      ? [BoxShadow(color: AppTokens.brandBlue.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flight_land_rounded, size: 16, color: provider.isArrivalMode ? Colors.white : theme.secondaryTextColor),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context)?.arrivals2 ?? RuntimeLocalizations.t(context, 'arrivals') ?? 'Arrivi',
                        style: TextStyle(
                          color: provider.isArrivalMode ? Colors.white : theme.secondaryTextColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
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
  }

  Widget _buildAirportFlightsSection(
      ThemeProvider theme, PlaneProvider provider, MapStateProvider mapState) {
    if (provider.isLoadingAirports) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: CircularProgressIndicator(),
      ));
    }

    if (provider.scheduledFlights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          border: Border.all(color: theme.borderColor.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(Icons.airplanemode_inactive_rounded, size: 40, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)?.noFlightsForAirport ??
                  RuntimeLocalizations.t(context, 'no_flights_for_airport') ??
                  'Nessun volo disponibile per questo aeroporto.',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              provider.isArrivalMode ? Icons.flight_land_rounded : Icons.flight_takeoff_rounded,
              size: 14,
              color: theme.secondaryTextColor,
            ),
            const SizedBox(width: 8),
            Text(
              provider.isArrivalMode
                  ? (AppLocalizations.of(context)?.arrivals ?? RuntimeLocalizations.t(context, 'arrivals') ?? 'ARRIVI')
                  : (AppLocalizations.of(context)?.departures ?? RuntimeLocalizations.t(context, 'departures') ?? 'PARTENZE'),
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTokens.planeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              ),
              child: Text(
                '${provider.scheduledFlights.length}',
                style: TextStyle(color: AppTokens.planeColor, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Solo layout: in landscape due colonne per sfruttare la larghezza.
        if (_isLandscape(context))
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 0,
            childAspectRatio: 2.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: provider.scheduledFlights
                .map((f) =>
                    _buildScheduledFlightCard(f, theme, provider, mapState))
                .toList(),
          )
        else
          ...provider.scheduledFlights.map(
              (f) => _buildScheduledFlightCard(f, theme, provider, mapState)),
      ],
    );
  }

  Widget _buildScheduledFlightCard(Flight f, ThemeProvider theme,
      PlaneProvider provider, MapStateProvider mapState) {
    String fmt(DateTime? d) {
      if (d == null) return '--:--';
      final local = d.toLocal();
      final hh = local.hour.toString().padLeft(2, '0');
      final mm = local.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }

    final scheduled =
        provider.isArrivalMode ? f.scheduledArrival : f.scheduledDeparture;
    final estimated =
        provider.isArrivalMode ? f.estimatedArrival : f.estimatedDeparture;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          onTap: () {
            provider.selectFlight(f);
            if (f.latitude != null && f.longitude != null) {
              mapState.flyTo(f.latitude!, f.longitude!, zoom: 10);
            }
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => FlightDetailsSheet(flight: f)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Flight icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.planeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                  ),
                  child: Icon(
                    provider.isArrivalMode ? Icons.flight_land_rounded : Icons.flight_takeoff_rounded,
                    color: AppTokens.planeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                // Flight info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${f.flightNumber} • ${f.airline}',
                        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.isArrivalMode ? f.origin : f.destination,
                        style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt(scheduled),
                      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    if (estimated != null && estimated != scheduled)
                      Text(
                        RuntimeLocalizations.t(context, 'est_prefix', params: {'time': fmt(estimated)}),
                        style: TextStyle(color: theme.warningColor, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

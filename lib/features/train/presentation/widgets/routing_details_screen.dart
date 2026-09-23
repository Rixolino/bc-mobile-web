// lib/presentation/trains/widgets/routing_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bc_transporter/presentation/providers/theme_provider.dart';
import 'package:bc_transporter/presentation/providers/settings_provider.dart';
import '../providers/train_provider.dart';
import 'package:bc_transporter/core/services/runtime_localizations.dart';
import 'package:intl/intl.dart';
import 'package:glassmorphism/glassmorphism.dart';

class RoutingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> routingData;
  final int selectedSolutionIndex;

  const RoutingDetailsScreen({
    super.key,
    required this.routingData,
    this.selectedSolutionIndex = 0,
  });

  @override
  State<RoutingDetailsScreen> createState() => _RoutingDetailsScreenState();
}

class _RoutingDetailsScreenState extends State<RoutingDetailsScreen>
    with TickerProviderStateMixin { // <-- CAMBIA QUI: SingleTickerProviderStateMixin -> TickerProviderStateMixin
  late TabController _tabController;
  int _selectedSolutionIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Mappa dei fusi orari per paese
  static const Map<String, String> _timezoneMap = {
    'IT': 'Europe/Rome',
    'AT': 'Europe/Vienna',
    'CH': 'Europe/Zurich',
    'DE': 'Europe/Berlin',
    'FR': 'Europe/Paris',
    'ES': 'Europe/Madrid',
    'GB': 'Europe/London',
    'GR': 'Europe/Athens',
    'NL': 'Europe/Amsterdam',
    'BE': 'Europe/Brussels',
    'DK': 'Europe/Copenhagen',
    'NO': 'Europe/Oslo',
    'SE': 'Europe/Stockholm',
    'FI': 'Europe/Helsinki',
    'PL': 'Europe/Warsaw',
    'CZ': 'Europe/Prague',
    'HU': 'Europe/Budapest',
    'RO': 'Europe/Bucharest',
    'SI': 'Europe/Ljubljana',
    'LU': 'Europe/Luxembourg',
    'IE': 'Europe/Dublin',
    'EE': 'Europe/Tallinn',
    'LV': 'Europe/Riga',
    'LT': 'Europe/Vilnius',
    'SK': 'Europe/Bratislava',
    'HR': 'Europe/Zagreb',
    'RS': 'Europe/Belgrade',
    'BA': 'Europe/Sarajevo',
    'MK': 'Europe/Skopje',
    'AL': 'Europe/Tirane',
    'ME': 'Europe/Podgorica',
    'XK': 'Europe/Belgrade',
    'MT': 'Europe/Malta',
    'CY': 'Asia/Nicosia',
    'FAL': 'Europe/Rome',
    'EU': 'Europe/Rome',
  };

  // GETTER: restituisce le soluzioni dal routingData
  List<Map<String, dynamic>> get _solutions {
    final solutions = widget.routingData['soluzioni'] as List? ?? [];
    return solutions.map((s) => Map<String, dynamic>.from(s)).toList();
  }

  // GETTER: restituisce la soluzione corrente
  Map<String, dynamic> get _currentSolution {
    final solutions = _solutions;
    if (_selectedSolutionIndex >= solutions.length) {
      return solutions.isNotEmpty ? solutions.first : {};
    }
    return solutions[_selectedSolutionIndex];
  }

  String _getTimezoneForCountry(String countryCode) {
    if (countryCode == null || countryCode.isEmpty) return 'Europe/Rome';
    final upper = countryCode.toUpperCase();
    return _timezoneMap[upper] ?? 'Europe/Rome';
  }

  String _formatTimeWithTimezone(String timeStr, String? dateStr, String countryCode) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '--:--') return '--:--';
    
    try {
      String datePart = dateStr ?? DateTime.now().toIso8601String().split('T').first;
      if (datePart.isEmpty) {
        datePart = DateTime.now().toIso8601String().split('T').first;
      }
      
      final fullDateStr = '$datePart $timeStr:00';
      final format = DateFormat('yyyy-MM-dd HH:mm:ss');
      
      DateTime utcTime;
      try {
        utcTime = format.parse(fullDateStr, true);
      } catch (e) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          final dateParts = datePart.split('-');
          if (dateParts.length == 3) {
            final year = int.tryParse(dateParts[0]) ?? DateTime.now().year;
            final month = int.tryParse(dateParts[1]) ?? DateTime.now().month;
            final day = int.tryParse(dateParts[2]) ?? DateTime.now().day;
            utcTime = DateTime.utc(year, month, day, hour, minute);
          } else {
            utcTime = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
          }
        } else {
          return timeStr;
        }
      }
      
      final targetTime = utcTime.toLocal();
      return DateFormat('HH:mm').format(targetTime);
    } catch (e) {
      return timeStr;
    }
  }

  String _getCountryCodeFromLeg(Map<String, dynamic> leg) {
    final country = leg['country'] ?? leg['countryCode'] ?? leg['provider'] ?? leg['operator'];
    if (country != null && country is String && country.isNotEmpty) {
      if (country.length == 2) return country.toUpperCase();
      final operatorMap = {
        'Trenitalia': 'IT',
        'Italo': 'IT',
        'ÖBB': 'AT',
        'DB': 'DE',
        'SNCF': 'FR',
        'Renfe': 'ES',
        'SBB': 'CH',
        'CFF': 'CH',
        'NS': 'NL',
        'SNCB': 'BE',
        'NMBS': 'BE',
        'DSB': 'DK',
        'VR': 'FI',
        'SJ': 'SE',
        'PKP': 'PL',
        'ČD': 'CZ',
        'MAV': 'HU',
        'CFR': 'RO',
        'FS': 'IT',
        'nationalExpress': 'DE',
        'ICE': 'DE',
        'IC': 'IT',
        'EC': 'EU',
        'RJ': 'AT',
        'NJ': 'AT',
        'WB': 'AT',
        'EN': 'EU',
        'TGV': 'FR',
        'AVE': 'ES',
        'Eurostar': 'GB',
      };
      
      for (final entry in operatorMap.entries) {
        if (country.toLowerCase().contains(entry.key.toLowerCase())) {
          return entry.value;
        }
      }
    }
    
    final richiesta = widget.routingData['richiesta'];
    if (richiesta != null) {
      final from = richiesta['from'] as String? ?? '';
      final to = richiesta['to'] as String? ?? '';
      
      final stationMap = {
        'bari': 'IT',
        'roma': 'IT',
        'milano': 'IT',
        'napoli': 'IT',
        'torino': 'IT',
        'venezia': 'IT',
        'bologna': 'IT',
        'firenze': 'IT',
        'genova': 'IT',
        'verona': 'IT',
        'innsbruck': 'AT',
        'vienna': 'AT',
        'berlin': 'DE',
        'monaco': 'DE',
        'francoforte': 'DE',
        'parigi': 'FR',
        'lione': 'FR',
        'madrid': 'ES',
        'barcellona': 'ES',
        'zurigo': 'CH',
        'ginevra': 'CH',
        'bruxelles': 'BE',
        'amsterdam': 'NL',
        'londra': 'GB',
      };
      
      final fromLower = from.toLowerCase();
      final toLower = to.toLowerCase();
      
      for (final entry in stationMap.entries) {
        if (fromLower.contains(entry.key) || toLower.contains(entry.key)) {
          return entry.value;
        }
      }
    }
    
    return 'IT';
  }

  String _getCountryCodeForSolution(Map<String, dynamic> solution) {
    final percorso = solution['percorso'] as List? ?? [];
    if (percorso.isNotEmpty) {
      final firstLeg = percorso.first;
      return _getCountryCodeFromLeg(firstLeg);
    }
    return 'IT';
  }

  @override
  void initState() {
    super.initState();
    _selectedSolutionIndex = widget.selectedSolutionIndex;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: 0,
    );
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ... il resto del codice rimane uguale ...
  // (tutte le funzioni _buildSolutionSummary, _buildOverviewTab, _buildSegmentsTab, _buildStopsTab,
  // _buildInfoChip, _buildTrainBadge, _buildColorBadge rimangono identiche)

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    
    final solutions = _solutions;
    final currentSolution = _currentSolution;

    if (solutions.isEmpty) {
      return Scaffold(
        backgroundColor: theme.backgroundColor,
        appBar: AppBar(
          backgroundColor: theme.surfaceColor,
          foregroundColor: theme.textColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            RuntimeLocalizations.t(context, 'routing_details') ?? 'Dettagli Percorso',
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 64,
                  color: theme.primaryColor.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nessuna soluzione disponibile',
                style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Seleziona un\'altra soluzione e riprova',
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              RuntimeLocalizations.t(context, 'routing_details') ?? 'Dettagli Percorso',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              '${solutions.length} ${RuntimeLocalizations.t(context, 'routing_solutions') ?? 'soluzioni'}',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (solutions.length > 1)
            PopupMenuButton<int>(
              onSelected: (index) {
                setState(() {
                  _selectedSolutionIndex = index;
                  _tabController.animateTo(0);
                  _animationController.reset();
                  _animationController.forward();
                });
              },
              offset: const Offset(0, 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: theme.surfaceColor,
              elevation: 4,
              itemBuilder: (context) {
                return solutions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final sol = entry.value;
                  final isSelected = idx == _selectedSolutionIndex;
                  final durata = sol['durataViaggioTotaleLeggibile'] ?? '--:--';
                  final cambi = sol['cambi'] ?? 0;
                  final label = cambi == 0
                      ? '🚄 Diretto - $durata'
                      : '🔄 $cambi cambi - $durata';
                  
                  return PopupMenuItem<int>(
                    value: idx,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: theme.primaryColor,
                            size: 18,
                          )
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isSelected ? theme.primaryColor : theme.textColor,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.primaryColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: theme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Soluzione ${_selectedSolutionIndex + 1}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, color: theme.primaryColor),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Landscape: riepilogo centrato a larghezza vincolata.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: _buildSolutionSummary(theme, currentSolution),
              ),
            ),
            Container(
              color: theme.surfaceColor,
              child: TabBar(
                controller: _tabController,
                indicatorColor: theme.primaryColor,
                labelColor: theme.primaryColor,
                unselectedLabelColor: theme.secondaryTextColor,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorPadding: const EdgeInsets.symmetric(horizontal: 4),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.normal,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.route_rounded, size: 18),
                    text: 'Panoramica',
                  ),
                  Tab(
                    icon: Icon(Icons.train_rounded, size: 18),
                    text: 'Tratte',
                  ),
                  Tab(
                    icon: Icon(Icons.map_rounded, size: 18),
                    text: 'Fermate',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(theme, currentSolution),
                  _buildSegmentsTab(theme, settings, currentSolution),
                  _buildStopsTab(theme, currentSolution),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== WIDGET BUILD ====================

  Widget _buildSolutionSummary(ThemeProvider theme, Map<String, dynamic> sol) {
    final cambi = sol['cambi'] as int? ?? 0;
    final durata = sol['durataViaggioTotaleLeggibile'] ?? '--:--';
    final arrivo = sol['arrivoStimato'] ?? '--:--';
    final dataArrivo = sol['dataArrivoStimata'] ?? '';
    final prezzo = sol['prezzo'] ?? 0;
    final percorso = sol['percorso'] as List? ?? [];
    final firstLeg = percorso.isNotEmpty ? percorso.first : null;
    final lastLeg = percorso.isNotEmpty ? percorso.last : null;
    
    final countryCode = _getCountryCodeForSolution(sol);
    
    final formattedPartenza = firstLeg != null 
        ? _formatTimeWithTimezone(
            firstLeg['partenza'] ?? '--:--',
            firstLeg['dataPartenza'],
            countryCode
          )
        : '--:--';
    
    final formattedArrivo = _formatTimeWithTimezone(
      arrivo,
      dataArrivo.isNotEmpty ? dataArrivo : null,
      countryCode
    );

    final isDirect = cambi == 0;

    return Container(
      padding: EdgeInsets.all(
          MediaQuery.of(context).orientation == Orientation.landscape
              ? 12
              : 16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // Landscape: contenuto avvolto per evitare overflow orizzontali.
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDirect 
                    ? [Colors.green.shade400, Colors.green.shade700] 
                    : [Colors.orange.shade400, Colors.orange.shade700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isDirect ? Colors.green : Colors.orange).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  isDirect ? '🚄' : '🔄',
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  isDirect
                      ? (RuntimeLocalizations.t(context, 'routing_direct') ?? 'Diretto')
                      : '$cambi ${RuntimeLocalizations.t(context, 'routing_changes') ?? 'cambi'}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        firstLeg?['da'] ?? '--',
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: theme.primaryColor, size: 16),
                    Expanded(
                      child: Text(
                        lastLeg?['a'] ?? '--',
                        style: TextStyle(
                          color: theme.textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Wrap: in landscape sfrutta la larghezza senza overflow.
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 12, color: theme.primaryColor),
                          const SizedBox(width: 4),
                          Text(
                            durata,
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, size: 12, color: theme.successColor),
                          const SizedBox(width: 4),
                          Text(
                            formattedArrivo,
                            style: TextStyle(
                              color: theme.successColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (prezzo > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.euro_rounded, size: 12, color: Colors.amber.shade700),
                            const SizedBox(width: 4),
                            Text(
                              prezzo.toStringAsFixed(2),
                              style: TextStyle(
                                color: Colors.amber.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Fuso orario: ${_getTimezoneForCountry(countryCode).split('/').last}',
                    style: TextStyle(
                      color: theme.secondaryTextColor.withOpacity(0.5),
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ThemeProvider theme, Map<String, dynamic> sol) {
    final percorso = sol['percorso'] as List? ?? [];
    final cambi = sol['cambi'] as int? ?? 0;
    final durataLeggibile = sol['durataViaggioTotaleLeggibile'] ?? '--:--';
    final countryCode = _getCountryCodeForSolution(sol);

    final totalStops = percorso.fold<int>(
      0,
      (sum, leg) => sum + ((leg['stops'] as List?)?.length ?? 0),
    );
    final categories = percorso.map((leg) => leg['categoria'] as String).toSet().toList();
    final trains = percorso.map((leg) => '${leg['categoria']} ${leg['numeroTreno']}').toSet().toList();

    // Landscape: margini laterali più ampi, contenuto centrato.
    final isLandscapeOverview =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscapeOverview ? 32 : 16,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                icon: Icons.access_time_rounded,
                label: 'Durata',
                value: durataLeggibile,
                theme: theme,
                color: theme.primaryColor,
              ),
              _buildInfoChip(
                icon: Icons.swap_horiz_rounded,
                label: 'Cambi',
                value: cambi == 0 ? 'Nessuno' : '$cambi',
                theme: theme,
                color: cambi == 0 ? Colors.green : Colors.orange,
              ),
              _buildInfoChip(
                icon: Icons.location_on_rounded,
                label: 'Fermate',
                value: '$totalStops',
                theme: theme,
                color: Colors.blue,
              ),
              _buildInfoChip(
                icon: Icons.train_rounded,
                label: 'Treni',
                value: '${percorso.length}',
                theme: theme,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (categories.isNotEmpty) ...[
            Text(
              RuntimeLocalizations.t(context, 'routing_trains_used') ?? 'Treni utilizzati',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: trains.map((train) {
                final parts = train.split(' ');
                final cat = parts.isNotEmpty ? parts.first : 'TRN';
                final num = parts.length > 1 ? parts.skip(1).join(' ') : '';
                return _buildTrainBadge(cat, num, theme);
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          Text(
            RuntimeLocalizations.t(context, 'routing_summary') ?? 'Riepilogo percorso',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...percorso.asMap().entries.map((entry) {
            final idx = entry.key;
            final leg = entry.value;
            final isLast = idx == percorso.length - 1;
            final legPartenza = _formatTimeWithTimezone(
              leg['partenza'] ?? '--:--',
              leg['dataPartenza'],
              countryCode
            );
            final legArrivo = _formatTimeWithTimezone(
              leg['arrivo'] ?? '--:--',
              leg['dataArrivo'],
              countryCode
            );
            final legDa = leg['da'] ?? '--';
            final legA = leg['a'] ?? '--';
            final legDurata = leg['durataLeggibile'] ?? '';
            final legCat = leg['categoria'] ?? 'TRN';
            final legNum = leg['numeroTreno'] ?? '';
            final attesa = leg['attesaCambioMinuti'] as int? ?? 0;

            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: theme.secondaryTextColor.withOpacity(0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (!isLast)
                            Container(
                              width: 2,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.primaryColor.withOpacity(0.3),
                                    Colors.transparent,
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                _buildTrainBadge(legCat, legNum, theme),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$legDa → $legA',
                                    style: TextStyle(
                                      color: theme.textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: theme.secondaryTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  '$legPartenza → $legArrivo',
                                  style: TextStyle(
                                    color: theme.secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                                if (legDurata.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      legDurata,
                                      style: TextStyle(
                                        color: theme.primaryColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (attesa > 0) ...[
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Attesa cambio: $attesa minuti',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast) const SizedBox(height: 8),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSegmentsTab(ThemeProvider theme, SettingsProvider settings, Map<String, dynamic> sol) {
    final percorso = sol['percorso'] as List? ?? [];
    final countryCode = _getCountryCodeForSolution(sol);

    if (percorso.isEmpty) {
      return Center(
        child: Text(
          'Nessuna tratta disponibile',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal:
            MediaQuery.of(context).orientation == Orientation.landscape
                ? 32
                : 16,
        vertical: 16,
      ),
      itemCount: percorso.length,
      itemBuilder: (ctx, idx) {
        final leg = percorso[idx];
        final legCat = leg['categoria'] ?? 'TRN';
        final legNum = leg['numeroTreno'] ?? '';
        final legDa = leg['da'] ?? '--';
        final legA = leg['a'] ?? '--';
        final legPartenza = _formatTimeWithTimezone(
          leg['partenza'] ?? '--:--',
          leg['dataPartenza'],
          countryCode
        );
        final legArrivo = _formatTimeWithTimezone(
          leg['arrivo'] ?? '--:--',
          leg['dataArrivo'],
          countryCode
        );
        final legDataPartenza = leg['dataPartenza'] ?? '';
        final legDataArrivo = leg['dataArrivo'] ?? '';
        final legDurataText = leg['durataLeggibile'] ?? '';
        final legStops = leg['stops'] as List? ?? [];
        final attesa = leg['attesaCambioMinuti'] as int? ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.secondaryTextColor.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [theme.primaryColor, theme.primaryColor.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '#${idx + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTrainBadge(legCat, legNum, theme),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                legDa,
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: theme.primaryColor),
                            Expanded(
                              child: Text(
                                legA,
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Partenza',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          legPartenza,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (legDataPartenza.isNotEmpty)
                          Text(
                            legDataPartenza,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      if (legDurataText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: theme.primaryColor),
                              const SizedBox(width: 4),
                              Text(
                                legDurataText,
                                style: TextStyle(
                                  color: theme.primaryColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (attesa > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.timer_rounded, size: 12, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                'Attesa $attesa min',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Arrivo',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          legArrivo,
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (legDataArrivo.isNotEmpty)
                          Text(
                            legDataArrivo,
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (legStops.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.secondaryTextColor.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.subdirectory_arrow_right_rounded,
                              size: 14, color: theme.secondaryTextColor),
                          const SizedBox(width: 4),
                          Text(
                            '${legStops.length} fermate',
                            style: TextStyle(
                              color: theme.secondaryTextColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: legStops.map((stop) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              stop.toString(),
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildStopsTab(ThemeProvider theme, Map<String, dynamic> sol) {
    final percorso = sol['percorso'] as List? ?? [];
    final countryCode = _getCountryCodeForSolution(sol);

    final allStops = <Map<String, dynamic>>[];
    
    for (int legIndex = 0; legIndex < percorso.length; legIndex++) {
      final leg = percorso[legIndex];
      final stops = leg['stops'] as List? ?? [];
      final legCat = leg['categoria'] ?? 'TRN';
      final legNum = leg['numeroTreno'] ?? '';
      final legPartenza = _formatTimeWithTimezone(
        leg['partenza'] ?? '--:--',
        leg['dataPartenza'],
        countryCode
      );
      final legArrivo = _formatTimeWithTimezone(
        leg['arrivo'] ?? '--:--',
        leg['dataArrivo'],
        countryCode
      );
      final isLastLeg = legIndex == percorso.length - 1;

      for (int i = 0; i < stops.length; i++) {
        final stop = stops[i];
        final isFirstInSegment = i == 0;
        final isLastInSegment = i == stops.length - 1;
        
        if (isFirstInSegment && legIndex > 0) {
          final lastStopInPrevious = allStops.isNotEmpty ? allStops.last['name'] : null;
          if (lastStopInPrevious == stop) {
            continue;
          }
        }

        final isFirstOverall = isFirstInSegment && legIndex == 0;
        final isLastOverall = isLastInSegment && isLastLeg;
        final isChangePoint = isFirstInSegment && legIndex > 0;

        allStops.add({
          'name': stop,
          'legIndex': legIndex,
          'isFirst': isFirstOverall,
          'isLast': isLastOverall,
          'isChangePoint': isChangePoint,
          'legCat': legCat,
          'legNum': legNum,
          'time': isFirstInSegment ? legPartenza : (isLastInSegment ? legArrivo : '--:--'),
          'isLastInSegment': isLastInSegment,
          'isFirstInSegment': isFirstInSegment,
        });
      }
    }

    if (allStops.isEmpty) {
      return Center(
        child: Text(
          'Nessuna fermata disponibile',
          style: TextStyle(color: theme.secondaryTextColor),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal:
            MediaQuery.of(context).orientation == Orientation.landscape
                ? 32
                : 16,
        vertical: 16,
      ),
      itemCount: allStops.length,
      itemBuilder: (ctx, idx) {
        final stop = allStops[idx];
        final isFirst = stop['isFirst'] as bool? ?? false;
        final isLast = stop['isLast'] as bool? ?? false;
        final isChangePoint = stop['isChangePoint'] as bool? ?? false;
        final isLastInSegment = stop['isLastInSegment'] as bool? ?? false;
        final name = stop['name'] as String? ?? '--';
        final time = stop['time'] as String? ?? '--:--';
        final legCat = stop['legCat'] as String? ?? 'TRN';
        final legNum = stop['legNum'] as String? ?? '';

        final bool isBold = isFirst || isLast || isChangePoint;
        
        final Color textColor = isFirst 
            ? Colors.green 
            : (isLast 
                ? Colors.red 
                : (isChangePoint 
                    ? Colors.orange 
                    : theme.textColor));

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  children: [
                    if (isFirst)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade400, Colors.green.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 12),
                      )
                    else if (isLast)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red.shade400, Colors.red.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.flag, color: Colors.white, size: 12),
                      )
                    else if (isChangePoint)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade400, Colors.orange.shade700],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.swap_horiz, color: Colors.white, size: 12),
                      )
                    else
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: theme.primaryColor.withOpacity(0.3),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              isLastInSegment && !isLast
                                  ? Colors.orange.withOpacity(0.5)
                                  : theme.secondaryTextColor.withOpacity(0.3),
                              isLastInSegment && !isLast
                                  ? Colors.orange.withOpacity(0.1)
                                  : theme.secondaryTextColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                  decoration: BoxDecoration(
                    color: isFirst || isLast || isChangePoint
                        ? textColor.withOpacity(0.05)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                                fontSize: isFirst || isLast ? 15 : 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.secondaryTextColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              time,
                              style: TextStyle(
                                color: theme.secondaryTextColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (isChangePoint) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.train_rounded, size: 12, color: theme.primaryColor),
                            const SizedBox(width: 4),
                            Text(
                              'Cambio con $legCat $legNum',
                              style: TextStyle(
                                color: theme.primaryColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (isFirst)
                        Text(
                          '🚆 Partenza',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      if (isLast)
                        Text(
                          '🏁 Arrivo',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required ThemeProvider theme,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainBadge(String category, String number, ThemeProvider theme) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final cat = category.isNotEmpty ? category : 'TRN';
    final num = number.isNotEmpty ? number : '---';

    final bool isHighSpeed = cat.toLowerCase().contains('fr') ||
        cat.toLowerCase().contains('freccia') ||
        cat.toLowerCase().contains('ec') ||
        cat.toLowerCase().contains('ic') ||
        cat.toLowerCase().contains('nationalexpress') ||
        cat.toLowerCase().contains('ice') ||
        cat.toLowerCase().contains('rj') ||
        cat.toLowerCase().contains('tgc') ||
        cat.toLowerCase().contains('tgv') ||
        cat.toLowerCase().contains('ave');
    
    final Color color = isHighSpeed ? Colors.redAccent : theme.primaryColor;

    if (settings.vectorLogosEnabled) {
      final key = cat.toUpperCase().replaceAll(' ', '_');
      final logo = trainProvider.trainLogos[key];
      final logoUrl = logo != null ? (logo['png'] ?? logo['svg']) : null;

      if (logoUrl != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 18,
              constraints: const BoxConstraints(maxWidth: 50),
              padding: theme.isDark
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                  : EdgeInsets.zero,
              decoration: theme.isDark
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => _buildColorBadge(cat, num, theme, color),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              num,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textColor,
                fontSize: 11,
              ),
            ),
          ],
        );
      }
    }
    return _buildColorBadge(cat, num, theme, color);
  }

  Widget _buildColorBadge(String category, String number, ThemeProvider theme, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(
        '$category $number',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
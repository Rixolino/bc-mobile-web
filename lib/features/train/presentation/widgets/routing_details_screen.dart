// lib/presentation/trains/widgets/routing_details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bc_transporter/presentation/providers/theme_provider.dart';
import 'package:bc_transporter/presentation/providers/settings_provider.dart';
import 'package:bc_transporter/core/services/runtime_localizations.dart';
import 'package:intl/intl.dart';

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
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedSolutionIndex = 0;

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          title: Text(
            RuntimeLocalizations.t(context, 'routing_details') ?? 'Dettagli Percorso',
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 64, color: theme.secondaryTextColor),
              const SizedBox(height: 16),
              Text(
                'Nessuna soluzione disponibile',
                style: TextStyle(color: theme.textColor, fontSize: 18),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              RuntimeLocalizations.t(context, 'routing_details') ?? 'Dettagli Percorso',
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
            ),
            Text(
              '${solutions.length} ${RuntimeLocalizations.t(context, 'routing_solutions') ?? 'soluzioni'}',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
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
                });
              },
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
      body: Column(
        children: [
          _buildSolutionSummary(theme, currentSolution),
          Container(
            color: theme.surfaceColor,
            child: TabBar(
              controller: _tabController,
              indicatorColor: theme.primaryColor,
              labelColor: theme.primaryColor,
              unselectedLabelColor: theme.secondaryTextColor,
              tabs: const [
                Tab(
                  icon: Icon(Icons.route_rounded, size: 20),
                  text: 'Panoramica',
                ),
                Tab(
                  icon: Icon(Icons.train_rounded, size: 20),
                  text: 'Tratte',
                ),
                Tab(
                  icon: Icon(Icons.map_rounded, size: 20),
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
    );
  }

  Widget _buildSolutionSummary(ThemeProvider theme, Map<String, dynamic> sol) {
    final cambi = sol['cambi'] as int? ?? 0;
    final durata = sol['durataViaggioTotaleLeggibile'] ?? '--:--';
    final arrivo = sol['arrivoStimato'] ?? '--:--';
    final dataArrivo = sol['dataArrivoStimata'] ?? '';
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  cambi == 0 ? '🚄' : '🔄',
                  style: const TextStyle(fontSize: 24),
                ),
                Text(
                  cambi == 0
                      ? (RuntimeLocalizations.t(context, 'routing_direct') ?? 'Diretto')
                      : '$cambi ${RuntimeLocalizations.t(context, 'routing_changes') ?? 'cambi'}',
                  style: TextStyle(
                    color: theme.primaryColor,
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
                          fontSize: 14,
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
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, size: 14, color: theme.secondaryTextColor),
                    const SizedBox(width: 4),
                    Text(
                      durata,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.flag_rounded, size: 14, color: theme.secondaryTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '$formattedArrivo${dataArrivo.isNotEmpty ? ' ($dataArrivo)' : ''}',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                // Mostra il fuso orario
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Fuso orario: ${_getTimezoneForCountry(countryCode).split('/').last}',
                    style: TextStyle(
                      color: theme.secondaryTextColor.withOpacity(0.6),
                      fontSize: 10,
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
              ),
              _buildInfoChip(
                icon: Icons.swap_horiz_rounded,
                label: 'Cambi',
                value: cambi == 0 ? 'Nessuno' : '$cambi',
                theme: theme,
              ),
              _buildInfoChip(
                icon: Icons.location_on_rounded,
                label: 'Fermate',
                value: '$totalStops',
                theme: theme,
              ),
              _buildInfoChip(
                icon: Icons.train_rounded,
                label: 'Treni',
                value: '${percorso.length}',
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (categories.isNotEmpty) ...[
            Text(
              RuntimeLocalizations.t(context, 'routing_trains_used') ?? 'Treni utilizzati',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
          ],
          Text(
            RuntimeLocalizations.t(context, 'routing_summary') ?? 'Riepilogo percorso',
            style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.primaryColor,
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
                            height: 40,
                            color: theme.secondaryTextColor.withOpacity(0.3),
                          ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildTrainBadge(legCat, legNum, theme),
                              const SizedBox(width: 8),
                              Text(
                                '$legDa → $legA',
                                style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 14, color: theme.secondaryTextColor),
                              const SizedBox(width: 4),
                              Text(
                                '$legPartenza → $legArrivo',
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 13,
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
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (attesa > 0) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.timer_rounded, size: 14, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'Attesa cambio: $attesa minuti',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
              color: theme.secondaryTextColor.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${idx + 1}',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
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
                            Icon(Icons.arrow_forward_rounded, size: 16, color: theme.primaryColor),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partenza',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        legPartenza,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (legDataPartenza.isNotEmpty)
                        Text(
                          legDataPartenza,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                          ),
                        ),
                    ],
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
                          child: Text(
                            legDurataText,
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (attesa > 0) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Attesa $attesa min',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Arrivo',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        legArrivo,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (legDataArrivo.isNotEmpty)
                        Text(
                          legDataArrivo,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                          ),
                        ),
                    ],
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.secondaryTextColor.withOpacity(0.05),
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

  // Raccogli TUTTE le fermate in sequenza unendo i segmenti
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

  return ListView.builder(
    padding: const EdgeInsets.all(16),
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

      // Determina se il testo deve essere in grassetto
      final bool isBold = isFirst || isLast || isChangePoint;
      
      // Colore del testo
      final Color textColor = isFirst 
          ? Colors.green 
          : (isLast 
              ? Colors.red 
              : (isChangePoint 
                  ? Colors.orange 
                  : theme.textColor));

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Linea verticale con cerchio
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  if (isFirst)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 12),
                    )
                  else if (isLast)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flag, color: Colors.white, size: 12),
                    )
                  else if (isChangePoint)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
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
                      ),
                    ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 28,
                      color: isLastInSegment && !isLast
                          ? Colors.orange.withOpacity(0.5)
                          : theme.secondaryTextColor.withOpacity(0.3),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
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
                            fontWeight: isBold ? FontWeight.bold : FontWeight.normal, // <-- GRASSETTO PER CAMBI
                            fontSize: isFirst || isLast ? 16 : 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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
                            fontSize: 11,
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
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (isLast)
                    Text(
                      '🏁 Arrivo',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (isLastInSegment && !isLast)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.withOpacity(0.5),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.secondaryTextColor.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.primaryColor),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: theme.textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainBadge(String category, String number, ThemeProvider theme) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final cat = category.isNotEmpty ? category : 'TRN';
    final num = number.isNotEmpty ? number : '---';

    if (settings.vectorLogosEnabled) {
      final fileName = cat.toLowerCase().replaceAll(' ', '_');
      final logoUrl = 'https://betacloud-transporter.is-cool.dev/assets/logos/trains/$fileName.png';
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 20,
            constraints: const BoxConstraints(maxWidth: 50),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _buildColorBadge(cat, num, theme),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            num,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: theme.textColor,
              fontSize: 12,
            ),
          ),
        ],
      );
    }
    return _buildColorBadge(cat, num, theme);
  }

  Widget _buildColorBadge(String category, String number, ThemeProvider theme) {
    final isHighSpeed = category.toLowerCase().contains('fr') ||
        category.toLowerCase().contains('freccia') ||
        category.toLowerCase().contains('ec') ||
        category.toLowerCase().contains('ic') ||
        category.toLowerCase().contains('nationalexpress') ||
        category.toLowerCase().contains('ice') ||
        category.toLowerCase().contains('rj') ||
        category.toLowerCase().contains('tgc') ||
        category.toLowerCase().contains('tgv') ||
        category.toLowerCase().contains('ave');
    final color = isHighSpeed ? Colors.redAccent : theme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$category $number',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
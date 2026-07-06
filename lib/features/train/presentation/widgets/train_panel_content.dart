import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marquee/marquee.dart';
import '../providers/train_provider.dart';
import '../../data/models/train_model.dart';
import '../../../../presentation/providers/settings_provider.dart';
import 'train_details_sheet.dart';
import '../../../../core/utils/country_time.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_stop.dart';
import '../../../auth/providers/auth_provider.dart';
import 'shimmer_and_toggle.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../../../core/services/runtime_localizations.dart';
import 'train_stats_screen.dart';
import 'package:bc_transporter/features/train/data/models/train_stats_model.dart';

class TrainPanelContent extends StatefulWidget {
  final bool showModeToggle;
  const TrainPanelContent({super.key, this.showModeToggle = false});

  @override
  State<TrainPanelContent> createState() => _TrainPanelContentState();
}

class _TrainPanelContentState extends State<TrainPanelContent> {
  final TextEditingController _searchController = TextEditingController();

  // Stato per i filtri
  String _selectedCountry = '';
  String _selectedCity = '';
  String? _selectedPlatformFilter;

  List<Map<String, String>> _countries = [];
  final Map<String, List<Map<String, String>>> _citiesByCountry = {};
  List<String> _countryOrder = [];
  bool _isOffline = false;
  Timer? _connectivityTimer;

  final Map<String, String> countryNames = {
    'AT': 'Austria',
    'BE': 'Belgio',
    'CH': 'Svizzera',
    'CZ': 'Rep. Ceca',
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
    'EU': 'Realtime EU',
  };

  // Variabili per il monitoraggio delle stazioni nel tabellone risultati
  bool _isMonitored = false;
  bool _checkingStatus = false;
  String? _lastCheckedStationId; // Tiene traccia della stazione attualmente aperta

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _startConnectivityMonitor();
  }

  void _startConnectivityMonitor() {
    _connectivityTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectivity());
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool hasInternet = true;
    if (!kIsWeb) {
      Socket? socket;
      try {
        socket = await Socket.connect('1.1.1.1', 53,
            timeout: const Duration(seconds: 2));
        hasInternet = true;
      } catch (_) {
        hasInternet = false;
      } finally {
        socket?.destroy();
      }
    }

    if (mounted && _isOffline != !hasInternet) {
      final wasOffline = _isOffline;
      setState(() {
        _isOffline = !hasInternet;
      });

      // Se siamo tornati online, rifacciamo la ricerca se c'è testo
      if (wasOffline && hasInternet) {
        final provider = Provider.of<TrainProvider>(context, listen: false);
        List<Map<String, String>> displayedCountries =
            provider.selectedService == 'direct'
                ? _countries
                    .where((c) => ['IT', 'FAL', 'EU'].contains(c['code']))
                    .toList()
                : _countries;
        _onSearchChanged(_searchController.text, provider, displayedCountries);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _connectivityTimer?.cancel();
    super.dispose();
  }

  // Metodo per controllare se la stazione è già nel DB (Richiamato automaticamente all'apertura del tabellone)
  Future<void> _checkStationStatus(String stationId) async {
    if (!mounted) return;
    setState(() => _checkingStatus = true);
    
    try {
      final response = await http.get(Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/monitor/check/$stationId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() => _isMonitored = data['isMonitored'] ?? false);
        }
      }
    } catch (e) {
      debugPrint("Errore controllo monitoraggio: $e");
    } finally {
      if (mounted) {
        setState(() => _checkingStatus = false);
      }
    }
  }

  // Metodo per aggiungere la stazione al monitoraggio
  Future<void> _addStationToDb(String stationId, String name) async {
    try {
      debugPrint("📝 Aggiunta stazione '$stationId' al DB...");
      final addResponse = await http.post(
        Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/monitor/add'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'stationId': stationId,
          'name': name,
          'country': _selectedCountry.isEmpty ? 'GLOBAL' : _selectedCountry
        }),
      );

      if (addResponse.statusCode == 200) {
        debugPrint("✅ Stazione aggiunta con successo");
        await _checkStationStatus(stationId); // Ricarica lo stato per aggiornare l'icona
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Stazione aggiunta al monitoraggio"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Errore nell'aggiunta della stazione: ${addResponse.statusCode}"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Errore durante l'operazione: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore di connessione: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Metodo per scaricare le statistiche reali dal server e navigare sullo screen
  Future<void> _loadStatsAndNavigate(BuildContext context, String stationId) async {
    setState(() => _checkingStatus = true);
    try {
      final response = await http.get(
        Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/station/$stationId')
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TrainStatsScreen(
                rawStats: data, 
                stationId: stationId,
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Nessun dato statistico disponibile al momento. Riprova più tardi.")),
          );
        }
      }
    } catch (e) {
      debugPrint("Errore caricamento statistiche: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore di connessione: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _checkingStatus = false);
      }
    }
  }

  // --- LOGICA DATI (Country & City) ---

  Future<void> _loadCountries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCountries = prefs.getString('countries_cache');
      final freshData = await _fetchProvidersFromAPI();

      if (freshData.isNotEmpty) {
        await prefs.setString('countries_cache', jsonEncode(freshData));
        if (mounted) {
          setState(() {
            _countries = freshData;
          });
        }
        await _loadCountryOrder();
      } else if (cachedCountries != null) {
        final cached = List<Map<String, String>>.from(
            (jsonDecode(cachedCountries) as List)
                .map((i) => Map<String, String>.from(i)));
        if (mounted) {
          setState(() {
            _countries = cached;
          });
        }
        await _loadCountryOrder();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _countries = [];
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
          final Map<String, Map<String, String>> countriesMap = {};

          for (final p in providers) {
            final code = (p['countryCode'] as String).toUpperCase();
            if (!countriesMap.containsKey(code)) {
              countriesMap[code] = {
                'code': code,
                'name': countryNames[code] ?? code
              };
            }
            if (p['city'] != null) {
              final cityData = {
                'name': p['city'].toString(),
                'provider': p['id'].toString()
              };
              _citiesByCountry.putIfAbsent(code, () => []).add(cityData);
            }
          }
          return countriesMap.values.toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _loadCountryOrder() async {
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('country_order') ?? [];
    if (mounted) {
      setState(() {
        _countryOrder = order;
        if (_countryOrder.isNotEmpty && _countries.isNotEmpty) {
          _countries.sort((a, b) {
            final ia = _countryOrder.indexOf(a['code']!);
            final ib = _countryOrder.indexOf(b['code']!);
            if (ia == -1) return 1;
            if (ib == -1) return -1;
            return ia.compareTo(ib);
          });
        }
      });
    }
  }

  void _saveCountryOrder() async {
    final prefs = await SharedPreferences.getInstance();
    _countryOrder = _countries.map((c) => c['code']!).toList();
    await prefs.setStringList('country_order', _countryOrder);
  }

  void _onReorderCountries(
      List<Map<String, String>> currentList, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final moved = currentList[oldIndex];
    final movedCode = moved['code']!;
    final globalOld = _countries.indexWhere((c) => c['code'] == movedCode);
    if (globalOld != -1) _countries.removeAt(globalOld);
    
    int insertIndex;
    if (currentList.isEmpty) {
      insertIndex = _countries.length;
    } else if (newIndex <= 0) {
      final firstCode = currentList.first['code']!;
      insertIndex = _countries.indexWhere((c) => c['code'] == firstCode);
      if (insertIndex == -1) insertIndex = 0;
    } else {
      final prevCode = currentList[newIndex - 1]['code']!;
      insertIndex = _countries.indexWhere((c) => c['code'] == prevCode);
      if (insertIndex == -1) {
        insertIndex = _countries.length;
      } else {
        insertIndex++;
      }
    }
    if (insertIndex > _countries.length) insertIndex = _countries.length;
    _countries.insert(insertIndex, moved);
    setState(() {});
    _saveCountryOrder();
  }

  // --- UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    final trainProvider = Provider.of<TrainProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    // Auto-load logos if enabled
    if (settings.vectorLogosEnabled && trainProvider.trainLogos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        trainProvider.loadTrainLogos();
      });
    }

    final station = trainProvider.selectedStation;

    // --- NUOVA LOGICA: Controllo automatico quando si entra nel tabellone ---
    if (station != null && station.id != _lastCheckedStationId) {
      _lastCheckedStationId = station.id; // Aggiorna l'ID in memoria
      
      // Esegue il check subito dopo la fine del frame per evitare conflitti di build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkStationStatus(station.id);
      });
    } else if (station == null && _lastCheckedStationId != null) {
      // L'utente è tornato alla ricerca, resettiamo l'ID in memoria
      _lastCheckedStationId = null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: station != null
          ? _buildTimetableResults(context, trainProvider, theme, station)
          : _buildSearchHome(context, trainProvider, theme),
    );
  }

  // 1. TABELLONE RISULTATI (Con filtri binari)
  Widget _buildTimetableResults(BuildContext context, TrainProvider provider,
      ThemeProvider theme, TrainStation station) {
    final List<String> availablePlatforms = provider.departures
        .map((e) => e.platform?.toString().trim() ?? '-')
        .where((e) => e != '-')
        .toSet()
        .toList();
    availablePlatforms.sort();

    final filteredDepartures = _selectedPlatformFilter == null
        ? provider.departures
        : provider.departures
            .where(
                (e) => e.platform.toString().trim() == _selectedPlatformFilter)
            .toList();

    return Column(
      key: const ValueKey('results'),
      children: [
        _buildTimetableHeader(provider, theme, station),
        if (availablePlatforms.isNotEmpty && !provider.isLoadingDepartures)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                    AppLocalizations.of(context)?.allPlatforms ??
                        "Tutti i Binari",
                    _selectedPlatformFilter == null,
                    theme,
                    () => setState(() => _selectedPlatformFilter = null)),
                ...availablePlatforms.map((p) => _buildFilterChip(
                    "${AppLocalizations.of(context)?.platform ?? 'Binario'} $p",
                    _selectedPlatformFilter == p,
                    theme,
                    () => setState(() => _selectedPlatformFilter = p))),
              ],
            ),
          ),
        Expanded(
          child: provider.isLoadingDepartures
              ? ShimmerLoading(baseColor: theme.secondaryTextColor)
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: filteredDepartures.length,
                  itemBuilder: (ctx, i) =>
                      _buildTrainCard(ctx, filteredDepartures[i], i, theme),
                ),
        ),
      ],
    );
  }

  Widget _buildTimetableHeader(
      TrainProvider provider, ThemeProvider theme, TrainStation station) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: theme.textColor, size: 20),
                  onPressed: () => provider.clearSelection()),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(station.name,
                        style: TextStyle(
                            color: theme.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(station.country,
                        style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              // Pulsante Statistiche inserito nel Tabellone della stazione
              _checkingStatus
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.bar_chart_rounded,
                        color: _isMonitored ? theme.primaryColor : theme.secondaryTextColor,
                      ),
                      onPressed: () async {
                        // Visto che lo stato è già stato verificato in automatico dall'apertura
                        if (_isMonitored) {
                          // Se è monitorata, apri direttamente lo screen dei dati
                          await _loadStatsAndNavigate(context, station.id);
                        } else {
                          // Altrimenti, proponi all'utente di inserirla nel sistema
                          showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: theme.surfaceColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  title: Text(
                                    RuntimeLocalizations.t(context, 'stats_monitoring_title'),
                                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                                  ),
                                  content: Text(
                                    RuntimeLocalizations.t(context, 'stats_monitoring_msg'),
                                    style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, height: 1.4),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(
                                        RuntimeLocalizations.t(context, 'cancel'),
                                        style: TextStyle(color: theme.secondaryTextColor),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.primaryColor,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await _addStationToDb(station.id, station.name);
                                      },
                                      child: Text(
                                        RuntimeLocalizations.t(context, 'add_now'),
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                        }
                      },
                      tooltip: 'Statistiche e Monitoraggio Stazione',
                    ),
              _buildFavoriteToggle(station, theme),
            ],
          ),
          const SizedBox(height: 16),
          _buildDepartureArrivalToggle(provider, theme),
        ],
      ),
    );
  }

  // 2. CARD TRENO (STILE BOARD)
  Widget _buildTrainCard(
      BuildContext context, dynamic dep, int index, ThemeProvider theme) {
    final displayTime = dep.estimatedTime ??
        (dep.scheduledTime?.add(Duration(minutes: dep.delayMinutes ?? 0))) ??
        dep.scheduledTime;
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final country = dep.country?.toString().isNotEmpty == true
        ? dep.country.toString()
        : trainProvider.selectedStation?.country;
    final timeStr = formatCountryTime(displayTime, country);
    final delay = dep.delayMinutes ?? 0;
    final isCancelled = dep.status == 'CANCELED';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showTrainDetails(context, dep, index, theme),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(timeStr,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: theme.textColor,
                            letterSpacing: -1)),
                    isCancelled
                        ? _buildBadge("CANC", Colors.red)
                        : (delay > 0
                            ? _buildBadge("+$delay'", Colors.orange)
                            : Text(
                                AppLocalizations.of(context)?.onTime ??
                                    "In orario",
                                style: TextStyle(
                                    fontSize: 10,
                                    color: theme.successColor,
                                    fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTrainTypeBadge(dep, theme),
                      const SizedBox(height: 4),
                      _SmartTrainRouteText(
                          departure: dep,
                          index: index,
                          theme: theme,
                          isArrivalMode:
                              Provider.of<TrainProvider>(context, listen: false)
                                  .isArrivalMode),
                    ],
                  ),
                ),
                _buildPlatformBox(dep.platform?.toString() ?? '-', theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 3. HOME RICERCA (Con logica Country + City)
  Widget _buildSearchHome(
      BuildContext context, TrainProvider provider, ThemeProvider theme) {
    List<Map<String, String>> displayedCountries =
        provider.selectedService == 'direct'
            ? _countries
                .where((c) => ['IT', 'FAL', 'EU'].contains(c['code']))
                .toList()
            : _countries;

    return Column(
      key: const ValueKey('search'),
      children: [
        _buildSearchHeader(provider, theme, displayedCountries),
        _buildFavoriteSection(provider, theme),
        _buildSavedTrainsButton(provider, theme),
        Expanded(
          child: _isOffline
              ? _buildOfflineError(theme)
              : (provider.isLoadingSuggestions
                  ? ShimmerLoading(baseColor: theme.secondaryTextColor)
                  : _buildStationSuggestionsList(provider, theme)),
        ),
      ],
    );
  }

  Widget _buildOfflineError(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.youAreOffline ?? "Sei offline",
            style: TextStyle(
                color: theme.textColor,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.connectToSearchStations ??
                "Connettiti per cercare nuove stazioni",
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedTrainsButton(TrainProvider provider, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showSavedStationsSheet(provider, theme),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: _isOffline ? 0.2 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.download_done_rounded, color: theme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        AppLocalizations.of(context)?.savedTrains ??
                            "Treni Salvati",
                        style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.bold)),
                    Text(
                        AppLocalizations.of(context)?.accessOfflineData ??
                            "Accedi ai dati scaricati offline",
                        style: TextStyle(
                            color: theme.secondaryTextColor, fontSize: 11)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 16, color: theme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }

  void _showSavedStationsSheet(TrainProvider provider, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (ctx, sc) => Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: theme.secondaryTextColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text(
                  AppLocalizations.of(context)?.savedTrainsOffline ??
                      "Treni Salvati (Offline)",
                  style: TextStyle(
                      color: theme.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: provider.getDownloadedTrains(),
                  builder: (ctx, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return Center(
                          child: Text(
                              AppLocalizations.of(context)?.noOfflineData ??
                                  "Nessun dato salvato offline",
                              style:
                                  TextStyle(color: theme.secondaryTextColor)));
                    }
                    return ListView.builder(
                      controller: sc,
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        final station = TrainStation.fromJson(item['station']);
                        final train = TrainDeparture.fromJson(item['train']);
                        return ListTile(
                          leading: Icon(Icons.train_rounded,
                              color: theme.primaryColor),
                          title: Text(
                              "${train.category ?? ''} ${train.trainNumber ?? ''}",
                              style: TextStyle(
                                  color: theme.textColor,
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                              "${train.origin ?? 'N/A'} \u2192 ${train.destination ?? 'N/A'}\n${station.name} (${item['mode'] == 'arrivals' ? (AppLocalizations.of(context)?.arrivals ?? 'Arrivi') : (AppLocalizations.of(context)?.departures ?? 'Partenze')})",
                              style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 12)),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: theme.secondaryTextColor),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.pop(ctx);
                            provider.selectSavedTrain(
                                station, train, item['service'], item['mode']);
                            _showTrainDetails(context, train, -1, theme);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchHeader(TrainProvider provider, ThemeProvider theme,
      List<Map<String, String>> countries) {
    final hasCities = _selectedCountry.isNotEmpty &&
        _citiesByCountry.containsKey(_selectedCountry);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: hasCities ? 180 : 135,
        borderRadius: 24, blur: 20, alignment: Alignment.center, border: 1,
        linearGradient: LinearGradient(colors: [
          theme.surfaceColor.withValues(alpha: 0.9),
          theme.surfaceColor.withValues(alpha: 0.5)
        ]),
        borderGradient: LinearGradient(
            colors: [theme.primaryColor.withValues(alpha: 0.3), Colors.transparent]),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) =>
                          _onSearchChanged(val, provider, countries),
                      style: TextStyle(
                          color: theme.textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)
                                ?.searchStationOrTrain ??
                            "Cerca stazione o treno...",
                        hintStyle: TextStyle(
                            color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: theme.primaryColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.reorder, color: theme.primaryColor),
                    onPressed: () => _openReorderSheet(provider, theme),
                    tooltip: AppLocalizations.of(context)?.reorderCountries ??
                        'Riordina nazioni',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Riga Nazioni
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildGlobalChip(provider, theme, countries),
                  ),
                  ...countries
                      .map((c) => Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: _buildCountryChip(
                                c, provider, theme, countries),
                          ))
                      .toList(),
                ],
              ),
            ),
            // Riga Città (se presenti)
            if (hasCities) ...[
              const Divider(height: 1),
              SizedBox(
                height: 45,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildCityChip({
                      'name': AppLocalizations.of(context)?.allCities ??
                          'Tutte le città',
                      'provider': ''
                    }, provider, theme, countries),
                    ..._citiesByCountry[_selectedCountry]!
                        .map((city) =>
                            _buildCityChip(city, provider, theme, countries))
                        .toList(),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildCountryChip(Map<String, String> c, TrainProvider provider,
      ThemeProvider theme, List<Map<String, String>> countries) {
    final isSelected = _selectedCountry == c['code'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(c['name']!,
            style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : theme.secondaryTextColor)),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedCountry = val ? c['code']! : '';
            _selectedCity = '';
          });
          _onSearchChanged(_searchController.text, provider, countries);
        },
        selectedColor: theme.primaryColor,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildGlobalChip(TrainProvider provider, ThemeProvider theme,
      List<Map<String, String>> countries) {
    final isSelected = _selectedCountry == 'GLOBAL';
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
            Text(RuntimeLocalizations.t(context, 'global_label'),
              style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white : theme.secondaryTextColor)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              RuntimeLocalizations.t(context, 'beta'),
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : theme.primaryColor,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          _selectedCountry = val ? 'GLOBAL' : '';
          _selectedCity = '';
        });
        _onSearchChanged(_searchController.text, provider, countries);
      },
      selectedColor: theme.primaryColor,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    );
  }

  Widget _buildCityChip(Map<String, String> city, TrainProvider provider,
      ThemeProvider theme, List<Map<String, String>> countries) {
    final isSelected = _selectedCity == city['name'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(city['name']!,
            style: TextStyle(
                fontSize: 10,
                color: isSelected
                    ? theme.primaryColor
                    : theme.secondaryTextColor)),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedCity = val ? city['name']! : '';
          });
          _onSearchChanged(_searchController.text, provider, countries);
        },
        selectedColor: theme.primaryColor.withValues(alpha: 0.15),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: isSelected ? theme.primaryColor : Colors.transparent)),
        showCheckmark: false,
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildFilterChip(
      String label, bool isSelected, ThemeProvider theme, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label,
            style: TextStyle(
                color: isSelected ? Colors.white : theme.textColor,
                fontWeight: FontWeight.bold,
                fontSize: 12)),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: theme.primaryColor,
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildPlatformBox(String bin, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
            Text(RuntimeLocalizations.t(context, 'platform_abbr'),
              style: TextStyle(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: theme.primaryColor)),
          Text(bin,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textColor)),
        ],
      ),
    );
  }

  void _onSearchChanged(String query, TrainProvider provider,
      List<Map<String, String>> countries) {
    if (query.length < 2 && _selectedCountry.isEmpty) {
      provider.clearStationSuggestions();
      return;
    }

    if (_selectedCountry.isNotEmpty) {
      if (_selectedCountry == 'EU') {
        provider.searchTrainByNumber(query);
      } else if (_selectedCountry == 'GLOBAL') {
        provider.searchStations(query, country: 'GLOBAL');
      } else {
        String? cityProvider;
        if (_selectedCity.isNotEmpty && _selectedCity != 'Tutte le città') {
          cityProvider = _citiesByCountry[_selectedCountry]!
              .firstWhere((c) => c['name'] == _selectedCity)['provider'];
        }
        provider.searchStations(query,
            country: _selectedCountry, city: cityProvider);
      }
    } else {
      _searchStationsMultipleCountries(query, countries, provider);
    }
  }

  void _openReorderSheet(TrainProvider provider, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.secondaryTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      AppLocalizations.of(context)?.reorderCountries ??
                          'Riordina nazioni',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textColor)),
                  TextButton(
                    onPressed: () {
                      _saveCountryOrder();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(AppLocalizations.of(context)?.save ?? 'Salva',
                        style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) =>
                      _onReorderCountries(_countries, oldIndex, newIndex),
                  children: [
                    for (var i = 0; i < _countries.length; i++)
                      ListTile(
                        key: ValueKey(_countries[i]['code']),
                        title: Text(_countries[i]['name']!,
                            style: TextStyle(color: theme.textColor)),
                        trailing: Icon(Icons.drag_handle,
                            color: theme.secondaryTextColor),
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

  Future<void> _searchStationsMultipleCountries(String query,
      List<Map<String, String>> countries, TrainProvider provider) async {
    final codes = countries.map((c) => c['code']!).toList();
    final results = await Future.wait(codes.map((code) => provider
        .searchStations(query, country: code)
        .then((_) => provider.stationSuggestions.toList())
        .catchError((_) => <TrainStation>[])));
    final all = results.expand((x) => x).toList();
    final seen = <String>{};
    provider.setStationSuggestions(
        all.where((s) => seen.add('${s.id}-${s.country}')).toList());
  }

  void _showTrainDetails(
      BuildContext context, dynamic dep, int index, ThemeProvider theme) {
    if (dep.stops == null || dep.stops.isEmpty) {
      Provider.of<TrainProvider>(context, listen: false)
          .expandTrainDetails(index);
    }
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.98,
            minChildSize: 0.5,
            builder: (_, sc) => TrainDetailsSheet(
                departure: dep,
                isArrivalMode:
                    Provider.of<TrainProvider>(context, listen: false)
                        .isArrivalMode,
                selectedCountry: _selectedCountry,
                scrollController: sc)));
  }

 Widget _buildTrainTypeBadge(dynamic dep, ThemeProvider theme) {
    if (dep == null) return const SizedBox.shrink();

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final category = (dep.category?.toString() ?? 'TRN').trim();
    final number = (dep.trainNumber?.toString() ?? '').trim();

    if (settings.vectorLogosEnabled) {
      final fileName = category.toLowerCase().replaceAll(' ', '_');
      final logoUrl = "https://betacloud-transporter.is-cool.dev/assets/logos/trains/$fileName.png";

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 20,
            constraints: const BoxConstraints(maxWidth: 60),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) {
                return _buildColorBadge(category, number, theme);
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  width: 20,
                  child: Center(
                    child: SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Text(
            number, 
            style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor)
          ),
        ],
      );
    }

    return _buildColorBadge(category, number, theme);
  }

  Widget _buildColorBadge(String category, String number, ThemeProvider theme) {
    final isHighSpeed = category.toLowerCase().contains('fr') || category.toLowerCase().contains('freccia');
    final color = isHighSpeed ? Colors.redAccent : theme.primaryColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        "$category $number",
        style: TextStyle(
          fontSize: 10, 
          fontWeight: FontWeight.w800, 
          color: color
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: color)));
  }

  Widget _buildFavoriteToggle(TrainStation station, ThemeProvider theme) {
    return Consumer2<FavoritesProvider, AuthProvider>(
        builder: (ctx, favs, auth, _) {
      if (!auth.isAuthenticated) return const SizedBox.shrink();
      final isFav = favs.isStopFavorite(station.id, StopType.trainStation,
          country: station.country);
      return IconButton(
          icon: Icon(isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : theme.secondaryTextColor),
          onPressed: () => isFav
              ? favs.removeStopFavorite(station.id, StopType.trainStation,
                  country: station.country)
              : favs.addStopFavorite(favs.createFavoriteStop(
                  userId: auth.currentUser?.id.toString() ?? '',
                  name: station.name,
                  code: station.id,
                  stopType: StopType.trainStation,
                  country: station.country)));
    });
  }

  Widget _buildDepartureArrivalToggle(
      TrainProvider provider, ThemeProvider theme) {
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: theme.secondaryTextColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Expanded(
              child: _buildToggleBtn(
                  AppLocalizations.of(context)?.departures ?? "PARTENZE",
                  !provider.isArrivalMode,
                  theme,
                  () => provider.setArrivalMode(false))),
          Expanded(
              child: _buildToggleBtn(
                  AppLocalizations.of(context)?.arrivals ?? "ARRIVI",
                  provider.isArrivalMode,
                  theme,
                  () => provider.setArrivalMode(true)))
        ]));
  }

  Widget _buildToggleBtn(
      String label, bool active, ThemeProvider theme, VoidCallback onTap) {
    return GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: active ? theme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12)),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? Colors.white : theme.secondaryTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 12))));
  }

  Widget _buildFavoriteSection(TrainProvider provider, ThemeProvider theme) {
    return Consumer2<FavoritesProvider, AuthProvider>(
        builder: (ctx, favs, auth, _) {
      if (!auth.isAuthenticated) return const SizedBox.shrink();
      final list = favs.favoriteStops
          .where((s) => s.stopType == StopType.trainStation)
          .toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return SizedBox(
          height: 90,
          child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (ctx, i) =>
                  _buildFavoriteCard(list[i], provider, theme)));
    });
  }

  Widget _buildFavoriteCard(
      FavoriteStop stop, TrainProvider provider, ThemeProvider theme) {
    return GestureDetector(
        onTap: () => provider.selectStation(TrainStation(
            id: stop.code,
            name: stop.name,
            country: stop.country ?? '',
            type: 'train')),
        child: Container(
            width: 110,
            margin: const EdgeInsets.only(right: 12, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: theme.primaryColor.withValues(alpha: 0.15))),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.star_rounded, color: theme.primaryColor, size: 18),
              const SizedBox(height: 4),
              Text(stop.name,
                  style: TextStyle(
                      color: theme.textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis)
            ])));
  }

  Widget _buildStationSuggestionsList(
      TrainProvider provider, ThemeProvider theme) {
    return ListView.builder(
        padding: const EdgeInsets.only(bottom: 100),
        itemCount: provider.stationSuggestions.length,
        itemBuilder: (ctx, i) {
          final s = provider.stationSuggestions[i];
          return _StationListTile(
            station: s,
            provider: provider,
            theme: theme,
            onLoadStats: _loadStatsAndNavigate,
            onAddStation: _addStationToDb,
          );
        });
  }
}

// Widget Scrolling Text
class _SmartTrainRouteText extends StatefulWidget {
  final dynamic departure;
  final int index;
  final ThemeProvider theme;
  final bool isArrivalMode;
  const _SmartTrainRouteText(
      {required this.departure,
      required this.index,
      required this.theme,
      required this.isArrivalMode});
  @override
  State<_SmartTrainRouteText> createState() => _SmartTrainRouteTextState();
}

class _SmartTrainRouteTextState extends State<_SmartTrainRouteText> {
  @override
  void initState() {
    super.initState();
    if (widget.isArrivalMode &&
        (widget.departure.origin == null || widget.departure.origin.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<TrainProvider>(context, listen: false)
              .expandTrainDetails(widget.index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.isArrivalMode
        ? (widget.departure.origin ??
            AppLocalizations.of(context)?.loading ??
            "Caricamento...")
        : (widget.departure.destination ?? "N/A");

    final style = TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: widget.theme.textColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();

        if (textPainter.size.width > constraints.maxWidth) {
          return SizedBox(
            height: 25,
            child: Marquee(
              text: text,
              style: style,
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              blankSpace: 30.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 0.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          );
        } else {
          return Text(text,
              style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
        }
      },
    );
  }
}

// Widget Lista Suggerimenti Stazioni
class _StationListTile extends StatefulWidget {
  final TrainStation station;
  final TrainProvider provider;
  final ThemeProvider theme;
  final Function(BuildContext, String) onLoadStats;
  final Function(String, String) onAddStation;

  const _StationListTile({
    required this.station,
    required this.provider,
    required this.theme,
    required this.onLoadStats,
    required this.onAddStation,
  });

  @override
  State<_StationListTile> createState() => _StationListTileState();
}

class _StationListTileState extends State<_StationListTile> {
  bool _isMonitored = false;
  bool _checkingStatus = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final response = await http.get(Uri.parse(
          'https://betacloud-transporter.is-cool.dev/api/stats/monitor/check/${widget.station.id}'));
      if (response.statusCode == 200 && mounted) {
        final data = json.decode(response.body);
        setState(() {
          _isMonitored = data['isMonitored'] ?? false;
          _checkingStatus = false;
        });
      }
    } catch (e) {
      debugPrint("Errore controllo automatico stazione ${widget.station.id}: $e");
      if (mounted) setState(() => _checkingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.location_on_outlined, color: widget.theme.primaryColor),
      title: Text(widget.station.name,
          style: TextStyle(color: widget.theme.textColor, fontWeight: FontWeight.bold)),
      subtitle: Text(widget.station.country,
          style: TextStyle(color: widget.theme.secondaryTextColor, fontSize: 12)),
      trailing: _checkingStatus
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: _isMonitored ? widget.theme.primaryColor : widget.theme.secondaryTextColor,
              ),
              onPressed: () async {
                if (_isMonitored) {
                  await widget.onLoadStats(context, widget.station.id);
                } else {
                  _showManualAddDialog();
                }
              },
            ),
      onTap: () => widget.provider.selectStation(widget.station),
    );
  }

  void _showManualAddDialog() {
        showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.theme.surfaceColor,
        title: Text(
          RuntimeLocalizations.t(context, 'activate_monitoring'), 
          style: TextStyle(color: widget.theme.textColor, fontWeight: FontWeight.bold)
        ),
        content: Text(
          RuntimeLocalizations.t(context, 'station_not_monitored_msg'), 
          style: TextStyle(color: widget.theme.secondaryTextColor)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              RuntimeLocalizations.t(context, 'cancel'), 
              style: TextStyle(color: widget.theme.secondaryTextColor)
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primaryColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onAddStation(widget.station.id, widget.station.name);
              _checkStatus();
            },
            child: Text(
              RuntimeLocalizations.t(context, 'add_now'), 
              style: const TextStyle(color: Colors.white)
            ),
          ),
        ],
      ),
    );
  }
}
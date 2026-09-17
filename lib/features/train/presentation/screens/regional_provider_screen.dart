import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../core/design_system.dart';
import '../../data/models/regional_provider_model.dart';
import '../widgets/regional_train_details_sheet.dart';
import 'news_browser_screen.dart';

class RegionalProviderScreen extends StatefulWidget {
  final RegionalProvider provider;

  const RegionalProviderScreen({super.key, required this.provider});

  @override
  State<RegionalProviderScreen> createState() => _RegionalProviderScreenState();
}

class _RegionalProviderScreenState extends State<RegionalProviderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedStationId;
  String? _selectedStationName;
  List<Map<String, dynamic>> _stations = [];
  List<Map<String, dynamic>> _departures = [];
  List<Map<String, dynamic>> _arrivals = [];
  List<Map<String, dynamic>> _news = [];
  bool _loadingStations = true;
  bool _loadingDepartures = false;
  bool _loadingArrivals = false;
  bool _loadingNews = false;
  final TextEditingController _stationSearchController = TextEditingController();
  String _stationQuery = '';
  Timer? _stationSearchDebounce;
  Timer? _autoRefreshTimer;
  bool _searchingStations = false;

  @override
  void initState() {
    super.initState();
    final tabs = <Tab>[];
    if (widget.provider.endpoints.stations) tabs.add(const Tab(text: 'Stazioni'));
    if (widget.provider.endpoints.departures) tabs.add(const Tab(text: 'Partenze'));
    if (widget.provider.endpoints.arrivals) tabs.add(const Tab(text: 'Arrivi'));
    if (widget.provider.endpoints.news) tabs.add(const Tab(text: 'News'));
    if (tabs.isEmpty) tabs.add(const Tab(text: 'Dettagli'));
    _tabController = TabController(length: tabs.length, vsync: this);
    _loadStations();
    if (widget.provider.endpoints.news) _loadNews();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _stationSearchDebounce?.cancel();
    _tabController.dispose();
    _stationSearchController.dispose();
    super.dispose();
  }

  /// Auto-refresh dei tabelloni live (partenze/arrivi) seguendo le impostazioni
  /// (stesso intervallo usato dal resto dell'app: SettingsProvider.trainRefreshSeconds).
  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    final interval = Provider.of<SettingsProvider>(context, listen: false).trainRefreshSeconds;
    if (interval > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(seconds: interval), (_) => _silentRefresh());
    }
  }

  void _toggleAutoRefresh() {
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer!.cancel();
      _autoRefreshTimer = null;
    } else {
      _startAutoRefresh();
    }
    if (mounted) setState(() {});
  }

  /// Ricarica manuale immediata (con feedback visivo).
  void _manualRefresh() {
    final stationId = _selectedStationId;
    if (stationId == null) {
      _loadStations(query: _stationQuery);
      return;
    }
    if (widget.provider.endpoints.departures) _loadDepartures(stationId);
    if (widget.provider.endpoints.arrivals) _loadArrivals(stationId);
  }

  /// Ricarica silenziosa (senza spinner) dei dati live della stazione selezionata.
  void _silentRefresh() {
    if (!mounted) return;
    final stationId = _selectedStationId;
    if (stationId == null) return;
    if (widget.provider.endpoints.departures) _loadDepartures(stationId, silent: true);
    if (widget.provider.endpoints.arrivals) _loadArrivals(stationId, silent: true);
  }

  String get _baseUrl => widget.provider.fullApiUrl;

  /// Ricerca stazioni lato server:
  /// GET /api/:country/trains/:provider/stations?query=<q>&limit=<n>
  /// (stesso endpoint usato dalla lista iniziale, con query opzionale).
  Future<void> _loadStations({String query = '', bool silent = false}) async {
    final q = query.trim();
    if (!silent) setState(() => _loadingStations = true);
    if (silent) setState(() => _searchingStations = true);
    try {
      final url = q.isEmpty
          ? '$_baseUrl/stations?limit=100'
          : '$_baseUrl/stations?query=${Uri.encodeComponent(q)}&limit=50';
      debugPrint('[RegionalProvider] Loading stations: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        if (mounted) {
          // Ignora risposte obsolete (query cambiata nel frattempo)
          if (q != _stationQuery.trim()) return;
          setState(() {
            _stations = list.cast<Map<String, dynamic>>();
            _loadingStations = false;
            _searchingStations = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingStations = false;
            _searchingStations = false;
          });
        }
      }
    } catch (e) {
      debugPrint('[RegionalProvider] Error loading stations: $e');
      if (mounted) {
        setState(() {
          _loadingStations = false;
          _searchingStations = false;
        });
      }
    }
  }

  /// Ricerca con debounce: query vuota -> lista completa, altrimenti API con query.
  void _onStationSearchChanged(String value) {
    setState(() => _stationQuery = value);
    _stationSearchDebounce?.cancel();
    if (value.trim().isEmpty) {
      _loadStations();
      return;
    }
    _stationSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _loadStations(query: _stationQuery, silent: true);
    });
  }

  Future<void> _loadDepartures(String stationId, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingDepartures = true;
        _departures = [];
      });
    }
    try {
      final url = '$_baseUrl/departures?stationId=$stationId';
      debugPrint('[RegionalProvider] Loading departures: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _departures = list.cast<Map<String, dynamic>>();
            _loadingDepartures = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingDepartures = false);
      }
    } catch (e) {
      debugPrint('[RegionalProvider] Error loading departures: $e');
      if (mounted) setState(() => _loadingDepartures = false);
    }
  }

  Future<void> _loadArrivals(String stationId, {bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loadingArrivals = true;
        _arrivals = [];
      });
    }
    try {
      final url = '$_baseUrl/arrivals?stationId=$stationId';
      debugPrint('[RegionalProvider] Loading arrivals: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _arrivals = list.cast<Map<String, dynamic>>();
            _loadingArrivals = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingArrivals = false);
      }
    } catch (e) {
      debugPrint('[RegionalProvider] Error loading arrivals: $e');
      if (mounted) setState(() => _loadingArrivals = false);
    }
  }

  Future<void> _loadNews() async {
    setState(() {
      _loadingNews = true;
      _news = [];
    });
    try {
      final url = '$_baseUrl/news';
      debugPrint('[RegionalProvider] Loading news: $url');
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _news = list.cast<Map<String, dynamic>>();
            _loadingNews = false;
          });
        }
      } else {
        if (mounted) setState(() => _loadingNews = false);
      }
    } catch (e) {
      debugPrint('[RegionalProvider] Error loading news: $e');
      if (mounted) setState(() => _loadingNews = false);
    }
  }

  void _onStationSelected(String stationId, String stationName) {
    setState(() {
      _selectedStationId = stationId;
      _selectedStationName = stationName;
    });
    if (widget.provider.endpoints.departures) _loadDepartures(stationId);
    if (widget.provider.endpoints.arrivals) _loadArrivals(stationId);
  }

  void _onDepartureTap(Map<String, dynamic> departure) {
    final tripId = departure['tripId'] ?? '';
    final tripNumber = departure['tripNumber'] ?? '';
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegionalTrainDetailsSheet(
          provider: widget.provider,
          trainNumber: tripNumber.toString(),
          tripId: tripId.toString(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = _autoRefreshTimer != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.provider.provider, style: const TextStyle(fontSize: 18)),
            Text(
              widget.provider.description,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.outline),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Aggiorna ora',
            onPressed: _manualRefresh,
          ),
          IconButton(
            icon: Icon(live ? Icons.timer_rounded : Icons.timer_off_rounded),
            color: live ? theme.colorScheme.primary : theme.colorScheme.outline,
            tooltip: live ? 'Auto-aggiornamento attivo' : 'Auto-aggiornamento disattivo',
            onPressed: _toggleAutoRefresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          tabs: [
            if (widget.provider.endpoints.stations) const Tab(icon: Icon(Icons.location_on), text: 'Stazioni'),
            if (widget.provider.endpoints.departures) const Tab(icon: Icon(Icons.departure_board), text: 'Partenze'),
            if (widget.provider.endpoints.arrivals) const Tab(icon: Icon(Icons.assignment_return), text: 'Arrivi'),
            if (widget.provider.endpoints.news) const Tab(icon: Icon(Icons.newspaper), text: 'News'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          if (widget.provider.endpoints.stations) _buildStationsTab(theme),
          if (widget.provider.endpoints.departures) _buildDeparturesTab(theme),
          if (widget.provider.endpoints.arrivals) _buildArrivalsTab(theme),
          if (widget.provider.endpoints.news) _buildNewsTab(theme),
        ],
      ),
    );
  }

  Widget _buildStationsTab(ThemeData theme) {
    if (_loadingStations) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _stationSearchController,
            decoration: InputDecoration(
              hintText: 'Cerca stazione...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchingStations
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _stationQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _stationSearchController.clear();
                            _onStationSearchChanged('');
                          },
                        )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: _onStationSearchChanged,
          ),
        ),
        if (_stations.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _stationQuery.trim().isNotEmpty
                    ? 'Nessuna stazione per "$_stationQuery"'
                    : 'Nessuna stazione trovata',
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _stations.length,
              itemBuilder: (context, index) {
                final station = _stations[index];
                final id = station['id']?.toString() ?? '';
                final name = station['name']?.toString() ?? '';
                final isSelected = id == _selectedStationId;

                return ListTile(
                  // Icona treno come nel details sheet (_TrainIcon):
                  // cerchio pieno trainColor con icona bianca.
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTokens.trainColor
                          : AppTokens.trainColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.train_rounded,
                      color: isSelected
                          ? Colors.white
                          : AppTokens.trainColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                      : const Icon(Icons.chevron_right),
                  onTap: () => _onStationSelected(id, name),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildDeparturesTab(ThemeData theme) {
    if (_selectedStationId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Seleziona una stazione dalla tab Stazioni',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    if (_loadingDepartures) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_departures.isEmpty) {
      return Center(child: Text('Nessuna partenza da $_selectedStationName'));
    }

    return RefreshIndicator(
      onRefresh: () => _loadDepartures(_selectedStationId!),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _departures.length,
        itemBuilder: (context, index) => _buildDepartureCard(theme, _departures[index], isArrivals: false),
      ),
    );
  }

  Widget _buildArrivalsTab(ThemeData theme) {
    if (_selectedStationId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_on, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Seleziona una stazione dalla tab Stazioni',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    if (_loadingArrivals) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_arrivals.isEmpty) {
      return Center(child: Text('Nessun arrivo a $_selectedStationName'));
    }

    return RefreshIndicator(
      onRefresh: () => _loadArrivals(_selectedStationId!),
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _arrivals.length,
        itemBuilder: (context, index) => _buildDepartureCard(theme, _arrivals[index], isArrivals: true),
      ),
    );
  }

  Widget _buildNewsTab(ThemeData theme) {
    if (_loadingNews) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_news.isEmpty) {
      return const Center(child: Text('Nessuna news al momento'));
    }

    return RefreshIndicator(
      onRefresh: _loadNews,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _news.length,
        itemBuilder: (context, index) => _buildNewsCard(theme, _news[index]),
      ),
    );
  }

  Widget _buildNewsCard(ThemeData theme, Map<String, dynamic> item) {
    final title = item['title']?.toString() ?? '';
    final shortTitle = item['shortTitle']?.toString() ?? '';
    final shortText = item['shortText60']?.toString() ?? '';
    final description = item['description']?.toString() ?? '';
    final severity = item['severity']?.toString() ?? '';
    final direttrice = item['direttrice']?.toString() ?? '';
    final validFrom = item['validFrom']?.toString() ?? '';
    final validTo = item['validTo']?.toString() ?? '';
    final trains = item['trains'] as List<dynamic>? ?? [];

    final header = title.isNotEmpty
        ? title
        : (shortTitle.isNotEmpty ? shortTitle : (shortText.isNotEmpty ? shortText : 'Avviso'));
    final isAlert = severity.isNotEmpty && severity != '0';
    final urls = _extractUrls(description, item['links']);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: Icon(
          isAlert ? Icons.warning_amber_rounded : Icons.info_outline,
          color: isAlert ? theme.colorScheme.error : theme.colorScheme.primary,
        ),
        title: Text(
          header,
          style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (direttrice.isNotEmpty)
              Text('Linea: $direttrice', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
            if (validFrom.isNotEmpty || validTo.isNotEmpty)
              Text(
                'Validità: ${_formatDate(validFrom)}${validTo.isNotEmpty ? ' → ${_formatDate(validTo)}' : ''}',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Text(description, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                for (final url in urls) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _openNewsLink(url, header),
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, size: 14, color: theme.colorScheme.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            url,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.primary,
                              decoration: TextDecoration.underline,
                              decorationColor: theme.colorScheme.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (trains.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Treni coinvolti: ${trains.length}',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Estrae gli URL dal testo della news + quelli forniti dal backend (links), senza duplicati.
  List<String> _extractUrls(String text, dynamic backendLinks) {
    final urls = <String>[];
    final urlRegExp = RegExp(r'https?://[^\s)>\]]+');
    for (final match in urlRegExp.allMatches(text)) {
      var url = match.group(0) ?? '';
      // Rimuove punteggiatura finale che non fa parte dell'URL
      url = url.replaceAll(RegExp(r'[.,;:!?]+$'), '');
      if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
    }
    if (backendLinks is List) {
      for (final link in backendLinks) {
        final url = link?.toString().trim() ?? '';
        if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
      }
    }
    return urls;
  }

  /// Apre il link nel browser interno all'app.
  void _openNewsLink(String url, String newsTitle) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => NewsBrowserScreen(url: url, title: newsTitle),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.length >= 10 ? raw.substring(0, 10) : raw;
    }
  }

  Widget _buildDepartureCard(ThemeData theme, Map<String, dynamic> item, {required bool isArrivals}) {
    final tripNumber = item['tripNumber']?.toString() ?? '';
    final category = item['category']?.toString() ?? '';
    final destination = item['destination']?.toString() ?? '';
    final origin = item['origin']?.toString() ?? '';
    final scheduledTime = item['scheduledTime']?.toString() ?? '';
    final estimatedTime = item['estimatedTime']?.toString() ?? '';
    final delay = item['delay'] ?? 0;
    final platform = item['platform']?.toString() ?? '-';
    final cancelled = item['cancelled'] == true;

    // La stazione corrente (selezionata) non si scrive mai nella riga:
    // in Partenze si mostra la destinazione, in Arrivi la provenienza.
    final current = (_selectedStationName ?? '').trim().toLowerCase();
    bool isCurrent(String name) => name.trim().toLowerCase() == current;
    final mainStation = isArrivals ? origin : destination;
    final subStation = isArrivals ? destination : origin;
    final showSub = subStation.isNotEmpty && !isCurrent(subStation);

    final time = _formatTime(estimatedTime.isNotEmpty ? estimatedTime : scheduledTime);
    final delayInt = delay is int ? delay : int.tryParse(delay.toString()) ?? 0;
    // Il backend non fornisce il binario (upstream FAL/Trenord non lo espone):
    // mostra il box solo quando il dato esiste davvero.
    final platformStr = platform.trim();
    final hasPlatform = platformStr.isNotEmpty && platformStr != '-' && platformStr.toLowerCase() != 'null';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _onDepartureTap(item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Orario + ritardo
                Column(
                  children: [
                    Text(
                      time,
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -1),
                    ),
                    if (cancelled)
                      _buildBadge('CANC', Colors.red)
                    else if (delayInt > 0)
                      _buildBadge('+$delayInt\'', Colors.orange)
                    else
                      const Text(
                        'In orario',
                        style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge categoria + numero treno
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${category.isNotEmpty ? '$category ' : ''}$tripNumber'.trim(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Stazione "altra" rispetto a quella corrente:
                      // destinazione in Partenze, provenienza in Arrivi.
                      // La stazione corrente non si scrive mai.
                      if (showSub)
                        Text(
                          subStation,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      Text(
                        mainStation.isNotEmpty ? mainStation : '--',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Box binario (solo se il backend lo fornisce)
                if (hasPlatform)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Bin',
                          style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        Text(
                          platformStr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '--:--';
    try {
      // Il backend fornisce ISO UTC: convertire sempre in ora locale
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (isoTime.contains('T')) {
        final parts = isoTime.split('T');
        if (parts.length > 1) {
          final timeParts = parts[1].substring(0, 5).split(':');
          return '${timeParts[0]}:${timeParts[1]}';
        }
      }
      return isoTime.length >= 5 ? isoTime.substring(0, 5) : isoTime;
    }
  }
}

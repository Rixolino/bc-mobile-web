import 'package:flutter/material.dart';
import '../../data/models/roadway_news_model.dart';
import '../../data/models/roadway_toll_model.dart';
import '../../data/models/roadway_service_model.dart';
import '../../data/services/roadway_service.dart';

class RoadwaysPage extends StatefulWidget {
  const RoadwaysPage({super.key});

  @override
  State<RoadwaysPage> createState() => _RoadwaysPageState();
}

class _RoadwaysPageState extends State<RoadwaysPage>
    with SingleTickerProviderStateMixin {
  final RoadwayService _service = RoadwayService(country: 'it');
  late TabController _tabController;

  Future<List<RoadwayNews>>? _newsFuture;
  Future<({List<RoadwayToll> tolls, String? note})>? _tollsFuture;
  Future<List<RoadwayAreaService>>? _servicesFuture;

  String _servicesFilter = '';
  String _country = 'it'; // 'it' | 'de'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  Future<void> _refreshData() async {
    _service.country = _country;
    setState(() {
      _newsFuture = _service.fetchNews();
      _tollsFuture = _service.fetchTolls();
      _servicesFuture = _service.fetchAreaServices();
      _servicesFilter = '';
    });

    await Future.wait([
      _newsFuture ?? Future.value([]),
      _tollsFuture ?? Future.value((tolls: <RoadwayToll>[], note: null)),
      _servicesFuture ?? Future.value([]),
    ]);
  }

  void _setCountry(String country) {
    if (_country == country) return;
    setState(() => _country = country);
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIt = _country == 'it';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          isIt ? 'Servizi Autostradali' : 'Autobahn-Services',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: SegmentedButton<String>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: 'it',
                  label: Text('IT'),
                  icon: Icon(Icons.flag, size: 16),
                ),
                ButtonSegment(
                  value: 'de',
                  label: Text('DE'),
                  icon: Icon(Icons.flag, size: 16),
                ),
              ],
              selected: {_country},
              onSelectionChanged: (s) => _setCountry(s.first),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: isIt ? 'Aggiorna' : 'Aktualisieren',
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: [
            Tab(
              text: isIt ? 'Notizie' : 'Meldungen',
              icon: const Icon(Icons.campaign_rounded),
            ),
            Tab(
              text: isIt ? 'Caselli' : 'Maut',
              icon: const Icon(Icons.euro_rounded),
            ),
            Tab(
              text: isIt ? 'Servizi' : 'Rastanlagen',
              icon: const Icon(Icons.local_gas_station_rounded),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewsTab(),
          _buildTollsTab(),
          _buildServicesTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // NEWS
  // ---------------------------------------------------------------------------

  Widget _buildNewsTab() {
    final theme = Theme.of(context);
    final isIt = _country == 'it';

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<RoadwayNews>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(
              theme,
              isIt
                  ? 'Errore nel caricamento notizie.'
                  : 'Fehler beim Laden der Meldungen.',
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              theme,
              isIt
                  ? 'Nessuna notizia disponibile.'
                  : 'Keine Meldungen verfügbar.',
              Icons.check_circle_outline,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              return _buildNewsCard(snapshot.data![index], theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(RoadwayNews news, ThemeData theme) {
    final typeColor = _newsTypeColor(news.type, theme);
    final typeIcon = _newsTypeIcon(news.type);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(typeIcon, color: typeColor, size: 24),
          ),
          title: Text(
            news.title.isNotEmpty ? news.title : news.description,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (news.location.isNotEmpty) news.location,
                    if (news.direction.isNotEmpty) news.direction,
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (news.type.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      news.type.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (news.description.isNotEmpty)
                    Text(
                      news.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  if (news.cause != null && news.cause!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Causa: ${news.cause}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (news.from != null || news.to != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tratta: ${news.from ?? "—"} → ${news.to ?? "—"}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  if (news.queueKm != null && news.queueKm! > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Coda: ${news.queueKm!.toStringAsFixed(1)} km'
                      '${news.delayMinutes != null ? " · Ritardo ${news.delayMinutes} min" : ""}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          news.date,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _newsTypeColor(String type, ThemeData theme) {
    switch (type.toLowerCase()) {
      case 'closure':
      case 'event':
        return theme.colorScheme.error;
      case 'warning':
        return Colors.orange;
      case 'roadworks':
        return Colors.amber.shade700;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _newsTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'closure':
        return Icons.block_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'roadworks':
        return Icons.construction_rounded;
      case 'event':
        return Icons.info_outline_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  // ---------------------------------------------------------------------------
  // TOLLS / CASELLI
  // ---------------------------------------------------------------------------

  Widget _buildTollsTab() {
    final theme = Theme.of(context);
    final isIt = _country == 'it';

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<({List<RoadwayToll> tolls, String? note})>(
        future: _tollsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(
              theme,
              isIt
                  ? 'Errore nel caricamento caselli.'
                  : 'Fehler beim Laden der Mautdaten.',
            );
          }

          final result = snapshot.data;
          final tolls = result?.tolls ?? [];
          final note = result?.note;

          if (tolls.isEmpty) {
            return _buildEmptyState(
              theme,
              note ??
                  (isIt
                      ? 'Caselli non disponibili.'
                      : 'In Deutschland gibt es keine physischen Mautstationen für Pkw.'),
              Icons.money_off_rounded,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: tolls.length,
            itemBuilder: (context, index) {
              return _buildTollCard(tolls[index], theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildTollCard(RoadwayToll toll, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.toll_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          title: Text(
            toll.name,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            [
              if (toll.highway.isNotEmpty) toll.highway,
              if (toll.highwayDescription.isNotEmpty) toll.highwayDescription,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (toll.address.isNotEmpty)
                    Text(toll.address, style: theme.textTheme.bodySmall),
                  if (toll.km > 0)
                    Text(
                      'Km ${toll.km.toStringAsFixed(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (toll.paymentMethods.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Pagamenti:',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Wrap(
                      spacing: 6,
                      children: toll.paymentMethods
                          .map((pm) => Chip(
                                label: Text(pm.description.isNotEmpty
                                    ? pm.description
                                    : pm.code),
                                visualDensity: VisualDensity.compact,
                              ))
                          .toList(),
                    ),
                  ],
                  if (toll.entranceGates.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Porte entrata: ${toll.entranceGates.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (toll.exitGates.isNotEmpty)
                    Text(
                      'Porte uscita: ${toll.exitGates.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                  Text(
                    'Stato: ${toll.status}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: toll.status == 'OPEN'
                          ? theme.colorScheme.primary
                          : theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SERVICES / RASTANLAGEN
  // ---------------------------------------------------------------------------

  Widget _buildServicesTab() {
    final theme = Theme.of(context);
    final isIt = _country == 'it';

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<RoadwayAreaService>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(
              theme,
              isIt
                  ? 'Errore nel caricamento servizi.'
                  : 'Fehler beim Laden der Rastanlagen.',
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              theme,
              isIt
                  ? 'Servizi non disponibili.'
                  : 'Keine Rastanlagen verfügbar.',
              Icons.local_gas_station_rounded,
            );
          }

          final allAreas = snapshot.data!;
          final filteredAreas = allAreas
              .where((area) => area.highway
                  .toLowerCase()
                  .contains(_servicesFilter.toLowerCase()))
              .toList();

          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  children: _buildHighwayFilterChips(allAreas, theme),
                ),
              ),
              Expanded(
                child: filteredAreas.isEmpty
                    ? _buildEmptyState(
                        theme,
                        isIt
                            ? 'Nessuna area trovata per questo filtro.'
                            : 'Keine Anlagen für diesen Filter.',
                        Icons.search_off_rounded,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: filteredAreas.length,
                        itemBuilder: (context, index) {
                          return _AreaServiceCardItem(
                            area: filteredAreas[index],
                            theme: theme,
                            isGerman: _country == 'de',
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildHighwayFilterChips(
    List<RoadwayAreaService> areas,
    ThemeData theme,
  ) {
    final highways = areas
        .map((area) => area.highway)
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(_country == 'it' ? 'Tutte' : 'Alle'),
          selected: _servicesFilter.isEmpty,
          onSelected: (_) => setState(() => _servicesFilter = ''),
          labelStyle: TextStyle(
            color: _servicesFilter.isEmpty
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
          selectedColor: theme.colorScheme.primary,
          checkmarkColor: theme.colorScheme.onPrimary,
        ),
      ),
      ...highways.map((highway) {
        final isSelected = _servicesFilter == highway;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text(highway),
            selected: isSelected,
            onSelected: (selected) {
              setState(() {
                _servicesFilter = selected ? highway : '';
              });
            },
            labelStyle: TextStyle(
              color: isSelected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            selectedColor: theme.colorScheme.primary,
            checkmarkColor: theme.colorScheme.onPrimary,
          ),
        );
      }),
    ];
  }

  // ---------------------------------------------------------------------------
  // EMPTY / ERROR
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 64, color: theme.colorScheme.surfaceContainerHighest),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// CARD AREA DI SERVIZIO
// =============================================================================

class _AreaServiceCardItem extends StatefulWidget {
  final RoadwayAreaService area;
  final ThemeData theme;
  final bool isGerman;

  const _AreaServiceCardItem({
    required this.area,
    required this.theme,
    this.isGerman = false,
  });

  @override
  State<_AreaServiceCardItem> createState() => _AreaServiceCardItemState();
}

class _AreaServiceCardItemState extends State<_AreaServiceCardItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final area = widget.area;
    final fuelBrand = area.fuelBrand;
    final foodBrands = area.foodBrands;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) {
            setState(() => _isExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fuelBrand.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fuelBrand,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.expand_more_rounded),
              ),
            ],
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_gas_station_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          title: Row(
            children: [
              if (foodBrands.isNotEmpty) ...[
                ...foodBrands.take(2).map(
                      (brand) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                          ),
                          child: Text(
                            brand,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
              Expanded(
                child: Text(
                  area.name,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isGerman
                    ? 'Autobahn ${area.highway}'
                    : 'Autostrada ${area.highway}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (area.highwayDescription.isNotEmpty)
                Text(
                  area.highwayDescription,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (area.km > 0)
                Text(
                  'Km ${area.km.toStringAsFixed(1)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (area.direction.isNotEmpty &&
                      area.direction.toLowerCase() != 'undefined')
                    Text(
                      widget.isGerman
                          ? 'Richtung: ${area.direction}'
                          : 'Direzione: ${area.direction}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (area.from.isNotEmpty || area.to.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        widget.isGerman
                            ? 'Strecke: ${area.from} → ${area.to}'
                            : 'Tratta: ${area.from} → ${area.to}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (area.descriptionAdsPmr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'PMR: ${area.descriptionAdsPmr}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (area.parking != null) ...[
                    if (area.parking!.carSpaces != null ||
                        area.parking!.truckSpaces != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Parkplätze: '
                          '${area.parking!.carSpaces != null ? "PKW ${area.parking!.carSpaces}" : ""}'
                          '${area.parking!.carSpaces != null && area.parking!.truckSpaces != null ? " · " : ""}'
                          '${area.parking!.truckSpaces != null ? "LKW ${area.parking!.truckSpaces}" : ""}'
                          '${area.parking!.isBlocked == true ? " (gesperrt)" : ""}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                  if (area.fuelPrices.values.any((f) => f.price > 0)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Text(
                        widget.isGerman ? 'Kraftstoff:' : 'Carburanti:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    ..._buildFuelPriceRows(area, theme),
                  ],
                ],
              ),
            ),
            if (area.events.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16.0),
                color: theme.colorScheme.errorContainer.withOpacity(0.2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: area.events.map((event) {
                    final text = event.title.isNotEmpty
                        ? event.title
                        : event.description;
                    final date = event.createdAt ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 16, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              date.isNotEmpty ? '$text ($date)' : text,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            if (area.services.isNotEmpty) ...[
              const Divider(height: 1),
              Container(
                padding: const EdgeInsets.all(16.0),
                color:
                    theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                child: SizedBox(
                  height: 110,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: area.services.map((service) {
                      final available = service.available ?? 0;
                      final total = service.total ?? 0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              service.name.isNotEmpty
                                  ? service.name
                                  : service.code,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (total > 0 || available > 0)
                              Text(
                                total > 0 ? '$available / $total' : '$available',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: available > 0
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                ),
                              ),
                            if (service.unavailableSince != null &&
                                service.unavailableSince!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  service.unavailableSince!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            if (area.brands.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isGerman ? 'Anbieter' : 'Esercenti',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: area.brands.map((brand) {
                        final label = brand.name.isNotEmpty
                            ? brand.name
                            : (brand.nameSecond.isNotEmpty
                                ? brand.nameSecond
                                : brand.type);
                        return Chip(
                          label: Text(label),
                          avatar: Icon(_iconForBrandType(brand.type), size: 16),
                          visualDensity: VisualDensity.compact,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFuelPriceRows(RoadwayAreaService area, ThemeData theme) {
    const labels = {
      'benzina': 'Benzina',
      'diesel': 'Diesel',
      'gpl': 'GPL',
      'metano': 'Metano',
    };

    final rows = <Widget>[];
    for (final entry in labels.entries) {
      final price = area.fuelPrices[entry.key];
      if (price == null || price.price <= 0) continue;
      final update = price.lastUpdate != null && price.lastUpdate!.isNotEmpty
          ? ' (${_shortDate(price.lastUpdate!)})'
          : '';
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 2.0),
          child: Text(
            '${entry.value}: €${price.price.toStringAsFixed(3)}/L$update',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      );
    }
    return rows;
  }

  String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  IconData _iconForBrandType(String type) {
    final t = type.toUpperCase();
    if (t == 'OIL' || t.contains('FUEL') || t.contains('CARB')) {
      return Icons.local_gas_station_rounded;
    }
    if (t == 'FOOD' || t.contains('RIST') || t.contains('BAR')) {
      return Icons.restaurant_rounded;
    }
    if (t.contains('ELECTRIC') || t.contains('CHARG')) {
      return Icons.ev_station_rounded;
    }
    return Icons.storefront_rounded;
  }
}
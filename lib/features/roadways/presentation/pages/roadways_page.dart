import 'package:flutter/material.dart';
import '../../data/models/roadway_news_model.dart';
import '../../data/models/roadway_toll_model.dart';
import '../../data/models/roadway_service_model.dart';
import '../../data/services/roadway_service.dart';
import '../../utils/brand_logos.dart';

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

  /// Mostra il Popup (Modal Bottom Sheet M3) per la selezione della nazionalità
  void _showCountryPicker() {
    final theme = Theme.of(context);
    final isIt = _country == 'it';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.brightness == Brightness.light ? Colors.white : const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Indicatore trascinamento superiore
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    isIt ? 'Seleziona Nazione' : 'Land auswählen',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCountryOption(
                  code: 'it',
                  name: 'Italia',
                  subtitle: 'Servizi autostradali IT',
                  icon: Icons.flag_rounded,
                  theme: theme,
                ),
                const SizedBox(height: 10),
                _buildCountryOption(
                  code: 'de',
                  name: 'Germania (Deutschland)',
                  subtitle: 'Autobahn-Services DE',
                  icon: Icons.flag_rounded,
                  theme: theme,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountryOption({
    required String code,
    required String name,
    required String subtitle,
    required IconData icon,
    required ThemeData theme,
  }) {
    final isSelected = _country == code;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _setCountry(code);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primaryContainer.withOpacity(0.4)
              : theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
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

    // Fissione dinamica tra primario e sfondo per eliminare il grigio
    final baseBgColor = theme.brightness == Brightness.light ? Colors.white : const Color(0xFF121212);
    final tintedBackground = Color.alphaBlend(
      theme.colorScheme.primary.withOpacity(0.08),
      baseBgColor,
    );

    return Scaffold(
      backgroundColor: tintedBackground,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          isIt ? 'Servizi Autostradali' : 'Autobahn-Services',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          // Bottone Popup Nazionalità
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _showCountryPicker,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.language_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _country.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(100),
          ),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          splashBorderRadius: BorderRadius.circular(100),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshData,
        elevation: 2,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        tooltip: isIt ? 'Aggiorna' : 'Aktualisieren',
        child: const Icon(Icons.refresh_rounded),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER PER LE CARD MATERIAL 3
  // ---------------------------------------------------------------------------
  BoxDecoration _m3CardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: theme.colorScheme.primary.withOpacity(0.15),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
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
              isIt ? 'Errore nel caricamento notizie.' : 'Fehler beim Laden der Meldungen.',
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              theme,
              isIt ? 'Nessuna notizia disponibile.' : 'Keine Meldungen verfügbar.',
              Icons.check_circle_outline,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _m3CardDecoration(theme),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(typeIcon, color: typeColor, size: 26),
          ),
          title: Text(
            news.title.isNotEmpty ? news.title : news.description,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [
                    if (news.location.isNotEmpty) news.location,
                    if (news.direction.isNotEmpty) news.direction,
                  ].join(' • '),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (news.type.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        news.type.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (news.description.isNotEmpty)
                    Text(
                      news.description,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                    ),
                  if (news.cause != null && news.cause!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Causa: ${news.cause}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (news.from != null || news.to != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.route_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tratta: ${news.from ?? "—"} → ${news.to ?? "—"}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (news.queueKm != null && news.queueKm! > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            'Coda: ${news.queueKm!.toStringAsFixed(1)} km'
                            '${news.delayMinutes != null ? " · Ritardo ${news.delayMinutes} min" : ""}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.access_time_filled_rounded, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        news.date,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
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
        return Colors.orange.shade600;
      case 'roadworks':
        return Colors.amber.shade700;
      default:
        return theme.colorScheme.primary;
    }
  }

  IconData _newsTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'closure': return Icons.block_rounded;
      case 'warning': return Icons.warning_rounded;
      case 'roadworks': return Icons.construction_rounded;
      case 'event': return Icons.event_note_rounded;
      default: return Icons.campaign_rounded;
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
              isIt ? 'Errore nel caricamento caselli.' : 'Fehler beim Laden der Mautdaten.',
            );
          }

          final result = snapshot.data;
          final tolls = result?.tolls ?? [];
          final note = result?.note;

          if (tolls.isEmpty) {
            return _buildEmptyState(
              theme,
              note ?? (isIt ? 'Caselli non disponibili.' : 'In Deutschland gibt es keine physischen Mautstationen für Pkw.'),
              Icons.money_off_rounded,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 80),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _m3CardDecoration(theme),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.toll_rounded,
              color: theme.colorScheme.onSecondaryContainer,
              size: 26,
            ),
          ),
          title: Text(
            toll.name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              [
                if (toll.highway.isNotEmpty) toll.highway,
                if (toll.highwayDescription.isNotEmpty) toll.highwayDescription,
              ].join(' • '),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (toll.address.isNotEmpty)
                    Text(toll.address, style: theme.textTheme.bodyMedium),
                  if (toll.km > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Km ${toll.km.toStringAsFixed(1)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (toll.paymentMethods.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'METODI DI PAGAMENTO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: toll.paymentMethods
                          .map((pm) => Chip(
                                label: Text(pm.description.isNotEmpty ? pm.description : pm.code),
                                backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (toll.entranceGates.isNotEmpty) 
                              Text('Porte entrata: ${toll.entranceGates.length}', style: theme.textTheme.bodyMedium),
                            if (toll.exitGates.isNotEmpty) 
                              Text('Porte uscita: ${toll.exitGates.length}', style: theme.textTheme.bodyMedium),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: toll.status == 'OPEN' 
                                ? Colors.green.withOpacity(0.1) 
                                : theme.colorScheme.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            toll.status,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: toll.status == 'OPEN' ? Colors.green.shade700 : theme.colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
              isIt ? 'Errore nel caricamento servizi.' : 'Fehler beim Laden der Rastanlagen.',
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(
              theme,
              isIt ? 'Servizi non disponibili.' : 'Keine Rastanlagen verfügbar.',
              Icons.local_gas_station_rounded,
            );
          }

          final allAreas = snapshot.data!;
          final filteredAreas = allAreas
              .where((area) => area.highway.toLowerCase().contains(_servicesFilter.toLowerCase()))
              .toList();

          return Column(
            children: [
              Container(
                height: 56,
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _buildHighwayFilterChips(allAreas, theme),
                ),
              ),
              Expanded(
                child: filteredAreas.isEmpty
                    ? _buildEmptyState(
                        theme,
                        isIt ? 'Nessuna area trovata per questo filtro.' : 'Keine Anlagen für diesen Filter.',
                        Icons.search_off_rounded,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 80),
                        itemCount: filteredAreas.length,
                        itemBuilder: (context, index) {
                          return _AreaServiceCardItem(
                            area: filteredAreas[index],
                            theme: theme,
                            isGerman: _country == 'de',
                            decoration: _m3CardDecoration(theme),
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

  List<Widget> _buildHighwayFilterChips(List<RoadwayAreaService> areas, ThemeData theme) {
    final highways = areas.map((area) => area.highway).where((h) => h.isNotEmpty).toSet().toList()..sort();

    return [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(_country == 'it' ? 'Tutte' : 'Alle'),
          selected: _servicesFilter.isEmpty,
          onSelected: (_) => setState(() => _servicesFilter = ''),
          showCheckmark: false,
          selectedColor: theme.colorScheme.primary,
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: _servicesFilter.isEmpty ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(
            color: _servicesFilter.isEmpty ? Colors.transparent : theme.colorScheme.outlineVariant,
          ),
        ),
      ),
      ...highways.map((highway) {
        final isSelected = _servicesFilter == highway;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(highway),
            selected: isSelected,
            onSelected: (selected) {
              setState(() => _servicesFilter = selected ? highway : '');
            },
            showCheckmark: false,
            selectedColor: theme.colorScheme.primary,
            labelStyle: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(
              color: isSelected ? Colors.transparent : theme.colorScheme.outlineVariant,
            ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
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
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_rounded, size: 64, color: theme.colorScheme.error),
          ),
          const SizedBox(height: 24),
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.error,
            ),
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
  final BoxDecoration decoration;

  const _AreaServiceCardItem({
    required this.area,
    required this.theme,
    required this.decoration,
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: widget.decoration,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (expanded) => setState(() => _isExpanded = expanded),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (fuelBrand.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    fuelBrand,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              AnimatedRotation(
                turns: _isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.local_gas_station_rounded,
              color: theme.colorScheme.onPrimaryContainer,
              size: 26,
            ),
          ),
          title: Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                _buildAreaLogo(area, theme),
                Expanded(
                  child: Text(
                    area.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isGerman ? 'Autobahn ${area.highway}' : 'Autostrada ${area.highway}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (area.highwayDescription.isNotEmpty)
                Text(
                  area.highwayDescription,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              if (area.km > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Km ${area.km.toStringAsFixed(1)}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  if (area.direction.isNotEmpty && area.direction.toLowerCase() != 'undefined')
                    _buildInfoRow(
                      Icons.navigation_rounded, 
                      widget.isGerman ? 'Richtung' : 'Direzione', 
                      area.direction, 
                      theme
                    ),
                  if (area.from.isNotEmpty || area.to.isNotEmpty)
                    _buildInfoRow(
                      Icons.route_rounded, 
                      widget.isGerman ? 'Strecke' : 'Tratta', 
                      '${area.from} → ${area.to}', 
                      theme
                    ),
                  if (area.descriptionAdsPmr.isNotEmpty)
                    _buildInfoRow(
                      Icons.accessible_rounded, 
                      'PMR', 
                      area.descriptionAdsPmr, 
                      theme
                    ),
                  
                  if (area.parking != null && (area.parking!.carSpaces != null || area.parking!.truckSpaces != null))
                    _buildInfoRow(
                      Icons.local_parking_rounded, 
                      widget.isGerman ? 'Parkplätze' : 'Parcheggi', 
                      '${area.parking!.carSpaces != null ? "PKW ${area.parking!.carSpaces}" : ""}'
                      '${area.parking!.carSpaces != null && area.parking!.truckSpaces != null ? " • " : ""}'
                      '${area.parking!.truckSpaces != null ? "LKW ${area.parking!.truckSpaces}" : ""}'
                      '${area.parking!.isBlocked == true ? " (gesperrt)" : ""}', 
                      theme
                    ),

                  if (area.fuelPrices.values.any((f) => f.price > 0)) ...[
                    const SizedBox(height: 24),
                    Text(
                      widget.isGerman ? 'KRAFTSTOFFPREISE' : 'PREZZI CARBURANTE',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._buildFuelPriceRows(area, theme),
                  ],
                ],
              ),
            ),
            
            if (area.events.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20.0),
                color: theme.colorScheme.errorContainer.withOpacity(0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: area.events.map((event) {
                    final text = event.title.isNotEmpty ? event.title : event.description;
                    final date = event.createdAt ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_rounded, size: 18, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              date.isNotEmpty ? '$text ($date)' : text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
                ),
                child: SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: area.services.map((service) {
                      final available = service.available ?? 0;
                      final total = service.total ?? 0;
                      return Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              service.name.isNotEmpty ? service.name : service.code,
                              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (total > 0 || available > 0)
                              Text(
                                total > 0 ? '$available / $total' : '$available',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: available > 0 ? theme.colorScheme.primary : theme.colorScheme.outline,
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isGerman ? 'ANBIETER' : 'ESERCENTI',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: area.brands.map((brand) {
                        final label = brand.name.isNotEmpty
                            ? brand.name
                            : (brand.nameSecond.isNotEmpty ? brand.nameSecond : brand.type);
                        final logoUrl = BrandLogos.getLogoUrl(label);
                        debugPrint('Brand: $label -> Logo URL: $logoUrl');
                        final hasLogo = logoUrl != null;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasLogo)
                                Image.network(
                                  logoUrl!,
                                  height: 20,
                                  width: 20,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(_iconForBrandType(brand.type), size: 16, color: theme.colorScheme.onSurfaceVariant),
                                )
                              else
                                Icon(_iconForBrandType(brand.type), size: 16, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                children: [
                  TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
                  TextSpan(text: value, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
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
          ? _shortDate(price.lastUpdate!)
          : '';
          
      rows.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                entry.value,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '€${price.price.toStringAsFixed(3)}/L',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (update.isNotEmpty)
                    Text(
                      'Aggiornato: $update',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  String _shortDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} '
             '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  IconData _iconForBrandType(String type) {
    final t = type.toUpperCase();
    if (t == 'OIL' || t.contains('FUEL') || t.contains('CARB')) return Icons.local_gas_station_rounded;
    if (t == 'FOOD' || t.contains('RIST') || t.contains('BAR')) return Icons.restaurant_rounded;
    if (t.contains('ELECTRIC') || t.contains('CHARG')) return Icons.ev_station_rounded;
    return Icons.storefront_rounded;
  }

  Widget _buildAreaLogo(RoadwayAreaService area, ThemeData theme) {
    String? logoBrand;
    if (area.foodBrands.isNotEmpty) {
      logoBrand = area.foodBrands.first;
    } else if (area.fuelBrand.isNotEmpty) {
      logoBrand = area.fuelBrand;
    } else if (area.brands.isNotEmpty) {
      logoBrand = area.brands.first.name.isNotEmpty ? area.brands.first.name : area.brands.first.type;
    }
    
    if (logoBrand == null) {
      return const SizedBox(width: 24, height: 24);
    }
    
    final logoUrl = BrandLogos.getLogoUrl(logoBrand);
    if (logoUrl == null) {
      return const SizedBox(width: 24, height: 24);
    }
    
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Image.network(
        logoUrl,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const SizedBox(width: 24, height: 24),
      ),
    );
  }
}
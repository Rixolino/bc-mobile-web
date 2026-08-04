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

class _RoadwaysPageState extends State<RoadwaysPage> with SingleTickerProviderStateMixin {
  final RoadwayService _service = RoadwayService();
  late TabController _tabController;
  Future<List<RoadwayNews>>? _newsFuture;
  Future<List<RoadwayToll>>? _tollsFuture;
  Future<List<RoadwayAreaService>>? _servicesFuture;
  String _servicesFilter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _newsFuture = _service.fetchItalyRealTimeNews();
      _tollsFuture = _service.fetchItalyTolls();
      _servicesFuture = _service.fetchAreaServices();
    });
    
    // Attende che tutte le chiamate siano completate per il RefreshIndicator
    await Future.wait([
      _newsFuture ?? Future.value([]),
      _tollsFuture ?? Future.value([]),
      _servicesFuture ?? Future.value([]),
    ]); // Ignora errori per non bloccare il RefreshIndicator
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Servizi Autostradali',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Aggiorna tutti i dati',
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent, // Rimuove la linea grigia standard sotto le tab
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Notizie', icon: Icon(Icons.campaign_rounded)),
            Tab(text: 'Tariffe', icon: Icon(Icons.euro_rounded)),
            Tab(text: 'Servizi', icon: Icon(Icons.local_gas_station_rounded)),
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

  Widget _buildNewsTab() {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<RoadwayNews>>(
        future: _newsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(theme, 'Errore nel caricamento notizie.');
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(theme, 'Nessuna notizia disponibile.', Icons.check_circle_outline);
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final news = snapshot.data![index];
              return _buildNewsCard(news, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildTollsTab() {
    final theme = Theme.of(context);
    
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<RoadwayToll>>(
        future: _tollsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(theme, 'Errore nel caricamento tariffe.');
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(theme, 'Tariffe non disponibili.', Icons.money_off_rounded);
          }

          final tolls = snapshot.data!;
          final companies = <String, Map<String, double>>{};
          
          for (var toll in tolls) {
            companies.putIfAbsent(toll.companyName, () => {});
            companies[toll.companyName]![toll.category] = toll.rate;
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: companies.keys.map((companyName) {
              final rates = companies[companyName]!;
              return _buildCompanyTollCard(companyName, rates, theme);
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildServicesTab() {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FutureBuilder<List<RoadwayAreaService>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _buildErrorState(theme, 'Errore nel caricamento servizi.');
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState(theme, 'Servizi non disponibili.', Icons.local_gas_station_rounded);
          }

          final allAreas = snapshot.data!;
          final filteredAreas = allAreas.where((area) => 
            area.highway.toLowerCase().contains(_servicesFilter.toLowerCase())
          ).toList();

          return Column(
            children: [
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _buildHighwayFilterChips(allAreas, theme),
                ),
              ),
              Expanded(
                child: filteredAreas.isEmpty 
                  ? _buildEmptyState(theme, 'Nessuna area trovata per questo filtro.', Icons.search_off_rounded)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: filteredAreas.length,
                      itemBuilder: (context, index) {
                        final area = filteredAreas[index];
                        return _buildAreaServiceCard(area, theme);
                      },
                    ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAreaServiceCard(RoadwayAreaService area, ThemeData theme) {
    // Find first non‑empty brand among services
    final brandItem = area.services.firstWhere(
      (s) => s.brand.isNotEmpty,
      orElse: () => RoadwayServiceItem(
        code: '', description: '', brand: '', quantity: 0, available: 0),
    );
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              Expanded(
                child: Text(
                  area.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (brandItem.brand.isNotEmpty)
                Text(
                  brandItem.brand,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Autostrada ${area.highway}',
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
            ],
          ),
          children: [
            // Informazioni aggiuntive sull'area di servizio
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (area.direction.isNotEmpty || area.destination.isNotEmpty)
                    Text(
                      'Direzione: ${area.direction} → ${area.destination}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (area.pmrAccessibilityDescription.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Accessibilità PMR: ${area.pmrAccessibilityDescription}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (area.benPrice > 0 || area.bdisPrice > 0 || area.bgplPrice > 0 || area.bhvoPrice > 0 || area.bgnsPrice > 0 || area.bmetPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Carburanti:',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (area.benPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0),
                      child: Text(
                        'Benzina: €${area.benPrice.toStringAsFixed(3)}/L',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (area.bdisPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0),
                      child: Text(
                        'Diesel: €${area.bdisPrice.toStringAsFixed(3)}/L',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (area.bgplPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0),
                      child: Text(
                        'GPL: €${area.bgplPrice.toStringAsFixed(3)}/L',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (area.bhvoPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0),
                      child: Text(
                        'Idrogeno: €${area.bhvoPrice.toStringAsFixed(3)}/L',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (area.bgnsPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0),
                      child: Text(
                        'Gas Naturale: €${area.bgnsPrice.toStringAsFixed(3)}/L',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  if (area.bmetPrice > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0, top: 2.0),
                      child: Text(
                        'Metano: €${area.bmetPrice.toStringAsFixed(3)}/L',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Servizi disponibili
            Container(
              padding: const EdgeInsets.all(16.0),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: SizedBox(
                height: 80,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: area.services.map((service) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            service.description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            service.brand,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${service.available.toInt()} / ${service.quantity.toInt()}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: service.available > 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
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
      ),
 )   );
  }

  List<Widget> _buildHighwayFilterChips(List<RoadwayAreaService> areas, ThemeData theme) {
    // Get unique highways, filter out empty strings, sort
    final highways = areas
        .map((area) => area.highway)
        .where((h) => h.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return highways.map((highway) {
      final isSelected = _servicesFilter == highway;
      return FilterChip(
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
      );
    }).toList();
  }

  Widget _buildNewsCard(RoadwayNews news, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Rimuove i bordi interni dell'ExpansionTile
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.warning_amber_rounded, 
              color: theme.colorScheme.error,
              size: 24,
            ),
          ),
          title: Text(
            news.title, 
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '${news.location} • ${news.direction}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.description, 
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Aggiornato il: ${news.date}',
                        style: theme.textTheme.labelMedium?.copyWith(
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

  Widget _buildCompanyTollCard(String companyName, Map<String, double> rates, ThemeData theme) {
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
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.corporate_fare_rounded, 
              color: theme.colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),
          title: Text(
            companyName, 
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Column(
                children: rates.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Classe ${e.key}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '€ ${e.value.toStringAsFixed(3)} /km',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: theme.colorScheme.surfaceContainerHighest),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(message, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
        ],
      ),
    );
  }
}
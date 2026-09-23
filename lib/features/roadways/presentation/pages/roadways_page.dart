import 'package:flutter/material.dart';
import '../../data/models/roadway_news_model.dart';
import '../../data/models/roadway_toll_model.dart';
import '../../data/models/roadway_service_model.dart';
import '../../data/services/roadway_service.dart';
import '../../utils/brand_logos.dart';
import 'roadway_area_service_screen.dart';

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
        // Solo layout: in landscape centra il foglio e affianca le opzioni.
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isLandscape ? 700 : double.infinity,
              ),
              child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.public_rounded, color: theme.colorScheme.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isIt ? 'Seleziona Nazione' : 'Land auswählen',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (isLandscape)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildCountryOption(
                          code: 'it',
                          name: 'Italia',
                          subtitle: 'Autostrade / Servizi autostradali',
                          flag: '🇮🇹',
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildCountryOption(
                          code: 'de',
                          name: 'Germania',
                          subtitle: 'Autobahn / Rastanlagen',
                          flag: '🇩🇪',
                          theme: theme,
                        ),
                      ),
                    ],
                  )
                else ...[
                _buildCountryOption(
                  code: 'it',
                  name: 'Italia',
                  subtitle: 'Autostrade / Servizi autostradali',
                  flag: '🇮🇹',
                  theme: theme,
                ),
                const SizedBox(height: 12),
                _buildCountryOption(
                  code: 'de',
                  name: 'Germania',
                  subtitle: 'Autobahn / Rastanlagen',
                  flag: '🇩🇪',
                  theme: theme,
                ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
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
    required String flag,
    required ThemeData theme,
  }) {
    final isSelected = _country == code;

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        _setCountry(code);
      },
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.75),
                  ],
                )
              : null,
          color: isSelected
              ? null
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary.withValues(alpha: 0.85)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onPrimary,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 16),
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

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                theme.brightness == Brightness.light
                    ? theme.colorScheme.primary.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isIt ? 'Servizi Autostradali' : 'Autobahn-Services',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isIt
                    ? 'Notifiche, caselli e aree di servizio'
                    : 'Meldungen, Maut & Rastanlagen',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: isIt ? 'Nazione' : 'Land',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showCountryPicker,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                          theme.colorScheme.secondary.withValues(alpha: 0.12),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _country == 'it' ? '🇮🇹' : '🇩🇪',
                          style: const TextStyle(fontSize: 20),
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
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              height: 50,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary.withValues(alpha: 0.15),
                      theme.colorScheme.secondary.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: [
                  Tab(
                    text: isIt ? 'Notizie' : 'Meldungen',
                    icon: const Icon(Icons.campaign_rounded, size: 20),
                  ),
                  Tab(
                    text: isIt ? 'Caselli' : 'Maut',
                    icon: const Icon(Icons.toll_rounded, size: 20),
                  ),
                  Tab(
                    text: isIt ? 'Servizi' : 'Rastanlagen',
                    icon: const Icon(Icons.local_gas_station_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ),
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16, right: 8),
        child: FloatingActionButton.extended(
          onPressed: _refreshData,
          elevation: 4,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          icon: const Icon(Icons.refresh_rounded, size: 22),
          label: Text(
            isIt ? 'Refresh' : 'Aktualisieren',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
// ---------------------------------------------------------------------------
  // HELPER PER LE CARD MATERIAL 3
  // ---------------------------------------------------------------------------

  BoxDecoration _m3CardDecoration(ThemeData theme) {
    return BoxDecoration(
      color: theme.brightness == Brightness.light ? Colors.white : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: theme.colorScheme.shadow.withValues(alpha: 0.08),
          blurRadius: 16,
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
      color: theme.colorScheme.primary,
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
              Icons.campaign_outlined,
            );
          }

          final news = snapshot.data!;
          // Solo layout: in landscape griglia a due colonne più densa.
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          if (isLandscape) {
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 0,
                childAspectRatio: 1.15,
              ),
              itemCount: news.length,
              itemBuilder: (context, index) {
                return _buildNewsCard(news[index], theme);
              },
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: news.length,
            itemBuilder: (context, index) {
              return _buildNewsCard(news[index], theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildNewsCard(RoadwayNews news, ThemeData theme) {
    final typeColor = _newsTypeColor(news.type, theme);
    final typeIcon = _newsTypeIcon(news.type);
    final isSevere = news.type.toLowerCase() == 'closure' || news.type.toLowerCase() == 'event';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _m3CardDecoration(theme),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSevere
                    ? [typeColor.withValues(alpha: 0.22), typeColor.withValues(alpha: 0.08)]
                    : [
                        theme.colorScheme.primary.withValues(alpha: 0.16),
                        theme.colorScheme.secondary.withValues(alpha: 0.12),
                      ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              typeIcon,
              color: isSevere ? typeColor : theme.colorScheme.primary,
              size: 24,
            ),
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
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Text(
                        news.type.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: typeColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                if (news.location.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.place_outlined, size: 14, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          news.location,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [typeColor.withValues(alpha: 0.06), Colors.transparent],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (news.description.isNotEmpty)
                    Text(
                      news.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.55,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                      ),
                    ),
                  if (news.direction.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _infoRow(
                      theme: theme,
                      icon: Icons.navigation_rounded,
                      color: typeColor,
                      text: news.direction,
                    ),
                  ],
                  if (news.cause != null && news.cause!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      theme: theme,
                      icon: Icons.report_problem_outlined,
                      color: Colors.orange.shade700,
                      text: news.cause!,
                    ),
                  ],
                  if (news.from != null || news.to != null) ...[
                    const SizedBox(height: 8),
                    _infoRow(
                      theme: theme,
                      icon: Icons.signpost_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      text: '${news.from ?? "—"} → ${news.to ?? "—"}',
                    ),
                  ],
                  if (news.queueKm != null && news.queueKm! > 0) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.traffic_rounded, size: 20, color: theme.colorScheme.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Code: ${news.queueKm!.toStringAsFixed(1)} km'
                              '${news.delayMinutes != null ? " · Delay ${news.delayMinutes} min" : ""}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_rounded, size: 14, color: typeColor),
                          const SizedBox(width: 6),
                          Text(
                            news.date,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: typeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Color _newsTypeColor(String type, ThemeData theme) {
    switch (type.toLowerCase()) {
      case 'open':
        return Colors.green.shade600;
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
      case 'open': return Icons.check_circle_outline_rounded;
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
      color: theme.colorScheme.primary,
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

          // Solo layout: in landscape griglia a due colonne più densa.
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          if (isLandscape) {
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 0,
                childAspectRatio: 1.1,
              ),
              itemCount: tolls.length,
              itemBuilder: (context, index) {
                return _buildTollCard(tolls[index], theme);
              },
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
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
    final isOpen = toll.status == 'OPEN';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: _m3CardDecoration(theme),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.secondary.withValues(alpha: 0.2),
                  theme.colorScheme.primary.withValues(alpha: 0.14),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.toll_rounded,
              color: theme.colorScheme.primary,
              size: 24,
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
            padding: const EdgeInsets.only(top: 6.0),
            child: Row(
              children: [
                _statusDot(isOpen),
                const SizedBox(width: 6),
                Text(
                  isOpen
                      ? (_country == 'it' ? 'Aperto' : 'Offen')
                      : (_country == 'it' ? 'Chiuso' : 'Geschlossen'),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isOpen ? Colors.green.shade600 : theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (toll.highway.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      toll.highway,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (toll.highwayDescription.isNotEmpty)
                    _infoRow(
                      theme: theme,
                      icon: Icons.signpost_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                      text: toll.highwayDescription,
                    ),
                  if (toll.address.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _infoRow(
                        theme: theme,
                        icon: Icons.location_on_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                        text: toll.address,
                      ),
                    ),
                  if (toll.km > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _infoRow(
                        theme: theme,
                        icon: Icons.straighten_rounded,
                        color: theme.colorScheme.primary,
                        text: 'Km ${toll.km.toStringAsFixed(1)}',
                      ),
                    ),
                  if (toll.paymentMethods.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel(
                      theme,
                      _country == 'de' ? 'ZAHLUNGSMETHODEN' : 'METODI DI PAGAMENTO',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: toll.paymentMethods.map((pm) {
                        final desc = pm.description.isNotEmpty ? pm.description : pm.code;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.payment_rounded, size: 15, color: theme.colorScheme.primary),
                              const SizedBox(width: 6),
                              Text(
                                desc,
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
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _GateStat(
                          count: toll.entranceGates.length,
                          label: _country == 'de' ? 'Einfahrt' : 'Entrata',
                          icon: Icons.call_missed_outgoing_rounded,
                          theme: theme,
                        ),
                        Container(width: 1, height: 34, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        _GateStat(
                          count: toll.exitGates.length,
                          label: _country == 'de' ? 'Ausfahrt' : 'Uscita',
                          icon: Icons.call_received_rounded,
                          theme: theme,
                        ),
                        Container(width: 1, height: 34, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                        _GateStatus(open: isOpen, theme: theme),
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
      color: theme.colorScheme.primary,
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
              Icons.local_gas_station_outlined,
            );
          }

          final allAreas = snapshot.data!;
          final filteredAreas = allAreas
              .where((area) => area.highway.toLowerCase().contains(_servicesFilter.toLowerCase()))
              .toList();

          return Column(
            children: [
              Container(
                height: 48,
                margin: const EdgeInsets.only(top: 10, bottom: 6),
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
                    : OrientationBuilder(
                        builder: (context, orientation) {
                          // Solo layout: in landscape due colonne.
                          final isLandscape =
                              orientation == Orientation.landscape;
                          if (isLandscape) {
                            return GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 4, 16, 96),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 0,
                                childAspectRatio: 2.8,
                              ),
                              itemCount: filteredAreas.length,
                              itemBuilder: (context, index) {
                                return _AreaServiceCardItem(
                                  area: filteredAreas[index],
                                  theme: theme,
                                  isGerman: _country == 'de',
                                  decoration: _m3CardDecoration(theme),
                                );
                              },
                            );
                          }
                          return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        itemCount: filteredAreas.length,
                        itemBuilder: (context, index) {
                          return _AreaServiceCardItem(
                            area: filteredAreas[index],
                            theme: theme,
                            isGerman: _country == 'de',
                            decoration: _m3CardDecoration(theme),
                          );
                        },
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
        child: _FilterChip(
          label: _country == 'it' ? 'Tutte' : 'Alle',
          icon: Icons.apps_rounded,
          selected: _servicesFilter.isEmpty,
          theme: theme,
          color: theme.colorScheme.primary,
          onSelected: () => setState(() => _servicesFilter = ''),
        ),
      ),
      ...highways.map((highway) {
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _FilterChip(
            label: highway,
            icon: Icons.route_rounded,
            selected: _servicesFilter == highway,
            theme: theme,
            color: theme.colorScheme.secondary,
            onSelected: () => setState(() => _servicesFilter = highway),
          ),
        );
      }),
    ];
  }

  // ---------------------------------------------------------------------------
  // COMMON UI HELPERS
  // ---------------------------------------------------------------------------
  Widget _sectionLabel(ThemeData theme, String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _statusDot(bool open) {
    final color = open ? Colors.green : Colors.red;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, String message, IconData icon) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.14),
                    theme.colorScheme.secondary.withValues(alpha: 0.08),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 26),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.cloud_off_rounded, size: 52, color: theme.colorScheme.error),
            ),
            const SizedBox(height: 26),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _refreshData,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(_country == 'it' ? 'Riprova' : 'Erneut versuchen'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// FILTER CHIP
// =============================================================================
class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final ThemeData theme;
  final Color color;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.theme,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    color,
                    color.withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: selected ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? Colors.transparent : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// GATE STAT
// =============================================================================
class _GateStat extends StatelessWidget {
  final int count;
  final String label;
  final IconData icon;
  final ThemeData theme;

  const _GateStat({
    required this.count,
    required this.label,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _GateStatus extends StatelessWidget {
  final bool open;
  final ThemeData theme;

  const _GateStatus({required this.open, required this.theme});

  @override
  Widget build(BuildContext context) {
    final color = open ? Colors.green.shade600 : theme.colorScheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            open ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            open ? 'Aperto' : 'Chiuso',
            style: theme.textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
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

class _AreaServiceCardItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final fuelBrand = area.fuelBrand;
    final foodBrands = area.foodBrands;
    final logoBrand = foodBrands.isNotEmpty
        ? foodBrands.first
        : (fuelBrand.isNotEmpty ? fuelBrand : null);
    final logoUrl = logoBrand != null ? BrandLogos.getLogoUrl(logoBrand) : null;
    final localLogoPath = logoBrand != null ? BrandLogos.getLocalLogoPath(logoBrand) : null;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RoadwayAreaServiceScreen(
              area: area,
              isGerman: isGerman,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Brand logo or fallback icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15)),
                ),
                padding: const EdgeInsets.all(8),
                child: _buildLogo(logoUrl, localLogoPath, theme),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      area.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (area.highway.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              area.highway,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (area.km > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.straighten_rounded, size: 14,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 3),
                              Text(
                                'Km ${area.km.toStringAsFixed(1)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (fuelBrand.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              fuelBrand,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(String? logoUrl, String? localLogoPath, ThemeData theme) {
    if (logoUrl != null) {
      return Image.network(
        logoUrl,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(width: 20, height: 20);
        },
        errorBuilder: (context, error, stackTrace) {
          if (localLogoPath != null) {
            return Image.asset(localLogoPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.local_gas_station_rounded, color: theme.colorScheme.primary, size: 20));
          }
          return Icon(Icons.local_gas_station_rounded, color: theme.colorScheme.primary, size: 20);
        },
      );
    }
    if (localLogoPath != null) {
      return Image.asset(localLogoPath, fit: BoxFit.contain, errorBuilder: (_, __, ___) => Icon(Icons.local_gas_station_rounded, color: theme.colorScheme.primary, size: 20));
    }
    return Icon(Icons.local_gas_station_rounded, color: theme.colorScheme.primary, size: 20);
  }
}

class _BrandIcon extends StatelessWidget {
  final String type;
  final ThemeData theme;

  const _BrandIcon({
    required this.type,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData;
    final t = type.toUpperCase();
    if (t == 'OIL' || t.contains('FUEL') || t.contains('CARB')) {
      iconData = Icons.local_gas_station_rounded;
    } else if (t == 'FOOD' || t.contains('RIST') || t.contains('BAR')) {
      iconData = Icons.restaurant_rounded;
    } else if (t.contains('ELECTRIC') || t.contains('CHARG')) {
      iconData = Icons.ev_station_rounded;
    } else {
      iconData = Icons.storefront_rounded;
    }

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 18, color: theme.colorScheme.primary),
    );
  }
}

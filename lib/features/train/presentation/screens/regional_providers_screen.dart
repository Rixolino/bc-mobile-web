import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../data/models/regional_provider_model.dart';
import '../../data/repositories/regional_providers_repository.dart';
import 'regional_provider_screen.dart';

class RegionalProvidersScreen extends StatefulWidget {
  final String country;

  const RegionalProvidersScreen({super.key, required this.country});

  @override
  State<RegionalProvidersScreen> createState() => _RegionalProvidersScreenState();
}

class _RegionalProvidersScreenState extends State<RegionalProvidersScreen> {
  final RegionalProvidersRepository _repository = RegionalProvidersRepository();
  final TextEditingController _searchController = TextEditingController();
  List<RegionalProvider> _providers = [];
  bool _loading = true;
  String? _error;
  String _query = '';

  static String _orderKey(String country) => 'regional_provider_order_$country';

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProviders() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final providers = await _repository.fetchProviders(widget.country);
      if (mounted) {
        setState(() {
          _providers = providers;
          _loading = false;
        });
        await _applySavedOrder();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  /// Applica l'ordine salvato dall'utente (per country); i nuovi provider
  /// non presenti nel salvataggio restano in coda.
  Future<void> _applySavedOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final order = prefs.getStringList(_orderKey(widget.country)) ?? [];
      if (order.isEmpty || !mounted) return;
      setState(() {
        _providers.sort((a, b) {
          final ia = order.indexOf(a.name);
          final ib = order.indexOf(b.name);
          if (ia == -1 && ib == -1) return 0;
          if (ia == -1) return 1;
          if (ib == -1) return -1;
          return ia.compareTo(ib);
        });
      });
    } catch (_) {}
  }

  Future<void> _saveOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _orderKey(widget.country),
        _providers.map((p) => p.name).toList(),
      );
    } catch (_) {}
  }

  List<RegionalProvider> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _providers;
    return _providers.where((p) {
      return p.provider.toLowerCase().contains(q) ||
          p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.region.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = (String key) => RuntimeLocalizations.t(context, key);

    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(t('regional_loading'), style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(t('regional_error'), style: theme.textTheme.bodyLarge),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.bodySmall),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProviders,
              icon: const Icon(Icons.refresh),
              label: Text(t('retry')),
            ),
          ],
        ),
      );
    }

    if (_providers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              t('regional_no_providers'),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProviders,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: t('regional_search_providers'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.sort_rounded),
                  tooltip: t('regional_reorder'),
                  onPressed: _openReorderSheet,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_filtered.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  t('regional_no_providers'),
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                itemCount: _filtered.length,
                itemBuilder: (context, index) =>
                    _providerCard(theme, _filtered[index]),
              ),
            ),
        ],
      ),
    );
  }

  /// Menu a sheet per riordinare i provider e salvare l'ordine.
  void _openReorderSheet() {
    final theme = Theme.of(context);
    final t = (String key) => RuntimeLocalizations.t(context, key);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sbSetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.outline.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      t('regional_reorder_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('regional_reorder_subtitle'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        itemCount: _providers.length,
                        onReorder: (oldIndex, newIndex) async {
                          sbSetState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _providers.removeAt(oldIndex);
                            _providers.insert(newIndex, item);
                          });
                          setState(() {});
                          await _saveOrder();
                        },
                        itemBuilder: (context, index) {
                          final p = _providers[index];
                          return ListTile(
                            key: ValueKey(p.name),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  p.provider.substring(0, 1),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(p.provider),
                            subtitle: Text(
                              p.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Icon(
                              Icons.drag_handle_rounded,
                              color: theme.colorScheme.outline,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _providerCard(ThemeData theme, RegionalProvider provider) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RegionalProviderScreen(provider: provider),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        provider.provider.substring(0, 1),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provider.provider,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          provider.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (provider.endpoints.stations)
                    _endpointChip(theme, Icons.location_on, 'Stazioni'),
                  if (provider.endpoints.departures)
                    _endpointChip(theme, Icons.departure_board, 'Partenze'),
                  if (provider.endpoints.arrivals)
                    _endpointChip(theme, Icons.assignment_return, 'Arrivi'),
                  if (provider.endpoints.realtime)
                    _endpointChip(theme, Icons.wifi_tethering, 'Realtime'),
                  if (provider.endpoints.trip)
                    _endpointChip(theme, Icons.route, 'Trip'),
                  if (provider.endpoints.lines)
                    _endpointChip(theme, Icons.linear_scale, 'Linee'),
                  if (provider.endpoints.news)
                    _endpointChip(theme, Icons.newspaper, 'News'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _endpointChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
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
  List<RegionalProvider> _providers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProviders();
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _providers.length,
        itemBuilder: (context, index) {
          final provider = _providers[index];
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
        },
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

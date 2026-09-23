import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bc_transporter/features/train/data/models/train_model.dart';
import 'package:bc_transporter/features/train/data/repositories/train_repository.dart';
import 'package:bc_transporter/features/train/presentation/providers/train_provider.dart';
import 'package:bc_transporter/presentation/providers/theme_provider.dart';
import 'package:bc_transporter/presentation/providers/settings_provider.dart';
import 'package:bc_transporter/core/design_system.dart';
import 'package:bc_transporter/core/services/runtime_localizations.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import 'package:bc_transporter/core/utils/country_time.dart';
import 'package:bc_transporter/core/services/tts_service.dart';

class StationDetailsScreen extends StatefulWidget {
  final String stationId;
  final String country;
  final String stationName;

  const StationDetailsScreen({
    super.key,
    required this.stationId,
    required this.country,
    required this.stationName,
  });

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  final TrainRepository _repository = TrainRepository();
  List<TrainDeparture> _departures = [];
  List<TrainDeparture> _arrivals = [];
  bool _isLoading = true;
  bool _isArrivalsMode = false;
  String? _error;
  Timer? _refreshTimer;
  String? _selectedPlatformFilter;

  @override
  void initState() {
    super.initState();
    _loadLogos();
    _fetchAll();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settings.trainRefreshSeconds;
    if (interval > 0) {
      _refreshTimer = Timer.periodic(Duration(seconds: interval), (_) {
        if (mounted) _fetchAll(silent: true);
      });
    }
  }

  void _loadLogos() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    if (settings.vectorLogosEnabled && trainProvider.trainLogos.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) trainProvider.loadTrainLogos(source: settings.logoSource);
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      final deps = await _repository.fetchDepartures(
        widget.stationId,
        country: widget.country,
        service: 'trainboardeu',
        isArrival: false,
      );
      final arrs = await _repository.fetchDepartures(
        widget.stationId,
        country: widget.country,
        service: 'trainboardeu',
        isArrival: true,
      );
      if (mounted) {
        setState(() {
          _departures = deps;
          _arrivals = arrs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final items = _isArrivalsMode ? _arrivals : _departures;
    final availablePlatforms = items
        .map((e) => (e.platform ?? '').trim())
        .where((e) => e.isNotEmpty && e != '-')
        .toSet()
        .toList()
      ..sort();
    final filtered = _selectedPlatformFilter == null
        ? items
        : items.where((e) => (e.platform ?? '').trim() == _selectedPlatformFilter).toList();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.stationName,
              style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              widget.country,
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textColor, size: 20),
            onPressed: () => _fetchAll(),
          ),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          // Landscape: vincola la larghezza, padding ariosi e safe area laterali.
          final isLandscape = orientation == Orientation.landscape;
          final sidePadding = MediaQuery.of(context).padding;
          return SafeArea(
            top: false,
            bottom: false,
            left: isLandscape,
            right: isLandscape,
            minimum: isLandscape
                ? EdgeInsets.only(
                    left: sidePadding.left > 0 ? 0 : 24,
                    right: sidePadding.right > 0 ? 0 : 24,
                  )
                : EdgeInsets.zero,
            child: Column(
              children: [
                _buildModeToggle(theme),
                if (availablePlatforms.isNotEmpty && !_isLoading && _error == null)
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLandscape ? 32 : 16,
                        vertical: 8,
                      ),
                      children: [
                        _buildFilterChip(
                          AppLocalizations.of(context)?.allPlatforms ?? 'Tutti i Binari',
                          _selectedPlatformFilter == null,
                          theme,
                          () => setState(() => _selectedPlatformFilter = null),
                        ),
                        ...availablePlatforms.map((p) => _buildFilterChip(
                              '${AppLocalizations.of(context)?.platform ?? 'Binario'} $p',
                              _selectedPlatformFilter == p,
                              theme,
                              () => setState(() => _selectedPlatformFilter = p),
                            )),
                      ],
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 900 : double.infinity,
                      ),
                      child: _isLoading
                          ? _buildLoading(theme)
                          : _error != null
                              ? _buildError(theme)
                              : filtered.isEmpty
                                  ? _buildEmpty(theme)
                                  : _buildDepartureList(filtered, theme),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildModeToggle(ThemeProvider theme) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final toggle = Container(
      color: theme.surfaceColor,
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 32 : 16,
        vertical: 8,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 600 : double.infinity,
          ),
          child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isArrivalsMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isArrivalsMode ? theme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    RuntimeLocalizations.t(context, 'regional_provider_departures'),
                    style: TextStyle(
                      color: !_isArrivalsMode ? Colors.white : theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isArrivalsMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isArrivalsMode ? theme.primaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    RuntimeLocalizations.t(context, 'regional_provider_arrivals'),
                    style: TextStyle(
                      color: _isArrivalsMode ? Colors.white : theme.textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
          ),
        ),
      ),
    );
    return toggle;
  }

  Widget _buildLoading(ThemeProvider theme) {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
      ),
    );
  }

  Widget _buildError(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              _error ?? 'Errore sconosciuto',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textColor),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchAll,
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.train_rounded, color: theme.secondaryTextColor, size: 48),
          const SizedBox(height: 16),
          Text(
            _isArrivalsMode
                ? RuntimeLocalizations.t(context, 'no_arrivals')
                : RuntimeLocalizations.t(context, 'no_departures'),
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartureList(List<TrainDeparture> items, ThemeProvider theme) {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      color: theme.primaryColor,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
        itemBuilder: (context, index) {
          final dep = items[index];
          return _buildDepartureItem(dep, theme, _isArrivalsMode);
        },
      ),
    );
  }

  Widget _buildDepartureItem(TrainDeparture dep, ThemeProvider theme, bool isArrival) {
    final cat = (dep.category ?? '').trim();
    final num = (dep.trainNumber ?? '').trim();
    // Arrivi: mostra la provenienza (la destinazione è la stazione stessa).
    // Partenze: mostra la destinazione.
    final dest = isArrival
        ? (dep.origin ?? '').trim()
        : (dep.destination ?? '').trim();
    final delay = dep.delayMinutes ?? 0;
    final scheduled = dep.scheduledTime;
    final estimated = dep.estimatedTime;
    final platform = dep.platform;
    final isHighSpeed = cat.toLowerCase().contains('fr') ||
        cat.toLowerCase().contains('freccia') ||
        cat.toLowerCase().contains('ec') ||
        cat.toLowerCase().contains('ice') ||
        cat.toLowerCase().contains('tgv');
    final color = isHighSpeed ? Colors.redAccent : AppTokens.trainColor;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    String? logoUrl;
    if (settings.vectorLogosEnabled) {
      final key = cat.toUpperCase().replaceAll(' ', '_');
      final logo = trainProvider.trainLogos[key];
      logoUrl = logo != null ? (logo['png'] ?? logo['svg']) : null;
    }

    final timeStr = formatCountryTime(scheduled, widget.country);
    final estStr = estimated != null
        ? formatCountryTime(estimated, widget.country)
        : null;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).orientation == Orientation.landscape ? 24 : 16,
        vertical: MediaQuery.of(context).orientation == Orientation.landscape ? 12 : 10,
      ),
      child: Row(
        children: [
          if (logoUrl != null)
            Container(
              height: 24,
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
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$cat $num',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                        fontSize: 14,
                      ),
                    ),
                    if (delay > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+$delay\'',
                          style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else if (delay < 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$delay\'',
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  dest.isNotEmpty ? dest : '--',
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (platform != null && platform.isNotEmpty) ...[
                _buildPlatformTicket(platform, theme),
                const SizedBox(width: 10),
              ],
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Builder(
                builder: (_) {
                  Color timeColor;
                  if (delay <= 0) {
                    timeColor = Colors.green;
                  } else if (delay <= 5) {
                    timeColor = Colors.orange;
                  } else if (delay <= 15) {
                    timeColor = Colors.deepOrange;
                  } else {
                    timeColor = Colors.red;
                  }
                  return Text(
                    estStr != null && estStr != timeStr ? estStr : timeStr,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: estStr != null && estStr != timeStr ? timeColor : theme.textColor,
                      fontSize: 15,
                    ),
                  );
                },
              ),
                  if (estStr != null && estStr != timeStr)
                    Text(
                      timeStr,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Cartello binario stile "ticket": riquadro scuro con numero bianco
  /// e tacche laterali, a sinistra degli orari (come nel tabellone principale).
  Widget _buildPlatformTicket(String bin, ThemeProvider theme) {
    final bg = theme.isDark ? const Color(0xFF5A5A5A) : const Color(0xFF4A4A4A);
    return Semantics(
      label: '${AppLocalizations.of(context)?.platform ?? 'Binario'} $bin',
      child: Container(
        width: 32,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  bin,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, ThemeProvider theme, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor : theme.surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? theme.primaryColor : theme.secondaryTextColor.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : theme.textColor,
            ),
          ),
        ),
      ),
    );
  }


}

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
      body: Column(
        children: [
          _buildModeToggle(theme),
          Expanded(
            child: _isLoading
                ? _buildLoading(theme)
                : _error != null
                    ? _buildError(theme)
                    : items.isEmpty
                        ? _buildEmpty(theme)
                        : _buildDepartureList(items, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildModeToggle(ThemeProvider theme) {
    return Container(
      color: theme.surfaceColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    RuntimeLocalizations.t(context, 'departures'),
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
                    RuntimeLocalizations.t(context, 'arrivals'),
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
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              if (platform != null && platform.isNotEmpty)
                Text(
                  'Bin $platform',
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
                ),
            ],
          ),
          _buildTtsButton(dep, isArrival, theme),
        ],
      ),
    );
  }

  Widget _buildTtsButton(TrainDeparture dep, bool isArrival, ThemeProvider theme) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.ttsEnabled) return const SizedBox.shrink();
    
    return GestureDetector(
      onTap: () async {
        final tts = TtsService();
        final langCode = settings.appLocale?.languageCode ?? 'it';
        tts.setLanguage(langCode);
        
        final cat = (dep.category ?? '').trim();
        final num = (dep.trainNumber ?? '').trim();
        final dest = isArrival
            ? (dep.origin ?? '').trim()
            : (dep.destination ?? '').trim();
        final delay = dep.delayMinutes ?? 0;
        final scheduled = dep.scheduledTime;
        final estimated = dep.estimatedTime;
        
        final timeStr = formatCountryTime(scheduled, widget.country);
        final estStr = estimated != null ? formatCountryTime(estimated, widget.country) : null;
        final displayTime = (estStr != null && estStr != timeStr) ? estStr : timeStr;
        
        String text = '';
        if (cat.isNotEmpty || num.isNotEmpty) {
          text += 'Treno $cat $num. ';
        }
        if (dest.isNotEmpty) {
          text += '${isArrival ? 'Provenienza' : 'Direzione'} $dest. ';
        }
        if (displayTime.isNotEmpty) {
          text += '${isArrival ? 'Arrivo' : 'Partenza'} alle $displayTime. ';
        }
        if (delay > 0) {
          text += 'Ritardo $delay minuti. ';
        } else if (delay == 0) {
          text += 'In orario. ';
        }
        
        if (text.isNotEmpty) {
          await tts.speak(text);
        }
      },
      child: Icon(
        Icons.volume_up_rounded,
        size: 20,
        color: theme.primaryColor.withValues(alpha: 0.6),
      ),
    );
  }
}

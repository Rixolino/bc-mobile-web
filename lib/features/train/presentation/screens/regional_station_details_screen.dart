import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../core/design_system.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../data/models/regional_provider_model.dart';
import '../widgets/regional_train_details_sheet.dart';

/// Stessa schermata dell'info stazione nazionale (StationDetailsScreen)
/// ma per i provider regionali (Trenord/FAL): toggle Partenze/Arrivi,
/// auto-refresh da impostazioni, tap sulla corsa -> dettaglio treno.
class RegionalStationDetailsScreen extends StatefulWidget {
  final RegionalProvider provider;
  final String stationId;
  final String stationName;

  const RegionalStationDetailsScreen({
    super.key,
    required this.provider,
    required this.stationId,
    required this.stationName,
  });

  @override
  State<RegionalStationDetailsScreen> createState() => _RegionalStationDetailsScreenState();
}

class _RegionalStationDetailsScreenState extends State<RegionalStationDetailsScreen> {
  List<Map<String, dynamic>> _departures = [];
  List<Map<String, dynamic>> _arrivals = [];
  bool _isLoading = true;
  bool _isArrivalsMode = false;
  String? _error;
  Timer? _refreshTimer;

  String get _baseUrl => widget.provider.fullApiUrl;

  @override
  void initState() {
    super.initState();
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

  void _toggleAutoRefresh() {
    if (_refreshTimer != null) {
      _refreshTimer!.cancel();
      _refreshTimer = null;
    } else {
      _startAutoRefresh();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchList(String mode) async {
    final url = '$_baseUrl/$mode?stationId=${widget.stationId}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = json.decode(response.body);
    final list = data['data'] as List<dynamic>? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> _fetchAll({bool silent = false}) async {
    if (!silent) setState(() { _isLoading = true; _error = null; });
    try {
      List<Map<String, dynamic>> deps = [];
      List<Map<String, dynamic>> arrs = [];
      if (widget.provider.endpoints.departures) {
        deps = await _fetchList('departures');
      }
      if (widget.provider.endpoints.arrivals) {
        arrs = await _fetchList('arrivals');
      }
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

  void _onTripTap(Map<String, dynamic> item) {
    final tripId = item['tripId']?.toString() ?? '';
    final tripNumber = item['tripNumber']?.toString() ?? '';
    if (tripId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegionalTrainDetailsSheet(
          provider: widget.provider,
          trainNumber: tripNumber,
          tripId: tripId,
        ),
      ),
    );
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
              widget.provider.provider,
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.textColor, size: 20),
            onPressed: () => _fetchAll(),
          ),
          IconButton(
            icon: Icon(
              _refreshTimer != null ? Icons.timer_rounded : Icons.timer_off_rounded,
              color: _refreshTimer != null ? theme.primaryColor : theme.secondaryTextColor,
              size: 20,
            ),
            onPressed: _toggleAutoRefresh,
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
            const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
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

  Widget _buildDepartureList(List<Map<String, dynamic>> items, ThemeProvider theme) {
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

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime.length >= 5 ? isoTime.substring(0, 5) : isoTime;
    }
  }

  Widget _buildDepartureItem(Map<String, dynamic> dep, ThemeProvider theme, bool isArrival) {
    final cat = (dep['category']?.toString() ?? '').trim();
    final num = (dep['tripNumber']?.toString() ?? '').trim();
    // Arrivi: mostra la provenienza (la destinazione e la stazione stessa).
    // Partenze: mostra la destinazione.
    // La stazione corrente non si scrive mai.
    final other = isArrival
        ? (dep['origin'] ?? '').toString().trim()
        : (dep['destination'] ?? '').toString().trim();
    final delayRaw = dep['delay'] ?? 0;
    final delay = delayRaw is int ? delayRaw : int.tryParse(delayRaw.toString()) ?? 0;
    final scheduled = dep['scheduledTime']?.toString() ?? '';
    final estimated = dep['estimatedTime']?.toString() ?? '';
    final platformRaw = dep['platform']?.toString().trim() ?? '';
    final hasPlatform = platformRaw.isNotEmpty && platformRaw != '-' && platformRaw.toLowerCase() != 'null';
    const color = AppTokens.trainColor;

    final timeStr = _formatTime(scheduled);
    final estStr = estimated.isNotEmpty ? _formatTime(estimated) : null;
    final showEst = estStr != null && estStr != timeStr;

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

    return InkWell(
      onTap: () => _onTripTap(dep),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
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
                        '$cat $num'.trim(),
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
                    other.isNotEmpty ? other : '--',
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
                Text(
                  showEst ? estStr : timeStr,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: showEst ? timeColor : theme.textColor,
                    fontSize: 15,
                  ),
                ),
                if (showEst)
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: theme.secondaryTextColor,
                      fontSize: 11,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                if (hasPlatform)
                  Text(
                    'Bin $platformRaw',
                    style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

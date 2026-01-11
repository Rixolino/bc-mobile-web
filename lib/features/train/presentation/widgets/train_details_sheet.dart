import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/models/train_model.dart';
import '../providers/train_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';

const Map<String, int> countryTimezoneOffsets = {
  'IT': 1, 'FR': 1, 'DE': 1, 'AT': 1, 'CH': 1, 'ES': 1,
  'GB': 0, 'NL': 1, 'BE': 1, 'LU': 1, 'CZ': 1, 'PL': 1,
  'HU': 1, 'RO': 2, 'GR': 2, 'SE': 1, 'NO': 1, 'DK': 1,
};

class _ActualTime {
  final DateTime time;
  final bool isEstimated;
  const _ActualTime(this.time, {this.isEstimated = false});
}

class TrainDetailsSheet extends StatefulWidget {
  final TrainDeparture departure;
  final bool isArrivalMode;

  const TrainDetailsSheet({super.key, required this.departure, required this.isArrivalMode});

  @override
  State<TrainDetailsSheet> createState() => _TrainDetailsSheetState();
}

class _TrainDetailsSheetState extends State<TrainDetailsSheet> {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settingsProvider.trainRefreshSeconds;
    if (interval > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(seconds: interval), (timer) => _refreshTrainDetails());
    }
  }

  void _toggleAutoRefresh() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final interval = settingsProvider.trainRefreshSeconds;
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer!.cancel();
      _autoRefreshTimer = null;
    } else if (interval > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(seconds: interval), (timer) => _refreshTrainDetails());
    }
    setState(() {});
  }

  void _refreshTrainDetails() {
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final index = trainProvider.departures.indexWhere((d) => 
      (widget.departure.tripId != null && d.tripId == widget.departure.tripId) ||
      (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination)
    );
    if (index != -1) trainProvider.expandTrainDetails(index);
  }

  String _formatStationTime(DateTime? date, String countryCode) {
    if (date == null) return '--:--';
    final int offset = countryTimezoneOffsets[countryCode] ?? 1;
    return DateFormat('HH:mm').format(date.toUtc().add(Duration(hours: offset)));
  }

  _ActualTime? _getActualTime(DateTime? scheduled, DateTime? estimated, int? delayMinutes) {
    if (estimated != null) return _ActualTime(estimated.toUtc(), isEstimated: true);
    if (scheduled != null) return _ActualTime(scheduled.toUtc().add(Duration(minutes: delayMinutes ?? 0)), isEstimated: false);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final List<TrainStop> stops = widget.departure.stops ?? [];
    final trainName = "${widget.departure.category ?? ''} ${widget.departure.trainNumber ?? ''}".trim();
    
    final lastDetection = widget.departure.metadata?['lastDetection'];
    final DateTime nowUtc = (lastDetection != null && lastDetection['timestamp'] != null)
        ? DateTime.parse(lastDetection['timestamp']).toUtc()
        : DateTime.now().toUtc();

    int currentSegmentIndex = -1;
    double segmentProgress = 0.0;
    bool isAtStation = false;

    if (stops.isNotEmpty) {
      for (int i = 0; i < stops.length - 1; i++) {
        final depCurrent = _getActualTime(stops[i].departure, stops[i].estimatedDeparture, stops[i].departureDelay ?? 0);
        final arrNext = _getActualTime(stops[i+1].arrival, stops[i+1].estimatedArrival, stops[i+1].arrivalDelay ?? 0);
        final arrCurrent = _getActualTime(stops[i].arrival, stops[i].estimatedArrival, stops[i].arrivalDelay ?? 0);

        if (depCurrent != null && depCurrent.isEstimated && arrNext != null && nowUtc.isAfter(depCurrent.time) && nowUtc.isBefore(arrNext.time)) {
          currentSegmentIndex = i;
          isAtStation = false;
          final total = arrNext.time.difference(depCurrent.time).inSeconds;
          final elapsed = nowUtc.difference(depCurrent.time).inSeconds;
          segmentProgress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 1.0;
          break;
        }

        if (arrCurrent != null && depCurrent != null && !nowUtc.isBefore(arrCurrent.time) && !nowUtc.isAfter(depCurrent.time)) {
          currentSegmentIndex = i;
          isAtStation = true;
          break;
        }
        
        if (arrNext != null && nowUtc.isAfter(arrNext.time)) currentSegmentIndex = i + 1;
      }
    }

    final int totalDelay = widget.departure.delayMinutes ?? 0;
    final String fullDisplayName = "$trainName";

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Container(
          decoration: BoxDecoration(color: theme.backgroundColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
      child: Column(
        children: [
          _buildHeader(context, fullDisplayName, totalDelay, theme),
          Expanded(
            child: stops.isEmpty 
              ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  itemCount: stops.length,
                  itemBuilder: (context, index) {
                    final isFuture = index > currentSegmentIndex;
                    return _TimelineRow(
                      stop: stops[index],
                      index: index,
                      isLast: index == stops.length - 1,
                      isCompleted: index < currentSegmentIndex,
                      isTraversing: (index == currentSegmentIndex) && !isAtStation && index < stops.length - 1,
                      isActiveStop: (index == currentSegmentIndex) && isAtStation,
                      progress: segmentProgress,
                      timeFormatter: _formatStationTime,
                      isFuture: isFuture,
                      totalDelay: totalDelay,
                      theme: theme,
                    );
                  },
                ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildHeader(BuildContext context, String displayName, int delay, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(color: theme.surfaceColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
      child: Column(
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.secondaryTextColor.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName, style: TextStyle(color: theme.textColor, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                    const SizedBox(height: 4),
                    Text(widget.isArrivalMode ? "Origine: ${widget.departure.origin}" : "Destinazione: ${widget.departure.destination}", 
                         style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              IconButton.filledTonal(icon: const Icon(Icons.refresh), onPressed: _refreshTrainDetails, style: IconButton.styleFrom(backgroundColor: theme.surfaceColor.withOpacity(0.05), foregroundColor: theme.primaryColor)),
              IconButton.filledTonal(icon: Icon(_autoRefreshTimer != null ? Icons.timer : Icons.timer_off), onPressed: _toggleAutoRefresh, style: IconButton.styleFrom(backgroundColor: theme.surfaceColor.withOpacity(0.05), foregroundColor: _autoRefreshTimer != null ? theme.primaryColor : theme.secondaryTextColor)),
            ],
          ),
          const SizedBox(height: 16),
          _buildDelayBadge(delay),
        ],
      ),
    );
  }

  Widget _buildDelayBadge(int delay) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    Color badgeColor;
    String statusText;
    IconData iconData;

    if (delay < 0) {
      badgeColor = theme.successColor;
      statusText = "In anticipo: $delay min";
      iconData = Icons.fast_forward_rounded;
    } else if (delay == 0) {
      badgeColor = theme.successColor;
      statusText = "In orario";
      iconData = Icons.check_circle_rounded;
    } else if (delay <= 5) {
      badgeColor = theme.warningColor;
      statusText = "Lieve ritardo: +$delay min";
      iconData = Icons.bolt_rounded;
    } else if (delay <= 15) {
      badgeColor = theme.warningColor;
      statusText = "Ritardo medio: +$delay min";
      iconData = Icons.warning_rounded;
    } else {
      badgeColor = theme.errorColor;
      statusText = "Forte ritardo: +$delay min";
      iconData = Icons.error_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(iconData, color: badgeColor, size: 18),
          const SizedBox(width: 8),
          Text(statusText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final TrainStop stop;
  final int index;
  final bool isLast;
  final bool isCompleted;
  final bool isTraversing;
  final bool isActiveStop;
  final double progress;
  final String Function(DateTime?, String) timeFormatter;
  final bool isFuture;
  final int totalDelay;
  final ThemeProvider theme;

  const _TimelineRow({
    required this.stop, required this.index, required this.isLast, 
    required this.isCompleted, required this.isTraversing, 
    required this.isActiveStop, required this.progress, required this.timeFormatter,
    required this.isFuture, required this.totalDelay, required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final bool highlighted = isCompleted || isActiveStop || isTraversing;

    String buildTimeString(String type, DateTime? scheduled, DateTime? estimated, int delay) {
      if (scheduled == null && estimated == null) return '';
      final effective = estimated ?? scheduled!.add(Duration(minutes: delay));
      final effStr = timeFormatter(effective, stop.country);
      final delayStr = delay != 0 ? " (${delay > 0 ? '+' : ''}${delay}min)" : "";
      
      if (scheduled != null && (estimated != null || delay != 0)) {
        return '$type: $effStr$delayStr (Previsto: ${timeFormatter(scheduled, stop.country)})';
      }
      return '$type: $effStr';
    }

    return IntrinsicHeight(
      child: Row(
        children: [
          const SizedBox(width: 16),
          _buildVisualTimeline(highlighted),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(stop.stationName, style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.6) : theme.textColor, fontSize: 16, fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600)),
                  if (stop.arrival != null) 
                    Text(buildTimeString('Arrivo', stop.arrival, stop.estimatedArrival, isFuture ? totalDelay : (stop.arrivalDelay ?? 0)),
                        style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor, fontSize: 12)),
                  if (stop.departure != null)
                    Text(buildTimeString('Partenza', stop.departure, stop.estimatedDeparture, isFuture ? totalDelay : (stop.departureDelay ?? 0)),
                        style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor, fontSize: 12)),
                ],
              ),
            ),
          ),
          if (stop.platform != null && stop.platform!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 12, bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: theme.primaryColor.withOpacity(0.5), width: 1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text("${stop.platform}", style: TextStyle(color: theme.primaryColor, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualTimeline(bool highlighted) {
    return SizedBox(
      width: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (index > 0) Positioned(top: 0, height: 17, width: 3, child: Container(color: highlighted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.05))),
          if (!isLast) Positioned(top: 17, bottom: 0, width: 3, child: Stack(children: [
            Container(color: theme.surfaceColor.withOpacity(0.05)),
            if (isCompleted) Container(color: theme.primaryColor),
            if (isTraversing) LayoutBuilder(builder: (c, ct) => Container(height: ct.maxHeight * progress, decoration: BoxDecoration(gradient: theme.progressGradient))),
          ])),
          Positioned(top: 17, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: highlighted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.08), shape: BoxShape.circle, border: Border.all(color: highlighted ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.24), width: 2)))),
          if (isTraversing) Positioned.fill(child: LayoutBuilder(builder: (c, ct) => Stack(alignment: Alignment.topCenter, children: [
            Positioned(top: 17 + ((ct.maxHeight - 17) * progress) - 10, child: const _TrainIcon(size: 20))
          ]))) else if (isActiveStop) Positioned(top: 12, child: _TrainIcon(size: 20)),
        ],
      ),
    );
  }
}

class _TrainIcon extends StatelessWidget {
  final double size;
  const _TrainIcon({required this.size});
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: theme.primaryColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: theme.primaryColor.withOpacity(0.4), blurRadius: 10)]),
      child: Icon(Icons.train, color: theme.textColor, size: size - 8),
    );
  }
}
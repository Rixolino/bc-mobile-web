import 'dart:async';
import 'dart:io';
import 'package:bc_transporter/features/train/presentation/widgets/train_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../data/models/train_model.dart';
import '../providers/train_provider.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_train.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../../core/utils/country_time.dart';
import '../../../../presentation/providers/notification_manager_provider.dart';
import '../pages/train_map_page.dart';
import '../../../../core/services/runtime_localizations.dart';
import 'dart:convert';

class _ActualTime {
  final DateTime time;
  final bool isEstimated;
  const _ActualTime(this.time, {this.isEstimated = false});
}

Map<String, DateTime?> _estimateStopTimesGlobal(TrainStop s, int trainDelay) {
  DateTime? arr = s.estimatedArrival?.toUtc() ?? (s.arrival != null ? s.arrival!.toUtc().add(Duration(minutes: trainDelay)) : null);
  DateTime? dep = s.estimatedDeparture?.toUtc() ?? (s.departure != null ? s.departure!.toUtc().add(Duration(minutes: trainDelay)) : null);

  if (arr == null && dep != null) arr = dep.subtract(const Duration(minutes: 1));
  if (dep == null && arr != null) dep = arr.add(const Duration(minutes: 1));

  return {'arr': arr, 'dep': dep};
}

class TrainDetailsSheet extends StatefulWidget {
  final TrainDeparture departure;
  final bool isArrivalMode;
  final String? selectedCountry;
  final ScrollController? scrollController;

  const TrainDetailsSheet({super.key, required this.departure, required this.isArrivalMode, this.selectedCountry, this.scrollController});

  @override
  State<TrainDetailsSheet> createState() => _TrainDetailsSheetState();
}

class _TrainNotificationsButton extends StatefulWidget {
  final TrainDeparture departure;
  final String? selectedCountry;
  final bool isPrimary;

  const _TrainNotificationsButton({
    required this.departure, 
    this.selectedCountry,
    this.isPrimary = false,
  });

  @override
  State<_TrainNotificationsButton> createState() => __TrainNotificationsButtonState();
} 

class __TrainNotificationsButtonState extends State<_TrainNotificationsButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _loadMonitoredState();
  }

  Future<void> _loadMonitoredState() async {
    final tripKey = widget.departure.tripId ?? widget.departure.trainNumber ?? '';
    if (tripKey.isEmpty) return;
    try {
      final monitored = await AndroidBackgroundService.getMonitoredTrips();
      if (monitored.containsKey(tripKey)) {
        if (!mounted) return;
        setState(() { _enabled = true; });
      }
    } catch (e) {
      // ignore errors
    }
  }

  String _buildTrainNotificationTitle(TrainDeparture d) {
    final parts = <String>[];
    if ((d.category ?? '').isNotEmpty) parts.add(d.category!);
    if ((d.trainNumber ?? '').isNotEmpty) parts.add(d.trainNumber!);
    final trainName = parts.join(' ').trim();

    String origin = d.origin ?? '';
    String dest = d.destination ?? '';
    final stops = d.stops ?? [];
    if ((origin.isEmpty || dest.isEmpty) && stops.isNotEmpty) {
      origin = origin.isNotEmpty ? origin : stops.first.stationName;
      dest = dest.isNotEmpty ? dest : stops.last.stationName;
    }

    if (origin.isEmpty && dest.isEmpty) {
      if (trainName.isNotEmpty) return trainName;
      return d.tripId ?? 'Treno';
    }

    final nameWithSpace = trainName.isNotEmpty ? '$trainName ' : '';
    return "$nameWithSpace($origin → $dest)";
  }

  String _buildTrainNotificationBody(TrainDeparture d, {String? userDestination}) {
    final now = DateTime.now().toUtc();
    final stops = d.stops ?? [];

    _ActualTime? _stopActual(DateTime? scheduled, DateTime? estimated, int? stopDelayMinutes) {
      if (estimated != null) return _ActualTime(estimated.toUtc(), isEstimated: true);
      if (scheduled != null) {
        final int trainDelay = d.delayMinutes ?? 0;
        final int useDelay = trainDelay != 0 ? trainDelay : (stopDelayMinutes ?? 0);
        return _ActualTime(scheduled.toUtc().add(Duration(minutes: useDelay)), isEstimated: false);
      }
      return null;
    }

    final stopStates = <Map<String, dynamic>>[];
    for (int i = 0; i < stops.length; i++) {
      final s = stops[i];
      final DateTime? arrUtc = _stopActual(s.arrival, s.estimatedArrival, 0)?.time;
      final DateTime? depUtc = _stopActual(s.departure, s.estimatedDeparture, s.departureDelay)?.time;
      stopStates.add({
        'index': i,
        'stop': s,
        'arrUtc': arrUtc,
        'depUtc': depUtc,
        'cancelled': s.cancelled,
      });
    }

    int nextIndex = -1;
    String nextStop = '';
    DateTime? nextArrival;
    DateTime? nextDeparture;
    String lastPassed = '';
    bool isAtStation = false;

    final meta = d.metadata;
    if (meta != null) {
      final Map? lastDet = meta['lastDetection'] as Map?;
      if (lastDet != null) {
        String? stationName = lastDet['station']?.toString() ?? lastDet['stationName']?.toString();
        int? idxFromMeta;
        if (lastDet['stopIndex'] != null) idxFromMeta = int.tryParse(lastDet['stopIndex'].toString());
        if (stationName != null && stationName.isNotEmpty) {
          idxFromMeta ??= stopStates.indexWhere((ss) => (ss['stop'] as TrainStop).stationName.trim().toLowerCase() == stationName.trim().toLowerCase());
        }
        if (idxFromMeta != null && idxFromMeta >= 0 && idxFromMeta < stopStates.length) {
          final currentIdx = idxFromMeta;
          lastPassed = (stopStates[currentIdx]['stop'] as TrainStop).stationName;

          final atStationFlag = lastDet['atStation'] ?? lastDet['isAtStation'] ?? false;
          if (atStationFlag == true) {
            isAtStation = true;
          } else {
            final tsRaw = lastDet['timestamp'];
            if (tsRaw != null) {
              final ts = DateTime.tryParse(tsRaw.toString())?.toUtc();
              if (ts != null) {
                final arrUtc = stopStates[currentIdx]['arrUtc'] as DateTime?;
                final depUtc = stopStates[currentIdx]['depUtc'] as DateTime?;
                if (arrUtc != null && depUtc != null && !ts.isBefore(arrUtc) && !ts.isAfter(depUtc)) {
                  isAtStation = true;
                }
              }
            }
          }

          final ni = currentIdx + 1;
          if (ni < stopStates.length) {
            final nxt = stopStates[ni];
            if (!(nxt['cancelled'] as bool)) {
              nextIndex = ni;
              nextStop = (nxt['stop'] as TrainStop).stationName;
              nextArrival = nxt['arrUtc'] as DateTime?;
              nextDeparture = nxt['depUtc'] as DateTime?;
            }
          }
        }
      }
    }

    if (nextIndex == -1) {
      DateTime? bestArr;
      int bestIdx = -1;
      for (var ss in stopStates) {
        if (ss['cancelled'] == true) continue;
        final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
        if (arrUtc != null && arrUtc.isAfter(now)) {
          final diff = arrUtc.difference(now).inSeconds;
          if (bestArr == null || diff < bestArr.difference(now).inSeconds) {
            bestArr = arrUtc;
            bestIdx = ss['index'] as int;
          }
        }
      }
      if (bestIdx != -1) {
        final s = stopStates[bestIdx];
        nextIndex = bestIdx;
        nextStop = (s['stop'] as TrainStop).stationName;
        nextArrival = s['arrUtc'] as DateTime?;
        nextDeparture = s['depUtc'] as DateTime?;
      }
    }

    if (nextIndex == -1 && stopStates.isNotEmpty) {
      int lastIdx = -1;
      for (var ss in stopStates) {
        final DateTime? depUtc = ss['depUtc'] as DateTime?;
        final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
        
        bool isPassed = false;
        if (depUtc != null) {
          if (depUtc.isBefore(now)) isPassed = true;
        } else if (arrUtc != null && arrUtc.isBefore(now)) {
          isPassed = true;
        }
        
        if (arrUtc != null && depUtc != null && !arrUtc.isAfter(now) && !depUtc.isBefore(now)) {
           isAtStation = true;
           lastPassed = (ss['stop'] as TrainStop).stationName;
           lastIdx = ss['index'] as int;
        } else if (isPassed) {
           lastIdx = ss['index'] as int;
        }
      }
      bool found = false;
      for (int i = lastIdx + 1; i < stopStates.length; i++) {
        if (stopStates[i]['cancelled'] == true) continue;
        nextIndex = i;
        nextStop = (stopStates[i]['stop'] as TrainStop).stationName;
        nextArrival = stopStates[i]['arrUtc'] as DateTime?;
        nextDeparture = stopStates[i]['depUtc'] as DateTime?;
        found = true;
        break;
      }
      if (!found) {
        for (var ss in stopStates) {
          if (ss['cancelled'] == true) continue;
          nextIndex = ss['index'] as int;
          nextStop = (ss['stop'] as TrainStop).stationName;
          nextArrival = ss['arrUtc'] as DateTime?;
          nextDeparture = ss['depUtc'] as DateTime?;
          break;
        }
      }
    }

    if (lastPassed.isEmpty) {
      int lastIdx = -1;
      for (var ss in stopStates) {
        final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
        final DateTime? depUtc = ss['depUtc'] as DateTime?;
        
        bool isPassed = false;
        if (depUtc != null) {
          if (depUtc.isBefore(now)) isPassed = true;
        } else if (arrUtc != null && arrUtc.isBefore(now)) {
           isPassed = true;
        }
        
        if (arrUtc != null && depUtc != null && !arrUtc.isAfter(now) && !depUtc.isBefore(now)) {
           lastIdx = ss['index'] as int;
           isAtStation = true;
        } else if (isPassed) {
           lastIdx = ss['index'] as int;
        }
      }
      if (lastIdx >= 0) lastPassed = (stopStates[lastIdx]['stop'] as TrainStop).stationName;
    }

    if (kDebugMode) {
      // ignore: avoid_print
      print('[notif-debug] now=$now nextIndex=$nextIndex nextStop=$nextStop lastPassed=$lastPassed isAtStation=$isAtStation');
    }

    final delay = d.delayMinutes ?? 0;

    int remaining = 0;
    if (userDestination != null && userDestination.trim().isNotEmpty && stops.isNotEmpty) {
      final destIndex = stops.indexWhere((s) => s.stationName.trim().toLowerCase() == userDestination.trim().toLowerCase());
      if (destIndex != -1 && nextIndex != -1) {
        final int start = nextIndex < destIndex ? nextIndex : nextIndex;
        int count = 0;
        for (int i = start + 1; i <= destIndex; i++) if (!stops[i].cancelled) count++;
        remaining = count;
      }
    } else if (nextIndex != -1) {
      int count = 0;
      for (int i = nextIndex + 1; i < stops.length; i++) if (!stops[i].cancelled) count++;
      remaining = count;
    }

    if (userDestination != null && userDestination.trim().isNotEmpty) {
      final destIdx = stops.indexWhere((s) => s.stationName.trim().toLowerCase() == userDestination.trim().toLowerCase());
      if (destIdx != -1 && stops[destIdx].cancelled) return '\u26A0\uFE0F La tua fermata ($userDestination) \u00E8 stata annullata.';
      if (isAtStation && lastPassed.trim().toLowerCase() == userDestination.trim().toLowerCase()) {
        return '\u26A0\uFE0F Treno in stazione: $userDestination. Ricordati di scendere.';
      }
      if (nextStop.trim().toLowerCase() == userDestination.trim().toLowerCase()) {
        return '\u26A0\uFE0F Sei in arrivo alla tua fermata: $userDestination. Prossima discesa.';
      }
      if (lastPassed.trim().toLowerCase() == userDestination.trim().toLowerCase() && nextIndex == -1) {
        return '\uD83D\uDE89 Sei arrivato a $userDestination. Ricordati di scendere dal treno!';
      }
    }

    final buffer = StringBuffer();
    if (nextStop.isNotEmpty) {
      final arrStr = nextArrival != null ? '${nextArrival.toLocal().hour.toString().padLeft(2, '0')}:${nextArrival.toLocal().minute.toString().padLeft(2, '0')}' : '--:--';
      final depStr = nextDeparture != null ? '${nextDeparture.toLocal().hour.toString().padLeft(2, '0')}:${nextDeparture.toLocal().minute.toString().padLeft(2, '0')}' : '';
      String platform = '';
      if (nextIndex >= 0 && nextIndex < stops.length) {
        platform = stops[nextIndex].platform ?? '';
      }
      final platformPart = platform.isNotEmpty ? ' \u2022 Binario: $platform' : '';
      String eventLabel = '';
      if (depStr.isNotEmpty) {
        eventLabel = 'In partenza alle $depStr';
      } else if (arrStr.isNotEmpty) {
        eventLabel = 'In arrivo alle $arrStr';
      }
      buffer.writeln('Prossima fermata: $nextStop$platformPart${eventLabel.isNotEmpty ? ' \u2022 $eventLabel' : ''}');
    } else {
      buffer.writeln('Prossima fermata: --');
    }

    if (isAtStation && lastPassed.isNotEmpty) {
      buffer.writeln('Treno in stazione: $lastPassed');
    } else {
      buffer.writeln('Stato attuale: ${lastPassed.isNotEmpty ? lastPassed : 'In transito'}');
    }

    if (delay > 0) {
      buffer.writeln(RuntimeLocalizations.t(context, 'delay_minutes', params: {'minutes': delay.toString()}));
    } else if (delay < 0) {
      buffer.writeln(RuntimeLocalizations.t(context, 'early_minutes', params: {'minutes': (-delay).toString()}));
    } else {
      buffer.writeln(RuntimeLocalizations.t(context, 'on_time'));
    }

    buffer.writeln(RuntimeLocalizations.t(context, 'remaining_stops', params: {'count': remaining.toString()}));

    return buffer.toString().trim();
  }

  Future<void> _toggle() async {
    final tripId = widget.departure.tripId ?? widget.departure.trainNumber ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        String? selectedStop;
        return StatefulBuilder(
          builder: (ctx, sbSetState) {
            final stops = widget.departure.stops ?? [];

            String previewTitle() => _buildTrainNotificationTitle(widget.departure);
            String previewBody() => _buildTrainNotificationBody(widget.departure, userDestination: selectedStop);

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(title: Text(RuntimeLocalizations.t(context, 'notify_until')), subtitle: Text(RuntimeLocalizations.t(context, 'choose_stop_from_list'))),
                  if (stops.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(RuntimeLocalizations.t(context, 'stops_list_unavailable_general_notification'))),
                  if (stops.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: stops.length,
                        itemBuilder: (c, i) {
                          final s = stops[i];
                          final nowUtc = DateTime.now().toUtc();
                          final times = _estimateStopTimesGlobal(s, widget.departure.delayMinutes ?? 0);
                          final DateTime? arr = times['arr'] as DateTime?;
                          final DateTime? dep = times['dep'] as DateTime?;

                          bool isPassed = false;
                          bool isCurrent = false;
                          if (dep != null && dep.isBefore(nowUtc)) {
                            isPassed = true;
                          } else if (arr != null && arr.isBefore(nowUtc) && (dep == null || arr.isBefore(nowUtc))) {
                            isPassed = true;
                          }
                          if (arr != null && nowUtc.isAfter(arr) && (dep == null || nowUtc.isBefore(dep))) {
                            isCurrent = true;
                          }
                          final bool isCancelled = s.cancelled;
                          final titleStyle = isCancelled ? TextStyle(color: Colors.red, fontStyle: FontStyle.italic) : (isPassed ? TextStyle(color: Colors.grey) : (isCurrent ? TextStyle(fontWeight: FontWeight.w700) : null));
                          final subParts = <String>[];
                          if (s.country.isNotEmpty) subParts.add(s.country);
                          if (isPassed) subParts.add('gi\u00E0 passata');
                          else if (isCurrent) subParts.add('attuale');
                          if (isCancelled) subParts.add('annullata');
                          final subtitleText = subParts.join(' \u2022 ');
                          final disabled = isPassed || isCancelled;
                          return RadioListTile<String>(
                            value: s.stationName,
                            groupValue: selectedStop,
                            title: Text(
                              s.stationName,
                              style: titleStyle,
                            ),
                            subtitle: subtitleText.isNotEmpty ? Text(subtitleText) : null,
                            onChanged: disabled ? null : (v) => sbSetState(() { selectedStop = v; }),
                            enabled: !disabled,
                          );
                        },
                      ),
                    ),
                  const Divider(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(RuntimeLocalizations.t(context, 'notification_preview'), style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(previewTitle(), style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(previewBody()),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            child: Text(RuntimeLocalizations.t(context, 'notify_to_selected_stop')),
                            onPressed: selectedStop == null && stops.isNotEmpty ? null : () async {
                              Navigator.pop(ctx);
                              final settings = Provider.of<SettingsProvider>(context, listen: false);
                              await AndroidBackgroundService.requestPermission();
                              await _resolveAndSchedule(
                                tripId: tripId.isNotEmpty ? tripId : null,
                                notifyMode: 'to_destination',
                                destinationStop: selectedStop,
                                settingsInterval: settings.trainRefreshSeconds,
                                ctx: context,
                              );
                              setState(() => _enabled = true);
                            },

                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            child: Text(RuntimeLocalizations.t(context, 'notify_general')),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              final settings = Provider.of<SettingsProvider>(context, listen: false);
                              await AndroidBackgroundService.requestPermission();
                              await _resolveAndSchedule(
                                tripId: tripId.isNotEmpty ? tripId : null,
                                notifyMode: 'general',
                                destinationStop: null,
                                settingsInterval: settings.trainRefreshSeconds,
                                ctx: context,
                              );
                              setState(() => _enabled = true);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextButton(
                      child: Text(RuntimeLocalizations.t(context, 'disable_notifications_for_this_train'), style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                      final monitorKey = tripId.isNotEmpty ? tripId : (widget.departure.trainNumber ?? '');
                      if (monitorKey.isNotEmpty) await AndroidBackgroundService.removeMonitoredTrip(monitorKey);
                      final key = 'train:$monitorKey';
                        await AndroidBackgroundService.cancelNotification(key: key);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(context, 'notifications_disabled'))));
                        setState(() => _enabled = false);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  bool ifNotEmpty(String? v) => v != null && v.isNotEmpty;

  Future<void> _resolveAndSchedule({String? tripId, required String? notifyMode, String? destinationStop, required int settingsInterval, required BuildContext ctx}) async {
    final prodBase = 'https://prod.cuzimmartin.dev/api';
    final trainProvider = Provider.of<TrainProvider>(ctx, listen: false);
    final idx = trainProvider.departures.indexWhere((d) => 
      (tripId != null && (d.tripId == tripId || d.trainNumber == tripId)) || 
      (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination)
    );
    if (idx != -1) {
      try {
        await trainProvider.expandTrainDetails(idx);
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (e) {
        // ignore
      }
    }

    final TrainDeparture currentDep = (idx != -1) ? trainProvider.departures[idx] : widget.departure;
    final metaEndpoint = currentDep.metadata != null ? (currentDep.metadata!['endpoint'] as String?) : null;
    dynamic countryCandidate = currentDep.metadata?['country'];
    if (countryCandidate == null || (countryCandidate is String && countryCandidate.toString().isEmpty)) {
      if (currentDep.country.isNotEmpty) {
        countryCandidate = currentDep.country;
      } else if (widget.selectedCountry != null && widget.selectedCountry!.isNotEmpty) {
        countryCandidate = widget.selectedCountry;
      } else {
        countryCandidate = null;
      }
    }
    final String? countryFromMeta = countryCandidate?.toString();

    String? resolvedEndpoint;
    String? usedCountry;

    if (metaEndpoint != null && metaEndpoint.isNotEmpty) {
      resolvedEndpoint = metaEndpoint;
    } else if (tripId != null && tripId.isNotEmpty && countryFromMeta != null && countryFromMeta.isNotEmpty) {
      final candidate = '$prodBase/${countryFromMeta}/trip?tripId=${Uri.encodeComponent(tripId)}';
      try {
        final resp = await http.get(Uri.parse(candidate)).timeout(const Duration(seconds: 6));
            if (resp.statusCode == 200) {
          final body = resp.body;
          if (body.contains('stops') || body.contains('data') || body.contains('trip')) {
            resolvedEndpoint = candidate;
            usedCountry = countryFromMeta;
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(ctx, 'endpoint_check_failed_country'))));
          }
          } else {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(ctx, 'endpoint_request_failed', params: {'candidate': candidate, 'code': resp.statusCode.toString()}))));
        }
      } catch (e) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(ctx, 'network_error_endpoint_check'))));
      }
    } else if (tripId != null && tripId.isNotEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(ctx, 'cannot_determine_url_set_country'))));
    }

    final settings = Provider.of<SettingsProvider>(ctx, listen: false);
    String? startingStop = widget.departure.stops?.isNotEmpty == true ? widget.departure.stops!.first.stationName : null;
    await AndroidBackgroundService.scheduleTrainsWorker(
      tripId: tripId,
      country: usedCountry ?? countryFromMeta,
      endpoint: resolvedEndpoint,
      intervalSeconds: settingsInterval,
      notifyMode: notifyMode,
      destinationStop: destinationStop,
      startingStop: startingStop,
      arrivalNoticeMinutes: settings.trainArrivalPreNoticeMinutes,
    );

    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(ctx, 'notification_set'))));

    if (notifyMode == 'to_destination' && destinationStop != null && destinationStop.isNotEmpty) {
      final notifProv = Provider.of<NotificationManagerProvider>(ctx, listen: false);
      notifProv.triggerProximityCheckForTrip(tripId ?? '', destinationStop, settings.trainArrivalPreNoticeMinutes, startingStop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    
    if (widget.isPrimary) {
      return Expanded(
        child: _PrimaryActionChip(
          icon: _enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
          label: RuntimeLocalizations.t(context, 'notifications'),
          isActive: _enabled,
          theme: theme,
          onTap: _toggle,
        ),
      );
    }
    
    return _PrimaryActionChip(
      icon: _enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
      label: "Notifiche",
      isActive: _enabled,
      theme: theme,
      onTap: _toggle,
    );
  }
}

class _TrainDetailsSheetState extends State<TrainDetailsSheet> {
  Timer? _autoRefreshTimer;
  Timer? _progressTimer;
  Timer? _connectivityTimer;
  late TrainProvider _trainProvider;
  late SettingsProvider _settingsProvider;
  bool _isCheckingConnectionForLive = false;
  bool _lastInternetState = true;
  bool _isNetworkOffline = false;
  bool _preventOnlineAutoRefresh = false;
  bool _isHandlingConnectivityChange = false;
  bool _isCachedOffline = false;
  bool _manualOfflineSaved = false;

  // Full details fetched locally for trains opened from outside the current timetable
  TrainDeparture? _externalDep;
  bool _isLoadingExternalDetails = false;
  bool _externalFetchAttempted = false;
  Timer? _fetchTimeoutTimer;
  
  // Aggiunto per evitare il flicker dell'errore
  bool _hasLoadedExternalData = false;

  @override
  void initState() {
    super.initState();
    _trainProvider = Provider.of<TrainProvider>(context, listen: false);
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _startAutoRefresh();
    _startConnectivityMonitor();
    _checkCacheStatus();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    
    _maybeFetchExternalTripDetails();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _progressTimer?.cancel();
    _connectivityTimer?.cancel();
    _fetchTimeoutTimer?.cancel();
    super.dispose();
  }

  bool get _needsExternalFetch {
    final hasStops = widget.departure.stops != null && widget.departure.stops!.isNotEmpty;
    return !hasStops;
  }

  Future<void> _maybeFetchExternalTripDetails() async {
    if (!_needsExternalFetch) {
      if (mounted) setState(() {
        _isLoadingExternalDetails = false;
        _externalFetchAttempted = true;
        _hasLoadedExternalData = true;
      });
      return;
    }

    if (_externalFetchAttempted || _isLoadingExternalDetails) return;
    
    final tripId = widget.departure.tripId;
    if (tripId == null || tripId.isEmpty) {
      if (mounted) setState(() {
        _isLoadingExternalDetails = false;
        _externalFetchAttempted = true;
        _hasLoadedExternalData = true;
        _externalDep = widget.departure.copyWith(error: 'ID treno mancante');
      });
      return;
    }

    if (mounted) setState(() {
      _isLoadingExternalDetails = true;
      _externalFetchAttempted = true;
    });

    _fetchTimeoutTimer?.cancel();
    _fetchTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      setState(() {
        _isLoadingExternalDetails = false;
        _hasLoadedExternalData = true;
        _externalDep = widget.departure.copyWith(error: 'Timeout durante il caricamento dei dettagli');
      });
    });

    final country = widget.departure.country.isNotEmpty
        ? widget.departure.country
        : (widget.selectedCountry ?? 'IT');

    debugPrint('📡 Fetching external trip: https://prod.cuzimmartin.dev/api/$country/trip?tripId=${Uri.encodeComponent(tripId)}');

    try {
      final uri = Uri.parse('https://prod.cuzimmartin.dev/api/$country/trip?tripId=${Uri.encodeComponent(tripId)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));

      _fetchTimeoutTimer?.cancel();

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final decoded = json.decode(resp.body);
        if (decoded is Map<String, dynamic>) {
          final tripData = decoded['trip'] ?? decoded['data'] ?? decoded;
          
          List<TrainStop> stops = [];
          final stopsData = tripData['stops'] ?? tripData['stopList'] ?? [];
          if (stopsData is List) {
            stops = stopsData.map((s) => TrainStop.fromJson(s as Map<String, dynamic>)).toList();
          }

          final enriched = TrainDeparture(
            tripId: widget.departure.tripId,
            trainNumber: tripData['trainNumber']?.toString() ?? widget.departure.trainNumber,
            category: tripData['category']?.toString() ?? widget.departure.category,
            origin: tripData['origin']?.toString() ?? widget.departure.origin,
            destination: tripData['destination']?.toString() ?? widget.departure.destination,
            country: tripData['country']?.toString() ?? country,
            status: tripData['status']?.toString() ?? widget.departure.status,
            delayMinutes: tripData['delay'] ?? widget.departure.delayMinutes ?? 0,
            scheduledTime: tripData['scheduledTime'] != null 
                ? DateTime.tryParse(tripData['scheduledTime'].toString()) 
                : widget.departure.scheduledTime,
            estimatedTime: tripData['estimatedTime'] != null 
                ? DateTime.tryParse(tripData['estimatedTime'].toString()) 
                : widget.departure.estimatedTime,
            platform: tripData['platform']?.toString() ?? widget.departure.platform,
            stops: stops,
            messages: tripData['messages'] != null 
                ? List<Map<String, dynamic>>.from(tripData['messages']) 
                : null,
            metadata: tripData['metadata'] as Map<String, dynamic>?,
          );

          setState(() {
            _externalDep = enriched;
            _isLoadingExternalDetails = false;
            _hasLoadedExternalData = true;
          });
          return;
        }
      }

      setState(() {
        _externalDep = widget.departure.copyWith(
          error: 'Impossibile caricare i dettagli del treno (HTTP ${resp.statusCode})'
        );
        _isLoadingExternalDetails = false;
        _hasLoadedExternalData = true;
      });
    } catch (e) {
      _fetchTimeoutTimer?.cancel();
      debugPrint('❌ Error fetching external trip: $e');
      if (!mounted) return;
      setState(() {
        _externalDep = widget.departure.copyWith(
          error: 'Errore di rete: $e'
        );
        _isLoadingExternalDetails = false;
        _hasLoadedExternalData = true;
      });
    }
  }

  Future<void> _checkCacheStatus() async {
    if (_trainProvider.selectedStation == null) return;
    
    final isCached = await _trainProvider.isTrainCachedOffline(widget.departure.tripId);
    
    if (mounted) {
      setState(() {
        _isCachedOffline = isCached;
        if (!isCached) {
          _manualOfflineSaved = false;
        }
      });
    }
  }

  void _startConnectivityMonitor() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _handleConnectivityTick(),
    );
    _handleConnectivityTick();
  }

  Future<void> _handleConnectivityTick() async {
    if (_isHandlingConnectivityChange || !mounted) return;

    _isHandlingConnectivityChange = true;
    try {
      final hasInternet = await _hasInternetConnection();
      if (!mounted) return;

      final wasNetworkOffline = _isNetworkOffline;
      _isNetworkOffline = !hasInternet;

      if (!hasInternet) {
        _preventOnlineAutoRefresh = true;
        _autoRefreshTimer?.cancel();
        _autoRefreshTimer = null;
        _trainProvider.setOnlineAutoRefreshBlocked(true);

        if (_lastInternetState && _settingsProvider.offlineSyncEnabled) {
          await _trainProvider.loadSelectedStationFromOfflineCache();
        }

        if (mounted && !wasNetworkOffline) setState(() {});
      }

      if (hasInternet && !_lastInternetState && _settingsProvider.offlineSyncEnabled) {
        final station = _trainProvider.selectedStation;
        if (station != null) {
          await _trainProvider.fetchDepartures(
            station.id,
            country: station.country,
            silent: true,
            offlineSyncEnabled: true,
          );
        }
        if (!_trainProvider.isUsingOfflineCache) {
          _preventOnlineAutoRefresh = false;
        }
      }

      _lastInternetState = hasInternet;
      if (mounted && wasNetworkOffline != _isNetworkOffline) setState(() {});
    } finally {
      _isHandlingConnectivityChange = false;
    }
  }

  void _startAutoRefresh() {
    if (_preventOnlineAutoRefresh || _trainProvider.isUsingOfflineCache || _isNetworkOffline) return;

    final interval = _settingsProvider.trainRefreshSeconds;
    if (interval > 0) {
      _autoRefreshTimer = Timer.periodic(Duration(seconds: interval), (timer) => _refreshTrainDetails());
    }
  }

  Future<void> _toggleAutoRefresh() async {
    if (_preventOnlineAutoRefresh || _trainProvider.isUsingOfflineCache || _isNetworkOffline) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      if (mounted) setState(() {});
      return;
    }

    final interval = _settingsProvider.trainRefreshSeconds;
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer!.cancel();
      _autoRefreshTimer = null;
    } else if (interval > 0) {
      if (!await _hasInternetConnection()) return;
      if (!mounted) return;
      _autoRefreshTimer = Timer.periodic(Duration(seconds: interval), (timer) => _refreshTrainDetails());
    }
    if (mounted) setState(() {});
  }

  void _refreshTrainDetails() {
    if (!mounted) return;
    if (_preventOnlineAutoRefresh || _trainProvider.isUsingOfflineCache || _isNetworkOffline) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      if (mounted) setState(() {});
      return;
    }

    final index = _trainProvider.departures.indexWhere((d) => 
      (widget.departure.tripId != null && d.tripId == widget.departure.tripId) ||
      (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination)
    );
    if (index != -1) {
       _trainProvider.expandTrainDetails(index);
     }
  }

  void _syncDetailsAutoRefresh(bool isUsingOfflineCache) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_preventOnlineAutoRefresh || isUsingOfflineCache || _isNetworkOffline) {
        if (_autoRefreshTimer != null) {
          _autoRefreshTimer!.cancel();
          _autoRefreshTimer = null;
          setState(() {});
        }
        return;
      }

      final interval = _settingsProvider.trainRefreshSeconds;
      if (interval > 0 && _autoRefreshTimer == null && !_isCheckingConnectionForLive) {
        _isCheckingConnectionForLive = true;
        final hasInternet = await _hasInternetConnection();
        _isCheckingConnectionForLive = false;
        if (!mounted || !hasInternet) return;
        if (_preventOnlineAutoRefresh || _isNetworkOffline) return;
        if (_trainProvider.isUsingOfflineCache) return;

        _autoRefreshTimer = Timer.periodic(
          Duration(seconds: interval),
          (timer) => _refreshTrainDetails(),
        );
        setState(() {});
      }
    });
  }

  Future<bool> _hasInternetConnection() async {
    if (kIsWeb) return true;
    Socket? socket;
    try {
      socket = await Socket.connect(
        '1.1.1.1',
        53,
        timeout: const Duration(seconds: 2),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  String _formatStationTime(DateTime? date, String countryCode) {
    return formatCountryTime(date, countryCode);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrainProvider>(
      builder: (context, provider, child) {
        _syncDetailsAutoRefresh(provider.isUsingOfflineCache);

        final currentDep = provider.departures.firstWhere(
           (d) => (d.tripId != null && d.tripId == widget.departure.tripId) || 
                  (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
           orElse: () => _externalDep ?? widget.departure
        );

        // ---- LOADING STATE - Solo shimmer nelle fermate ----
        if (_isLoadingExternalDetails && (currentDep.stops == null || currentDep.stops!.isEmpty) && currentDep.error == null) {
          return Consumer<ThemeProvider>(
            builder: (context, theme, child) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.backgroundColor, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
                ),
                child: Column(
                  children: [
                    // Header visibile (non shimmer)
                    _buildHeader(context, "N/D", 0, theme, currentDep, isLoading: false),
                    // Solo timeline in shimmer
                    Expanded(
                      child: _buildTimelineShimmer(theme),
                    ),
                    // Footer con messaggio caricamento
                    _buildLoadingFooter(theme),
                  ],
                ),
              );
            },
          );
        }

        // ---- ERROR STATE - Solo se _hasLoadedExternalData è true e c'è un errore ----
        if (_hasLoadedExternalData && currentDep.error != null && currentDep.error!.isNotEmpty) {
          return Consumer<ThemeProvider>(
            builder: (context, theme, child) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.backgroundColor, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
                ),
                child: Column(
                  children: [
                    _buildHeader(context, "N/D", 0, theme, currentDep),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_off_rounded, size: 64, color: theme.secondaryTextColor.withOpacity(0.5)),
                              const SizedBox(height: 24),
                              Text(
                                RuntimeLocalizations.t(context, 'something_went_wrong'),
                                style: TextStyle(color: theme.textColor, fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentDep.error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: 200,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _externalFetchAttempted = false;
                                      _isLoadingExternalDetails = true;
                                      _hasLoadedExternalData = false;
                                      _externalDep = null;
                                    });
                                    _fetchTimeoutTimer?.cancel();
                                    _maybeFetchExternalTripDetails();
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(RuntimeLocalizations.t(context, 'retry')),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        }

        // ---- NO STOPS STATE - Solo se _hasLoadedExternalData è true ----
        if (_hasLoadedExternalData && (currentDep.stops == null || currentDep.stops!.isEmpty) && currentDep.error == null) {
          return Consumer<ThemeProvider>(
            builder: (context, theme, child) {
              return Container(
                decoration: BoxDecoration(
                  color: theme.backgroundColor, 
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
                ),
                child: Column(
                  children: [
                    _buildHeader(context, "N/D", 0, theme, currentDep),
                    Expanded(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.train_rounded, size: 64, color: theme.secondaryTextColor.withOpacity(0.3)),
                              const SizedBox(height: 24),
                              Text(
                                'Nessuna fermata disponibile',
                                style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'I dettagli di questo treno non sono stati caricati.',
                                style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _externalFetchAttempted = false;
                                    _isLoadingExternalDetails = true;
                                    _hasLoadedExternalData = false;
                                    _externalDep = null;
                                  });
                                  _fetchTimeoutTimer?.cancel();
                                  _maybeFetchExternalTripDetails();
                                },
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text('Ricarica'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              );
            },
          );
        }

        // ---- NORMAL STATE ----
        final List<TrainStop> stops = currentDep.stops ?? [];
        final trainName = "${currentDep.category ?? ''} ${currentDep.trainNumber ?? ''}".trim();
        
        final DateTime nowUtc = DateTime.now().toUtc();

        int currentSegmentIndex = -1;
        double segmentProgress = 0.0;
        bool isAtStation = false;

        if (stops.isNotEmpty) {
          for (int i = 0; i < stops.length - 1; i++) {
            final curTimes = _estimateStopTimesGlobal(stops[i], currentDep.delayMinutes ?? 0);
            final nextTimes = _estimateStopTimesGlobal(stops[i+1], currentDep.delayMinutes ?? 0);

            final _ActualTime? depCurrent = curTimes['dep'] != null ? _ActualTime(curTimes['dep']!, isEstimated: stops[i].estimatedDeparture != null) : null;
            final _ActualTime? arrCurrent = curTimes['arr'] != null ? _ActualTime(curTimes['arr']!, isEstimated: stops[i].estimatedArrival != null) : null;
            final _ActualTime? arrNext = nextTimes['arr'] != null ? _ActualTime(nextTimes['arr']!, isEstimated: stops[i+1].estimatedArrival != null) : null;

            if (depCurrent != null && arrNext != null && nowUtc.isAfter(depCurrent.time) && nowUtc.isBefore(arrNext.time)) {
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

        final int totalDelay = currentDep.delayMinutes ?? 0;
        final String fullDisplayName = "$trainName";
        final bool isLoading = stops.isEmpty;

        return Consumer<ThemeProvider>(
          builder: (context, theme, child) {
            return Container(
              decoration: BoxDecoration(
                color: theme.backgroundColor, 
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))
              ),
              child: Column(
                children: [
                  _buildHeader(context, fullDisplayName, totalDelay, theme, currentDep, isLoading: isLoading),
                  Expanded(
                    child: isLoading 
                      ? _buildTimelineShimmer(theme)
                      : ListView.builder(
                          controller: widget.scrollController,
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
      },
    );
  }

  // ---- TIMELINE SHIMMER SOLO PER LE FERMATE ----
  Widget _buildTimelineShimmer(ThemeProvider theme) {
    return Shimmer.fromColors(
      baseColor: theme.secondaryTextColor.withOpacity(0.1),
      highlightColor: theme.secondaryTextColor.withOpacity(0.05),
      child: ListView.builder(
        itemCount: 8,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  Container(width: 2, height: 40, color: Colors.white),
                ],
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16, 
                      width: double.infinity, 
                      margin: const EdgeInsets.only(right: 80), 
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12, 
                      width: 120, 
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    height: 14, 
                    width: 40, 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12, 
                    width: 60, 
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4)
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // ---- FOOTER DI CARICAMENTO ----
  Widget _buildLoadingFooter(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.primaryColor.withOpacity(0.05),
        border: Border(top: BorderSide(color: theme.primaryColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '⏳ Caricamento fermate...',
            style: TextStyle(
              color: theme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _cleanStationName(String? name) {
    if (name == null || name.isEmpty || name == '{}' || name.toLowerCase() == 'null') {
      return 'N/A';
    }
    return name;
  }

  String _getEffectiveOrigin(TrainDeparture d) {
    if (d.stops != null && d.stops!.isNotEmpty) {
      try {
        final firstValid = d.stops!.firstWhere((s) => !s.cancelled);
        return firstValid.stationName;
      } catch (_) {
        return d.stops!.first.stationName; 
      }
    }
    return _cleanStationName(d.origin);
  }

  String _getEffectiveDestination(TrainDeparture d) {
    if (d.stops != null && d.stops!.isNotEmpty) {
      try {
        final lastValid = d.stops!.lastWhere((s) => !s.cancelled);
        return lastValid.stationName;
      } catch (_) {
        return d.stops!.last.stationName;
      }
    }
    return _cleanStationName(d.destination);
  }

  Widget _buildHeader(BuildContext context, String displayName, int delay, ThemeProvider theme, TrainDeparture departure, {bool isLoading = false}) {
    final effectiveOrigin = _getEffectiveOrigin(departure);
    final effectiveDest = _getEffectiveDestination(departure);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, -4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.secondaryTextColor.withOpacity(0.3), 
                borderRadius: BorderRadius.circular(2)
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _buildTrainIdentifier(context, theme, departure),
              ),
              const SizedBox(width: 16),
              _buildModernDelayBadge(delay, theme),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 10, 
                    height: 10, 
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.secondaryTextColor, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 24,
                    color: theme.secondaryTextColor.withOpacity(0.3),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading)
                      Shimmer.fromColors(
                        baseColor: theme.secondaryTextColor.withOpacity(0.1),
                        highlightColor: theme.secondaryTextColor.withOpacity(0.05),
                        child: Container(
                          height: 15, 
                          width: double.infinity, 
                          margin: const EdgeInsets.only(right: 60),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4)
                          ),
                        ),
                      )
                    else
                      Text(
                        effectiveOrigin,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    
                    const SizedBox(height: 14),
                    
                    if (isLoading)
                      Shimmer.fromColors(
                        baseColor: theme.textColor.withOpacity(0.1),
                        highlightColor: theme.textColor.withOpacity(0.05),
                        child: Container(
                          height: 16, 
                          width: double.infinity,
                          margin: const EdgeInsets.only(right: 40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4)
                          ),
                        ),
                      )
                    else
                      Text(
                        effectiveDest,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Consumer2<FavoritesProvider, AuthProvider>(
                builder: (context, favoritesProvider, authProvider, child) {
                  if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                  final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                  final isFavorite = favoritesProvider.isTrainFavorite(
                    departure.trainNumber ?? '',
                    departure.origin ?? '',
                    departure.destination ?? '',
                  );
                    return Expanded(
                    child: _PrimaryActionChip(
                      icon: isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      label: AppLocalizations.of(context)?.save ?? 'Salva',
                      isActive: isFavorite,
                      activeColor: Colors.red,
                      theme: theme,
                      onTap: () async {
                         if (isFavorite) {
                          await favoritesProvider.removeTrainFavorite(
                            departure.trainNumber ?? '',
                            departure.origin ?? '',
                            departure.destination ?? '',
                          );
                        } else {
                          final favoriteTrain = FavoriteTrain(
                            id: '${userId}_train_${departure.trainNumber}_${departure.origin}_${departure.destination}',
                            addedAt: DateTime.now(),
                            userId: userId,
                            trainNumber: departure.trainNumber ?? '',
                            departureStation: departure.origin ?? '',
                            arrivalStation: departure.destination ?? '',
                            departureTime: departure.scheduledTime?.toIso8601String() ?? '',
                            arrivalTime: '',
                            operator: null,
                            category: widget.departure.category,
                            routeId: widget.departure.tripId,
                            provider: null,
                          );
                          await favoritesProvider.addTrainFavorite(favoriteTrain);
                        }
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return Expanded(
                    child: _buildOfflineSyncButton(
                      context: context,
                      theme: theme,
                      isCached: _isCachedOffline || _manualOfflineSaved,
                      manualMode: !settings.offlineSyncEnabled,
                      onSync: () async {
                        final trainProvider = Provider.of<TrainProvider>(context, listen: false);
                        await trainProvider.saveTrainOffline(widget.departure);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                settings.offlineSyncEnabled
                                    ? RuntimeLocalizations.t(context, 'train_saved_offline')
                                    : RuntimeLocalizations.t(context, 'train_saved_manual_offline')
                              ),
                              backgroundColor: theme.primaryColor,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          setState(() {
                            _manualOfflineSaved = true;
                          });
                        }
                        await _checkCacheStatus();
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _TrainNotificationsButton(
                departure: departure, 
                selectedCountry: widget.selectedCountry, 
                isPrimary: true
              ),
            ],
          ),

          const SizedBox(height: 16),

          Consumer<TrainProvider>(
            builder: (context, provider, _) {
              if (provider.isUsingOfflineCache) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Modalità offline: il progresso del treno è basato sui dati salvati l'ultima volta.",
                          style: TextStyle(color: Colors.amber.shade900, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildInfoChip(
                  Icons.analytics_rounded,
                  RuntimeLocalizations.t(context, 'statistics') ?? 'Statistiche',
                  theme,
                  () {
                    final category = (departure.category ?? '').trim();
                    final tripNumber = (departure.trainNumber ?? '').trim();
                    
                    if (category.isNotEmpty && tripNumber.isNotEmpty) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => TrainStatsScreen(
                            category: category,
                            tripNumber: tripNumber,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(RuntimeLocalizations.t(context, 'insufficient_data') ?? 'Dati treno mancanti'),
                          backgroundColor: theme.errorColor,
                        ),
                      );
                    }
                  },
                ),

                _buildInfoChip(
                  Icons.map_rounded,
                  RuntimeLocalizations.t(context, 'map'),
                  theme,
                  () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => TrainMapPage(departure: departure, isArrivalMode: widget.isArrivalMode, currentDelay: delay)),
                  ),
                ),

                _buildInfoChip(
                  Icons.refresh_rounded,
                  RuntimeLocalizations.t(context, 'update'),
                  theme,
                  _refreshTrainDetails,
                ),

                Consumer<TrainProvider>(
                  builder: (context, trainProvider, child) {
                    final isOffline = _preventOnlineAutoRefresh || trainProvider.isUsingOfflineCache || _isNetworkOffline;
                    return _buildInfoChip(
                      isOffline
                          ? Icons.cloud_off_rounded
                          : (_autoRefreshTimer != null ? Icons.timer_rounded : Icons.timer_off_rounded),
                      isOffline ? RuntimeLocalizations.t(context, 'offline') : RuntimeLocalizations.t(context, 'live'),
                      theme,
                      isOffline ? null : () => _toggleAutoRefresh(),
                      isActive: !isOffline && _autoRefreshTimer != null,
                    );
                  },
                ),

                if (_hasMessages())
                  _buildInfoChip(
                    Icons.warning_amber_rounded,
                    '${RuntimeLocalizations.t(context, 'alerts')} (${_messages()?.length ?? 0})',
                    theme,
                    _showMessagesSheet,
                    isActive: true,
                    isWarning: true,
                  ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, ThemeProvider theme, VoidCallback? onTap, {bool isActive = false, bool isWarning = false}) {
    final Color iconColor = isWarning ? theme.warningColor : theme.primaryColor;
    final Color labelColor = isWarning ? theme.warningColor : theme.textColor;
    
    final Color bgColor = isActive ? theme.primaryColor.withOpacity(0.08) : theme.surfaceColor;
    final BorderSide side = isActive 
       ? BorderSide(color: theme.primaryColor.withOpacity(0.3))
       : BorderSide(color: theme.secondaryTextColor.withOpacity(0.1));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: onTap,
        backgroundColor: bgColor,
        side: side,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        avatar: Icon(icon, size: 14, color: iconColor),
        label: Text(label, style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTrainIdentifier(BuildContext context, ThemeProvider theme, TrainDeparture departure) {
    final settings = Provider.of<SettingsProvider>(context);
    final category = (departure.category ?? 'TRN').trim();
    final number = (departure.trainNumber ?? '').trim();

    if (settings.vectorLogosEnabled) {
      final fileName = category.toLowerCase().replaceAll(' ', '_');
      final logoUrl = "https://betacloud-transporter.is-cool.dev/assets/logos/trains/$fileName.png";

      return Row(
        children: [
          Container(
            height: 24,
            constraints: const BoxConstraints(maxWidth: 80),
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              errorBuilder: (context, error, stackTrace) {
                return _buildColorText(category, number, theme);
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(
            number, 
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textColor)
          ),
        ],
      );
    }

    return _buildColorText(category, number, theme);
  }

  Widget _buildColorText(String category, String number, ThemeProvider theme) {
    final isHighSpeed = category.toLowerCase().contains('fr') || category.toLowerCase().contains('freccia');
    final color = isHighSpeed ? Colors.redAccent : theme.primaryColor;

    return Text(
      "$category $number",
      style: TextStyle(
        fontSize: 22, 
        fontWeight: FontWeight.w900, 
        color: color
      ),
    );
  }

  Widget _buildModernDelayBadge(int delay, ThemeProvider theme) {
    Color color;
    String text;
    IconData icon;
    
    if (delay < 0) {
      color = theme.successColor;
      text = "Anticipo ${-delay}'";
      icon = Icons.fast_forward_rounded;
    } else if (delay == 0) {
      color = theme.successColor;
      text = "In Orario";
      icon = Icons.check_circle_rounded;
    } else if (delay <= 5) {
      color = const Color(0xFFFFA000);
      text = "+$delay min";
      icon = Icons.access_time_rounded;
    } else {
      color = theme.errorColor;
      text = "+$delay min";
      icon = Icons.warning_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>>? _messages() {
    final List<Map<String, dynamic>> out = [];

    final tripMsgs = widget.departure.messages;
    if (tripMsgs != null && tripMsgs.isNotEmpty) {
      out.addAll(tripMsgs.map((m) => Map<String, dynamic>.from(m)));
    }

    final meta = widget.departure.metadata;
    if (meta != null) {
      final raw = meta['messages'] ?? meta['alerts'] ?? meta['notes'];
      if (raw is List && raw.isNotEmpty) {
        out.addAll(raw.map<Map<String, dynamic>>((e) => e is Map<String, dynamic> ? Map<String, dynamic>.from(e) : (e is Map ? Map<String, dynamic>.from(e) : {'text': e?.toString()})));
      }
    }

    final stops = widget.departure.stops ?? [];
    for (final s in stops) {
      if (s.messages != null && s.messages!.isNotEmpty) {
        for (final m in s.messages!) {
          final Map<String, dynamic> mm = Map<String, dynamic>.from(m);
          mm['station'] = s.stationName;
          out.add(mm);
        }
      }
    }

    return out.isNotEmpty ? out : null;
  }

  bool _hasMessages() => (_messages() ?? []).isNotEmpty;

  void _showMessagesSheet() {
    final msgs = _messages() ?? [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        final Map<String, int> priCounts = {};
        for (final m in msgs) {
          final p = (m['priority'] ?? '').toString().toLowerCase();
          if (p.isNotEmpty) priCounts[p] = (priCounts[p] ?? 0) + 1;
        }
        return SafeArea(
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(RuntimeLocalizations.t(context, 'messages'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(RuntimeLocalizations.t(context, 'messages_count', params: {'count': msgs.length.toString()})),
                        if (priCounts.isNotEmpty) const SizedBox(height: 6),
                        if (priCounts.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: priCounts.entries.map<Widget>((e) {
                              final key = e.key;
                              final count = e.value;
                              final bg = key == 'high'
                                  ? Theme.of(context).colorScheme.error.withOpacity(0.12)
                                  : (key == 'medium' ? Colors.amber.withOpacity(0.12) : Theme.of(context).primaryColor.withOpacity(0.12));
                              final textColor = key == 'high' ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor;
                              return Chip(label: Text('${key}: ${count}', style: TextStyle(color: textColor, fontSize: 12)), backgroundColor: bg);
                            }).toList(),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: msgs.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (c, i) {
                      final m = msgs[i];
                      final type = (m['type'] ?? 'info').toString().toLowerCase();
                      final title = (m['title'] ?? '').toString();
                      final text = (m['text'] ?? '').toString();
                      final icon = type == 'warning' ? Icons.warning_rounded : Icons.info_outline;
                      final color = type == 'warning' ? Theme.of(context).colorScheme.error : Theme.of(context).primaryColor;
                      final station = (m['station'] ?? '').toString();
                      final priority = (m['priority'] ?? '').toString().toLowerCase();
                      final subtitleWidget = station.isNotEmpty
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(station, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              const SizedBox(height: 8),
                              Text(text, style: TextStyle(fontSize: 13)),
                            ],
                          )
                        : Text(text);

                      final Color priColor = priority == 'high'
                        ? Theme.of(context).colorScheme.error
                        : (priority == 'medium' ? Colors.amber : Theme.of(context).primaryColor);

                      final bgColor = priority == 'high'
                        ? Theme.of(context).colorScheme.error.withOpacity(0.04)
                        : (priority == 'medium' ? Colors.amber.withOpacity(0.04) : Theme.of(context).primaryColor.withOpacity(0.02));

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border(left: BorderSide(color: priColor, width: priority.isNotEmpty ? 4 : 0)),
                        ),
                        child: ListTile(
                          leading: Icon(icon, color: color),
                          title: Row(children: [
                            Expanded(child: Text(title.isNotEmpty ? title : (station.isNotEmpty ? station : ''), style: TextStyle(fontWeight: FontWeight.w700))),
                            if (priority.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                child: Chip(
                                  label: Text(priority.toUpperCase(), style: TextStyle(color: priColor, fontSize: 11, fontWeight: FontWeight.w800)),
                                  backgroundColor: priColor.withOpacity(0.12),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ]),
                          subtitle: subtitleWidget,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(ctx), child: Text(RuntimeLocalizations.t(context, 'close')))),
              ],
            ),
          ),
        );
      },
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
      
      final int effectiveDelay = (estimated == null && delay == 0 && isActiveStop && totalDelay != 0) 
          ? totalDelay 
          : delay;

      final effective = estimated ?? scheduled!.add(Duration(minutes: effectiveDelay));
      final effStr = timeFormatter(effective, stop.country);
      final delayStr = effectiveDelay != 0 ? " (${effectiveDelay > 0 ? '+' : ''}${effectiveDelay}min)" : "";
      
      if (scheduled != null && (estimated != null || effectiveDelay != 0)) {
        return '$type: $effStr$delayStr (${RuntimeLocalizations.t(context, 'scheduled_label')}: ${timeFormatter(scheduled, stop.country)})';
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
                  Row(children: [
                    Expanded(
                      child: Text(stop.stationName, style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.6) : theme.textColor, fontSize: 16, fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600)),
                    ),
                        if (stop.cancelled)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.errorColor.withOpacity(0.12),
                          border: Border.all(color: theme.errorColor.withOpacity(0.3)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(RuntimeLocalizations.t(context, 'cancelled'), style: TextStyle(color: theme.errorColor, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                  ],),
                  if (stop.arrival != null) 
                Text(buildTimeString(RuntimeLocalizations.t(context, 'arrival'), stop.arrival, stop.estimatedArrival, isFuture ? totalDelay : (stop.arrivalDelay ?? 0)),
                        style: TextStyle(color: stop.cancelled ? theme.secondaryTextColor.withOpacity(0.5) : (isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor), fontSize: 12, decoration: stop.cancelled ? TextDecoration.lineThrough : TextDecoration.none)),
                  if (stop.departure != null)
                Text(buildTimeString(RuntimeLocalizations.t(context, 'departure'), stop.departure, stop.estimatedDeparture, isFuture ? totalDelay : (stop.departureDelay ?? 0)),
                        style: TextStyle(color: stop.cancelled ? theme.secondaryTextColor.withOpacity(0.5) : (isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor), fontSize: 12, decoration: stop.cancelled ? TextDecoration.lineThrough : TextDecoration.none)),

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
          Positioned(top: 17, child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: stop.cancelled ? theme.errorColor : (highlighted ? theme.primaryColor : theme.surfaceColor.withOpacity(0.08)),
              shape: BoxShape.circle,
              border: Border.all(color: stop.cancelled ? theme.errorColor : (highlighted ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.24)), width: 2),
            ),
          )),
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

Widget _buildOfflineSyncButton({
  required BuildContext context,
  required ThemeProvider theme,
  required VoidCallback onSync,
  bool isCached = false,
  bool manualMode = false,
}) {
  return _PrimaryActionChip(
    icon: isCached
        ? Icons.cloud_done_rounded
        : (manualMode ? Icons.save_alt_rounded : Icons.cloud_download_rounded),
    label: manualMode
        ? RuntimeLocalizations.t(context, 'save_offline')
        : RuntimeLocalizations.t(context, 'offline_mode'),
    isActive: isCached,
    theme: theme,
    onTap: onSync,
  );
}

class _PrimaryActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ThemeProvider theme;
  final bool isActive;
  final Color? activeColor;

  const _PrimaryActionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.theme,
    this.isActive = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isActive ? (activeColor ?? theme.primaryColor) : theme.secondaryTextColor;
    final bgColor = isActive ? (activeColor?.withOpacity(0.1) ?? theme.primaryColor.withOpacity(0.1)) : theme.surfaceColor;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive ? (activeColor?.withOpacity(0.3) ?? theme.primaryColor.withOpacity(0.3)) : theme.secondaryTextColor.withOpacity(0.2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: effectiveColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
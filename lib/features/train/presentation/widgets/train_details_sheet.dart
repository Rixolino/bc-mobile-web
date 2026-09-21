import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:bc_transporter/features/train/presentation/widgets/train_stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../data/models/train_model.dart';
import '../providers/train_provider.dart';
import '../../../../core/services/offline_sync_service.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/design_system.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_train.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/train_presence_service.dart';
import '../../../../core/utils/country_time.dart';
import '../../../../presentation/providers/notification_manager_provider.dart';
import '../pages/train_map_page.dart';
import '../screens/station_details_screen.dart';
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
  TrainDeparture _liveDeparture(BuildContext context) {
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    try {
      return trainProvider.departures.firstWhere(
        (d) => (widget.departure.tripId != null && d.tripId == widget.departure.tripId) ||
               (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
      );
    } catch (_) {
      return widget.departure;
    }
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
      buffer.writeln(RuntimeLocalizations.t(context, 'nextStopFallback') ?? 'Prossima fermata: --');
    }

    if (isAtStation && lastPassed.isNotEmpty) {
      buffer.writeln('Treno in stazione: $lastPassed');
    } else {
      buffer.writeln('Stato attuale: ${lastPassed.isNotEmpty ? lastPassed : RuntimeLocalizations.t(context, 'inTransit') ?? 'In transito'}');
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
    final dep = _liveDeparture(context);
    final tripId = dep.tripId ?? dep.trainNumber ?? '';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (ctx) {
        String? selectedStop;
        return StatefulBuilder(
          builder: (ctx, sbSetState) {
            final stops = dep.stops ?? [];

            String previewTitle() => _buildTrainNotificationTitle(dep);
            String previewBody() => _buildTrainNotificationBody(dep, userDestination: selectedStop);

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
                          if (isPassed) subParts.add(RuntimeLocalizations.t(context, 'stopAlreadyPassed') ?? 'gi\u00E0 passata');
                          else if (isCurrent) subParts.add(RuntimeLocalizations.t(context, 'stopCurrent') ?? 'attuale');
                          if (isCancelled) subParts.add(RuntimeLocalizations.t(context, 'stopCancelled') ?? 'annullata');
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
    final liveDep = _liveDeparture(ctx);
    String? startingStop = liveDep.stops?.isNotEmpty == true ? liveDep.stops!.first.stationName : null;
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
    final Color iconColor = _enabled ? theme.primaryColor : theme.secondaryTextColor;
    final Color labelColor = _enabled ? theme.primaryColor : theme.textColor;
    final Color bgColor = _enabled ? theme.primaryColor.withValues(alpha: 0.08) : theme.surfaceColor;
    final BorderSide side = _enabled
        ? BorderSide(color: theme.primaryColor.withValues(alpha: 0.3))
        : BorderSide(color: theme.secondaryTextColor.withValues(alpha: 0.1));

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        onPressed: _toggle,
        backgroundColor: bgColor,
        side: side,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        avatar: Icon(_enabled ? Icons.notifications_active_rounded : Icons.notifications_none_rounded, size: 14, color: iconColor),
        label: Text(
          widget.isPrimary ? RuntimeLocalizations.t(context, 'notifications') ?? RuntimeLocalizations.t(context, 'notifications') ?? 'Notifiche' : "Notifiche",
          style: TextStyle(color: labelColor, fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
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
  bool _isSharing = false;
  // Country effettivo del pannello, risolto una volta all'apertura e usato
  // per condivisione link/DB e apertura pannello stazione
  late String _sheetCountry;

  // Full details fetched locally for trains opened from outside the current timetable
  TrainDeparture? _externalDep;
  bool _isLoadingExternalDetails = false;
  bool _externalFetchAttempted = false;
  Timer? _fetchTimeoutTimer;
  
  // Aggiunto per evitare il flicker dell'errore
  bool _hasLoadedExternalData = false;

  // Scroll controller per navigare alle fermate
  final ScrollController _scrollController = ScrollController();

  // Evita fallback ritardo concorrenti
  bool _isRefreshingDelayFallback = false;

  // Refresh manuale in corso (feedback sul chip Aggiorna)
  bool _isManualRefreshing = false;

  // Presenza live: quanti utenti stanno guardando questo treno
  Timer? _presenceTimer;
  int? _viewersCount;
  String? _presenceKey;
  // Ultimo tripId / fermate buoni inviati all'API: il primo utente che apre
  // il treno li pubblica mentre la sheet è aperta, e non si perdono più
  // (il refresh del tabellone può temporaneamente azzerarli).
  String? _lastPresenceTripId;
  List<TrainStop>? _lastPresenceStops;

  @override
  void initState() {
    super.initState();
    _trainProvider = Provider.of<TrainProvider>(context, listen: false);
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _sheetCountry = (widget.selectedCountry ?? '').isNotEmpty
        ? widget.selectedCountry!
        : (widget.departure.country.isNotEmpty
            ? widget.departure.country
            : (_trainProvider.selectedStation?.country ?? 'IT'));
    _startAutoRefresh();
    _startConnectivityMonitor();
    _checkCacheStatus();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    // Annuncio vocale all'apertura del dettaglio treno
    _speakTrainInfo();

    // Presenza live: heartbeat mentre la sheet è aperta
    _startPresence();

    // Carica i loghi se attivi ma non ancora in memoria
    // (es. sheet aperto da deep link senza passare dal pannello treni)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_settingsProvider.vectorLogosEnabled &&
          _trainProvider.trainLogos.isEmpty) {
        _trainProvider.loadTrainLogos(source: _settingsProvider.logoSource);
      }
    });
    
    _maybeFetchExternalTripDetails();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _progressTimer?.cancel();
    _connectivityTimer?.cancel();
    _fetchTimeoutTimer?.cancel();
    _presenceTimer?.cancel();
    final presenceKey = _presenceKey;
    if (presenceKey != null && presenceKey.isNotEmpty) {
      TrainPresenceService().leave(presenceKey);
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Avvia l'heartbeat di presenza live (ogni 5s, TTL backend 45s).
  void _startPresence() {
    final dep = widget.departure;
    _presenceKey =
        '${dep.category ?? ''}|${dep.trainNumber ?? ''}|${dep.scheduledTime?.toIso8601String() ?? ''}';
    _presenceTick();
    _presenceTimer?.cancel();
    _presenceTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _presenceTick());
  }

  Future<void> _presenceTick() async {
    final key = _presenceKey;
    if (!mounted || key == null || key.isEmpty) {
      print('[Presence] tick skip: mounted=$mounted key=$key');
      return;
    }
    print('[Presence] tick key=$key');
    final current = _findDisplayedDeparture() ?? _externalDep ?? widget.departure;
    // Miglior tripId / fermate da tutte le fonti: il primo utente che apre
    // il treno li pubblica all'API mentre la sheet è aperta.
    final bestTripId = current.tripId?.isNotEmpty == true
        ? current.tripId
        : (_externalDep?.tripId?.isNotEmpty == true
            ? _externalDep?.tripId
            : widget.departure.tripId);
    if (bestTripId != null &&
        bestTripId.isNotEmpty &&
        bestTripId != _lastPresenceTripId) {
      _lastPresenceTripId = bestTripId;
      print('[Presence] tripId pubblicato: $bestTripId');
    }
    final List<TrainStop>? bestStops =
        current.stops?.isNotEmpty == true
            ? current.stops
            : (_externalDep?.stops?.isNotEmpty == true
                ? _externalDep?.stops
                : widget.departure.stops);
    final cleanedStops = _cleanPresenceStops(bestStops);
    if (cleanedStops != null) {
      _lastPresenceStops = cleanedStops;
    }
    // Mai inviare 'N/A' (fallback locale quando i nomi mancano): il server
    // lo scarterebbe comunque, ma così non inquiniamo proprio il payload.
    final bestOrigin = _firstValidPresenceStr(
        [current.origin, _externalDep?.origin, widget.departure.origin]);
    final bestDestination = _firstValidPresenceStr([
      current.destination,
      _externalDep?.destination,
      widget.departure.destination
    ]);
    final count = await TrainPresenceService().heartbeat(
      trainKey: key,
      screen: 'national',
      train: {
        'category': current.category,
        'trainNumber': current.trainNumber,
        'origin': bestOrigin,
        'destination': bestDestination,
        'scheduledTime': current.scheduledTime?.toIso8601String(),
        'estimatedTime': current.estimatedTime?.toIso8601String(),
        'delayMinutes': current.delayMinutes,
        'platform': current.platform,
        'operator': current.operator,
        'country': _sheetCountry,
        'isArrival': widget.isArrivalMode,
        // Dati completi per la sezione "più visualizzati": tripId per
        // ricaricare il trip + tutte le fermate così il dettaglio è completo.
        'tripId': _lastPresenceTripId ?? bestTripId,
        'stops': (_lastPresenceStops ?? cleanedStops)
            ?.map((s) => s.toJson())
            .toList(),
      },
    );
    print('[Presence] viewers=$count (was $_viewersCount)');
    if (!mounted || count == null || count == _viewersCount) return;
    setState(() => _viewersCount = count);
  }

  Future<void> _speakTrainInfo() async {
    if (!_settingsProvider.ttsEnabled) return;
    
    final tts = TtsService();
    final langCode = _settingsProvider.appLocale?.languageCode ?? 'it';
    tts.setLanguage(langCode);
    
    // Imposta voce per lingua
    final voices = TtsService.getVoicesForLanguage(langCode);
    final selected = voices.firstWhere(
      (v) => v.name == _settingsProvider.ttsVoiceForLang(langCode),
      orElse: () => voices.isNotEmpty ? voices.first : const OddcastVoice(name: 'Roberto', id: 7, engine: 2, gender: 'M'),
    );
    tts.setSelectedVoice(selected);
    
    final departure = widget.departure;
    final isArrivals = widget.isArrivalMode;

    final announcement = TtsService.buildAnnouncement(
      category: departure.category,
      trainNumber: departure.trainNumber,
      isArrival: isArrivals,
      origin: departure.origin,
      destination: departure.destination,
      scheduledTime: departure.scheduledTime,
      estimatedTime: departure.estimatedTime,
      delayMinutes: departure.delayMinutes ?? 0,
      platform: departure.platform,
      langCode: langCode,
      operator: departure.operator,
    );

    final stops = departure.stops ?? [];
    final ttsStrings = TtsService.getTtsStrings(langCode);
    String text = announcement;
    if (stops.isNotEmpty) {
      final now = DateTime.now();
      TrainStop? nextStop;
      
      for (var stop in stops) {
        if (stop.departure != null && stop.departure!.isAfter(now)) {
          nextStop = stop;
          break;
        }
        if (stop.arrival != null && stop.arrival!.isAfter(now)) {
          nextStop = stop;
          break;
        }
      }
      
      if (nextStop != null) {
        final stopName = nextStop.stationName ?? '';
        final time = nextStop.departure ?? nextStop.arrival;
        
        if (stopName.isNotEmpty && time != null) {
          final timeStr = TtsService.formatTtsTime(time, langCode);
          text += '. ${ttsStrings['next_stop'] ?? "Prossima fermata:"} $stopName alle $timeStr';
        }
      }
    }
    
    if (text.isNotEmpty) {
      final trainKey = '${departure.category ?? ''}|${departure.trainNumber ?? ''}|${departure.scheduledTime?.toIso8601String() ?? ''}';
      await tts.speak(text, trainKey: trainKey);
    }
  }

  bool get _needsExternalFetch {
    final hasStops = widget.departure.stops != null && widget.departure.stops!.isNotEmpty;
    return !hasStops;
  }

  /// Costruisce la departure arricchita dai dati trip (usato al primo load
  /// e nei refresh continui): base = snapshot esistente per i fallback.
  TrainDeparture _buildEnrichedDeparture(dynamic tripData, TrainDeparture base, String country) {
    List<TrainStop> stops = [];
    final stopsData = tripData['stops'] ?? tripData['stopList'] ?? [];
    if (stopsData is List) {
      stops = stopsData.map((s) => TrainStop.fromJson(s as Map<String, dynamic>)).toList();
    }

    return TrainDeparture(
      tripId: base.tripId,
      trainNumber: tripData['trainNumber']?.toString() ?? base.trainNumber,
      category: tripData['category']?.toString() ?? base.category,
      origin: _resolveStringField(tripData['origin']) ?? base.origin,
      destination: _resolveStringField(tripData['destination']) ?? base.destination,
      country: tripData['country']?.toString() ?? country,
      status: tripData['status']?.toString() ?? base.status,
      delayMinutes: tripData['delay'] ?? tripData['delayMinutes'] ?? base.delayMinutes ?? 0,
      scheduledTime: tripData['scheduledTime'] != null
          ? DateTime.tryParse(tripData['scheduledTime'].toString())
          : base.scheduledTime,
      estimatedTime: tripData['estimatedTime'] != null
          ? DateTime.tryParse(tripData['estimatedTime'].toString())
          : base.estimatedTime,
      platform: tripData['platform']?.toString() ?? base.platform,
      stops: stops,
      messages: tripData['messages'] != null
          ? List<Map<String, dynamic>>.from(tripData['messages'])
          : null,
      metadata: tripData['metadata'] as Map<String, dynamic>?,
    );
  }

  /// 'N/A' e simili non sono nomi veri: non vanno mai inviati all'API.
  static bool _isJunkPresenceStr(String? v) {
    if (v == null) return true;
    final s = v.trim().toUpperCase();
    return s.isEmpty || s == 'N/A' || s == 'N/D' || s == '--' || s == '-';
  }

  static String? _firstValidPresenceStr(List<String?> values) {
    for (final v in values) {
      if (!_isJunkPresenceStr(v)) return v;
    }
    return null;
  }

  /// Scarta le fermate con nome spazzatura (fallback 'N/A' locali).
  static List<TrainStop>? _cleanPresenceStops(List<TrainStop>? stops) {
    if (stops == null || stops.isEmpty) return null;
    final cleaned =
        stops.where((s) => !_isJunkPresenceStr(s.stationName)).toList();
    return cleaned.isEmpty ? null : cleaned;
  }

  /// Estrae una stringa da un valore che puo essere String, Map o null.
  static String? _resolveStringField(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) return value;
    if (value is Map) {
      for (final key in ['name', 'text', 'stationName', 'stationname', 'station_name']) {
        if (value[key] is String && (value[key] as String).isNotEmpty) return value[key] as String;
      }
      for (final key in ['id', 'stationId', 'stationid', 'station_id']) {
        if (value[key] is String && (value[key] as String).isNotEmpty) return value[key] as String;
      }
      return value.toString();
    }
    return value.toString();
  }

  /// Refresh continuo del trip per treni esterni al tabellone (modalità link):
  /// ricarica fermate/orari/ritardi e aggiorna la copia locale solo se
  /// le fermate nuove non sono vuote (mai sovrascrivere col vuoto).
  Future<void> _refreshExternalTripDetails() async {
    if (!mounted || _isLoadingExternalDetails) return;
    final base = _externalDep ?? widget.departure;
    final tripId = base.tripId;
    if (tripId == null || tripId.isEmpty) return;
    final country = base.country.isNotEmpty
        ? base.country
        : (widget.selectedCountry ?? 'IT');

    debugPrint('[NationalDelay] Refresh trip esterno: https://prod.cuzimmartin.dev/api/$country/trip?tripId=${Uri.encodeComponent(tripId)}');
    try {
      final uri = Uri.parse('https://prod.cuzimmartin.dev/api/$country/trip?tripId=${Uri.encodeComponent(tripId)}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 12));
      if (!mounted || resp.statusCode != 200) return;
      final decoded = json.decode(resp.body);
      if (decoded is! Map<String, dynamic>) return;
      final tripData = decoded['trip'] ?? decoded['data'] ?? decoded;
      final rawStops = tripData['stops'] ?? tripData['stopList'] ?? [];
      final count = rawStops is List ? rawStops.length : 0;
      if (count == 0) {
        debugPrint('[NationalDelay] Trip esterno senza fermate, tengo i dati esistenti');
        return;
      }
      final enriched = _buildEnrichedDeparture(tripData, base, country);
      // Modalita link: logo e numero restano intatti (quelli dello snapshot
      // condiviso, da cui deriva anche il logo); si aggiornano solo
      // fermate/orari/ritardi/stato. copyWith non espone questi campi
      // (restano fissi dal costruttore), quindi ricostruisco qui.
      final frozen = TrainDeparture(
        tripId: enriched.tripId,
        trainNumber: base.trainNumber,
        category: base.category,
        origin: enriched.origin,
        destination: enriched.destination,
        country: enriched.country,
        status: enriched.status,
        delayMinutes: enriched.delayMinutes,
        scheduledTime: enriched.scheduledTime,
        estimatedTime: enriched.estimatedTime,
        platform: enriched.platform,
        stops: enriched.stops,
        messages: enriched.messages,
        metadata: enriched.metadata,
      );
      setState(() {
        _externalDep = frozen;
        _hasLoadedExternalData = true;
      });
      // Pubblica subito tripId + fermate all'API (primo utente che apre
      // il treno), senza aspettare il prossimo tick da 5s.
      if ((_lastPresenceTripId == null || _lastPresenceTripId!.isEmpty) ||
          _lastPresenceStops == null) {
        _presenceTick();
      }
      debugPrint('[NationalDelay] Trip esterno aggiornato: ${frozen.stops?.length} fermate');
    } catch (e) {
      debugPrint('[NationalDelay] Errore refresh trip esterno: $e');
    }
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
        _externalDep = widget.departure.copyWith(error: RuntimeLocalizations.t(context, 'missingTrainId') ?? 'ID treno mancante');
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
        _externalDep = widget.departure.copyWith(error: RuntimeLocalizations.t(context, 'loadingDetailsTimeout') ?? 'Timeout durante il caricamento dei dettagli');
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

          final enriched = _buildEnrichedDeparture(tripData, widget.departure, country);

          setState(() {
            _externalDep = enriched;
            _isLoadingExternalDetails = false;
            _hasLoadedExternalData = true;
          });
          // Pubblica subito tripId + fermate all'API (primo utente che
          // apre il treno), senza aspettare il prossimo tick da 5s.
          if ((_lastPresenceTripId == null ||
                  _lastPresenceTripId!.isEmpty) ||
              _lastPresenceStops == null) {
            _presenceTick();
          }
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

  Future<void> _refreshTrainDetails() async {
    if (!mounted || _isManualRefreshing) return;
    if (_preventOnlineAutoRefresh || _trainProvider.isUsingOfflineCache || _isNetworkOffline) {
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      if (mounted) setState(() {});
      return;
    }

    setState(() => _isManualRefreshing = true);
    try {
      // 1. Ricarica il tabellone della stazione: ritardo/orario/binario freschi.
      // (expandTrainDetails aggiorna solo le fermate, quindi senza questo
      // passo l'header resterebbe con i dati vecchi e sembrerebbe "non agire".)
      final station = _trainProvider.selectedStation;
      if (station != null && station.id.isNotEmpty) {
        await _trainProvider.fetchDepartures(
          station.id,
          country: station.country,
          silent: true,
        );
      }
      if (!mounted) return;

      // 2. Ricarica i dettagli della corsa (fermate).
      final index = _trainProvider.departures.indexWhere((d) =>
        (widget.departure.tripId != null && d.tripId == widget.departure.tripId) ||
        (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination)
      );
      if (index != -1) {
        // Modalita tabellone: ricarica completa continua (fermate/orari/ritardi),
        // poi ritardo fresco dalle bacheche. Il provider non sovrascrive mai col vuoto.
        await _trainProvider.expandTrainDetails(index, forceRefresh: true);
      } else {
        // Modalita link (treno esterno al tabellone): ricarica trip + fallback stazioni
        await _refreshExternalTripDetails();
      }
      if (!mounted) return;

      // 3. Ritardo fresco dalle bacheche delle prossime stazioni.
      await _refreshDelayFallback();
    } finally {
      if (mounted) setState(() => _isManualRefreshing = false);
    }
  }

  /// Risolve il country: fermata → corsa → country del pannello.
  String _resolveCountry(String stopCountry, String depCountry) {
    if (stopCountry.isNotEmpty) return stopCountry;
    if (depCountry.isNotEmpty) return depCountry;
    return _sheetCountry;
  }

  TrainDeparture? _findDisplayedDeparture() {
    try {
      return _trainProvider.departures.firstWhere(
        (d) =>
            (widget.departure.tripId != null && d.tripId == widget.departure.tripId) ||
            (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
      );
    } catch (_) {
      return null;
    }
  }

  /// Se i minuti di ritardo non sono più ottenibili via trip endpoint
  /// (refresh fallito -> error impostato, oppure delay assente), li cerca
  /// nei tabelloni delle prossime stazioni della tratta.
  /// Gira in continuo finche la sheet e aperta (ad ogni tick auto-refresh):
  /// nessun throttle, solo mutex anti-concorrenza.
  Future<void> _refreshDelayFallback() async {
    if (!mounted || _isRefreshingDelayFallback) {
      if (_isRefreshingDelayFallback) debugPrint('[NationalDelay] Skip: aggiornamento gia in corso');
      return;
    }
    final current = _findDisplayedDeparture() ?? _externalDep ?? widget.departure;
    debugPrint('[NationalDelay] Treno ${current.trainNumber} (delay attuale ${current.delayMinutes}): cerco nei tabelloni');

    _isRefreshingDelayFallback = true;
    try {
      final delay = await _trainProvider.refreshDelayFromUpcomingStations(current);
      if (!mounted || delay == null) {
        if (delay == null) debugPrint('[NationalDelay] Nessun ritardo trovato nei tabelloni');
        return;
      }
      // Se la departure visualizzata è esterna al tabellone, aggiorna la copia locale
      if (_externalDep != null && identical(current, _externalDep)) {
        if (_externalDep!.delayMinutes != delay) {
          setState(() {
            _externalDep = _externalDep!.copyWith(delayMinutes: delay);
          });
          debugPrint('[NationalDelay] Copia esterna aggiornata: ${current.delayMinutes} -> $delay min');
        } else {
          debugPrint('[NationalDelay] Copia esterna invariata: $delay min');
        }
      } else if (_findDisplayedDeparture() == null &&
          current.delayMinutes != delay) {
        // Treno esterno (es. deep-link): salva copia aggiornata così
        // tutti i punti che leggono _externalDep ?? widget.departure si aggiornano
        setState(() {
          _externalDep = current.copyWith(delayMinutes: delay);
        });
        debugPrint('[NationalDelay] Snapshot esterno aggiornato: ${current.delayMinutes} -> $delay min');
      } else {
        debugPrint('[NationalDelay] Ritardo $delay min gia nel tabellone corrente');
      }
    } finally {
      _isRefreshingDelayFallback = false;
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
    final theme = Provider.of<ThemeProvider>(context);
    final trainProvider = Provider.of<TrainProvider>(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDetailsAutoRefresh(trainProvider.isUsingOfflineCache);
    });

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeroHeader(context, theme, trainProvider),
                Expanded(
                  child: _buildContentArea(context, theme, trainProvider),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, ThemeProvider theme, TrainProvider trainProvider) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.isDark ? 0.2 : 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  final currentDep = _findDisplayedDeparture() ?? _externalDep ?? widget.departure;
                  return Row(
                    children: [
                      _BackButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Navigator.of(context).pop(), theme: theme),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTrainIdentifier(context, theme, currentDep),
                      ),
                      const SizedBox(width: 8),
                      _buildProgressButton(context, theme, trainProvider),
                      const SizedBox(width: 12),
                      _buildModernDelayBadge(currentDep.delayMinutes ?? 0, theme),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildRouteRow(context, theme, trainProvider),
              const SizedBox(height: 12),
              _buildViewersRow(theme),
              const SizedBox(height: 8),
              _buildActionChips(context, theme, trainProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteRow(BuildContext context, ThemeProvider theme, TrainProvider trainProvider) {
    final dep = trainProvider.departures.firstWhere(
      (d) => (d.tripId != null && d.tripId == widget.departure.tripId) ||
             (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
      orElse: () => widget.departure,
    );
    final origin = _getEffectiveOrigin(dep);
    final dest = _getEffectiveDestination(dep);

    // Calcola la posizione del treno (0.0 to 1.0)
    double progress = 0.0;
    final stops = dep.stops ?? [];
    if (stops.isNotEmpty) {
      final DateTime nowUtc = DateTime.now().toUtc();
      int currentIdx = -1;
      for (int i = 0; i < stops.length; i++) {
        final arrUtc = stops[i].estimatedArrival?.toUtc() ?? stops[i].arrival?.toUtc();
        if (arrUtc != null && nowUtc.isBefore(arrUtc)) {
          currentIdx = i;
          break;
        }
      }
      if (currentIdx == -1) {
        progress = 1.0;
      } else if (currentIdx == 0) {
        progress = 0.0;
      } else {
        final prevDep = stops[currentIdx - 1].estimatedDeparture?.toUtc() ?? stops[currentIdx - 1].departure?.toUtc();
        final nextArr = stops[currentIdx].estimatedArrival?.toUtc() ?? stops[currentIdx].arrival?.toUtc();
        if (prevDep != null && nextArr != null) {
          final totalDuration = nextArr.difference(prevDep).inSeconds;
          final elapsed = nowUtc.difference(prevDep).inSeconds;
          final segmentProgress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;
          progress = ((currentIdx - 1) + segmentProgress) / (stops.length - 1);
        } else {
          progress = currentIdx / (stops.length - 1);
        }
      }
      progress = progress.clamp(0.0, 1.0);
    }

    // Indice fermata corrente per il pulsante "vai alla posizione"
    int scrollIdx = -1;
    if (stops.isNotEmpty) {
      final nowUtc2 = DateTime.now().toUtc();
      for (int i = 0; i < stops.length; i++) {
        final arrTime =
            stops[i].estimatedArrival?.toUtc() ?? stops[i].arrival?.toUtc();
        final depTime = stops[i].estimatedDeparture?.toUtc() ??
            stops[i].departure?.toUtc();
        if (arrTime != null &&
            depTime != null &&
            nowUtc2.isAfter(arrTime) &&
            nowUtc2.isBefore(depTime)) {
          scrollIdx = i;
          break;
        }
        if (depTime != null && nowUtc2.isBefore(depTime)) {
          scrollIdx = i;
          break;
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withValues(alpha: theme.isDark ? 0.5 : 0.7),
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visual
          SizedBox(
            width: 24,
            child: Column(
              children: [
                // Origin dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.secondaryTextColor, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                // Connecting line with progress
                SizedBox(
                  height: 60,
                  width: 3,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(width: 3, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
                      FractionallySizedBox(
                        heightFactor: progress,
                        child: Container(
                          width: 3,
                          decoration: BoxDecoration(
                            gradient: theme.progressGradient,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Destination dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppTokens.trainColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Origin label
                Text(
                  RuntimeLocalizations.t(context, 'origin') ?? 'Partenza',
                  style: AppTextStyle.labelSmall(color: theme.secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        origin,
                        style: AppTextStyle.titleMedium(color: theme.textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (scrollIdx >= 0) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _scrollToStop(scrollIdx),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: AppTokens.trainColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),
                // Destination label
                Text(
                  RuntimeLocalizations.t(context, 'destination') ?? 'Arrivo',
                  style: AppTextStyle.labelSmall(color: theme.secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  dest,
                  style: AppTextStyle.titleMedium(color: theme.textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                // Percentage pill
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChips(BuildContext context, ThemeProvider theme, TrainProvider trainProvider) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildInfoChip(
            Icons.analytics_rounded,
            RuntimeLocalizations.t(context, 'statistics') ?? RuntimeLocalizations.t(context, 'statistics') ?? 'Statistiche',
            theme,
            () {
              final category = (widget.departure.category ?? '').trim();
              final tripNumber = (widget.departure.trainNumber ?? '').trim();
              if (category.isNotEmpty && tripNumber.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => TrainStatsScreen(category: category, tripNumber: tripNumber),
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
            RuntimeLocalizations.t(context, 'map') ?? RuntimeLocalizations.t(context, 'map') ?? 'Mappa',
            theme,
            () {
              final currentDep = _findDisplayedDeparture() ?? _externalDep ?? widget.departure;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => TrainMapPage(
                    departure: currentDep,
                    isArrivalMode: trainProvider.isArrivalMode,
                    currentDelay: currentDep.delayMinutes ?? 0,
                  ),
                ),
              );
            },
          ),
          _buildInfoChip(
            _isManualRefreshing ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
            RuntimeLocalizations.t(context, 'update') ?? RuntimeLocalizations.t(context, 'update') ?? 'Aggiorna',
            theme,
            _isManualRefreshing ? null : () => _refreshTrainDetails(),
          ),
          _buildInfoChip(
            _isSharing ? Icons.hourglass_empty_rounded : Icons.share_rounded,
            RuntimeLocalizations.t(context, 'share_trip', fallback: 'Condividi'),
            theme,
            _isSharing ? null : () async {
              setState(() => _isSharing = true);
              try {
                final currentDep = _findDisplayedDeparture() ?? _externalDep ?? widget.departure;
                // Il provider completa la catena col country del pannello
                final url = await _trainProvider.shareTripLink(
                  currentDep,
                  countryFallback: _sheetCountry,
                );
                if (!mounted) return;
                if (url == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(RuntimeLocalizations.t(context, 'share_failed', fallback: 'Condivisione non riuscita, riprova')),
                      backgroundColor: theme.errorColor,
                    ),
                  );
                  return;
                }
                final cat = (currentDep.category ?? '').trim();
                final num = (currentDep.trainNumber ?? '').trim();
                final msg = "${RuntimeLocalizations.t(context, 'share_trip_msg', fallback: 'Segui il mio viaggio live')}: $cat $num\n$url";
                await Share.share(msg, subject: '$cat $num'.trim());
              } finally {
                if (mounted) setState(() => _isSharing = false);
              }
            },
          ),
          Consumer<TrainProvider>(
            builder: (context, tp, _) {
              final isOffline = _preventOnlineAutoRefresh || tp.isUsingOfflineCache || _isNetworkOffline;
              return _buildInfoChip(
                isOffline
                    ? Icons.cloud_off_rounded
                    : (_autoRefreshTimer != null ? Icons.timer_rounded : Icons.timer_off_rounded),
                isOffline ? (RuntimeLocalizations.t(context, 'offline') ?? RuntimeLocalizations.t(context, 'offline') ?? 'Offline') : (RuntimeLocalizations.t(context, 'live') ?? 'LIVE'),
                theme,
                isOffline ? null : () => _toggleAutoRefresh(),
                isActive: !isOffline && _autoRefreshTimer != null,
              );
            },
          ),
          _buildInfoChip(
            Icons.bookmark_rounded,
            RuntimeLocalizations.t(context, 'save') ?? RuntimeLocalizations.t(context, 'save') ?? 'Salva',
            theme,
            () async {
              final trainProvider = Provider.of<TrainProvider>(context, listen: false);
              final settings = Provider.of<SettingsProvider>(context, listen: false);
              await trainProvider.saveTrainOffline(widget.departure);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      settings.offlineSyncEnabled
                          ? (RuntimeLocalizations.t(context, 'train_saved_offline') ?? 'Salvato offline')
                          : (RuntimeLocalizations.t(context, 'train_saved_manual_offline') ?? 'Salvato manualmente')
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
          if (_hasMessages())
            _buildInfoChip(
              Icons.warning_amber_rounded,
              '${RuntimeLocalizations.t(context, 'alerts') ?? RuntimeLocalizations.t(context, 'alerts') ?? 'Avvisi'} (${_messages()?.length ?? 0})',
              theme,
              _showMessagesSheet,
              isActive: true,
              isWarning: true,
            ),
          // Favorite button
          Consumer2<FavoritesProvider, AuthProvider>(
            builder: (context, favoritesProvider, authProvider, _) {
              if (!authProvider.isAuthenticated) return const SizedBox.shrink();
              final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
              final isFavorite = favoritesProvider.isTrainFavorite(
                widget.departure.trainNumber ?? '',
                widget.departure.origin ?? '',
                widget.departure.destination ?? '',
              );
              return _buildInfoChip(
                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                AppLocalizations.of(context)?.save ?? 'Salva',
                theme,
                () async {
                  if (isFavorite) {
                    await favoritesProvider.removeTrainFavorite(
                      widget.departure.trainNumber ?? '',
                      widget.departure.origin ?? '',
                      widget.departure.destination ?? '',
                    );
                  } else {
                    final favoriteTrain = FavoriteTrain(
                      id: '${userId}_train_${widget.departure.trainNumber}_${widget.departure.origin}_${widget.departure.destination}',
                      addedAt: DateTime.now(),
                      userId: userId,
                      trainNumber: widget.departure.trainNumber ?? '',
                      departureStation: widget.departure.origin ?? '',
                      arrivalStation: widget.departure.destination ?? '',
                      departureTime: widget.departure.scheduledTime?.toIso8601String() ?? '',
                      arrivalTime: '',
                      operator: null,
                      category: widget.departure.category,
                      routeId: widget.departure.tripId,
                      provider: null,
                    );
                    await favoritesProvider.addTrainFavorite(favoriteTrain);
                  }
                },
                isActive: isFavorite,
              );
            },
          ),
          // Notifications button
          _TrainNotificationsButton(
            departure: widget.departure,
            selectedCountry: widget.selectedCountry,
            isPrimary: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressButton(BuildContext context, ThemeProvider theme, TrainProvider trainProvider) {
    final dep = trainProvider.departures.firstWhere(
      (d) => (d.tripId != null && d.tripId == widget.departure.tripId) ||
             (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
      orElse: () => widget.departure,
    );
    final stops = dep.stops ?? [];
    double progress = 0.0;
    if (stops.isNotEmpty) {
      final DateTime nowUtc = DateTime.now().toUtc();
      int currentIdx = -1;
      for (int i = 0; i < stops.length; i++) {
        final arrUtc = stops[i].estimatedArrival?.toUtc() ?? stops[i].arrival?.toUtc();
        if (arrUtc != null && nowUtc.isBefore(arrUtc)) {
          currentIdx = i;
          break;
        }
      }
      if (currentIdx == -1) {
        progress = 1.0;
      } else if (currentIdx > 0) {
        final prevDep = stops[currentIdx - 1].estimatedDeparture?.toUtc() ?? stops[currentIdx - 1].departure?.toUtc();
        final nextArr = stops[currentIdx].estimatedArrival?.toUtc() ?? stops[currentIdx].arrival?.toUtc();
        if (prevDep != null && nextArr != null) {
          final totalDuration = nextArr.difference(prevDep).inSeconds;
          final elapsed = nowUtc.difference(prevDep).inSeconds;
          final segmentProgress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;
          progress = ((currentIdx - 1) + segmentProgress) / (stops.length - 1);
        } else {
          progress = currentIdx / (stops.length - 1);
        }
      }
      progress = progress.clamp(0.0, 1.0);
    }

    return GestureDetector(
      onTap: () => _showProgressDialog(context, theme, trainProvider),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppTokens.trainColor.withValues(alpha: theme.isDark ? 0.3 : 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: AppTokens.trainColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2.5,
                backgroundColor: theme.borderColor.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(AppTokens.trainColor),
              ),
            ),
            Icon(Icons.train_rounded, color: AppTokens.trainColor, size: 10),
          ],
        ),
      ),
    );
  }

  void _showProgressDialog(BuildContext context, ThemeProvider theme, TrainProvider trainProvider) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius2Xl)),
        child: _ProgressDialogBody(
          resolveCurrent: () => _findDisplayedDeparture() ?? _externalDep ?? widget.departure,
          originOf: _getEffectiveOrigin,
          destOf: _getEffectiveDestination,
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context, ThemeProvider theme, TrainProvider trainProvider) {
    final currentDep = trainProvider.departures.firstWhere(
      (d) => (d.tripId != null && d.tripId == widget.departure.tripId) ||
             (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
      orElse: () => _externalDep ?? widget.departure,
    );

    if (_isLoadingExternalDetails && (currentDep.stops == null || currentDep.stops!.isEmpty) && currentDep.error == null) {
      return Center(child: _buildTimelineShimmer(theme));
    }

    if (_hasLoadedExternalData && currentDep.error != null && currentDep.error!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              Text(RuntimeLocalizations.t(context, 'something_went_wrong'), style: AppTextStyle.titleLarge(color: theme.textColor)),
              const SizedBox(height: 8),
              Text(currentDep.error!, textAlign: TextAlign.center, style: AppTextStyle.bodyMedium(color: theme.secondaryTextColor)),
              const SizedBox(height: 32),
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
                label: Text(RuntimeLocalizations.t(context, 'retry') ?? RuntimeLocalizations.t(context, 'retry') ?? 'Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasLoadedExternalData && (currentDep.stops == null || currentDep.stops!.isEmpty) && currentDep.error == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.train_rounded, size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
              const SizedBox(height: 24),
              Text(RuntimeLocalizations.t(context, 'noStopsAvailable') ?? 'Nessuna fermata disponibile', style: AppTextStyle.titleMedium(color: theme.textColor)),
              const SizedBox(height: 8),
              Text(RuntimeLocalizations.t(context, 'noStopsAvailableDesc') ?? 'I dettagli di questo treno non sono stati caricati.', style: AppTextStyle.bodyMedium(color: theme.secondaryTextColor)),
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
                label: Text(RuntimeLocalizations.t(context, 'reloadStops') ?? 'Ricarica'),
              ),
            ],
          ),
        ),
      );
    }

    final List<TrainStop> stops = currentDep.stops ?? [];
    final DateTime nowUtc = DateTime.now().toUtc();

    int currentSegmentIndex = -1;
    double segmentProgress = 0.0;
    bool isAtStation = false;

    if (stops.isNotEmpty) {
      for (int i = 0; i < stops.length - 1; i++) {
        final curTimes = _estimateStopTimesGlobal(stops[i], currentDep.delayMinutes ?? 0);
        final nextTimes = _estimateStopTimesGlobal(stops[i+1], currentDep.delayMinutes ?? 0);
        final depCurrent = curTimes['dep'] != null ? _ActualTime(curTimes['dep']!, isEstimated: stops[i].estimatedDeparture != null) : null;
        final arrCurrent = curTimes['arr'] != null ? _ActualTime(curTimes['arr']!, isEstimated: stops[i].estimatedArrival != null) : null;
        final arrNext = nextTimes['arr'] != null ? _ActualTime(nextTimes['arr']!, isEstimated: stops[i+1].estimatedArrival != null) : null;

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

    if (stops.isEmpty) {
      return Center(child: _buildTimelineShimmer(theme));
    }

    // Calcola la posizione attuale del treno
    final int currentIdx = currentSegmentIndex;
    final bool atStation = isAtStation;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final isFuture = index > currentSegmentIndex;
        final stop = stops[index];
        final hasStationId = stop.id != null && stop.id!.isNotEmpty;
        return _TimelineRow(
          stop: stop,
          index: index,
          isLast: index == stops.length - 1,
          isCompleted: index < currentSegmentIndex,
          isTraversing: (index == currentSegmentIndex) && !isAtStation && index < stops.length - 1,
          isActiveStop: (index == currentSegmentIndex) && isAtStation,
          progress: segmentProgress,
          timeFormatter: _formatStationTime,
          isFuture: isFuture,
          totalDelay: currentDep.delayMinutes ?? 0,
          theme: theme,
          onStationTap: hasStationId ? () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (ctx) => StationDetailsScreen(
                  stationId: stop.id!,
                  country: _resolveCountry(stop.country, currentDep.country),
                  stationName: stop.stationName,
                ),
              ),
            );
          } : null,
        );
      },
    );
  }

  /// Scorre la timeline fino alla fermata [index].
  void _scrollToStop(int index) {
    if (!_scrollController.hasClients) return;
    // Calcola l'offset approssimato della fermata corrente
    const itemHeight = 72.0; // Altezza approssimativa di ogni riga fermata
    final targetOffset =
        (index * itemHeight).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

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
            RuntimeLocalizations.t(context, 'loadingStops') ?? '⏳ Caricamento fermate...',
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
                          RuntimeLocalizations.t(context, 'offlineModeBanner') ?? "Modalità offline: il progresso del treno è basato sui dati salvati l'ultima volta.",
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
                  _isManualRefreshing ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
                  RuntimeLocalizations.t(context, 'update'),
                  theme,
                  _isManualRefreshing ? null : () => _refreshTrainDetails(),
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
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final category = (departure.category ?? 'TRN').trim();
    final number = (departure.trainNumber ?? '').trim();
    final screenWidth = MediaQuery.of(context).size.width;
    final scale = (screenWidth / 400).clamp(0.65, 1.0);

    if (settings.vectorLogosEnabled) {
      final key = category.toUpperCase().replaceAll(' ', '_');
      final logo = trainProvider.trainLogos[key];
      final logoUrl = logo != null ? (logo['png'] ?? logo['svg']) : null;

      if (logoUrl != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 24 * scale,
              constraints: BoxConstraints(maxWidth: 80 * scale),
              padding: theme.isDark
                  ? EdgeInsets.symmetric(
                      horizontal: 6 * scale, vertical: 2 * scale)
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
                errorBuilder: (context, error, stackTrace) {
                  return _buildColorText(category, number, theme);
                },
              ),
            ),
            SizedBox(width: 8 * scale),
            Flexible(
              child: Text(
                number,
                style: TextStyle(fontSize: 22 * scale, fontWeight: FontWeight.bold, color: theme.textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      }
    }

    return _buildColorText(category, number, theme);
  }

  /// Contatore spettatori live sopra i pulsanti, allineato a sinistra.
  Widget _buildViewersRow(ThemeProvider theme) {
    if (_viewersCount == null || _viewersCount! <= 0) {
      return const SizedBox.shrink();
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              _viewersCount == 1
                  ? RuntimeLocalizations.t(context, 'viewers_watching_one')
                  : RuntimeLocalizations.t(
                      context,
                      'viewers_watching_many',
                      params: {'count': '$_viewersCount'},
                    ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: theme.secondaryTextColor,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => _showViewersInfo(context, theme),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(
                    alpha: theme.isDark ? 0.25 : 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.primaryColor.withValues(alpha: 0.4),
                ),
              ),
              child: Icon(
                Icons.info_rounded,
                size: 14,
                color: theme.primaryColor,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  /// Popup che spiega come viene raccolto il numero di spettatori.
  void _showViewersInfo(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          RuntimeLocalizations.t(ctx, 'viewers_info_title') ??
              'Come contiamo gli spettatori',
          style: TextStyle(
              color: theme.textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold),
        ),
        content: Text(
          RuntimeLocalizations.t(ctx, 'viewers_info_body') ?? '',
          style: TextStyle(color: theme.textColor, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(RuntimeLocalizations.t(ctx, 'close') ?? 'Chiudi'),
          ),
        ],
      ),
    );
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
      text = RuntimeLocalizations.t(context, 'trainEarly', params: {'delay': (-delay).toString()}) ?? "Anticipo ${-delay}'";
      icon = Icons.fast_forward_rounded;
    } else if (delay == 0) {
      color = theme.successColor;
      text = RuntimeLocalizations.t(context, 'trainOnTime') ?? 'In Orario';
      icon = Icons.check_circle_rounded;
    } else if (delay <= 5) {
      color = const Color(0xFFFFA000);
      text = RuntimeLocalizations.t(context, 'trainDelayed', params: {'delay': delay.toString()}) ?? "+$delay min";
      icon = Icons.access_time_rounded;
    } else {
      color = theme.errorColor;
      text = RuntimeLocalizations.t(context, 'trainDelayed', params: {'delay': delay.toString()}) ?? "+$delay min";
      icon = Icons.warning_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
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

class _ProgressDialogBody extends StatefulWidget {
  final TrainDeparture Function() resolveCurrent;
  final String Function(TrainDeparture) originOf;
  final String Function(TrainDeparture) destOf;

  const _ProgressDialogBody({
    required this.resolveCurrent,
    required this.originOf,
    required this.destOf,
  });

  @override
  State<_ProgressDialogBody> createState() => _ProgressDialogBodyState();
}

class _ProgressDialogBodyState extends State<_ProgressDialogBody> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    // Rebuild anche quando il provider aggiorna partenze/ritardi
    context.watch<TrainProvider>();

    final dep = widget.resolveCurrent();
    final stops = dep.stops ?? [];
    final origin = widget.originOf(dep);
    final dest = widget.destOf(dep);

    // Calcola progresso (stessa logica del bottone header)
    double progress = 0.0;
    if (stops.isNotEmpty) {
      final DateTime nowUtc = DateTime.now().toUtc();
      int currentIdx = -1;
      for (int i = 0; i < stops.length; i++) {
        final arrUtc = stops[i].estimatedArrival?.toUtc() ?? stops[i].arrival?.toUtc();
        if (arrUtc != null && nowUtc.isBefore(arrUtc)) {
          currentIdx = i;
          break;
        }
      }
      if (currentIdx == -1) {
        progress = 1.0;
      } else if (currentIdx == 0) {
        progress = 0.0;
      } else {
        final prevDep = stops[currentIdx - 1].estimatedDeparture?.toUtc() ?? stops[currentIdx - 1].departure?.toUtc();
        final nextArr = stops[currentIdx].estimatedArrival?.toUtc() ?? stops[currentIdx].arrival?.toUtc();
        if (prevDep != null && nextArr != null) {
          final totalDuration = nextArr.difference(prevDep).inSeconds;
          final elapsed = nowUtc.difference(prevDep).inSeconds;
          final segmentProgress = totalDuration > 0 ? (elapsed / totalDuration).clamp(0.0, 1.0) : 0.0;
          progress = ((currentIdx - 1) + segmentProgress) / (stops.length - 1);
        } else {
          progress = currentIdx / (stops.length - 1);
        }
      }
      progress = progress.clamp(0.0, 1.0);
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            RuntimeLocalizations.t(context, 'progress_title', fallback: 'Progresso Viaggio'),
            style: AppTextStyle.titleLarge(color: theme.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '${dep.trainNumber ?? dep.category ?? "Treno"} - ${(progress * 100).toInt()}%',
            style: AppTextStyle.bodyMedium(color: theme.secondaryTextColor),
          ),
          const SizedBox(height: 24),
          // Progress visualization
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.backgroundColor,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: theme.borderColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                // Route with progress
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        origin,
                        style: AppTextStyle.bodyMedium(color: theme.textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        dest,
                        style: AppTextStyle.bodyMedium(color: theme.textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Progress bar
                SizedBox(
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background line
                      Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: theme.borderColor.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      // Progress line
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              gradient: theme.progressGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                      // Train position indicator
                      Align(
                        alignment: Alignment(-1.0 + (progress * 2), 0),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTokens.trainColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.surfaceColor, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: AppTokens.trainColor.withValues(alpha: 0.5),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.train_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Percentage
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    color: AppTokens.trainColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Close button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              RuntimeLocalizations.t(context, 'close', fallback: 'Chiudi'),
              style: TextStyle(color: theme.primaryColor),
            ),
          ),
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
  final VoidCallback? onStationTap;

  const _TimelineRow({
    required this.stop, required this.index, required this.isLast, 
    required this.isCompleted, required this.isTraversing, 
    required this.isActiveStop, required this.progress, required this.timeFormatter,
    required this.isFuture, required this.totalDelay, required this.theme,
    this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool highlighted = isCompleted || isActiveStop || isTraversing;

    ({String text, int delay}) buildTime(String type, DateTime? scheduled, DateTime? estimated, int? delay) {
      if (scheduled == null && estimated == null) {
        return (text: '', delay: 0);
      }

      // delay null = ritardo per-fermata sconosciuto: se la fermata non e futura,
      // usa il ritardo del treno (le fermate gia passate/attuale hanno subito
      // lo stesso ritardo; quelle future usano gia totalDelay dal chiamante).
      // Uno 0 esplicito (fermata puntuale misurata) viene rispettato.
      // Se esiste lo stimato ma non il ritardo, lo si deriva da stimato-programmato.
      final int effectiveDelay;
      if (delay != null) {
        effectiveDelay = delay;
      } else if (estimated != null && scheduled != null) {
        effectiveDelay = (estimated.difference(scheduled).inSeconds / 60).round();
      } else if (estimated == null && !isFuture && totalDelay != 0) {
        effectiveDelay = totalDelay;
      } else {
        effectiveDelay = 0;
      }

      final effective = estimated ?? scheduled!.add(Duration(minutes: effectiveDelay));
      final effStr = timeFormatter(effective, stop.country);

      final String text;
      if (scheduled != null && (estimated != null || effectiveDelay != 0)) {
        text = '$type: $effStr (${RuntimeLocalizations.t(context, 'scheduled_label')}: ${timeFormatter(scheduled, stop.country)})';
      } else {
        text = '$type: $effStr';
      }
      return (text: text, delay: effectiveDelay);
    }

    Widget delayBadge(int delay) {
      final Color color;
      if (delay <= 0) {
        color = Colors.green;
      } else if (delay <= 5) {
        color = Colors.orange;
      } else if (delay <= 15) {
        color = Colors.deepOrange;
      } else {
        color = Colors.red;
      }
      final text = delay > 0 ? '+$delay\'' : '$delay\'';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      );
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
                      child: Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Builder(
                                builder: (_) {
                                  // Più il nome è lungo, più il font si rimpicciolisce (16 → 9, senza limite intermedio);
                                  // il FittedBox garantisce che entri comunque su ogni schermo.
                                  final size = (16.0 - (stop.stationName.length - 20) * 0.25).clamp(9.0, 16.0);
                                  return Text(stop.stationName, maxLines: 1, style: TextStyle(color: isCompleted ? theme.secondaryTextColor.withOpacity(0.6) : theme.textColor, fontSize: size, fontWeight: highlighted ? FontWeight.w800 : FontWeight.w600));
                                },
                              ),
                            ),
                          ),
                          if (onStationTap != null)
                            GestureDetector(
                              onTap: onStationTap,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.train_rounded, size: 14, color: theme.primaryColor),
                                ),
                              ),
                            ),
                        ],
                      ),
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
                    Builder(builder: (_) {
                      final arr = buildTime(RuntimeLocalizations.t(context, 'arrival'), stop.arrival, stop.estimatedArrival, isFuture ? totalDelay : stop.arrivalDelay);
                      if (arr.text.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(arr.text,
                              style: TextStyle(color: stop.cancelled ? theme.secondaryTextColor.withOpacity(0.5) : (isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor), fontSize: 12, decoration: stop.cancelled ? TextDecoration.lineThrough : TextDecoration.none)),
                          if (arr.delay != 0 && !stop.cancelled) delayBadge(arr.delay),
                        ],
                      );
                    }),
                  if (stop.departure != null)
                    Builder(builder: (_) {
                      final dep = buildTime(RuntimeLocalizations.t(context, 'departure'), stop.departure, stop.estimatedDeparture, isFuture ? totalDelay : stop.departureDelay);
                      if (dep.text.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(dep.text,
                              style: TextStyle(color: stop.cancelled ? theme.secondaryTextColor.withOpacity(0.5) : (isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor), fontSize: 12, decoration: stop.cancelled ? TextDecoration.lineThrough : TextDecoration.none)),
                          if (dep.delay != 0 && !stop.cancelled) delayBadge(dep.delay),
                        ],
                      );
                    }),

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

// ─────────────────────────────────────────────────────────
// Back button widget



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




// ─────────────────────────────────────────────────────────
// Train logo widget
// ─────────────────────────────────────────────────────────
class _TrainLogoWidget extends StatelessWidget {
  final String? category;
  final ThemeProvider theme;

  const _TrainLogoWidget({required this.category, required this.theme});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final cat = (category ?? 'TRN').trim();
    
    if (settings.vectorLogosEnabled) {
      final key = cat.toUpperCase().replaceAll(' ', '_');
      final logo = trainProvider.trainLogos[key];
      final logoUrl = logo != null ? (logo['png'] ?? logo['svg']) : null;

      if (logoUrl != null) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTokens.trainColor, AppTokens.trainColor.withValues(alpha: 0.7)],
            ),
            borderRadius: BorderRadius.circular(AppTokens.radiusXl),
            boxShadow: [BoxShadow(color: AppTokens.trainColor.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: SizedBox(
            height: 40,
            width: 40,
            child: Image.network(
              logoUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return _buildCategoryFallback(cat);
              },
            ),
          ),
        );
      }
    }
    
    return _buildCategoryFallback(cat);
  }
  
  Widget _buildCategoryFallback(String category) {
    final isHighSpeed = category.toLowerCase().contains('fr') || category.toLowerCase().contains('freccia');
    final color = isHighSpeed ? Colors.redAccent : AppTokens.trainColor;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: BorderRadius.circular(AppTokens.radiusXl),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.train_rounded, color: Colors.white, size: 28),
          const SizedBox(width: 8),
          Text(category, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Back button widget
// ─────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeProvider theme;

  const _BackButton({required this.icon, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.surfaceColor.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: theme.textColor, size: 18),
          ),
        ),
      ),
    );
  }
}

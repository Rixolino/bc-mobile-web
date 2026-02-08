import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../data/models/train_model.dart';
import '../providers/train_provider.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_train.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../../core/services/android_background_service.dart';
import '../../../../presentation/providers/notification_manager_provider.dart';

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

// Shared helper: estimate arrival and departure UTC times for a stop using train-level delay when schedules are used.
Map<String, DateTime?> _estimateStopTimesGlobal(TrainStop s, int trainDelay) {
  DateTime? arr = s.estimatedArrival?.toUtc() ?? (s.arrival != null ? s.arrival!.toUtc().add(Duration(minutes: trainDelay)) : null);
  DateTime? dep = s.estimatedDeparture?.toUtc() ?? (s.departure != null ? s.departure!.toUtc().add(Duration(minutes: trainDelay)) : null);

  // Ensure both exist when possible
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

// Small widget to manage notifications toggle for a specific train
class _TrainNotificationsButton extends StatefulWidget {
  final TrainDeparture departure;
  final String? selectedCountry;
  const _TrainNotificationsButton({required this.departure, this.selectedCountry});

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

  // Helper: build notification title
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

  // Helper: build notification body according to spec
  String _buildTrainNotificationBody(TrainDeparture d, {String? userDestination}) {
    final now = DateTime.now().toUtc();
    final stops = d.stops ?? [];

    // Local helper to compute effective UTC times respecting train-level delay
    _ActualTime? _stopActual(DateTime? scheduled, DateTime? estimated, int? stopDelayMinutes) {
      if (estimated != null) return _ActualTime(estimated.toUtc(), isEstimated: true);
      if (scheduled != null) {
        final int trainDelay = d.delayMinutes ?? 0;
        final int useDelay = trainDelay != 0 ? trainDelay : (stopDelayMinutes ?? 0);
        return _ActualTime(scheduled.toUtc().add(Duration(minutes: useDelay)), isEstimated: false);
      }
      return null;
    }

    // Structured stop info with normalized UTC times
    final stopStates = <Map<String, dynamic>>[];
    for (int i = 0; i < stops.length; i++) {
      final s = stops[i];
      // FIX: Notification delay should never use arrivalDelay (user request). 
      // We pass 0 so _stopActual will rely on trainDelay or 0.
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

    // 1) If metadata contains a lastDetection use it as authoritative when possible
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

          // determine if we are at station using explicit flag or timestamp proximity
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

    // 2) If metadata didn't resolve nextIndex, pick the nearest future arrival (skip cancelled stops)
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

    // 3) Fallback: choose the first non-cancelled stop after last passed index; otherwise first non-cancelled
    if (nextIndex == -1 && stopStates.isNotEmpty) {
      int lastIdx = -1;
      for (var ss in stopStates) {
        final DateTime? depUtc = ss['depUtc'] as DateTime?;
        final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
        
        // FIX: Consider passed ONLY if departure is past (if exists), or arrival is past (if terminus).
        bool isPassed = false;
        if (depUtc != null) {
          if (depUtc.isBefore(now)) isPassed = true;
        } else if (arrUtc != null && arrUtc.isBefore(now)) {
          isPassed = true;
        }
        
        // Also detect "At Station" if we are here (arr < now < dep)
        if (arrUtc != null && depUtc != null && !arrUtc.isAfter(now) && !depUtc.isBefore(now)) {
           isAtStation = true;
           lastPassed = (ss['stop'] as TrainStop).stationName; // Ensure 'lastPassed' reflects current station for display
           // Do NOT mark as passed if we want "Next Stop" to be the NEXT one?
           // Actually, if we are AT station X, Next Stop usually implies X+1.
           // But if user complains about skipping, maybe they want Next Stop to be X while arriving?
           // If 'isAtStation' is true, we usually display "Treno in stazione: X".
           // In that case nextIndex SHOULD be X+1.
           // But let's stick to standard logic: if At Station, lastIdx = X.
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
        // first non-cancelled overall
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

    // 4) Compute lastPassed if still empty
    if (lastPassed.isEmpty) {
      int lastIdx = -1;
      for (var ss in stopStates) {
        final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
        final DateTime? depUtc = ss['depUtc'] as DateTime?;
        
        // Same robust logic for lastPassed
        bool isPassed = false;
        if (depUtc != null) {
          if (depUtc.isBefore(now)) isPassed = true;
        } else if (arrUtc != null && arrUtc.isBefore(now)) {
           isPassed = true;
        }
        
        // If at station, use that
        if (arrUtc != null && depUtc != null && !arrUtc.isAfter(now) && !depUtc.isBefore(now)) {
           lastIdx = ss['index'] as int;
           isAtStation = true;
        } else if (isPassed) {
           lastIdx = ss['index'] as int;
        }
      }
      if (lastIdx >= 0) lastPassed = (stopStates[lastIdx]['stop'] as TrainStop).stationName;
    }

    // Debug logs to help reproduce issues (only in debug builds)
    if (kDebugMode) {
      // ignore: avoid_print
      print('[notif-debug] now=$now nextIndex=$nextIndex nextStop=$nextStop lastPassed=$lastPassed isAtStation=$isAtStation');
    }

    final delay = d.delayMinutes ?? 0;

    // Count remaining stops to destination (ignore cancelled stops)
    int remaining = 0;
    if (userDestination != null && userDestination.trim().isNotEmpty && stops.isNotEmpty) {
      final destIndex = stops.indexWhere((s) => s.stationName.trim().toLowerCase() == userDestination.trim().toLowerCase());
      if (destIndex != -1 && nextIndex != -1) {
        // count only non-cancelled stops between nextIndex and destIndex
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

    // If user's destination is cancelled, return informative message
    if (userDestination != null && userDestination.trim().isNotEmpty) {
      final destIdx = stops.indexWhere((s) => s.stationName.trim().toLowerCase() == userDestination.trim().toLowerCase());
      if (destIdx != -1 && stops[destIdx].cancelled) return '\u26A0\uFE0F La tua fermata ($userDestination) \u00E8 stata annullata.';
      if (isAtStation && lastPassed.trim().toLowerCase() == userDestination.trim().toLowerCase()) {
        // keep neutral informational message for main channel
        return '\u26A0\uFE0F Treno in stazione: $userDestination. Ricordati di scendere.';
      }
      if (nextStop.trim().toLowerCase() == userDestination.trim().toLowerCase()) {
        // do not instruct to "prepare bags" here; proximity alerts will be sent on a dedicated channel
        return '\u26A0\uFE0F Sei in arrivo alla tua fermata: $userDestination. Prossima discesa.';
      }
      if (lastPassed.trim().toLowerCase() == userDestination.trim().toLowerCase() && nextIndex == -1) {
        return '\uD83D\uDE89 Sei arrivato a $userDestination. Ricordati di scendere dal treno!';
      }
    }

    // Build standard body
    final buffer = StringBuffer();
    if (nextStop.isNotEmpty) {
      final arrStr = nextArrival != null ? '${nextArrival.toLocal().hour.toString().padLeft(2, '0')}:${nextArrival.toLocal().minute.toString().padLeft(2, '0')}' : '--:--';
      final depStr = nextDeparture != null ? '${nextDeparture.toLocal().hour.toString().padLeft(2, '0')}:${nextDeparture.toLocal().minute.toString().padLeft(2, '0')}' : '';
      // try to find platform for next stop
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

    // If train is at station show that specially
    if (isAtStation && lastPassed.isNotEmpty) {
      buffer.writeln('Treno in stazione: $lastPassed');
    } else {
      buffer.writeln('Stato attuale: ${lastPassed.isNotEmpty ? lastPassed : 'In transito'}');
    }

    // Show explicit delay/advance line without duplicating words
    if (delay > 0) {
      buffer.writeln('Ritardo: ${delay} min');
    } else if (delay < 0) {
      buffer.writeln('Anticipo: ${-delay} min');
    } else {
      buffer.writeln('In orario');
    }

    buffer.writeln('Fermate rimanenti: $remaining');

    return buffer.toString().trim();
  }

  Future<void> _toggle() async {
    final tripId = widget.departure.tripId ?? widget.departure.trainNumber ?? '';
    // Prefer an explicit endpoint if present in train metadata to avoid guessing country

    // Open bottom sheet with options: 1) Notify until chosen destination, 2) General notification
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
                  ListTile(title: const Text('Notifica fino a...'), subtitle: const Text('Scegli una fermata dalla lista')),
                  if (stops.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text('Lista fermate non disponibile, verrà usata notifica generale.')),
                  if (stops.isNotEmpty)
                    SizedBox(
                      height: 200,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: stops.length,
                        itemBuilder: (c, i) {
                          final s = stops[i];
                          final nowUtc = DateTime.now().toUtc();
                          // Compute effective arrival/departure times using train-level delay when estimates are missing
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
                            isCurrent = true; // train currently at this station
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

                  // Preview
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Anteprima notifica', style: TextStyle(fontWeight: FontWeight.bold)),
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
                            child: const Text('Notifica fino alla fermata selezionata'),
                            onPressed: selectedStop == null && stops.isNotEmpty ? null : () async {
                              Navigator.pop(ctx);
                              // schedule with destination
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
                            child: const Text('Notifica generale'),
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
                      child: const Text('Disattiva notifiche per questo treno', style: TextStyle(color: Colors.red)),
                      onPressed: () async {
                        Navigator.pop(ctx);
                      final monitorKey = tripId.isNotEmpty ? tripId : (widget.departure.trainNumber ?? '');
                      if (monitorKey.isNotEmpty) await AndroidBackgroundService.removeMonitoredTrip(monitorKey);
                      final key = 'train:$monitorKey';
                        await AndroidBackgroundService.cancelNotification(key: key);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifiche disattivate')));
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
    // Try to refresh details in provider to let it populate metadata/endpoint if possible
    final trainProvider = Provider.of<TrainProvider>(ctx, listen: false);
    // Always search for the train, whether by tripId or by trainNumber/destination combo
    final idx = trainProvider.departures.indexWhere((d) => 
      (tripId != null && (d.tripId == tripId || d.trainNumber == tripId)) || 
      (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination)
    );
    if (idx != -1) {
      try {
        await trainProvider.expandTrainDetails(idx);
        // small pause to allow provider to update UI/state
        await Future.delayed(const Duration(milliseconds: 400));
      } catch (e) {
        // ignore
      }
    }

    // Re-check metadata from provider's up-to-date model (prefer that over local widget.departure)
    final TrainDeparture currentDep = (idx != -1) ? trainProvider.departures[idx] : widget.departure;
    final metaEndpoint = currentDep.metadata != null ? (currentDep.metadata!['endpoint'] as String?) : null;
    // Determine country but avoid using the panel default 'IT' unless explicitly set by user
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
      // try to infer country from endpoint if possible
    } else if (tripId != null && tripId.isNotEmpty && countryFromMeta != null && countryFromMeta.isNotEmpty) {
      final candidate = '$prodBase/${countryFromMeta}/trip?tripId=${Uri.encodeComponent(tripId)}';
      try {
        final resp = await http.get(Uri.parse(candidate)).timeout(const Duration(seconds: 6));
        if (resp.statusCode == 200) {
          // Basic heuristic: response must contain stops or data
          final body = resp.body;
          if (body.contains('stops') || body.contains('data') || body.contains('trip')) {
            resolvedEndpoint = candidate;
            usedCountry = countryFromMeta;
          } else {
            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Impossibile verificare l\'endpoint dal country selezionata')));
          }
        } else {
          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Richiesta all\'endpoint ${candidate} fallita: HTTP ${resp.statusCode}')));
        }
      } catch (e) {
        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Errore di rete durante la verifica dell\'endpoint')));
      }
    } else if (tripId != null && tripId.isNotEmpty) {
      // No country available: ask user to set it instead of guessing
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Non è possibile determinare l\'URL esatto: imposta la country del pannello o utilizza l\'endpoint manuale')));
    }

    // Proceed to schedule even if resolvedEndpoint is null (service will skip fetch if no country/endpoint)
    // include arrival pre-notice from settings
    // also pass the current first stop as the "starting" reference point for consistent calculations
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

    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Notifica impostata')));

    // If user requested destination-specific notify, do an immediate proximity check (may trigger the pre-notice now)
    if (notifyMode == 'to_destination' && destinationStop != null && destinationStop.isNotEmpty) {
      final notifProv = Provider.of<NotificationManagerProvider>(ctx, listen: false);
      notifProv.triggerProximityCheckForTrip(tripId ?? '', destinationStop, settings.trainArrivalPreNoticeMinutes, startingStop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return IconButton.filledTonal(
      icon: Icon(_enabled ? Icons.notifications_active : Icons.notifications_none),
      onPressed: _toggle,
      style: IconButton.styleFrom(
        backgroundColor: theme.primaryColor.withOpacity(0.15),
        foregroundColor: theme.primaryColor,
      ),
    );
  }
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
    if (index != -1) {
       // Force update via provider (which re-uses last know country or station country)
       trainProvider.expandTrainDetails(index);
       // Check if we need to locally update local widget state if not watching provider fully?
       // Actually, the build method relies on `widget.departure`. 
       // If standard MVP, we should be using `Consumer` or refetching a fresh object from the provider into the state.
       // However, `ListView.builder` in `build` uses `widget.departure.stops`. 
       // `widget.departure` is final. IT DOES NOT UPDATE when provider updates!
       // START FIX: We need to pull the LATEST departure object from provider
       final freshDep = trainProvider.departures[index];
       // We can't update `widget.departure`. We should probably wrap the body in a Consumer or check provider here.
    }
  }

  String _formatStationTime(DateTime? date, String countryCode) {
    if (date == null) return '--:--';
    final int offset = countryTimezoneOffsets[countryCode] ?? 1;
    return DateFormat('HH:mm').format(date.toUtc().add(Duration(hours: offset)));
  }





  @override
  Widget build(BuildContext context) {
    // FIX: Listen to provider to get updates for THIS train
    return Consumer<TrainProvider>(
      builder: (context, provider, child) {
        // Find the most up-to-date version of this departure
        final currentDep = provider.departures.firstWhere(
           (d) => (d.tripId != null && d.tripId == widget.departure.tripId) || 
                  (d.trainNumber == widget.departure.trainNumber && d.destination == widget.departure.destination),
           orElse: () => widget.departure // fallback to initial
        );

    // ERROR STATE HANDLING
    if (currentDep.error != null && currentDep.error!.isNotEmpty) {
      return Consumer<ThemeProvider>(
        builder: (context, theme, child) {
          return Container(
            decoration: BoxDecoration(color: theme.backgroundColor, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
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
                            "Ops! Qualcosa è andato storto",
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
                              onPressed: _refreshTrainDetails,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text("Riprova"),
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
        }
      );
    }

    final List<TrainStop> stops = currentDep.stops ?? [];
    final trainName = "${currentDep.category ?? ''} ${currentDep.trainNumber ?? ''}".trim();
    
    final lastDetection = currentDep.metadata?['lastDetection'];
    final DateTime nowUtc = (lastDetection != null && lastDetection['timestamp'] != null)
        ? DateTime.parse(lastDetection['timestamp']).toUtc()
        : DateTime.now().toUtc();

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

        // If the train is currently traversing between depCurrent and arrNext
        if (depCurrent != null && arrNext != null && nowUtc.isAfter(depCurrent.time) && nowUtc.isBefore(arrNext.time)) {
          currentSegmentIndex = i;
          isAtStation = false;
          final total = arrNext.time.difference(depCurrent.time).inSeconds;
          final elapsed = nowUtc.difference(depCurrent.time).inSeconds;
          segmentProgress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 1.0;
          break;
        }

        // If the current stop window covers now, mark as at station
        if (arrCurrent != null && depCurrent != null && !nowUtc.isBefore(arrCurrent.time) && !nowUtc.isAfter(depCurrent.time)) {
          currentSegmentIndex = i;
          isAtStation = true;
          break;
        }

        // If we've already passed the next arrival, move the index forward
        if (arrNext != null && nowUtc.isAfter(arrNext.time)) currentSegmentIndex = i + 1;
      }
    }

    final int totalDelay = currentDep.delayMinutes ?? 0;
    final String fullDisplayName = "$trainName";

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        return Container(
          decoration: BoxDecoration(color: theme.backgroundColor, borderRadius: BorderRadius.only(topLeft: Radius.circular(28), topRight: Radius.circular(28))),
      child: Column(
        children: [
          _buildHeader(context, fullDisplayName, totalDelay, theme, currentDep),
          Expanded(
            child: stops.isEmpty 
              ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
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
   }); // End Consumer
  }

  Widget _buildHeader(BuildContext context, String displayName, int delay, ThemeProvider theme, TrainDeparture departure) {
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
                    Text(widget.isArrivalMode ? "Origine: ${departure.origin}" : "Destinazione: ${departure.destination}", 
                         style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Consumer2<FavoritesProvider, AuthProvider>(
                builder: (context, favoritesProvider, authProvider, child) {
                  if (!authProvider.isAuthenticated) return const SizedBox.shrink();
                  
                  final userId = authProvider.currentUser?.id?.toString() ?? 'guest';
                  final isFavorite = favoritesProvider.isTrainFavorite(
                    departure.trainNumber ?? '',
                    departure.origin ?? '',
                    departure.destination ?? '',
                  );
                  return IconButton.filledTonal(
                    icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                    onPressed: () async {
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
                          arrivalTime: '', // Non disponibile
                          operator: null, // Non disponibile
                          category: widget.departure.category,
                          routeId: widget.departure.tripId,
                          provider: null, // Non disponibile
                        );
                        await favoritesProvider.addTrainFavorite(favoriteTrain);
                      }
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: theme.surfaceColor.withOpacity(0.05),
                      foregroundColor: isFavorite ? Colors.red : theme.secondaryTextColor,
                    ),
                  );
                },
              ),
              // Messages button (se presenti)
              if (_hasMessages())
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(Icons.error_outline),
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(color: theme.errorColor, shape: BoxShape.circle),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            '${(_messages()?.length ?? 0)}',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: _showMessagesSheet,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.surfaceColor.withOpacity(0.05),
                    foregroundColor: theme.warningColor,
                  ),
                ),

              // Notifications button
              Builder(builder: (ctx) {
                return _TrainNotificationsButton(departure: departure, selectedCountry: widget.selectedCountry);
              }),
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

  // Messages helpers: extract and display train messages when present
  List<Map<String, dynamic>>? _messages() {
    final List<Map<String, dynamic>> out = [];

    // Trip-level messages (preferred source: explicit parsed field)
    final tripMsgs = widget.departure.messages;
    if (tripMsgs != null && tripMsgs.isNotEmpty) {
      out.addAll(tripMsgs.map((m) => Map<String, dynamic>.from(m)));
    }

    // Some providers may embed messages inside metadata as fallback
    final meta = widget.departure.metadata;
    if (meta != null) {
      final raw = meta['messages'] ?? meta['alerts'] ?? meta['notes'];
      if (raw is List && raw.isNotEmpty) {
        out.addAll(raw.map<Map<String, dynamic>>((e) => e is Map<String, dynamic> ? Map<String, dynamic>.from(e) : (e is Map ? Map<String, dynamic>.from(e) : {'text': e?.toString()})));
      }
    }

    // Stop-level messages: include station context
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
                    Text('Messaggi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${msgs.length}'),
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
                              const SizedBox(height: 4),
                              Text(text),
                            ],
                          )
                        : Text(text);

                      // Priority colors
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
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi'))),
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
                  // Station name with cancelled badge if applicable
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
                        child: Text('Annullata', style: TextStyle(color: theme.errorColor, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                  ],),
                  if (stop.arrival != null) 
                    Text(buildTimeString('Arrivo', stop.arrival, stop.estimatedArrival, isFuture ? totalDelay : (stop.arrivalDelay ?? 0)),
                        style: TextStyle(color: stop.cancelled ? theme.secondaryTextColor.withOpacity(0.5) : (isCompleted ? theme.secondaryTextColor.withOpacity(0.4) : theme.secondaryTextColor), fontSize: 12, decoration: stop.cancelled ? TextDecoration.lineThrough : TextDecoration.none)),
                  if (stop.departure != null)
                    Text(buildTimeString('Partenza', stop.departure, stop.estimatedDeparture, isFuture ? totalDelay : (stop.departureDelay ?? 0)),
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
          // Circle for the stop: highlight in red when cancelled
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
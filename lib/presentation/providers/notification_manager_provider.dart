import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../constants/notification_channels.dart';
import '../../core/services/android_background_service.dart';

class MonitoredStop {
  final String id;
  final String name;
  String? rawPayload; // JSON string
  String lastPreview = '';
  String lastUpdated = '';

  MonitoredStop({required this.id, required this.name, this.rawPayload});
}

class MonitoredTrip {
  final String tripId;
  final String? metaJson;
  String? rawPayload;

  MonitoredTrip({required this.tripId, this.metaJson, this.rawPayload});

  String? get endpoint {
    if (metaJson == null) return null;
    try {
      final m = jsonDecode(metaJson!);
      if (m is Map && m.containsKey('endpoint')) return m['endpoint']?.toString();
    } catch (e) {}
    return null;
  }

  String? get country {
    if (metaJson == null) return null;
    try {
      final m = jsonDecode(metaJson!);
      if (m is Map && m.containsKey('country')) return m['country']?.toString();
    } catch (e) {}
    return null;
  }
}

class NotificationManagerProvider extends ChangeNotifier {
  final List<MonitoredStop> stops = [];
  final List<String> stations = [];
  final Map<String, String?> stationPreviews = {};
  final Map<String, String> stationLastUpdated = {};

  // Monitored trips
  final List<MonitoredTrip> trips = [];
  final Map<String, String?> tripPreviews = {};
  final Map<String, String> tripLastUpdated = {};
  // Human-friendly titles extracted from payload (category + number / name)
  final Map<String, String> tripTitles = {}; 

  bool loading = false;

  Future<void> loadAll() async {
    loading = true;
    notifyListeners();

    try {
      final stopMap = await AndroidBackgroundService.getMonitoredStops();
      stops.clear();
      stopMap.forEach((id, name) {
        stops.add(MonitoredStop(id: id, name: name));
      });

      final stationList = await AndroidBackgroundService.getMonitoredStations();
      stations.clear();
      stations.addAll(stationList);

      // Monitored trips
      final tripMap = await AndroidBackgroundService.getMonitoredTrips();
      trips.clear();
      tripMap.forEach((tId, meta) {
        trips.add(MonitoredTrip(tripId: tId, metaJson: meta));
      });

      // Load cached payloads for preview and timestamps
      for (final s in stops) {
        final payload = await AndroidBackgroundService.getCachedStopData(s.id);
        s.rawPayload = payload;
        s.lastPreview = _buildPreviewFromPayload(payload);
        s.lastUpdated = _extractLastUpdatedFromPayload(payload) ?? _formatNow();
      }

      for (final sid in stations) {
        final payload = await AndroidBackgroundService.getCachedStationData(sid);
        stationPreviews[sid] = _buildPreviewFromPayload(payload);
        stationLastUpdated[sid] = _extractLastUpdatedFromPayload(payload) ?? _formatNow();
      }

      for (final t in trips) {
        // Try to pass country if available in metadata to help resolve the correct endpoint
        String? country;
        if (t.metaJson != null) {
          try {
            final meta = jsonDecode(t.metaJson!);
            if (meta is Map && meta.containsKey('country')) country = meta['country']?.toString();
          } catch (e) {}
        }
        final payload = await AndroidBackgroundService.forceFetchTrip(t.tripId, country: country);
        t.rawPayload = payload;
        tripPreviews[t.tripId] = _buildTripPreviewFromPayload(payload);
        final lastUpdated = _extractLastUpdatedFromPayload(payload);
        tripLastUpdated[t.tripId] = lastUpdated ?? _formatNow();
        tripTitles[t.tripId] = _extractTitleFromPayload(payload) ?? t.tripId;
      }
    } catch (e) {
      if (kDebugMode) print('Error loading monitored targets: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> removeStop(String stopId) async {
    await AndroidBackgroundService.removeMonitoredStop(stopId);
    await AndroidBackgroundService.cancelNotification(key: 'stop:$stopId');
    stops.removeWhere((s) => s.id == stopId);
    notifyListeners();
  }

  Future<void> refreshStop(String stopId) async {
    final payload = await AndroidBackgroundService.forceFetchStop(stopId);
    final idx = stops.indexWhere((s) => s.id == stopId);
    if (idx != -1) {
      stops[idx].rawPayload = payload;
      stops[idx].lastPreview = _buildPreviewFromPayload(payload);
      stops[idx].lastUpdated = _extractLastUpdatedFromPayload(payload) ?? _formatNow();
      notifyListeners();
    }
  }

  Future<void> removeStation(String stationId) async {
    await AndroidBackgroundService.removeMonitoredStation(stationId);
    await AndroidBackgroundService.cancelNotification(key: 'station:$stationId');
    stations.remove(stationId);
    stationPreviews.remove(stationId);
    stationLastUpdated.remove(stationId);
    notifyListeners();
  }

  Future<void> removeTrip(String tripId) async {
    await AndroidBackgroundService.removeMonitoredTrip(tripId);
    await AndroidBackgroundService.cancelNotification(key: 'train:$tripId');
    trips.removeWhere((t) => t.tripId == tripId);
    tripPreviews.remove(tripId);
    tripLastUpdated.remove(tripId);
    notifyListeners();
  }

  Future<void> refreshTrip(String tripId) async {
    // Try to pass country from the monitored trip metadata when available
    final idx = trips.indexWhere((t) => t.tripId == tripId);
    String? country;
    if (idx != -1 && trips[idx].metaJson != null) {
      try {
        final meta = jsonDecode(trips[idx].metaJson!);
        if (meta is Map && meta.containsKey('country')) country = meta['country']?.toString();
      } catch (e) {
        // ignore
      }
    }

    final payload = await AndroidBackgroundService.forceFetchTrip(tripId, country: country);
    if (idx != -1) {
      trips[idx].rawPayload = payload;
      tripPreviews[tripId] = _buildTripPreviewFromPayload(payload);
      tripLastUpdated[tripId] = _extractLastUpdatedFromPayload(payload) ?? _formatNow();
      tripTitles[tripId] = _extractTitleFromPayload(payload) ?? tripId;
      notifyListeners();
    }
  }

  /// Check arrival time for [tripId] and [destinationStop]. If the effective
  /// arrival time (scheduled + delay) is within [preNoticeMinutes] from now,
  /// send an immediate proximity notification on the dedicated channel.
  Future<void> triggerProximityCheckForTrip(String tripId, String destinationStop, int preNoticeMinutes, [String? startingStop]) async {
    try {
      // try to fetch latest trip payload (prefer country info when available)
      final idx = trips.indexWhere((t) => t.tripId == tripId);
      String? country;
      if (idx != -1 && trips[idx].metaJson != null) {
        try {
          final meta = jsonDecode(trips[idx].metaJson!);
          if (meta is Map && meta.containsKey('country')) country = meta['country']?.toString();
        } catch (e) {}
      }

      final payload = await AndroidBackgroundService.forceFetchTrip(tripId, country: country);
      if (payload == null || payload.isEmpty) return;

      final root = jsonDecode(payload);
      final json = root is Map && root.containsKey('data') ? root['data'] : root;
      final stops = json['stops'] as List<dynamic>?;
      if (stops == null || stops.isEmpty) return;

      // Find destination stop record
      Map<String, dynamic>? destRec;
      for (final s in stops) {
        final name = (s['stationName'] ?? s['name'] ?? s['stop'] ?? '').toString().trim().toLowerCase();
        if (name.isEmpty) continue;
        if (name == destinationStop.trim().toLowerCase()) {
          destRec = Map<String, dynamic>.from(s);
          break;
        }
      }
      if (destRec == null) return;
      final dr = destRec; // promote to non-null local for analyzer and closures

      // Prefer explicit estimated/expected/actual arrival timestamps when available
      DateTime? tryParseAnyTime(dynamic v) {
        if (v == null) return null;
        try {
          return DateTime.parse(v.toString());
        } catch (e) {
          // try numeric epoch (seconds or milliseconds)
          try {
            final n = num.tryParse(v.toString());
            if (n != null) {
              var ms = n.toInt();
              if (v.toString().length <= 10) ms = (n * 1000).round();
              return DateTime.fromMillisecondsSinceEpoch(ms);
            }
          } catch (e2) {}
        }
        return null;
      }

      // Helper to normalize raw delay values (convert seconds -> minutes when value looks like seconds)
      int normalizeDelay(dynamic raw, String? country) {
        if (raw == null) return 0;
        int v = 0;
        try { v = int.parse(raw.toString()); } catch (e) { return 0; }
        // If it looks like seconds (large absolute value), convert to minutes (floor)
        if (v.abs() > 1000) return v ~/ 60;
        // For DE provider, some delays are expressed as seconds; if value > 60 assume seconds
        if (country == 'de' && v.abs() > 60) return v ~/ 60;
        return v;
      }

      // Prefer explicit estimated/expected/actual arrival timestamps when available
      DateTime? effective;
      final estimateKeys = ['expectedArrival','estimatedArrival','actualArrival','expectedTime','estimatedDeparture','expectedDeparture','actualDeparture'];
      final fallbackKeys = ['arrival','arrivalTime','time','scheduledArrival','scheduledDeparture','departureTime'];

      // Declare variables before use
      var usedArrivalDelayFallback = false;
      int fallbackDelayMin = 0;

      // Try estimate keys first (these represent explicit estimated times)
      for (final k in estimateKeys) {
        if (dr.containsKey(k)) {
          final dt = tryParseAnyTime(dr[k]);
          if (dt != null) {
            // If there's a scheduled counterpart, derive delay in whole minutes (floor) and compute effective as scheduled + delay
            DateTime? schedCandidate;
            if (dr.containsKey('scheduledArrival')) schedCandidate = tryParseAnyTime(dr['scheduledArrival']);
            else if (dr.containsKey('scheduledDeparture')) schedCandidate = tryParseAnyTime(dr['scheduledDeparture']);
            if (schedCandidate != null) {
              final calcDelay = dt.toUtc().difference(schedCandidate.toUtc()).inMinutes; // floor minutes
              effective = schedCandidate.add(Duration(minutes: calcDelay));
              usedArrivalDelayFallback = calcDelay != 0;
            } else {
              effective = dt;
            }
            break;
          }
        }
      }

      // If no explicit estimate, try common arrival fields (may be scheduled)
      if (effective == null) {
        for (final k in fallbackKeys) {
          if (dr.containsKey(k)) {
            final dt = tryParseAnyTime(dr[k]);
            if (dt != null) { effective = dt; break; }
          }
        }
      }

      // If still no explicit time, fallback to scheduled + delay heuristics
      usedArrivalDelayFallback = false;
      fallbackDelayMin = 0;
      DateTime? schedForDelay;
      if (effective == null) {
        DateTime? sched;
        if (dr.containsKey('scheduledArrival')) { sched = tryParseAnyTime(dr['scheduledArrival']); schedForDelay = sched; }
        if (sched == null && dr.containsKey('arrival')) { sched = tryParseAnyTime(dr['arrival']); schedForDelay = schedForDelay ?? sched; }
        if (sched == null && dr.containsKey('time')) { sched = tryParseAnyTime(dr['time']); schedForDelay = schedForDelay ?? sched; }

        int delayMin = 0;
        // Accept multiple delay field names, and handle seconds values > 1000
        if (dr.containsKey('arrivalDelay')) {
          try { delayMin = int.parse(dr['arrivalDelay'].toString()); } catch (e) {}
        } else if (dr.containsKey('departureDelay')) {
          try { delayMin = int.parse(dr['departureDelay'].toString()); } catch (e) {}
        } else if (dr.containsKey('delayMinutes')) {
          try { delayMin = int.parse(dr['delayMinutes'].toString()); } catch (e) {}
        } else if (dr.containsKey('delay')) {
          try { delayMin = int.parse(dr['delay'].toString()); } catch (e) {}
        } else if (dr.containsKey('delaySeconds')) {
          try {
            var v = int.parse(dr['delaySeconds'].toString());
            // convert seconds to minutes (floor)
            delayMin = v ~/ 60;
          } catch (e) {}
        }

        if (sched == null) return;
        effective = sched.add(Duration(minutes: delayMin));
        usedArrivalDelayFallback = delayMin != 0;
        fallbackDelayMin = delayMin;
      }

      final now = DateTime.now().toUtc();
      final diff = effective.toUtc().difference(now);
      // Use integer division (floor) so delay minutes don't get an extra +1 and remain consistent
      final secs = diff.inSeconds;
      final mins = (secs <= 0) ? 0 : (secs ~/ 60); // floor division for positives

      // Consider it an estimated arrival only if we used one of the estimateKeys or arrivalDelay fallback
      final usedEstimated = estimateKeys.any((k) => dr.containsKey(k)) || usedArrivalDelayFallback;

      // Compute a delay value to show in notification (prefer explicit train-level delay, then destination fields, else propagate from earlier stops or derive from scheduled)
      int computedDelay = 0;
      // Prefer trip-level delay if present (so notifications and UI match TrainDeparture.delayMinutes)
      try {
        final tripDelay = json['delayMinutes'] ?? json['delay'];
        if (tripDelay != null) {
          computedDelay = normalizeDelay(tripDelay, country);
        }
      } catch (e) {}

      // If we derived a delay by comparing estimated vs scheduled on the destination, prefer that value
      if (computedDelay == 0 && usedArrivalDelayFallback) {
        computedDelay = normalizeDelay(fallbackDelayMin, country);
      }

      // try explicit fields first on the destination record
      for (final k in ['arrivalDelay','departureDelay','delayMinutes','delay']) {
        if (dr.containsKey(k)) {
          try { computedDelay = normalizeDelay(dr[k], country); break; } catch (e) {}
        }
      }
      if (computedDelay == 0 && dr.containsKey('delaySeconds')) {
        try { computedDelay = normalizeDelay(int.parse(dr['delaySeconds'].toString()), country); } catch (e) {}
      }

      // If still zero, try to propagate a delay observed earlier in the trip (scan stops up to the destination)
      if (computedDelay == 0 && stops.isNotEmpty) {
        // find destination index by stationId or name
        String? destId = dr['stationId']?.toString();
        int destIdx = -1;
        if (destId != null && destId.isNotEmpty) {
          destIdx = stops.indexWhere((s) => (s['stationId'] ?? '').toString() == destId);
        }
        if (destIdx == -1) {
          destIdx = stops.indexWhere((s) {
            final name = (s['stationName'] ?? s['name'] ?? s['stop'] ?? '').toString().trim().toLowerCase();
            return name == destinationStop.trim().toLowerCase();
          });
        }
        if (destIdx != -1) {
          for (int i = 0; i <= destIdx; i++) {
            final s = stops[i];
            if (s == null) continue;
            int val = 0;
            try {
              if (s.containsKey('departureDelay')) val = normalizeDelay(s['departureDelay'], country);
            } catch (e) {}
            if (val == 0) {
              try { if (s.containsKey('arrivalDelay')) val = normalizeDelay(s['arrivalDelay'], country); } catch (e) {}
            }
            // if still zero, try estimated vs scheduled on that stop
            if (val == 0) {
              try {
                DateTime? est;
                DateTime? sched;
                if (s.containsKey('estimatedArrival')) est = tryParseAnyTime(s['estimatedArrival']);
                else if (s.containsKey('estimatedDeparture')) est = tryParseAnyTime(s['estimatedDeparture']);
                if (s.containsKey('scheduledArrival')) sched = tryParseAnyTime(s['scheduledArrival']);
                else if (s.containsKey('scheduledDeparture')) sched = tryParseAnyTime(s['scheduledDeparture']);
                if (est != null && sched != null) val = est.difference(sched).inMinutes;
              } catch (e) {}
            }
            if (val != 0) { 
              computedDelay = val; break; 
            }
          }
        }
      }

      // if still unknown and we have a scheduled time, derive it relative to scheduled arrival
      if (computedDelay == 0 && schedForDelay != null) {
        computedDelay = effective.difference(schedForDelay).inMinutes;
      }

      if (mins <= preNoticeMinutes && mins >= 0) {
        // Build a friendly title
        final title = _extractTitleFromPayload(payload) ?? 'Treno';
        final at = '${effective.toLocal().hour.toString().padLeft(2, '0')}:${effective.toLocal().minute.toString().padLeft(2, '0')}';
        final label = 'Arrivo calcolato';

        String delayPart;
        if (computedDelay > 0) delayPart = '• Ritardo: +${computedDelay} min';
        else if (computedDelay < 0) delayPart = '• Anticipo: ${-computedDelay} min';
        else delayPart = '• In orario';

        // Build enriched notification body using same heuristics as TrainDetailsSheet
        // Build stopStates similar to UI
        final stopStates = <Map<String, dynamic>>[];
        for (int i = 0; i < stops.length; i++) {
          final s = Map<String, dynamic>.from(stops[i]);
          DateTime? arrUtc;
          DateTime? depUtc;
          if (s.containsKey('estimatedArrival')) arrUtc = tryParseAnyTime(s['estimatedArrival'])?.toUtc();
          else if (s.containsKey('scheduledArrival')) arrUtc = tryParseAnyTime(s['scheduledArrival'])?.toUtc()?.add(Duration(minutes: computedDelay));
          else if (s.containsKey('arrival')) arrUtc = tryParseAnyTime(s['arrival'])?.toUtc()?.add(Duration(minutes: computedDelay));

          if (s.containsKey('estimatedDeparture')) depUtc = tryParseAnyTime(s['estimatedDeparture'])?.toUtc();
          else if (s.containsKey('scheduledDeparture')) depUtc = tryParseAnyTime(s['scheduledDeparture'])?.toUtc()?.add(Duration(minutes: computedDelay));
          else if (s.containsKey('departure')) depUtc = tryParseAnyTime(s['departure'])?.toUtc()?.add(Duration(minutes: computedDelay));

          stopStates.add({'index': i, 'stop': s, 'arrUtc': arrUtc, 'depUtc': depUtc, 'cancelled': s['cancelled'] == true});
        }

        // Find starting stop index if provided (reference point for stop counting)
        int startingIndex = -1;
        if (startingStop != null && startingStop.isNotEmpty && stopStates.isNotEmpty) {
          startingIndex = stopStates.indexWhere((ss) {
            final name = (ss['stop']['stationName'] ?? ss['stop']['name'] ?? ss['stop']['stop'] ?? '').toString().trim().toLowerCase();
            return name == startingStop.trim().toLowerCase();
          });
          if (startingIndex >= 0) {
            // ignore: avoid_print
            print('triggerProximityCheckForTrip: Found startingStop="$startingStop" at index $startingIndex');
          }
        }

        // Determine nextIndex and lastPassed akin to UI
        // Start scanning from startingIndex (or 0)
        int nextIndex = -1; String nextStop = ''; DateTime? nextArrival; DateTime? nextDeparture; String lastPassed = ''; bool isAtStation = false;
        final scanStart = startingIndex >= 0 ? startingIndex : 0;
        
        // 1) nearest future arrival
        DateTime? bestArr; int bestIdx = -1;
        for (int i = scanStart; i < stopStates.length; i++) {
          final ss = stopStates[i];
          if (ss['cancelled'] == true) continue;
          final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
          if (arrUtc != null && arrUtc.isAfter(now)) {
            final diffSecs = arrUtc.difference(now).inSeconds;
            if (bestArr == null || diffSecs < bestArr.difference(now).inSeconds) {
              bestArr = arrUtc; bestIdx = ss['index'] as int;
            }
          }
        }
        if (bestIdx != -1) {
          final s = stopStates[bestIdx];
          nextIndex = bestIdx;
          nextStop = (s['stop']['stationName'] ?? s['stop']['name'] ?? s['stop']['stop'] ?? '').toString();
          nextArrival = s['arrUtc'] as DateTime?;
          nextDeparture = s['depUtc'] as DateTime?;
        }

        // fallback last passed logic
        if (nextIndex == -1 && stopStates.isNotEmpty) {
          int lastIdx = -1;
          for (var ss in stopStates) {
            final DateTime? depUtc = ss['depUtc'] as DateTime?;
            final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
            if ((depUtc != null && depUtc.isBefore(now)) || (arrUtc != null && arrUtc.isBefore(now))) lastIdx = ss['index'] as int;
          }
          for (int i = lastIdx + 1; i < stopStates.length; i++) {
            if (stopStates[i]['cancelled'] == true) continue;
            nextIndex = i;
            nextStop = (stopStates[i]['stop']['stationName'] ?? stopStates[i]['stop']['name'] ?? stopStates[i]['stop']['stop'] ?? '').toString();
            nextArrival = stopStates[i]['arrUtc'] as DateTime?;
            nextDeparture = stopStates[i]['depUtc'] as DateTime?;
            break;
          }
          if (nextIndex == -1) {
            for (var ss in stopStates) {
              if (ss['cancelled'] == true) continue;
              nextIndex = ss['index'] as int;
              nextStop = (ss['stop']['stationName'] ?? ss['stop']['name'] ?? ss['stop']['stop'] ?? '').toString();
              nextArrival = ss['arrUtc'] as DateTime?;
              nextDeparture = ss['depUtc'] as DateTime?;
              break;
            }
          }
        }

        // Compute lastPassed if empty
        if (lastPassed.isEmpty) {
          int lastIdx = -1;
          for (var ss in stopStates) {
            final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
            final DateTime? depUtc = ss['depUtc'] as DateTime?;
            if ((depUtc != null && depUtc.isBefore(now)) || (arrUtc != null && arrUtc.isBefore(now))) lastIdx = ss['index'] as int;
          }
          if (lastIdx >= 0) lastPassed = (stopStates[lastIdx]['stop']['stationName'] ?? stopStates[lastIdx]['stop']['name'] ?? stopStates[lastIdx]['stop']['stop'] ?? '').toString();
        }

        // isAtStation detection
        for (var ss in stopStates) {
          final DateTime? arrUtc = ss['arrUtc'] as DateTime?;
          final DateTime? depUtc = ss['depUtc'] as DateTime?;
          if (arrUtc != null && depUtc != null && !now.isBefore(arrUtc) && !now.isAfter(depUtc)) {
            isAtStation = true;
            lastPassed = (ss['stop']['stationName'] ?? ss['stop']['name'] ?? ss['stop']['stop'] ?? '').toString();
            break;
          }
        }

        // Compute remaining stops relative to destinationStop
        // Count from nextIndex (or startingIndex+1 if startingStop is set)
        int remaining = 0;
        final destIdx = stops.indexWhere((s) => ((s['stationName'] ?? s['name'] ?? s['stop'] ?? '').toString().trim().toLowerCase() == destinationStop.trim().toLowerCase()));
        final countStartIndex = startingIndex >= 0 ? startingIndex : (nextIndex >= 0 ? nextIndex : 0);
        
        if (destIdx != -1 && nextIndex != -1) {
          final int start = nextIndex < destIdx ? nextIndex : nextIndex;
          int count = 0;
          for (int i = start + 1; i <= destIdx; i++) if (!(stops[i]['cancelled'] == true)) count++;
          remaining = count;
        } else if (nextIndex != -1) {
          int count = 0;
          for (int i = nextIndex + 1; i < stops.length; i++) if (!(stops[i]['cancelled'] == true)) count++;
          remaining = count;
        }

        // Platform for destination (if available)
        String destPlatform = '';
        try { destPlatform = (dr['platform'] ?? dr['plannedPlatform'] ?? '').toString(); } catch (e) {}
        final platformPart = destPlatform.isNotEmpty ? ' • Binario: $destPlatform' : '';

        final destArrStr = _formatTimeToHHmm(dr['scheduledArrival'] ?? dr['arrival'] ?? dr['time']) ?? at;
        final calcAt = at;

        String delayLine;
        if (computedDelay > 0) delayLine = '• Ritardo: +${computedDelay} min';
        else if (computedDelay < 0) delayLine = '• Anticipo: ${-computedDelay} min';
        else delayLine = '• In orario';

        final stateLine = 'Stato attuale: ${lastPassed.isNotEmpty ? lastPassed : 'In transito'}';
        final remainingLine = 'Fermate rimanenti: $remaining';

        // If called for a specific destination, add an explicit target line to the notification
        String targetLine = '';
        if (destinationStop.trim().isNotEmpty) {
          targetLine = '\nTarget destinazione: ${destinationStop}';
        }

        final body = '⚠️ Prepara i bagagli! $label: $destinationStop$platformPart • In arrivo alle $destArrStr. Arrivo calcolato: $calcAt $delayLine\\n$stateLine\\n$remainingLine$targetLine';

        if (kDebugMode) {
          final observed = <String, dynamic>{};
          for (final k in [...estimateKeys, ...fallbackKeys, 'arrivalDelay','departureDelay','delay','delayMinutes','delaySeconds']) {
            if (dr.containsKey(k)) observed[k] = dr[k];
          }
          print('triggerProximityCheckForTrip: trip=$tripId dest=$destinationStop now=${now.toIso8601String()} effective=${effective.toIso8601String()} usedEstimated=$usedEstimated secs=$secs mins=$mins computedDelay=$computedDelay nextStop=$nextStop lastPassed=$lastPassed isAtStation=$isAtStation remaining=$remaining observed=$observed');
        }

        await AndroidBackgroundService.showNotification(channel: NotificationChannels.trainProximity, title: title, body: body, key: 'proximity:train:$tripId:$destinationStop');
      }
    } catch (e) {
      if (kDebugMode) print('Error in triggerProximityCheckForTrip: $e');
    }
  }

  Future<String?> refreshStation(String stationId) async {
    final payload = await AndroidBackgroundService.forceFetchStation(stationId);
    stationPreviews[stationId] = _buildPreviewFromPayload(payload);
    stationLastUpdated[stationId] = _extractLastUpdatedFromPayload(payload) ?? _formatNow();
    notifyListeners();
    return payload;
  }

  String _buildPreviewFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return 'Nessun dato';
    try {
      final json = jsonDecode(payload);
      final departures = json['departures'] as List<dynamic>?;
      if (departures == null || departures.isEmpty) return 'Nessun dato';
      final items = departures.take(3).map((d) {
        final line = d['line'] ?? d['lineCode'] ?? d['route'] ?? '';
        final timeRaw = d['time'] ?? d['scheduledTime'] ?? d['departureTime'] ?? '';
        final time = _formatTimeToHHmm(timeRaw) ?? timeRaw.toString();
        final dest = d['destination'] ?? d['to'] ?? d['headsign'] ?? '';
        return '${line ?? ''} ${time ?? ''}${dest != '' ? ' → $dest' : ''}';
      }).toList();
      return items.join(' • ');
    } catch (e) {
      return 'Errore nel parsing';
    }
  }

  String _buildTripPreviewFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return 'Nessun dato';
    try {
      final root = jsonDecode(payload);
      final json = root is Map && root.containsKey('data') ? root['data'] : root;
      final category = json['category'] ?? json['type'] ?? '';
      final num = json['tripNumber'] ?? json['trainNumber'] ?? json['service'] ?? '';

      // Try to find next stop and platform
      final stops = json['stops'] as List<dynamic>?;
      String nextStop = '';
      String platform = '';
      if (stops != null && stops.isNotEmpty) {
        for (final s in stops) {
          final arr = s['scheduledArrival'] ?? s['arrival'] ?? s['arrivalTime'] ?? s['time'];
          final parsed = _formatTimeToHHmm(arr);
          if (parsed != null) {
            nextStop = s['stationName'] ?? s['name'] ?? s['stop'] ?? '';
            platform = s['platform'] ?? s['plannedPlatform'] ?? '';
            break;
          }
        }
      }

      final titleParts = <String>[];
      if ((category ?? '').isNotEmpty) titleParts.add(category);
      if ((num ?? '').isNotEmpty) titleParts.add(num);
      final title = titleParts.join(' ');
      final stopPart = nextStop.isNotEmpty ? 'Prossima: $nextStop' : '';
      final platformPart = platform.isNotEmpty ? 'Binario: $platform' : '';
      final parts = [title, stopPart, platformPart].where((p) => p.isNotEmpty).toList();
      return parts.join(' • ');
    } catch (e) {
      return 'Errore nel parsing';
    }
  }

  Future<void> cancelNotification(String key) async {
    await AndroidBackgroundService.cancelNotification(key: key);
  }

  String? _extractLastUpdatedFromPayload(String? payload) {
    if (payload == null) return null;
    try {
      final json = jsonDecode(payload);
      final candidates = ['lastUpdate', 'updatedAt', 'timestamp', 'lastFetched', 'time'];
      for (var k in candidates) {
        final v = json[k];
        if (v != null) {
          final t = _formatTimeToHHmm(v);
          if (t != null) return t;
        }
      }

      final departures = json['departures'] as List<dynamic>?;
      if (departures != null && departures.isNotEmpty) {
        for (final d in departures) {
          final timeVal = d['time'] ?? d['departureTime'] ?? d['scheduledTime'];
          final t = _formatTimeToHHmm(timeVal);
          if (t != null) return t;
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String? _extractTitleFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final root = jsonDecode(payload);
      final json = root is Map && root.containsKey('data') ? root['data'] : root;
      final category = json['category'] ?? json['type'] ?? '';
      final num = json['tripNumber'] ?? json['trainNumber'] ?? json['service'] ?? json['id'] ?? '';
      if ((category ?? '').toString().isNotEmpty || (num ?? '').toString().isNotEmpty) {
        final parts = <String>[];
        if ((category ?? '').toString().isNotEmpty) parts.add(category.toString());
        if ((num ?? '').toString().isNotEmpty) parts.add(num.toString());
        return parts.join(' ');
      }
      // As fallback try a friendly title from 'name' or 'title' fields
      final alt = json['name'] ?? json['title'] ?? json['serviceName'] ?? '';
      if (alt != null && alt.toString().isNotEmpty) return alt.toString();
    } catch (e) {
      // ignore
    }
    return null;
  }
  String? _formatTimeToHHmm(dynamic value) {
    if (value == null) return null;
    try {
      if (value is num) {
        var ms = value.toInt();
        if (ms.toString().length <= 10) ms = ms * 1000;
        final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      final s = value.toString();
      final maybeNum = double.tryParse(s);
      if (maybeNum != null) {
        var ms = maybeNum.round();
        if (s.length <= 10) ms = (maybeNum * 1000).round();
        final dt = DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      // ISO format
      final dt = DateTime.parse(s).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }
}

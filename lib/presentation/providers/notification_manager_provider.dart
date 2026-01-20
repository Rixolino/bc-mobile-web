import 'dart:convert';
import 'package:flutter/foundation.dart';
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
        tripLastUpdated[t.tripId] = _extractLastUpdatedFromPayload(payload) ?? _formatNow();
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
        return '${line ?? ''} ${time ?? ''}${dest != null && dest != '' ? ' → $dest' : ''}';
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

import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import '../../data/models/regional_provider_model.dart';
import '../screens/regional_station_details_screen.dart';
import '../../../../presentation/providers/settings_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/api_constants.dart';
import '../../../../core/design_system.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/services/train_presence_service.dart';
import 'dart:convert';

/// Parse i formati ora delle API regionali (Trenord/FAL):
/// - ISO 8601 ("2026-09-16T16:05:00.000Z")
/// - "HH:mm" ("16:01", riferito a oggi)
/// - null / stringhe vuote
DateTime? _parseRegionalTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  final s = raw.toString().trim();
  if (s.isEmpty || s == 'null' || s == '-') return null;
  // ISO 8601
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  // "HH:mm" o "HH:mm:ss" -> oggi
  final hm = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(s);
  if (hm != null) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(hm.group(1)!),
      int.parse(hm.group(2)!),
      hm.group(3) != null ? int.parse(hm.group(3)!) : 0,
    );
  }
  return null;
}

/// Equivalente di _estimateStopTimesGlobal dell'originale ma su Map.
/// Risolve arrivo/partenza effettivi: stimati prima, poi programmati + ritardo.
/// Se uno dei due manca lo sintetizza dall'altro (+/- 1 minuto).
Map<String, DateTime?> _estimateRegionalStopTimes(
    Map<String, dynamic> s, int trainDelay) {
  final schedArr =
      _parseRegionalTime(s['scheduledArrival'] ?? s['scheduledTime']);
  final schedDep =
      _parseRegionalTime(s['scheduledDeparture'] ?? s['scheduledTime']);
  final estArr = _parseRegionalTime(s['estimatedArrival']);
  final estDep = _parseRegionalTime(s['estimatedDeparture']);

  DateTime? arr = estArr?.toUtc() ??
      (schedArr != null
          ? schedArr.toUtc().add(Duration(minutes: trainDelay))
          : null);
  DateTime? dep = estDep?.toUtc() ??
      (schedDep != null
          ? schedDep.toUtc().add(Duration(minutes: trainDelay))
          : null);

  if (arr == null && dep != null)
    arr = dep.subtract(const Duration(minutes: 1));
  if (dep == null && arr != null) dep = arr.add(const Duration(minutes: 1));

  return {'arr': arr, 'dep': dep};
}

/// Progresso 0..1 lungo la tratta (stessa patch del nazionale):
/// senza fermate o senza alcun orario resta 0 (mai "completato" per
/// mancanza dati); con 1 sola fermata scatta 0/1 (niente divisione per zero).
double _calcRegionalRouteProgress(
    List<Map<String, dynamic>> stops, DateTime nowUtc, int trainDelay) {
  if (stops.isEmpty) return 0.0;
  DateTime? stopArr(int i) =>
      _estimateRegionalStopTimes(stops[i], trainDelay)['arr'];
  DateTime? stopDep(int i) =>
      _estimateRegionalStopTimes(stops[i], trainDelay)['dep'];
  if (stops.length == 1) {
    final arr = stopArr(0) ?? stopDep(0);
    if (arr == null) return 0.0;
    return nowUtc.isBefore(arr) ? 0.0 : 1.0;
  }
  int currentIdx = -1;
  var hasAnyTime = false;
  for (int i = 0; i < stops.length; i++) {
    final arrUtc = stopArr(i);
    if (arrUtc == null) continue;
    hasAnyTime = true;
    if (nowUtc.isBefore(arrUtc)) {
      currentIdx = i;
      break;
    }
  }
  if (!hasAnyTime) return 0.0;
  double progress;
  if (currentIdx == -1) {
    progress = 1.0;
  } else if (currentIdx == 0) {
    progress = 0.0;
  } else {
    final prevDep = stopDep(currentIdx - 1);
    final nextArr = stopArr(currentIdx);
    if (prevDep != null && nextArr != null) {
      final totalDuration = nextArr.difference(prevDep).inSeconds;
      final elapsed = nowUtc.difference(prevDep).inSeconds;
      final segmentProgress = totalDuration > 0
          ? (elapsed / totalDuration).clamp(0.0, 1.0)
          : 0.0;
      progress = ((currentIdx - 1) + segmentProgress) / (stops.length - 1);
    } else {
      progress = currentIdx / (stops.length - 1);
    }
  }
  return progress.clamp(0.0, 1.0);
}

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

/// Come _asInt ma preserva null (ritardo per-fermata sconosciuto vs 0 misurato).
int? _asIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  return int.tryParse(v.toString());
}

String _asStr(dynamic v) {
  if (v == null) return '';
  final s = v.toString().trim();
  if (s == 'null' || s == '-') return '';
  return s;
}

/// Copia di TrainDetailsSheet adattata alle API regionali (Trenord/FAL).
/// Stessa UI dell'originale, ma i dati sono Map<String, dynamic>
/// invece di TrainDeparture/TrainStop.
class RegionalTrainDetailsSheet extends StatefulWidget {
  final RegionalProvider provider;
  final String tripId;
  final String? trainNumber;
  final bool isArrivalMode;
  final ScrollController? scrollController;
  // Tabellone da cui è stato aperto il treno: la sheet si affida a lui
  // per il ritardo (match esatto, niente treni sbagliati).
  final String? originStationId;
  final Map<String, dynamic>? originBoardEntry;

  const RegionalTrainDetailsSheet({
    super.key,
    required this.provider,
    required this.tripId,
    this.trainNumber,
    this.isArrivalMode = false,
    this.scrollController,
    this.originStationId,
    this.originBoardEntry,
  });

  @override
  State<RegionalTrainDetailsSheet> createState() =>
      _RegionalTrainDetailsSheetState();
}

class _RegionalTrainDetailsSheetState extends State<RegionalTrainDetailsSheet> {
  Timer? _autoRefreshTimer;
  Timer? _progressTimer;
  Timer? _fetchTimeoutTimer;
  late SettingsProvider _settingsProvider;

  Map<String, dynamic>? _tripData;
  bool _isLoading = true;
  bool _fetchAttempted = false;
  bool _hasLoadedData = false;
  String? _error;
  bool _isSharing = false;

  // Logo e numero congelati all'apertura: i refresh per i ritardi
  // non devono mai alterarli.
  String? _frozenCategory;
  String? _frozenNumber;
  // Fermate per cui è già stato emesso l'avviso "siamo in arrivo"
  // (una sola volta per fermata, per apertura sheet).
  final Set<String> _announcedArrivals = {};
  // Ritardo da bacheca memorizzato: una volta trovato (tabellone di
  // apertura o successive), resta per tutta la sessione. Niente più
  // oscillazioni tra trip e bacheche a ogni tick.
  int? _memorizedDelay;
  // Isteresi adozione ritardo (come il nazionale): un valore diverso da
  // quello mostrato viene memorizzato solo dopo 2 conferme consecutive.
  int? _boardDelayCandidate;
  int _boardDelayHits = 0;

  // Presenza live: quanti utenti stanno guardando questo treno
  Timer? _presenceTimer;
  int? _viewersCount;
  String? _presenceKey;
  // Ultime fermate buone inviate all'API: il primo utente che apre il treno
  // le pubblica mentre la sheet è aperta, e non si perdono più.
  List<Map<String, dynamic>>? _lastPresenceStopsRaw;

  final ScrollController _scrollController = ScrollController();

  String get _tripId => widget.tripId;
  String get _baseUrl => widget.provider.fullApiUrl;

  @override
  void initState() {
    super.initState();
    _settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    _frozenCategory = _category;
    _frozenNumber = _trainNumber;
    _memorizedDelay = _asIntOrNull(widget.originBoardEntry?['delay'] ??
        widget.originBoardEntry?['delayMinutes']);
    _startAutoRefresh();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
      _checkArrivalAlert();
    });
    // Annuncio vocale all'apertura del dettaglio treno
    _speakTrainInfo();
    _fetchTripDetails();
    _refreshOriginBoardDelay();
    // Presenza live: heartbeat mentre la sheet è aperta
    _startPresence();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _progressTimer?.cancel();
    _fetchTimeoutTimer?.cancel();
    _presenceTimer?.cancel();
    final presenceKey = _presenceKey;
    if (presenceKey != null && presenceKey.isNotEmpty) {
      TrainPresenceService().leave(presenceKey);
      // Doppio leave ritardato: un heartbeat già in volo potrebbe
      // rientrare dopo il leave e resuscitare il fantasma.
      Future.delayed(const Duration(seconds: 3), () {
        TrainPresenceService().leave(presenceKey);
      });
      Future.delayed(const Duration(seconds: 10), () {
        TrainPresenceService().leave(presenceKey);
      });
    }
    _scrollController.dispose();
    super.dispose();
  }

  /// Avvia l'heartbeat di presenza live (ogni 5s, TTL backend 45s).
  void _startPresence() {
    final trip = _current;
    final scheduled = _parseTime(trip['scheduledTime'])?.toIso8601String() ?? '';
    final num =
        (trip['tripNumber'] ?? trip['trainNumber'] ?? widget.trainNumber ?? '')
            .toString();
    final cat = (trip['category'] ?? '').toString();
    _presenceKey = widget.tripId.isNotEmpty
        ? widget.tripId
        : '$cat|$num|$scheduled';
    _presenceTick();
    _presenceTimer?.cancel();
    _presenceTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _presenceTick());
  }

  Future<void> _presenceTick() async {
    final key = _presenceKey;
    if (!mounted || key == null || key.isEmpty) {
      print('[Presence] regional tick skip: mounted=$mounted key=$key');
      return;
    }
    print('[Presence] regional tick key=$key');
    final trip = _current;
    // Migliori fermate da tutte le fonti + ricordo dell'ultimo buono.
    // Scarta quelle con nome spazzatura (mai inviare 'N/A' all'API).
    final rawStops = trip['stops'];
    if (rawStops is List && rawStops.isNotEmpty) {
      final cleaned = List<Map<String, dynamic>>.from(rawStops
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((s) => !_isJunkPresenceStr(
              (s['stationName'] ?? s['station'] ?? s['name'])?.toString())));
      if (cleaned.isNotEmpty) {
        _lastPresenceStopsRaw = cleaned;
        print(
            '[Presence] fermate pubblicate: ${_lastPresenceStopsRaw!.length}');
      }
    }
    final effOrigin = _getEffectiveOrigin(trip);
    final effDestination = _getEffectiveDestination(trip);
    final count = await TrainPresenceService().heartbeat(
      trainKey: key,
      screen: 'regional',
      train: {
        'category': trip['category']?.toString(),
        'trainNumber':
            (trip['tripNumber'] ?? trip['trainNumber'] ?? '').toString(),
        'origin': _isJunkPresenceStr(effOrigin) ? null : effOrigin,
        'destination':
            _isJunkPresenceStr(effDestination) ? null : effDestination,
        'scheduledTime':
            _parseTime(trip['scheduledTime'])?.toIso8601String(),
        'estimatedTime':
            _parseTime(trip['estimatedTime'])?.toIso8601String(),
        'delayMinutes': _asInt(trip['delay'] ?? trip['delayMinutes']),
        'platform': (trip['platform'] ?? '').toString(),
        'operator': trip['operator']?.toString(),
        'provider': widget.provider.name,
        'isArrival': widget.isArrivalMode,
        // Dati completi per la sezione "più visualizzati": tutte le
        // fermate così il dettaglio è completo come la vista normale.
        'tripId': widget.tripId.isNotEmpty ? widget.tripId : null,
        'stops': _lastPresenceStopsRaw ?? trip['stops'],
      },
    );
    print('[Presence] regional viewers=$count (was $_viewersCount)');
    if (!mounted || count == null || count == _viewersCount) return;
    setState(() => _viewersCount = count);
  }

  Future<void> _speakTrainInfo({bool force = false}) async {
    if (!_settingsProvider.ttsAnnouncementsOn) return;
    
    final tts = TtsService();
    final langCode = _settingsProvider.appLocale?.languageCode ?? 'it';
    tts.setLanguage(langCode);
    
    // Imposta voce per lingua (voce apertura treno se scelta, altrimenti normale)
    final voices = TtsService.getVoicesForLanguage(langCode);
    final openingName = _settingsProvider.ttsOpeningVoiceForLang(langCode);
    final wantedName = openingName ?? _settingsProvider.ttsVoiceForLang(langCode);
    final selected = voices.firstWhere(
      (v) => v.name == wantedName,
      orElse: () => voices.isNotEmpty ? voices.first : const OddcastVoice(name: 'Roberto', id: 2, engine: 3, gender: 'M'),
    );
    tts.setSelectedVoice(selected);
    
    final trip = _current;
    final trainNumberStr = (trip['tripNumber'] ?? trip['trainNumber'] ?? '').toString();
    final categoryStr = trip['category']?.toString();
    final operatorStr = trip['operator']?.toString();
    final isArrivals = widget.isArrivalMode;
    final stops = trip['stops'] as List? ?? [];

    String? origin;
    String? destination;
    if (isArrivals) {
      origin = _getEffectiveOrigin(trip);
      destination = null;
    } else {
      origin = null;
      destination = _getEffectiveDestination(trip);
    }

    final scheduledTime = _parseTime(trip['scheduledTime']);
    final estimatedTime = _parseTime(trip['estimatedTime']);
    final platform = (trip['platform'] ?? '').toString();
    final delayMin = _asInt(trip['delay'] ?? trip['delayMinutes']);

    final announcement = TtsService.buildOnboardAnnouncement(
      category: categoryStr,
      trainNumber: trainNumberStr,
      isArrival: isArrivals,
      origin: origin,
      destination: destination,
      scheduledTime: scheduledTime,
      estimatedTime: estimatedTime,
      delayMinutes: delayMin,
      platform: platform.isNotEmpty ? platform : null,
      langCode: langCode,
      operator: operatorStr,
    );

    String text = announcement;
    if (stops.isNotEmpty) {
      final now = DateTime.now();
      Map<String, dynamic>? nextStop;

      for (var stop in stops) {
        final depTime = _parseTime(stop['departure'] ?? stop['scheduledDeparture']);
        if (depTime != null && depTime.isAfter(now)) {
          nextStop = stop;
          break;
        }
        final arrTime = _parseTime(stop['arrival'] ?? stop['scheduledArrival']);
        if (arrTime != null && arrTime.isAfter(now)) {
          nextStop = stop;
          break;
        }
      }

      if (nextStop != null) {
        final stopName = (nextStop['stationName'] ?? nextStop['name'] ?? '').toString();
        final depTime = _parseTime(nextStop['departure'] ?? nextStop['scheduledDeparture']);
        final arrTime = _parseTime(nextStop['arrival'] ?? nextStop['scheduledArrival']);
        final time = depTime ?? arrTime;

        if (stopName.isNotEmpty && time != null) {
          text = TtsService.appendNextStop(
            baseText: text,
            stopName: stopName,
            time: time,
            langCode: langCode,
          );
        }

        // Elenco delle fermate successive (esclusa la prossima, già detta).
        final following = <String>[];
        var seenNext = false;
        for (var stop in stops) {
          if (identical(stop, nextStop)) {
            seenNext = true;
            continue;
          }
          if (!seenNext) continue;
          if (stop is! Map) continue;
          final t = _parseTime(stop['estimatedDeparture'] ??
              stop['departure'] ??
              stop['scheduledDeparture'] ??
              stop['estimatedArrival'] ??
              stop['arrival'] ??
              stop['scheduledArrival']);
          if (t == null || !t.isAfter(now)) continue;
          if (stop['cancelled'] == true || stop['canceled'] == true) continue;
          final name = (stop['stationName'] ?? stop['name'] ?? '').toString().trim();
          if (name.isEmpty) continue;
          if (following.contains(name)) continue;
          following.add(name);
          if (following.length >= 12) break;
        }
        if (following.isNotEmpty) {
          text = TtsService.appendCallingAt(
            baseText: text,
            stopNames: following,
            langCode: langCode,
          );
        }
      }
    }
    
    if (text.isNotEmpty) {
      final trainKey = '$categoryStr|$trainNumberStr|${_parseTime(trip['scheduledTime'])?.toIso8601String() ?? ''}';
      await tts.speak(text,
          trainKey: trainKey,
          force: force || _settingsProvider.ttsAlwaysAnnounce,
          rate: _settingsProvider.ttsOpeningSpeechRate,
          bullhorn: true);
    }
  }

  /// Avviso "siamo in arrivo a {fermata}" quando mancano <= 5 minuti
  /// all'arrivo effettivo alla prossima fermata. Una volta per fermata.
  Future<void> _checkArrivalAlert() async {
    if (!mounted) return;
    if (!_settingsProvider.ttsAnnouncementsOn) return;

    final trip = _current;
    final stops = trip['stops'] as List? ?? [];
    if (stops.isEmpty) return;
    final now = DateTime.now();
    Map<String, dynamic>? nextStop;
    for (var stop in stops) {
      if (stop is! Map) continue;
      final t = _parseTime(stop['estimatedArrival'] ??
          stop['arrival'] ??
          stop['scheduledArrival']);
      if (t != null && !t.isBefore(now)) {
        nextStop = Map<String, dynamic>.from(stop);
        break;
      }
    }
    if (nextStop == null) return;
    final arrival = _parseTime(nextStop['estimatedArrival'] ??
        nextStop['arrival'] ??
        nextStop['scheduledArrival']);
    if (arrival == null) return;
    final name =
        (nextStop['stationName'] ?? nextStop['name'] ?? '').toString().trim();
    if (name.isEmpty) return;
    final diff = arrival.difference(now);
    if (diff.isNegative || diff.inMinutes > 5) return;
    final key = '$name|${arrival.toIso8601String()}';
    if (_announcedArrivals.contains(key)) return;
    _announcedArrivals.add(key);

    final tts = TtsService();
    final langCode = _settingsProvider.appLocale?.languageCode ?? 'it';
    tts.setLanguage(langCode);
    final voices = TtsService.getVoicesForLanguage(langCode);
    final openingName = _settingsProvider.ttsOpeningVoiceForLang(langCode);
    final wantedName = openingName ?? _settingsProvider.ttsVoiceForLang(langCode);
    final selected = voices.firstWhere(
      (v) => v.name == wantedName,
      orElse: () => voices.isNotEmpty ? voices.first : const OddcastVoice(name: 'Roberto', id: 2, engine: 3, gender: 'M'),
    );
    tts.setSelectedVoice(selected);
    final trainNumberStr =
        (trip['tripNumber'] ?? trip['trainNumber'] ?? '').toString();
    final categoryStr = trip['category']?.toString() ?? '';
    final trainKey =
        '$categoryStr|$trainNumberStr|${_parseTime(trip['scheduledTime'])?.toIso8601String() ?? ''}|arr|$key';
    await tts.speak(
      TtsService.buildArrivingNow(stopName: name, langCode: langCode),
      trainKey: trainKey,
      force: true,
      rate: _settingsProvider.ttsOpeningSpeechRate,
      bullhorn: true,
    );
  }

  DateTime? _parseTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Dati (copia di _findDisplayedDeparture / _maybeFetchExternalTripDetails)
  // ---------------------------------------------------------------------------

  /// Dato corrente: dettaglio del trip se caricato, altrimenti fallback
  /// con tripId/trainNumber passati dal tabellone.
  Map<String, dynamic> get _current {
    if (_tripData != null) return _tripData!;
    return {
      'tripNumber': widget.trainNumber ?? '',
      'tripId': _tripId,
      'operator': widget.provider.provider,
      'stops': <Map<String, dynamic>>[],
    };
  }

  List<Map<String, dynamic>> get _stops {
    final raw = _current['stops'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  int get _delay => _asInt(_current['delay'] ?? _current['delayMinutes']);

  String get _trainNumber {
    final t = _current;
    final meta = t['metadata'] is Map
        ? Map<String, dynamic>.from(t['metadata'] as Map)
        : <String, dynamic>{};
    return _asStr(t['tripNumber'] ??
        t['trainNumber'] ??
        meta['numeroTreno'] ??
        meta['codiceTrasporto'] ??
        widget.trainNumber);
  }

  String get _category {
    final t = _current;
    // 1. Campo category diretto.
    var cat = _asStr(t['category']);
    // 2. Primo token di 'line' (es. "RE 2626" -> "RE"), come il nazionale.
    //    Mai il nome provider/operator lungo ("Trenord").
    if (cat.isEmpty) {
      final line = _asStr(t['line']);
      if (line.isNotEmpty) {
        final token = line.trim().split(RegExp(r'\s+')).first;
        final cleaned = token.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
        if (cleaned.isNotEmpty && RegExp(r'[A-Za-z]').hasMatch(cleaned)) {
          cat = RegExp(r'^S\d+$').hasMatch(cleaned)
              ? cleaned
              : cleaned.replaceAll(RegExp(r'\d'), '');
        }
      }
    }
    // 3. Operator solo se sembra una sigla di categoria (es. "FAL", "R").
    if (cat.isEmpty) {
      final op = _asStr(t['operator']).trim();
      if (op.isNotEmpty && op.length <= 4 && op == op.toUpperCase()) {
        cat = op;
      }
    }
    return cat;
  }

  String _cleanStationName(dynamic v) => _asStr(v);

  /// Copia di _getEffectiveOrigin: prima fermata non cancellata, poi origin.
  String _getEffectiveOrigin(Map<String, dynamic> d) {
    final stops = d['stops'];
    if (stops is List && stops.isNotEmpty) {
      final maps = stops
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      try {
        final firstValid = maps.firstWhere((s) => s['cancelled'] != true);
        final n = _asStr(firstValid['stationName']);
        if (n.isNotEmpty) return n;
      } catch (_) {}
      final n = _asStr(maps.first['stationName']);
      if (n.isNotEmpty) return n;
    }
    final origin = d['origin'];
    if (origin is Map) return _cleanStationName(origin['stationName']);
    if (origin != null) return _cleanStationName(origin);
    final meta = d['metadata'];
    if (meta is Map) {
      final n = _cleanStationName(meta['primaStazione']);
      if (n.isNotEmpty) return n;
    }
    return '';
  }

  /// Copia di _getEffectiveDestination: ultima fermata non cancellata, poi destination.
  String _getEffectiveDestination(Map<String, dynamic> d) {
    final stops = d['stops'];
    if (stops is List && stops.isNotEmpty) {
      final maps = stops
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      try {
        final lastValid = maps.lastWhere((s) => s['cancelled'] != true);
        final n = _asStr(lastValid['stationName']);
        if (n.isNotEmpty) return n;
      } catch (_) {}
      final n = _asStr(maps.last['stationName']);
      if (n.isNotEmpty) return n;
    }
    final dest = d['destination'];
    if (dest is Map) return _cleanStationName(dest['stationName']);
    if (dest != null) return _cleanStationName(dest);
    final meta = d['metadata'];
    if (meta is Map) {
      final n = _cleanStationName(meta['ultimaStazione']);
      if (n.isNotEmpty) return n;
    }
    return '';
  }

  Future<void> _fetchTripDetails() async {
    if (_tripId.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _fetchAttempted = true;
          _hasLoadedData = true;
          _error = 'ID treno mancante';
        });
      }
      return;
    }
    if (_fetchAttempted && _isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _fetchAttempted = true;
        _error = null;
      });
    }

    _fetchTimeoutTimer?.cancel();
    _fetchTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedData = true;
        _error = 'Timeout durante il caricamento dei dettagli';
      });
    });

    // Gli endpoint regionali supportano sia /trip/<id> che /trip?tripId=<id>.
    // FAL risponde su /trip/fal-247-149, Trenord su /trip?tripId=12345.
    final candidates = <String>[
      '$_baseUrl/trip/${Uri.encodeComponent(_tripId)}',
      '$_baseUrl/trip?tripId=${Uri.encodeComponent(_tripId)}',
    ];

    try {
      for (final url in candidates) {
        debugPrint('[RegionalTrip] Fetching: $url');
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 12));
        if (resp.statusCode != 200) continue;
        final decoded = json.decode(resp.body);
        if (decoded is! Map<String, dynamic>) continue;
        if (decoded['success'] == false) continue;
        // Formati osservati: {data: {...trip...}} oppure {trip: {...}} oppure {...trip...}
        dynamic trip = decoded['data'] ?? decoded['trip'] ?? decoded;
        if (trip is Map && trip['data'] is Map && trip['stops'] == null) {
          trip = trip['data'];
        }
        if (trip is Map) {
          final tripMap = Map<String, dynamic>.from(trip);
          final freshStops =
              tripMap['stops'] is List ? (tripMap['stops'] as List).length : 0;
          _fetchTimeoutTimer?.cancel();
          if (!mounted) return;
          if (freshStops == 0 && _stops.isNotEmpty) {
            // Il treno e sparito dall'upstream (risposta senza fermate):
            // non sovrascrivere mai i dati gia caricati col vuoto.
            debugPrint(
                '[RegionalTrip] Trip $_tripId senza fermate, tengo i dati esistenti');
            setState(() {
              _isLoading = false;
              _hasLoadedData = true;
              _error = null;
            });
          } else {
            debugPrint('[RegionalTrip] delay fonti: trip=${tripMap['delay']}/${tripMap['delayMinutes']} vs current=${_current['delay']}/${_current['delayMinutes']}');
            setState(() {
              // Il ritardo fresco dal trip endpoint vince su quello vecchio
              // (altrimenti il refresh resterebbe fermo al dato stantio).
              // _refreshDelayFromBoards gira subito dopo e ha l'ultima parola
              // quando trova il treno nei tabelloni in tempo reale.
              _tripData = {
                ...tripMap,
                'delay': tripMap['delay'] ??
                    tripMap['delayMinutes'] ??
                    _current['delay'] ??
                    _current['delayMinutes'],
                'delayMinutes': tripMap['delayMinutes'] ??
                    tripMap['delay'] ??
                    _current['delayMinutes'] ??
                    _current['delay']
              };
              _isLoading = false;
              _hasLoadedData = true;
              _error = null;
            });
          }
          // Pubblica subito le fermate all'API (primo utente che apre
          // il treno), senza aspettare il prossimo tick da 5s.
          if (_lastPresenceStopsRaw == null) {
            _presenceTick();
          }
          // All'apertura: cerca il ritardo fresco nei tabelloni delle
          // fermate (stessa logica del flusso nazionale) e aggiornalo.
          _refreshDelayFromBoards();
          return;
        }
      }
      _fetchTimeoutTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedData = true;
        _error = 'Dettaglio corsa non disponibile';
      });
    } catch (e) {
      _fetchTimeoutTimer?.cancel();
      debugPrint('[RegionalTrip] Error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasLoadedData = true;
        _error = 'Errore di rete: $e';
      });
    }
  }

  /// Copia di TrainProvider.refreshDelayFromUpcomingStations per i regionali:
  /// se il trip endpoint non fornisce un ritardo aggiornato, lo cerca nei
  /// tabelloni (departures/arrivals) delle prossime fermate della tratta.
  ///
  /// 1. Prende le prossime fermate non cancellate con stationId valido (max 3).
  /// 2. Fetcha l'URL di bacheca (arrivi per l'ultima fermata, partenze le altre).
  /// 3. Matcha la corsa per tripId, con fallback su numero treno + destinazione
  ///    (i tripId regionali cambiano da stazione a stazione:
  ///    FAL `fal-<num>-<stationId>`, Trenord `<codice>-<mir>-<epoch>`).
  /// 4. Aggiorna il delay del dettaglio.
  bool _isRefreshingBoards = false;

  /// Normalizza un nome stazione: minuscolo, spazi singoli.
  String _normStation(String s) {
    return s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Stessa destinazione? Maiuscole/minuscole, spazi e abbreviazioni
  /// ("MILANO C.LE" vs "Milano Centrale") non devono bloccare il match.
  /// Se una delle due manca, non si scarta.
  bool _sameDestination(String a, String b) {
    final na = _normStation(a);
    final nb = _normStation(b);
    if (na.isEmpty || nb.isEmpty) return true;
    if (na == nb) return true;
    final fa = na.split(' ').first;
    final fb = nb.split(' ').first;
    if (fa.isNotEmpty && fa == fb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    return false;
  }

  /// Stesso treno con formato numero diverso (Trenord: 2624 vs 102624)?
  /// Confronto esatto + suffisso con max 2 cifre di prefisso in più.
  bool _sameTrainNumber(String a, String b) {
    final na = a.trim();
    final nb = b.trim();
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    final da = na.replaceAll(RegExp(r'\D'), '');
    final db = nb.replaceAll(RegExp(r'\D'), '');
    if (da.isEmpty || db.isEmpty) return false;
    if (da == db) return true;
    if (da.length > db.length &&
        da.endsWith(db) &&
        da.length - db.length <= 2) {
      return true;
    }
    if (db.length > da.length &&
        db.endsWith(da) &&
        db.length - da.length <= 2) {
      return true;
    }
    return false;
  }

  Future<void> _refreshDelayFromBoards({int maxStations = 3}) async {
    // Mutex: niente ricerche sovrapposte (il timer puo scattare prima
    // che la precedente abbia finito).
    if (_isRefreshingBoards) {
      debugPrint('[RegionalDelay] Skip: ricerca gia in corso');
      return;
    }
    final stops = _stops;
    if (stops.isEmpty) {
      debugPrint('[RegionalDelay] Skip: nessuna fermata');
      return;
    }
    _isRefreshingBoards = true;
    try {

    final nowUtc = DateTime.now().toUtc();

    // Indici delle prossime fermate non cancellate (prima non ancora passata)
    final indices = <int>[];
    for (int i = 0; i < stops.length && indices.length < maxStations; i++) {
      final s = stops[i];
      if (s['cancelled'] == true) continue;
      final times = _estimateRegionalStopTimes(s, _delay);
      final depTime = times['dep'];
      if (depTime != null &&
          depTime.isBefore(nowUtc.subtract(const Duration(minutes: 2)))) {
        continue; // già passata
      }
      if (_asStr(s['stationId'] ?? s['id']).isEmpty) continue;
      indices.add(i);
    }
    // Se risultano tutte passate (treno in arrivo), prova comunque le ultime
    if (indices.isEmpty) {
      for (int i = stops.length - 1;
          i >= 0 && indices.length < maxStations;
          i--) {
        if (stops[i]['cancelled'] == true) continue;
        if (_asStr(stops[i]['stationId'] ?? stops[i]['id']).isEmpty) continue;
        indices.insert(0, i);
      }
    }
    if (indices.isEmpty) {
      debugPrint('[RegionalDelay] Skip: nessuna fermata futura con stationId');
      return;
    }

    final tripNumber = _trainNumber;
    final dest = _getEffectiveDestination(_current).trim().toLowerCase();
    // ID stazione della destinazione (i tabelloni a volte riportano l'ID,
    // es. "S09999", invece del nome: anche quello deve matchare).
    String destStationId = '';
    for (int k = stops.length - 1; k >= 0; k--) {
      final s = stops[k];
      if (s is! Map) continue;
      if (s['cancelled'] == true) continue;
      destStationId = _asStr(s['stationId'] ?? s['id']);
      if (destStationId.isNotEmpty) break;
    }
    // Stazioni restanti in base all'indice del treno (dalla prima futura a fine tratta)
    final startIdx = indices.reduce((a, b) => a < b ? a : b);
    final remaining = stops
        .sublist(startIdx)
        .map((s) => _asStr(s['stationName']))
        .where((n) => n.isNotEmpty)
        .toList();
    debugPrint(
        '[RegionalDelay] Treno $tripNumber (delay attuale $_delay): indice $startIdx, stazioni restanti (${remaining.length}): ${remaining.join(' → ')}');

    for (final i in indices) {
      final stop = stops[i];
      final stationId = _asStr(stop['stationId'] ?? stop['id']);
      // Mai la bacheca arrivi della destinazione finale: è una previsione
      // che oscilla (4 -> 1 -> 0 -> 4) e sporca il ritardo generale del trip.
      if (i == stops.length - 1) {
        debugPrint('[RegionalDelay] Salto arrivi destinazione ${_asStr(stop['stationName'])} (solo previsioni)');
        continue;
      }
      final modes = ['departures', 'arrivals'];
      bool matchFound = false;

      for (final mode in modes) {
        List<Map<String, dynamic>> board;
        try {
          final url =
              '$_baseUrl/$mode?stationId=${Uri.encodeComponent(stationId)}';
          debugPrint(
              '[RegionalDelay] Fetch $mode stazione ${_asStr(stop['stationName'])} ($stationId): $url');
          final resp = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 8));
          if (resp.statusCode != 200) {
            debugPrint(
                '[RegionalDelay] HTTP ${resp.statusCode} da $stationId, provo altro modo');
            continue;
          }
          final decoded = json.decode(resp.body);
          final list =
              (decoded is Map ? decoded['data'] as List<dynamic>? : null) ?? [];
          board = list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          debugPrint(
              '[RegionalDelay] Tabellone $stationId ($mode): ${board.length} corse');
        } catch (e) {
          debugPrint('[RegionalDelay] Errore fetch $stationId ($mode): $e');
          continue;
        }

        Map<String, dynamic>? match;
        String matchBy = '';
        if (_tripId.isNotEmpty) {
          for (final b in board) {
            if (_asStr(b['tripId']) == _tripId) {
              match = b;
              matchBy = 'tripId';
              break;
            }
          }
        }
        if (match == null && tripNumber.isNotEmpty) {
          for (final b in board) {
            if (!_sameTrainNumber(
                _asStr(b['tripNumber'] ?? b['trainNumber']), tripNumber)) {
              continue;
            }
            final bDest = _asStr(b['destination'] ??
                b['arrivalStation'] ??
                b['stazione']);
            bool destOk = _sameDestination(dest, bDest);
            if (!destOk && destStationId.isNotEmpty) {
              final bLow = bDest.toLowerCase();
              destOk = bLow == destStationId.toLowerCase() ||
                  _asStr(b['destinationId'] ?? b['destination_id'])
                          .toLowerCase() ==
                      destStationId.toLowerCase();
            }
            if (!destOk) continue;
            match = b;
            matchBy = 'numero+destinazione';
            break;
          }
        }
        if (match == null) {
          debugPrint(
              '[RegionalDelay] Treno non trovato nel tabellone $stationId ($mode), '
              'cerco: num="$tripNumber" dest="$dest", '
              'tabellone: ${board.map((b) => '${_asStr(b['tripNumber'] ?? b['trainNumber'])}→${_asStr(b['destination'])}').join(', ')}');
          continue;
        }
        debugPrint(
            '[RegionalDelay] Match via $matchBy nel tabellone $stationId ($mode)');
        if (match['delay'] == null) {
          debugPrint(
              '[RegionalDelay] Match senza delay, provo altro modo/stazione');
          continue;
        }
        // Niente scarto per bacheca non live: se il treno è listato con
        // un ritardo, lo si usa (le piccole stazioni non hanno mai il
        // flag live e altrimenti la ricerca non servirebbe a nulla).
        if (match['realtime'] == false) {
          debugPrint(
              '[RegionalDelay] Match non live ma con delay, lo uso comunque ($stationId, $mode)');
        }

        final delay = _asInt(match['delay']);
        matchFound = true;
        if (!mounted) return;
        // Isteresi a doppia conferma (come il nazionale): adotta solo
        // valori confermati, poi si memorizza e resta (niente oscillazioni
        // col trip ai tick successivi).
        final before = _headerDelay;
        _adoptBoardDelay(delay, _asStr(stop['stationName']));
        if (_headerDelay != before) return; // Adottato, esce da entrambe le liste
        // Non confermato: continua con altro modo/stazione.
        continue;
      }

      if (!matchFound) {
        debugPrint(
            '[RegionalDelay] Nessun match trovato a $stationId, passo alla prossima stazione');
      }
    }
    debugPrint(
        '[RegionalDelay] Nessun tabellone utile, ritardo invariato ($_delay min)');
    } finally {
      _isRefreshingBoards = false;
    }
  }

  void _retry() {
    setState(() {
      _fetchAttempted = false;
      _isLoading = true;
      _hasLoadedData = false;
      _error = null;
      _tripData = null;
    });
    _fetchTimeoutTimer?.cancel();
    _fetchTripDetails();
  }

  // ---------------------------------------------------------------------------
  // Condivisione treno (stesso algoritmo di TrainProvider.shareTripLink +
  // TrainRepository.shareTrip: snapshot sul server -> URL pubblico /share/?id=)
  // ---------------------------------------------------------------------------

  String _isoTime(dynamic raw) {
    final dt = _parseRegionalTime(raw);
    if (dt == null) return '';
    return dt.toIso8601String();
  }

  /// Copia di shareTripLink: salva uno snapshot della corsa sul server
  /// (POST /api/share-trip) e restituisce l'URL pubblico di condivisione.
  Future<String?> _shareTripLink() async {
    try {
      final current = _current;
      final meta = current['metadata'] is Map
          ? Map<String, dynamic>.from(current['metadata'] as Map)
          : <String, dynamic>{};
      final origin = current['origin'];
      final originMap = origin is Map
          ? Map<String, dynamic>.from(origin)
          : <String, dynamic>{};
      debugPrint('[RegionalTrip] Sharing trip $_category $_trainNumber...');
      // Colonna "share" del backend: chiave stabile per ritrovare il provider
      // all'apertura del link + nome da scrivere nella condivisione.
      final shareKey = widget.provider.share.key.isNotEmpty
          ? widget.provider.share.key
          : widget.provider.name;
      final payload = {
        'tripId': _tripId,
        'country': widget.provider.country,
        'category': _category,
        'tripNumber': _trainNumber,
        'origin': _getEffectiveOrigin(current),
        'destination': _getEffectiveDestination(current),
        'operator': _asStr(meta['operator'] ??
            meta['company'] ??
            current['operator'] ??
            widget.provider.provider),
        'regionalProvider': shareKey,
        'platform': _asStr(current['platform'] ?? originMap['platform']),
        'delay': _delay,
        'scheduledTime':
            _isoTime(current['scheduledTime'] ?? originMap['scheduledTime']),
        'estimatedTime':
            _isoTime(current['estimatedTime'] ?? originMap['estimatedTime']),
        'stops': _stops.map((s) {
          final j = Map<String, dynamic>.from(s);
          if ((j['country'] ?? '').toString().isEmpty &&
              widget.provider.country.isNotEmpty) {
            j['country'] = widget.provider.country;
          }
          return j;
        }).toList(),
      };
      final url = '${ApiConstants.baseUrl}/api/share-trip';
      debugPrint('[RegionalShare] POST $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: json.encode(payload),
      );
      debugPrint('[RegionalShare] Status: ${response.statusCode}');
      if (response.statusCode != 200) return null;
      final Map<String, dynamic> data = json.decode(response.body);
      final shareId = data['shareId']?.toString();
      if (shareId == null || shareId.isEmpty) return null;
      final shareUrl = '${ApiConstants.baseUrl}/share/?id=$shareId';
      debugPrint('[RegionalTrip] Share URL: $shareUrl');
      return shareUrl;
    } catch (e) {
      debugPrint('[RegionalTrip] Share error: $e');
      return null;
    }
  }

  /// Stesso flusso del chip Condividi dell'originale: snapshot -> URL -> Share.
  Future<void> _shareTrip(ThemeProvider theme) async {
    setState(() => _isSharing = true);
    try {
      final url = await _shareTripLink();
      if (!mounted) return;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(RuntimeLocalizations.t(context, 'share_failed',
                fallback: 'Condivisione non riuscita, riprova')),
            backgroundColor: theme.errorColor,
          ),
        );
        return;
      }
      final cat = _category;
      final num = _trainNumber;
      final providerName = widget.provider.share.providerName.isNotEmpty
          ? widget.provider.share.providerName
          : widget.provider.provider;
      final msg =
          "${RuntimeLocalizations.t(context, 'share_trip_msg', fallback: 'Segui il mio viaggio live')}: $providerName $cat $num\n$url";
      await SharePlus.instance.share(
          ShareParams(text: msg, subject: '$providerName $cat $num'.trim()));
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-refresh + delay continuo da tabelloni finche la sheet e aperta
  // ---------------------------------------------------------------------------

  /// Tick continuo: prima il tabellone di apertura (fonte autorevole),
  /// poi il trip live, poi il ritardo fresco dalle bacheche.
  Future<void> _autoRefreshTick() async {
    if (!mounted) return;
    await _refreshOriginBoardDelay();
    if (!mounted) return;
    await _fetchTripDetails();
    if (!mounted) return;
    await _refreshDelayFromBoards();
  }

  void _startAutoRefresh() {
    final interval = _settingsProvider.trainRefreshSeconds;
    if (interval > 0) {
      _autoRefreshTimer = Timer.periodic(
          Duration(seconds: interval), (_) => _autoRefreshTick());
    }
  }

  Future<void> _toggleAutoRefresh() async {
    final interval = _settingsProvider.trainRefreshSeconds;
    if (_autoRefreshTimer != null) {
      _autoRefreshTimer!.cancel();
      _autoRefreshTimer = null;
    } else if (interval > 0) {
      _autoRefreshTimer = Timer.periodic(
          Duration(seconds: interval), (_) => _autoRefreshTick());
    }
    if (mounted) setState(() {});
  }

  void _refreshTrainDetails() {
    if (!mounted) return;
    _autoRefreshTick();
  }

  String _formatStationTime(DateTime? date, String countryCode) {
    if (date == null) return '--:--';
    final local = date.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  // ---------------------------------------------------------------------------
  // Build (stessa struttura dell'originale)
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            OrientationBuilder(
              builder: (context, orientation) {
                // Layout orizzontale: NON altera la logica, solo la disposizione.
                if (orientation == Orientation.landscape) {
                  return _buildLandscapeLayout(context, theme);
                }
                // Layout verticale originale, invariato.
                return Column(
                  children: [
                    _buildHeroHeader(context, theme),
                    Expanded(
                      child: _buildContentArea(context, theme),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Layout per orientamento orizzontale (landscape):
  /// colonna sinistra con controlli/origine-destinazione/stato,
  /// colonna destra con la timeline del percorso scorrevole.
  /// Riusa esclusivamente i widget/metodi già esistenti: nessuna logica nuova.
  Widget _buildLandscapeLayout(BuildContext context, ThemeProvider theme) {
    final current = _current;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: theme.isDark ? 0.4 : 0.12),
                  blurRadius: 20,
                  offset: const Offset(4, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: SafeArea(
              right: false,
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _BackButton(
                            icon: Icons.arrow_back_ios_new_rounded,
                            onTap: () => Navigator.of(context).pop(),
                            theme: theme),
                        const Spacer(),
                        _buildProgressButton(context, theme),
                        const SizedBox(width: 12),
                        _buildModernDelayBadge(_headerDelay, theme),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Riga dedicata: categoria e numero treno su tutta la larghezza
                    // della colonna, per evitare che vengano tagliati (solo
                    // adattamento di layout tramite FittedBox, nessuna modifica
                    // alla logica del widget originale).
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _buildTrainIdentifier(context, theme, current),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Indicatore utente in ascolto, subito sotto categoria e numero treno.
                    _buildViewersRow(theme),
                    const SizedBox(height: 16),
                    // Pulsanti di controllo in alto nella colonna sinistra: tutti visibili.
                    _buildActionChips(context, theme, wrap: true),
                    const SizedBox(height: 16),
                    // Origine e destinazione, subito sotto ai pulsanti.
                    _buildRouteRow(context, theme),
                    const SizedBox(height: 12),
                    // Barra di stato / peggioramento, sotto origine e destinazione.
                    _buildDelayTrendPlate(context, theme),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Colonna destra: timeline del percorso, scorrevole, altezza piena.
        Expanded(
          child: SafeArea(
            left: false,
            bottom: false,
            child: _buildContentArea(context, theme),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroHeader(BuildContext context, ThemeProvider theme) {
    final current = _current;
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
              Row(
                children: [
                  _BackButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).pop(),
                      theme: theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTrainIdentifier(context, theme, current),
                  ),
                  const SizedBox(width: 8),
                  _buildProgressButton(context, theme),
                  const SizedBox(width: 12),
                  _buildModernDelayBadge(_headerDelay, theme),
                ],
              ),
              const SizedBox(height: 12),
              _buildRouteRow(context, theme),
              _buildDelayTrendPlate(context, theme),
              const SizedBox(height: 12),
              _buildViewersRow(theme),
              const SizedBox(height: 8),
              _buildActionChips(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteRow(BuildContext context, ThemeProvider theme) {
    final current = _current;
    final origin = _getEffectiveOrigin(current);
    final dest = _getEffectiveDestination(current);

    // Posizione del treno (0.0..1.0) — calcolo robusto condiviso, con il
    // ritardo di header (bacheca memorizzata o trip) dentro gli orari.
    final stops = _stops;
    final progress =
        _calcRegionalRouteProgress(stops, DateTime.now().toUtc(), _headerDelay);

    // Indice fermata corrente per il pulsante "vai alla posizione"
    int scrollIdx = -1;
    if (stops.isNotEmpty) {
      final nowUtc2 = DateTime.now().toUtc();
      for (int i = 0; i < stops.length; i++) {
        final times = _estimateRegionalStopTimes(stops[i], _delay);
        final arrTime = times['arr'];
        final depTime = times['dep'];
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
                    border:
                        Border.all(color: theme.secondaryTextColor, width: 2),
                    shape: BoxShape.circle,
                  ),
                ),
                // Connecting line with progress
                SizedBox(
                  height: 84,
                  width: 3,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                          width: 3,
                          color:
                              theme.secondaryTextColor.withValues(alpha: 0.3)),
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
                  style:
                      AppTextStyle.labelSmall(color: theme.secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        origin.isNotEmpty ? origin : '--',
                        style:
                            AppTextStyle.titleMedium(color: theme.textColor),
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
                  style:
                      AppTextStyle.labelSmall(color: theme.secondaryTextColor),
                ),
                const SizedBox(height: 2),
                Text(
                  dest.isNotEmpty ? dest : '--',
                  style: AppTextStyle.titleMedium(color: theme.textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int? _diffMinutes(DateTime? sched, DateTime? est) {
    if (sched == null || est == null) return null;
    return est.difference(sched).inMinutes;
  }

  /// Ritardo header: prima quello memorizzato dalle bacheche (apertura
  /// o successive), poi il generale del trip. Mai quello di una singola
  /// fermata: il badge deve coincidere con i tabelloni, senza oscillare.
  int get _headerDelay => _memorizedDelay ?? _delay;

  /// Memorizza un ritardo trovato in bacheca (solo se diverso).
  void _memorizeBoardDelay(int delay, String where) {
    if (_memorizedDelay != delay) {
      setState(() => _memorizedDelay = delay);
      debugPrint(
          '[RegionalDelay] Memorizzato: $delay min (da $where)');
    }
  }

  /// Isteresi come nel nazionale: un ritardo diverso da quello mostrato
  /// viene memorizzato solo dopo 2 conferme consecutive (stesso valore).
  /// Evita oscillazioni da jitter ±1-2 min tra bacheche diverse.
  void _adoptBoardDelay(int delay, String where) {
    if (delay == _headerDelay) {
      _boardDelayCandidate = null;
      _boardDelayHits = 0;
      return;
    }
    if (_boardDelayCandidate == delay) {
      _boardDelayHits++;
    } else {
      _boardDelayCandidate = delay;
      _boardDelayHits = 1;
    }
    if (_boardDelayHits < 2) {
      debugPrint('[RegionalDelay] $delay min da $where non confermato (1/2)');
      return;
    }
    _boardDelayCandidate = null;
    _boardDelayHits = 0;
    _memorizeBoardDelay(delay, where);
  }

  /// Match anti-treno-sbagliato sul tabellone di apertura (stesso formato
  /// dati): tripId esatto, oppure numero + destinazione + orario
  /// programmato vicino (±10 min, solo se noto da ambo le parti).
  bool _matchOriginEntry(Map<String, dynamic> entry) {
    final myTrip = _tripId;
    final eTrip = _asStr(entry['tripId']);
    if (myTrip.isNotEmpty && eTrip.isNotEmpty) return eTrip == myTrip;
    final num = _trainNumber;
    if (num.isEmpty) return false;
    if (!_sameTrainNumber(
        _asStr(entry['tripNumber'] ?? entry['trainNumber']), num)) {
      return false;
    }
    final bDest = _asStr(entry['destination'] ??
        entry['arrivalStation'] ??
        entry['stazione']);
    bool destOk = _sameDestination(
        _getEffectiveDestination(_current), bDest);
    if (!destOk) {
      // Come nella ricerca bacheche: vale anche l'ID stazione.
      String destId = '';
      final myStops = _stops;
      for (int k = myStops.length - 1; k >= 0; k--) {
        final s = myStops[k];
        if (s is! Map) continue;
        if (s['cancelled'] == true) continue;
        destId = _asStr(s['stationId'] ?? s['id']);
        if (destId.isNotEmpty) break;
      }
      if (destId.isNotEmpty) {
        final bLow = bDest.toLowerCase();
        destOk = bLow == destId.toLowerCase() ||
            _asStr(entry['destinationId'] ?? entry['destination_id'])
                    .toLowerCase() ==
                destId.toLowerCase();
      }
    }
    if (!destOk) return false;
    final eSched = _parseTime(entry['scheduledDeparture'] ??
        entry['departure'] ??
        entry['scheduledTime']);
    final mySched = _parseTime(_current['scheduledTime']);
    if (eSched != null && mySched != null) {
      if ((eSched.difference(mySched).inMinutes).abs() > 10) return false;
    }
    return true;
  }

  /// Ricontrolla il tabellone di apertura: finché il treno è listato lì,
  /// il suo ritardo è quello ufficiale per il badge.
  Future<void> _refreshOriginBoardDelay() async {
    final stationId = widget.originStationId ?? '';
    if (stationId.isEmpty || !mounted) return;
    int? found;
    for (final mode in ['departures', 'arrivals']) {
      try {
        final url =
            '$_baseUrl/$mode?stationId=${Uri.encodeComponent(stationId)}';
        final resp = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) continue;
        final decoded = json.decode(resp.body);
        final list =
            (decoded is Map ? decoded['data'] as List<dynamic>? : null) ??
                [];
        for (final b in list.whereType<Map>()) {
          final entry = Map<String, dynamic>.from(b);
          if (!_matchOriginEntry(entry)) continue;
          final d = _asIntOrNull(
              entry['delay'] ?? entry['delayMinutes']);
          if (d == null) continue;
          found = d;
          debugPrint(
              '[RegionalDelay] Origine $stationId ($mode): match, delay $d min');
          break;
        }
        if (found != null) break;
      } catch (e) {
        debugPrint('[RegionalDelay] Origine $stationId ($mode): errore $e');
        continue;
      }
    }
    if (!mounted) return;
    if (found != null) {
      // Trovato: si adotta con isteresi e resta (anche se poi esce dal tabellone).
      _adoptBoardDelay(found, 'origine $stationId');
    } else {
      debugPrint(
          '[RegionalDelay] Origine $stationId: treno uscito, tengo il memorizzato');
    }
  }

  // Storico ritardi ricevuti in sessione: la targhetta si aggiorna con
  // tutti i dati arrivati (fermate + ritardo attuale), senza mai perdere
  // i picchi già visti.
  int? _trendMin;
  int? _trendMax;
  int? _trendFirst;

  /// Targhetta andamento ritardo: min/max dalle fermate della corsa +
  /// barra con la posizione del ritardo attuale e tendenza vs partenza
  /// (recupero/peggioramento). Solo dati reali, niente backend.
  Widget _buildDelayTrendPlate(BuildContext context, ThemeProvider theme) {
    // Solo fermate già passate (misure reali): quelle future sono previsioni
    // e falserebbero min/max e tendenza.
    final now = DateTime.now();
    final delays = <int>[];
    for (final e in _stops) {
      if (e is! Map) continue;
      final s = Map<String, dynamic>.from(e);
      if (s['cancelled'] == true) continue;
      final sched = _parseTime(s['scheduledDeparture'] ??
          s['departure'] ??
          s['scheduledArrival'] ??
          s['arrival']);
      if (sched != null &&
          sched.isAfter(now.add(const Duration(minutes: 1)))) {
        continue;
      }
      // Come i badge in timeline: prima le differenze orari troncate ai
      // minuti (niente arrotondamenti), poi i ritardi dichiarati.
      int? d = _diffMinutes(
        _parseTime(s['scheduledDeparture'] ?? s['departure']),
        _parseTime(s['estimatedDeparture']),
      );
      d ??= _asIntOrNull(s['departureDelay']) ?? _asIntOrNull(s['delay']);
      d ??= _diffMinutes(
        _parseTime(s['scheduledArrival'] ?? s['arrival']),
        _parseTime(s['estimatedArrival']),
      );
      d ??= _asIntOrNull(s['arrivalDelay']);
      if (d != null) delays.add(d);
    }
    // Accumula tutto il ricevuto in sessione (senza setState: nessun loop).
    if (delays.isNotEmpty) {
      final sMin = delays.reduce(min);
      final sMax = delays.reduce(max);
      _trendMin = _trendMin == null ? sMin : min(_trendMin!, sMin);
      _trendMax = _trendMax == null ? sMax : max(_trendMax!, sMax);
      _trendFirst ??= delays.first;
    }
    final current = _headerDelay;
    _trendMin = _trendMin == null ? current : min(_trendMin!, current);
    _trendMax = _trendMax == null ? current : max(_trendMax!, current);
    if (_trendMin == null || _trendMax == null || _trendFirst == null) {
      return const SizedBox.shrink();
    }
    final maxD = _trendMax!;
    final minD = _trendMin!;
    debugPrint('[DelayTrend] snapshot=${delays.length} voci current=$current stored=($minD..$maxD) first=$_trendFirst');
    if (maxD == minD) return const SizedBox.shrink();
    final diff = current - _trendFirst!;
    final String label;
    final Color trendColor;
    final IconData trendIcon;
    String deltaStr = '';
    if (diff < 0) {
      label =
          RuntimeLocalizations.t(context, 'delay_trend_better') ?? 'In recupero';
      trendColor = Colors.green;
      trendIcon = Icons.trending_down_rounded;
      deltaStr = ' ${-diff}\'';
    } else if (diff > 0) {
      label = RuntimeLocalizations.t(context, 'delay_trend_worse') ??
          'In peggioramento';
      trendColor = diff > 5 ? Colors.red : Colors.orange;
      trendIcon = Icons.trending_up_rounded;
      deltaStr = ' +$diff\'';
    } else {
      label =
          RuntimeLocalizations.t(context, 'delay_trend_stable') ?? 'Stabile';
      trendColor = theme.secondaryTextColor;
      trendIcon = Icons.trending_flat_rounded;
    }
    String fmt(int d) => d < 0 ? "$d'" : (d == 0 ? "0'" : "+$d'");
    final frac = (((current - minD) / (maxD - minD)).clamp(0.0, 1.0)).toDouble();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withValues(alpha: theme.isDark ? 0.5 : 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(trendIcon, size: 14, color: trendColor),
              const SizedBox(width: 4),
              Text(
                '$label$deltaStr',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: trendColor),
              ),
              const Spacer(),
              Text(
                '${RuntimeLocalizations.t(context, 'delay_trend_min') ?? 'Min'} ${fmt(minD)}',
                style:
                    TextStyle(fontSize: 10, color: theme.secondaryTextColor),
              ),
              const SizedBox(width: 8),
              Text(
                '${RuntimeLocalizations.t(context, 'delay_trend_max') ?? 'Max'} ${fmt(maxD)}',
                style:
                    TextStyle(fontSize: 10, color: theme.secondaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              return SizedBox(
                height: 12,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.green,
                            Colors.yellow,
                            Colors.orange,
                            Colors.red
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: (frac * (w - 12)).clamp(0.0, w > 12 ? w - 12 : 0.0),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: trendColor, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 3)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionChips(BuildContext context, ThemeProvider theme, {bool wrap = false}) {
    final chips = [
          _buildInfoChip(
            Icons.refresh_rounded,
            RuntimeLocalizations.t(context, 'update') ?? 'Aggiorna',
            theme,
            _refreshTrainDetails,
          ),
          _buildInfoChip(
            _isSharing ? Icons.hourglass_empty_rounded : Icons.share_rounded,
            RuntimeLocalizations.t(context, 'share_trip',
                fallback: 'Condividi'),
            theme,
            _isSharing ? null : () => _shareTrip(theme),
          ),
          _buildInfoChip(
            _autoRefreshTimer != null
                ? Icons.timer_rounded
                : Icons.timer_off_rounded,
            RuntimeLocalizations.t(context, 'live') ?? 'LIVE',
            theme,
            () => _toggleAutoRefresh(),
            isActive: _autoRefreshTimer != null,
          ),
          if (_hasMessages())
            _buildInfoChip(
              Icons.warning_amber_rounded,
              '${RuntimeLocalizations.t(context, 'alerts') ?? 'Avvisi'} (${_messages()?.length ?? 0})',
              theme,
              _showMessagesSheet,
              isActive: true,
              isWarning: true,
            ),
    ];

    if (wrap) {
      // Modalità orizzontale: tutti i pulsanti visibili, su più righe se serve.
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: chips,
      ),
    );
  }

  Widget _buildInfoChip(
      IconData icon, String label, ThemeProvider theme, VoidCallback? onTap,
      {bool isActive = false, bool isWarning = false}) {
    final Color iconColor = isWarning ? theme.warningColor : theme.primaryColor;
    final Color labelColor = isWarning ? theme.warningColor : theme.textColor;

    final Color bgColor =
        isActive ? theme.primaryColor.withOpacity(0.08) : theme.surfaceColor;
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
        label: Text(label,
            style: TextStyle(
                color: labelColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildTrainIdentifier(BuildContext context, ThemeProvider theme,
      Map<String, dynamic> departure) {
    // Logo e numero congelati all'apertura (i refresh ritardi non li toccano).
    final liveCat = _category;
    final liveNum = _trainNumber;
    final category = (_frozenCategory?.isNotEmpty == true
            ? _frozenCategory!
            : liveCat);
    final number =
        (_frozenNumber?.isNotEmpty == true ? _frozenNumber! : liveNum);
    return _buildColorText(category, number, theme);
  }

  Widget _buildColorText(String category, String number, ThemeProvider theme) {
    final isHighSpeed = category.toLowerCase().contains('fr') ||
        category.toLowerCase().contains('freccia');
    final color = isHighSpeed ? Colors.redAccent : theme.primaryColor;

    final label = '${category.isNotEmpty ? '$category ' : ''}$number'.trim();
    return Text(
      label.isNotEmpty ? label : 'Treno',
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color),
    );
  }

  /// 'N/A' e simili non sono nomi veri: non vanno mai inviati all'API.
  static bool _isJunkPresenceStr(String? v) {
    if (v == null) return true;
    final s = v.trim().toUpperCase();
    return s.isEmpty || s == 'N/A' || s == 'N/D' || s == '--' || s == '-';
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

  Widget _buildModernDelayBadge(int delay, ThemeProvider theme) {
    Color color;
    String text;
    IconData icon;

    if (delay < 0) {
      color = theme.successColor;
      text = RuntimeLocalizations.t(context, 'trainEarly',
              params: {'delay': (-delay).toString()}) ??
          "Anticipo ${-delay}'";
      icon = Icons.fast_forward_rounded;
    } else if (delay == 0) {
      color = theme.successColor;
      text = RuntimeLocalizations.t(context, 'trainOnTime') ?? 'In Orario';
      icon = Icons.check_circle_rounded;
    } else if (delay <= 5) {
      color = const Color(0xFFFFA000);
      text = RuntimeLocalizations.t(context, 'trainDelayed',
              params: {'delay': delay.toString()}) ??
          "+$delay min";
      icon = Icons.access_time_rounded;
    } else {
      color = theme.errorColor;
      text = RuntimeLocalizations.t(context, 'trainDelayed',
              params: {'delay': delay.toString()}) ??
          "+$delay min";
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
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressButton(BuildContext context, ThemeProvider theme) {
    final stops = _stops;
    final progress =
        _calcRegionalRouteProgress(stops, DateTime.now().toUtc(), _headerDelay);

    return GestureDetector(
      onTap: () => _showProgressDialog(context, theme),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color:
              AppTokens.trainColor.withValues(alpha: theme.isDark ? 0.3 : 0.15),
          shape: BoxShape.circle,
          border: Border.all(
              color: AppTokens.trainColor.withValues(alpha: 0.5), width: 1),
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

  void _showProgressDialog(BuildContext context, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radius2Xl)),
        child: _ProgressDialogBody(
          resolveCurrent: () => _current,
          originOf: _getEffectiveOrigin,
          destOf: _getEffectiveDestination,
          headerDelay: _headerDelay,
        ),
      ),
    );
  }

  Widget _buildContentArea(BuildContext context, ThemeProvider theme) {
    if (_isLoading && _stops.isEmpty && _error == null) {
      return Center(child: _buildTimelineShimmer(theme));
    }

    if (_hasLoadedData &&
        _error != null &&
        _error!.isNotEmpty &&
        _stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded,
                  size: 64,
                  color: theme.secondaryTextColor.withValues(alpha: 0.5)),
              const SizedBox(height: 24),
              Text(
                  RuntimeLocalizations.t(context, 'something_went_wrong') ??
                      'Qualcosa è andato storto',
                  style: AppTextStyle.titleLarge(color: theme.textColor)),
              const SizedBox(height: 8),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style:
                      AppTextStyle.bodyMedium(color: theme.secondaryTextColor)),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label:
                    Text(RuntimeLocalizations.t(context, 'retry') ?? 'Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    if (_hasLoadedData && _stops.isEmpty && _error == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.train_rounded,
                  size: 64,
                  color: theme.secondaryTextColor.withValues(alpha: 0.3)),
              const SizedBox(height: 24),
              Text(
                  RuntimeLocalizations.t(context, 'noStopsAvailable') ??
                      'Nessuna fermata disponibile',
                  style: AppTextStyle.titleMedium(color: theme.textColor)),
              const SizedBox(height: 8),
              Text(
                  RuntimeLocalizations.t(context, 'noStopsAvailableDesc') ??
                      'I dettagli di questo treno non sono stati caricati.',
                  style:
                      AppTextStyle.bodyMedium(color: theme.secondaryTextColor)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(RuntimeLocalizations.t(context, 'reloadStops') ??
                    'Ricarica'),
              ),
            ],
          ),
        ),
      );
    }

    final List<Map<String, dynamic>> stops = _stops;
    final DateTime nowUtc = DateTime.now().toUtc();

    int currentSegmentIndex = -1;
    double segmentProgress = 0.0;
    bool isAtStation = false;

    if (stops.isNotEmpty) {
      for (int i = 0; i < stops.length - 1; i++) {
        final curTimes = _estimateRegionalStopTimes(stops[i], _delay);
        final nextTimes = _estimateRegionalStopTimes(stops[i + 1], _delay);
        final depCurrent = curTimes['dep'];
        final arrCurrent = curTimes['arr'];
        final arrNext = nextTimes['arr'];

        if (depCurrent != null &&
            arrNext != null &&
            nowUtc.isAfter(depCurrent) &&
            nowUtc.isBefore(arrNext)) {
          currentSegmentIndex = i;
          isAtStation = false;
          final total = arrNext.difference(depCurrent).inSeconds;
          final elapsed = nowUtc.difference(depCurrent).inSeconds;
          segmentProgress = total > 0 ? (elapsed / total).clamp(0.0, 1.0) : 1.0;
          break;
        }
        if (arrCurrent != null &&
            depCurrent != null &&
            !nowUtc.isBefore(arrCurrent) &&
            !nowUtc.isAfter(depCurrent)) {
          currentSegmentIndex = i;
          isAtStation = true;
          break;
        }
        if (arrNext != null && nowUtc.isAfter(arrNext))
          currentSegmentIndex = i + 1;
      }
    }

    if (stops.isEmpty) {
      return Center(child: _buildTimelineShimmer(theme));
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: stops.length,
      itemBuilder: (context, index) {
        final isFuture = index > currentSegmentIndex;
        final stop = stops[index];
        final stopStationId = _asStr(stop['stationId'] ?? stop['id']);
        final stopStationName = _asStr(stop['stationName']);
        return _TimelineRow(
          stop: stop,
          index: index,
          isLast: index == stops.length - 1,
          isCompleted: index < currentSegmentIndex,
          isTraversing: (index == currentSegmentIndex) &&
              !isAtStation &&
              index < stops.length - 1,
          isActiveStop: (index == currentSegmentIndex) && isAtStation,
          progress: segmentProgress,
          timeFormatter: _formatStationTime,
          isFuture: isFuture,
          totalDelay: _headerDelay,
          theme: theme,
          onStationTap: stopStationId.isNotEmpty
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => RegionalStationDetailsScreen(
                        provider: widget.provider,
                        stationId: stopStationId,
                        stationName: stopStationName.isNotEmpty
                            ? stopStationName
                            : stopStationId,
                      ),
                    ),
                  );
                }
              : null,
        );
      },
    );
  }

  /// Scorre la timeline fino alla fermata [index].
  void _scrollToStop(int index) {
    const itemHeight = 72.0;
    if (!_scrollController.hasClients) return;
    final targetOffset = (index * itemHeight)
        .clamp(0.0, _scrollController.position.maxScrollExtent);
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
                    width: 12,
                    height: 12,
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
                          borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4)),
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
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 60,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>>? _messages() {
    final List<Map<String, dynamic>> out = [];
    final t = _current;

    final tripMsgs = t['messages'];
    if (tripMsgs is List && tripMsgs.isNotEmpty) {
      out.addAll(
          tripMsgs.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
    }

    final meta = t['metadata'];
    if (meta is Map) {
      final raw = meta['messages'] ?? meta['alerts'] ?? meta['notes'];
      if (raw is List && raw.isNotEmpty) {
        out.addAll(raw.map<Map<String, dynamic>>((e) =>
            e is Map ? Map<String, dynamic>.from(e) : {'text': e?.toString()}));
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
                    Text(
                        RuntimeLocalizations.t(context, 'messages') ??
                            'Messaggi',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(RuntimeLocalizations.t(context, 'messages_count',
                                params: {'count': msgs.length.toString()}) ??
                            '${msgs.length} messaggi'),
                        if (priCounts.isNotEmpty) const SizedBox(height: 6),
                        if (priCounts.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            children: priCounts.entries.map<Widget>((e) {
                              final key = e.key;
                              final count = e.value;
                              final bg = key == 'high'
                                  ? Theme.of(context)
                                      .colorScheme
                                      .error
                                      .withOpacity(0.12)
                                  : (key == 'medium'
                                      ? Colors.amber.withOpacity(0.12)
                                      : Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.12));
                              final textColor = key == 'high'
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).primaryColor;
                              return Chip(
                                  label: Text('$key: $count',
                                      style: TextStyle(
                                          color: textColor, fontSize: 12)),
                                  backgroundColor: bg);
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
                      final type =
                          (m['type'] ?? 'info').toString().toLowerCase();
                      final title = (m['title'] ?? '').toString();
                      final text = (m['text'] ?? '').toString();
                      final icon = type == 'warning'
                          ? Icons.warning_rounded
                          : Icons.info_outline;
                      final color = type == 'warning'
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).primaryColor;
                      final station = (m['station'] ?? '').toString();
                      final priority =
                          (m['priority'] ?? '').toString().toLowerCase();
                      final subtitleWidget = station.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(station,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                                const SizedBox(height: 8),
                                Text(text,
                                    style: const TextStyle(fontSize: 13)),
                              ],
                            )
                          : Text(text);

                      final Color priColor = priority == 'high'
                          ? Theme.of(context).colorScheme.error
                          : (priority == 'medium'
                              ? Colors.amber
                              : Theme.of(context).primaryColor);

                      final bgColor = priority == 'high'
                          ? Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.04)
                          : (priority == 'medium'
                              ? Colors.amber.withOpacity(0.04)
                              : Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.02));

                      return Container(
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: Border(
                              left: BorderSide(
                                  color: priColor,
                                  width: priority.isNotEmpty ? 4 : 0)),
                        ),
                        child: ListTile(
                          leading: Icon(icon, color: color),
                          title: Row(children: [
                            Expanded(
                                child: Text(
                                    title.isNotEmpty
                                        ? title
                                        : (station.isNotEmpty ? station : ''),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            if (priority.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                child: Chip(
                                  label: Text(priority.toUpperCase(),
                                      style: TextStyle(
                                          color: priColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800)),
                                  backgroundColor: priColor.withOpacity(0.12),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
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
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(RuntimeLocalizations.t(context, 'close') ??
                            'Chiudi'))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProgressDialogBody extends StatefulWidget {
  final Map<String, dynamic> Function() resolveCurrent;
  final String Function(Map<String, dynamic>) originOf;
  final String Function(Map<String, dynamic>) destOf;
  final int headerDelay;

  const _ProgressDialogBody(
      {required this.resolveCurrent,
      required this.originOf,
      required this.destOf,
      required this.headerDelay});

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

    final dep = widget.resolveCurrent();
    final rawStops = dep['stops'];
    final List<Map<String, dynamic>> stops = rawStops is List
        ? rawStops
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];
    final origin = widget.originOf(dep);
    final dest = widget.destOf(dep);

    // Progresso (stessa logica robusta del bottone header, con ritardo header)
    final progress = _calcRegionalRouteProgress(
        stops, DateTime.now().toUtc(), widget.headerDelay);

    final trainLabel = _asStr(
        dep['tripNumber'] ?? dep['trainNumber'] ?? dep['category'] ?? 'Treno');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            RuntimeLocalizations.t(context, 'progress_title',
                fallback: 'Progresso Viaggio'),
            style: AppTextStyle.titleLarge(color: theme.textColor),
          ),
          const SizedBox(height: 8),
          Text(
            '$trainLabel - ${(progress * 100).toInt()}%',
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
              border:
                  Border.all(color: theme.borderColor.withValues(alpha: 0.15)),
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
                            border:
                                Border.all(color: theme.surfaceColor, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppTokens.trainColor.withValues(alpha: 0.5),
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
  final Map<String, dynamic> stop;
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
    required this.stop,
    required this.index,
    required this.isLast,
    required this.isCompleted,
    required this.isTraversing,
    required this.isActiveStop,
    required this.progress,
    required this.timeFormatter,
    required this.isFuture,
    required this.totalDelay,
    required this.theme,
    this.onStationTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool highlighted = isCompleted || isActiveStop || isTraversing;
    final String stationName = _asStr(stop['stationName']);
    final bool cancelled = stop['cancelled'] == true;
    final String? platform =
        _asStr(stop['platform']).isNotEmpty ? _asStr(stop['platform']) : null;

    ({String text, int delay}) buildTimeString(
        String type, DateTime? scheduled, DateTime? estimated, int? delay) {
      if (scheduled == null && estimated == null) {
        return (text: '', delay: 0);
      }

      // Il badge deve corrispondere agli orari mostrati: prima la differenza
      // troncata ai minuti (niente arrotondamenti tipo 7'40" -> +8'), poi il
      // ritardo dichiarato solo se mancano gli orari.
      // Uno 0 esplicito (fermata puntuale misurata) viene rispettato.
      final int effectiveDelay;
      if (estimated != null && scheduled != null) {
        effectiveDelay = estimated.difference(scheduled).inMinutes;
      } else if (delay != null) {
        effectiveDelay = delay;
      } else if (estimated == null && !isFuture && totalDelay != 0) {
        effectiveDelay = totalDelay;
      } else {
        effectiveDelay = 0;
      }

      final effective =
          estimated ?? scheduled!.add(Duration(minutes: effectiveDelay));
      final effStr = timeFormatter(effective, 'IT');

      final String text;
      if (scheduled != null && (estimated != null || effectiveDelay != 0)) {
        text = '$type: $effStr (${RuntimeLocalizations.t(context, 'scheduled_label') ?? 'Prog'}: ${timeFormatter(scheduled, 'IT')})';
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

    final schedArr = _parseRegionalTime(stop['scheduledArrival']);
    final schedDep =
        _parseRegionalTime(stop['scheduledDeparture'] ?? stop['scheduledTime']);
    final estArr = _parseRegionalTime(stop['estimatedArrival']);
    final estDep = _parseRegionalTime(stop['estimatedDeparture']);
    final int? arrDelay = _asIntOrNull(stop['arrivalDelay']);
    final int? depDelay = _asIntOrNull(stop['departureDelay']);
    // Fermate future: lo stimato è programmato + ritardo attuale
    // (il ritardo si somma alle fermate future).
    final projArr = isFuture && schedArr != null
        ? schedArr.add(Duration(minutes: totalDelay))
        : estArr;
    final projDep = isFuture && schedDep != null
        ? schedDep.add(Duration(minutes: totalDelay))
        : estDep;

    return IntrinsicHeight(
      child: Row(
        children: [
          const SizedBox(width: 16),
          _buildVisualTimeline(highlighted, cancelled),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Builder(
                                  builder: (_) {
                                    // Piu il nome e lungo, piu il font si rimpicciolisce (16 -> 9);
                                    // il FittedBox garantisce che entri comunque su ogni schermo.
                                    final size = (16.0 -
                                            (stationName.length - 20) * 0.25)
                                        .clamp(9.0, 16.0);
                                    return Text(stationName,
                                        maxLines: 1,
                                        style: TextStyle(
                                            color: isCompleted
                                                ? theme.secondaryTextColor
                                                    .withOpacity(0.6)
                                                : theme.textColor,
                                            fontSize: size,
                                            fontWeight: highlighted
                                                ? FontWeight.w800
                                                : FontWeight.w600));
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
                                      color: theme.primaryColor
                                          .withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.train_rounded,
                                        size: 14, color: theme.primaryColor),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (cancelled)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.errorColor.withOpacity(0.12),
                            border: Border.all(
                                color: theme.errorColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              RuntimeLocalizations.t(context, 'cancelled') ??
                                  'Cancellata',
                              style: TextStyle(
                                  color: theme.errorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800)),
                        ),
                    ],
                  ),
                  if (schedArr != null || estArr != null)
                    Builder(builder: (_) {
                      final arr = buildTimeString(
                          RuntimeLocalizations.t(context, 'arrival') ??
                              'Arrivo',
                          schedArr,
                          projArr,
                          isFuture ? totalDelay : arrDelay);
                      if (arr.text.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(arr.text,
                                style: TextStyle(
                                    color: cancelled
                                        ? theme.secondaryTextColor.withOpacity(0.5)
                                        : (isCompleted
                                            ? theme.secondaryTextColor.withOpacity(0.4)
                                            : theme.secondaryTextColor),
                                    fontSize: 12,
                                    decoration: cancelled
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none)),
                            if (arr.delay != 0 && !cancelled) delayBadge(arr.delay),
                          ],
                        ),
                      );
                    }),
                  if (schedDep != null || estDep != null)
                    Builder(builder: (_) {
                      final dep = buildTimeString(
                          RuntimeLocalizations.t(context, 'departure') ??
                              'Partenza',
                          schedDep,
                          projDep,
                          isFuture ? totalDelay : depDelay);
                      if (dep.text.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(dep.text,
                              style: TextStyle(
                                  color: cancelled
                                      ? theme.secondaryTextColor.withOpacity(0.5)
                                      : (isCompleted
                                          ? theme.secondaryTextColor.withOpacity(0.4)
                                          : theme.secondaryTextColor),
                                  fontSize: 12,
                                  decoration: cancelled
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none)),
                          if (dep.delay != 0 && !cancelled) delayBadge(dep.delay),
                        ],
                      );
                    }),
                ],
              ),
            ),
          ),
          if (platform != null && platform.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 12, bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
              ),
              child: Text(platform,
                  style: TextStyle(
                      color: theme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualTimeline(bool highlighted, bool cancelled) {
    return SizedBox(
      width: 30,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (index > 0)
            Positioned(
                top: 0,
                height: 17,
                width: 3,
                child: Container(
                    color: highlighted
                        ? theme.primaryColor
                        : theme.surfaceColor.withOpacity(0.05))),
          if (!isLast)
            Positioned(
                top: 17,
                bottom: 0,
                width: 3,
                child: Stack(children: [
                  Container(color: theme.surfaceColor.withOpacity(0.05)),
                  if (isCompleted) Container(color: theme.primaryColor),
                  if (isTraversing)
                    LayoutBuilder(
                        builder: (c, ct) => Container(
                            height: ct.maxHeight * progress,
                            decoration: BoxDecoration(
                                gradient: theme.progressGradient))),
                ])),
          Positioned(
              top: 17,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cancelled
                      ? theme.errorColor
                      : (highlighted
                          ? theme.primaryColor
                          : theme.surfaceColor.withOpacity(0.08)),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: cancelled
                          ? theme.errorColor
                          : (highlighted
                              ? theme.primaryColor
                              : theme.secondaryTextColor.withOpacity(0.24)),
                      width: 2),
                ),
              )),
          if (isTraversing)
            Positioned.fill(
                child: LayoutBuilder(
                    builder: (c, ct) =>
                        Stack(alignment: Alignment.topCenter, children: [
                          Positioned(
                              top: 17 + ((ct.maxHeight - 17) * progress) - 10,
                              child: const _TrainIcon(size: 20))
                        ])))
          else if (isActiveStop)
            Positioned(top: 12, child: _TrainIcon(size: 20)),
        ],
      ),
    );
  }
}

class _TrainIcon extends StatelessWidget {
  final double size;
  const _TrainIcon({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppTokens.trainColor,
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.train_rounded, color: Colors.white, size: size * 0.6),
    );
  }
}

class _BackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeProvider theme;

  const _BackButton(
      {required this.icon, required this.onTap, required this.theme});

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
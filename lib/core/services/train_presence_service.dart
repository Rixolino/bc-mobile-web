import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bc_transporter/core/api_constants.dart';

/// Presenza live sui dettagli treno: conta quanti utenti stanno
/// visualizzando lo stesso treno in questo momento.
///
/// Il client invia un heartbeat mentre la sheet è aperta (ogni ~5s);
/// il backend scade le entry dopo 45s senza heartbeat (+ leave esplicito).
class TrainPresenceService {
  static final TrainPresenceService _instance = TrainPresenceService._internal();
  factory TrainPresenceService() => _instance;
  TrainPresenceService._internal();

  static const String _clientIdKey = 'train_presence_client_id';
  static const Duration _timeout = Duration(seconds: 8);

  String? _clientId;

  /// ID anonimo persistente di questo dispositivo.
  Future<String> getClientId() async {
    if (_clientId != null && _clientId!.isNotEmpty) return _clientId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_clientIdKey);
      if (id == null || id.isEmpty) {
        // Bound <= 2^31-1: valido su tutte le piattaforme (incluso web,
        // dove 1 << 32 non è rappresentabile come bound di nextInt).
        final rnd = Random.secure();
        id = 'app-${DateTime.now().microsecondsSinceEpoch}-'
            '${rnd.nextInt(0x7FFFFFFF).toRadixString(16)}'
            '${rnd.nextInt(0x7FFFFFFF).toRadixString(16)}';
        await prefs.setString(_clientIdKey, id);
      }
      _clientId = id;
      return id;
    } catch (e) {
      // Fallback in memoria: la presenza non deve mai rompersi per l'ID.
      print('[Presence] clientId fallback in memoria: $e');
      _clientId ??=
          'mem-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(0x7FFFFFFF).toRadixString(16)}';
      return _clientId!;
    }
  }

  /// Invia heartbeat per [trainKey]; ritorna il numero di viewer attuali
  /// oppure null in caso di errore (mai eccezioni verso i chiamanti).
  Future<int?> heartbeat({
    required String trainKey,
    required String screen,
    Map<String, dynamic>? train,
  }) async {
    try {
      final clientId = await getClientId();
      final resp = await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/api/train-presence/heartbeat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'clientId': clientId,
              'trainKey': trainKey,
              'screen': screen,
              if (train != null) 'train': train,
            }),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        print('[Presence] heartbeat HTTP ${resp.statusCode}');
        return null;
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['viewers'] is int) {
        return decoded['viewers'] as int;
      }
      print('[Presence] heartbeat risposta inattesa: ${resp.body}');
      return null;
    } catch (e) {
      print('[Presence] heartbeat errore: $e');
      return null;
    }
  }

  /// Segnala l'uscita dalla schermata (fire-and-forget).
  Future<void> leave(String trainKey) async {
    try {
      final clientId = await getClientId();
      await http
          .post(
            Uri.parse('${ApiConstants.baseUrl}/api/train-presence/leave'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'clientId': clientId, 'trainKey': trainKey}),
          )
          .timeout(_timeout);
    } catch (_) {}
  }

  /// Legge la classifica dei treni più visualizzati adesso
  /// (GET /api/train-presence/live, già ordinata per viewer desc).
  /// Ritorna lista di {trainKey, viewers, screen, train, lastSeen}, mai eccezioni.
  /// Null in caso di errore (i chiamanti devono tenere i dati vecchi).
  Future<List<Map<String, dynamic>>?> fetchMostViewed() async {
    final data = await fetchLiveData();
    return data?.trains;
  }

  /// GET /live completo: treni + totale utenti collegati adesso.
  /// Null in caso di errore (i chiamanti devono tenere i dati vecchi,
  /// altrimenti un timeout svuoterebbe le sezioni senza motivo).
  Future<({List<Map<String, dynamic>> trains, int totalViewers})?>
      fetchLiveData() async {
    try {
      final resp = await http
          .get(
            Uri.parse('${ApiConstants.baseUrl}/api/train-presence/live'),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        final trains = decoded['trains'] is List
            ? (decoded['trains'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        final total = decoded['totalViewers'] is int
            ? decoded['totalViewers'] as int
            : trains.fold<int>(
                0,
                (s, t) =>
                    s + ((t['viewers'] is int) ? t['viewers'] as int : 0));
        return (trains: trains, totalViewers: total);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Treni visti nell'ultima ora (GET /api/train-presence/recent),
  /// anche se ora non li guarda più nessuno. Stesso formato di /live
  /// + peakViewers. Null in caso di errore (tenere i dati vecchi).
  Future<List<Map<String, dynamic>>?> fetchRecentTrains({int limit = 20}) async {
    try {
      final resp = await http
          .get(
            Uri.parse(
                '${ApiConstants.baseUrl}/api/train-presence/recent?limit=$limit'),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['trains'] is List) {
        return (decoded['trains'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Legge il numero di viewer attuali per [trainKey] (null se errore).
  Future<int?> fetchViewers(String trainKey) async {
    try {
      final resp = await http
          .get(
            Uri.parse(
                '${ApiConstants.baseUrl}/api/train-presence/viewers?trainKey=${Uri.encodeComponent(trainKey)}'),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      if (decoded is Map && decoded['viewers'] is int) {
        return decoded['viewers'] as int;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}

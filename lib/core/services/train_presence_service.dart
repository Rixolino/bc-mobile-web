import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bc_transporter/core/api_constants.dart';

/// Presenza live sui dettagli treno: conta quanti utenti stanno
/// visualizzando lo stesso treno in questo momento.
///
/// Il client invia un heartbeat mentre la sheet è aperta (ogni ~15s);
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
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_clientIdKey);
    if (id == null || id.isEmpty) {
      final rnd = Random.secure();
      id = 'app-${DateTime.now().microsecondsSinceEpoch}-'
          '${rnd.nextInt(1 << 32).toRadixString(16)}${rnd.nextInt(1 << 32).toRadixString(16)}';
      await prefs.setString(_clientIdKey, id);
    }
    _clientId = id;
    return id;
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

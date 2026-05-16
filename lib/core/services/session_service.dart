import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/models/user.dart';

/// SessionService: Salva e carica la sessione account offline.
/// Su web usa SharedPreferences, su mobile lo stesso.
class SessionService {
  static const String _sessionPrefix = 'user_session_';
  static const String _sessionDataKey = '${_sessionPrefix}data';
  static const String _sessionTimestampKey = '${_sessionPrefix}timestamp';

  /// Salva la sessione utente offline
  static Future<void> saveSession(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = {
        'id': user.id,
        'email': user.email,
        'nickname': user.nickname,
        'createdAt': user.createdAt?.toIso8601String(),
      };
      
      await prefs.setString(_sessionDataKey, jsonEncode(userData));
      await prefs.setInt(_sessionTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('[SessionService] Sessione salvata per: ${user.email}');
    } catch (e) {
      debugPrint('[SessionService] Errore nel salvataggio sessione: $e');
    }
  }

  /// Carica la sessione utente offline
  static Future<User?> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionDataJson = prefs.getString(_sessionDataKey);
      
      if (sessionDataJson == null || sessionDataJson.isEmpty) {
        debugPrint('[SessionService] Nessuna sessione salvata');
        return null;
      }

      final userData = jsonDecode(sessionDataJson) as Map<String, dynamic>;
      final user = User(
        id: userData['id'] as int?,
        email: userData['email'] as String,
        nickname: userData['nickname'] as String?,
        createdAt: userData['createdAt'] != null 
          ? DateTime.parse(userData['createdAt'] as String)
          : null,
        password: '', // La password non viene salvata offline
      );
      
      debugPrint('[SessionService] Sessione caricata per: ${user.email}');
      return user;
    } catch (e) {
      debugPrint('[SessionService] Errore nel caricamento sessione: $e');
      return null;
    }
  }

  /// Cancella la sessione utente offline
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionDataKey);
      await prefs.remove(_sessionTimestampKey);
      
      debugPrint('[SessionService] Sessione cancellata');
    } catch (e) {
      debugPrint('[SessionService] Errore nel cancellamento sessione: $e');
    }
  }

  /// Restituisce il timestamp dell'ultima sessione salvata
  static Future<int?> getSessionTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_sessionTimestampKey);
    } catch (e) {
      return null;
    }
  }

  /// Verifica se esiste una sessione offline valida
  static Future<bool> hasValidSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionDataJson = prefs.getString(_sessionDataKey);
      return sessionDataJson != null && sessionDataJson.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}

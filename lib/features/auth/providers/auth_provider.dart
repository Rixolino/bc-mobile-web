import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';
import '../../../core/services/session_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _repository = AuthRepository();
  static const String _userIdKey = 'user_id';

  User? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initializeSession();
  }

  Future<void> _initializeSession() async {
    try {
      // Prova a caricare la sessione offline prima
      final offlineUser = await SessionService.loadSession();
      if (offlineUser != null) {
        _currentUser = offlineUser;
        print('Sessione offline caricata per: ${offlineUser.nickname ?? offlineUser.email}');
      } else {
        // Se non c'è sessione offline, prova a ripristinare dal vecchio formato
        final prefs = await SharedPreferences.getInstance();
        final userIdString = prefs.getString(_userIdKey);

        if (userIdString != null) {
          final userId = int.tryParse(userIdString);
          if (userId != null) {
            // Verifica se l'utente esiste ancora nel database
            final user = await _repository.getUserById(userId);
            if (user != null) {
              _currentUser = user;
              // Salva il profilo nel nuovo formato SessionService
              await SessionService.saveSession(user);
              print('Session restored for user: ${user.nickname ?? user.email}');
            } else {
              // L'utente non esiste più, cancella la sessione
              await _clearSession();
              print('User not found, session cleared');
            }
          }
        }
      }
    } catch (e) {
      print('Errore durante il caricamento della sessione: $e');
      await _clearSession();
    } finally {
      _isInitialized = true;
      print('Auth initialization completed - currentUser: ${_currentUser?.nickname ?? _currentUser?.email ?? 'null'}');
      notifyListeners();
    }
  }

  Future<void> _saveSession(User user) async {
    try {
      // Salva il profilo completo usando SessionService
      await SessionService.saveSession(user);
      // Mantieni anche l'ID nel vecchio formato per compatibilità
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, user.id.toString());
    } catch (e) {
      print('Errore durante il salvataggio della sessione: $e');
    }
  }

  Future<void> _clearSession() async {
    try {
      // Cancella la sessione offline
      await SessionService.clearSession();
      // Cancella anche il vecchio formato per compatibilità
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
    } catch (e) {
      print('Errore durante la cancellazione della sessione: $e');
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await _repository.login(email, password);
      if (user != null) {
        _currentUser = user;
        await _saveSession(user); // Salva la sessione
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Credenziali non valide';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Errore durante il login: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password, String nickname) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if email already exists
      final emailExists = await _repository.checkEmailExists(email);
      if (emailExists) {
        _error = 'Questa email è già registrata. Prova ad accedere o usa un\'altra email.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final user = await _repository.register(email, password, nickname);
      if (user != null) {
        _currentUser = user;
        await _saveSession(user); // Salva la sessione dopo la registrazione
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Errore durante la registrazione';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Errore durante la registrazione: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _error = null;
    await _clearSession(); // Cancella la sessione salvata
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
import 'package:flutter/foundation.dart';
import '../../features/auth/models/user.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../core/services/session_service.dart';

/// AuthProvider: Gestisce lo stato di autenticazione con supporto offline
class AuthProvider with ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isOfflineMode = false;

  // Getters
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isOfflineMode => _isOfflineMode;

  /// Inizializza il provider caricando la sessione offline se disponibile
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Prova a caricare la sessione offline
      final offlineUser = await _repository.loadOfflineSession();
      if (offlineUser != null) {
        _currentUser = offlineUser;
        _isOfflineMode = true;
        debugPrint('[AuthProvider] Sessione offline caricata per: ${offlineUser.email}');
      }
    } catch (e) {
      debugPrint('[AuthProvider] Errore nel caricamento della sessione offline: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Login con email e password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.login(email, password);
      if (user != null) {
        _currentUser = user;
        _isOfflineMode = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Credenziali non valide';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Errore durante il login: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Register con email, password e nickname
  Future<bool> register(String email, String password, String nickname) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _repository.register(email, password, nickname);
      if (user != null) {
        _currentUser = user;
        _isOfflineMode = false;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'Registrazione fallita';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'Errore durante la registrazione: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      // Cancella la sessione offline
      await _repository.clearOfflineSession();
      _currentUser = null;
      _isOfflineMode = false;
      notifyListeners();
      debugPrint('[AuthProvider] Logout completato');
    } catch (e) {
      debugPrint('[AuthProvider] Errore durante il logout: $e');
    }
  }

  /// Verifica se l'email esiste già
  Future<bool> checkEmailExists(String email) async {
    try {
      return await _repository.checkEmailExists(email);
    } catch (e) {
      debugPrint('[AuthProvider] Errore nel controllo email: $e');
      return false;
    }
  }

  /// Ottieni l'utente per ID
  Future<User?> getUserById(int id) async {
    try {
      return await _repository.getUserById(id);
    } catch (e) {
      debugPrint('[AuthProvider] Errore nel recupero utente: $e');
      return null;
    }
  }

  /// Sincronizza la sessione con il server (quando è disponibile la connessione)
  Future<void> syncSession() async {
    if (_currentUser == null || !_isOfflineMode) {
      return;
    }

    try {
      // Prova a recuperare i dati aggiornati dal server
      final updatedUser = await _repository.getUserById(_currentUser!.id ?? 0);
      if (updatedUser != null) {
        _currentUser = updatedUser;
        _isOfflineMode = false;
        // Salva la sessione aggiornata
        await SessionService.saveSession(updatedUser);
        notifyListeners();
        debugPrint('[AuthProvider] Sessione sincronizzata dal server');
      }
    } catch (e) {
      debugPrint('[AuthProvider] Errore durante la sincronizzazione: $e');
      // Rimani in modalità offline
    }
  }
}

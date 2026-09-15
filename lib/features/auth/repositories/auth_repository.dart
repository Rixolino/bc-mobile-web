import '../../../core/services/libsql_dart_web_stub.dart' if (dart.library.io) 'package:libsql_dart/libsql_dart.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../models/user.dart';
import '../../../core/services/session_service.dart';

class AuthRepository {
  // Turso database configuration
  static const String _tursoUrl = 'libsql://betacloud-transporter-rixolino.aws-eu-west-1.turso.io';
  // TODO: Replace with your actual Turso auth token
  static const String _tursoToken = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3Njg2NTc3NDEsImlkIjoiMjI1ZTU0OTgtMmUxYS00ZWM3LTg0ZWUtMDlkMGRmM2YxOWMwIiwicmlkIjoiYWNkMDBiOGYtNTMxYS00MWMxLTk5YjQtYjg5ODc2YTJkMzVhIn0.nUl4jePNi0wZvxhdGvLlwk24EI9BL4jUvBoHKEMdGpatHD_bkn5V8PpcWvMujn4gwfNhmFmqNRH7JYjcjd9zBw';

  LibsqlClient? _client;

  Future<LibsqlClient> _getClient() async {
    if (_client != null) return _client!;

    try {
      print('Connecting to Turso database...');
      _client = LibsqlClient.remote(_tursoUrl, authToken: _tursoToken);
      await _client!.connect();
      await _initializeDatabase();
      print('Turso database connected successfully');
      return _client!;
    } catch (e) {
      print('Turso connection error: $e');
      rethrow;
    }
  }

  Future<String> _hashPassword(String password) async {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  Future<bool> _verifyPassword(String password, String hashedPassword) async {
    return BCrypt.checkpw(password, hashedPassword);
  }

  Future<void> _initializeDatabase() async {
    final client = await _getClient();
    await client.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        nickname TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    print('Users table created/verified in Turso');
  }

  String get _authBase => '${ApiConstants.baseUrl}/api/auth';

  /// Costruisce uno User dalla risposta JSON del server
  /// (che non include mai l'hash della password).
  User _userFromApi(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}'),
      email: '${json['email'] ?? ''}',
      password: '',
      nickname: json['nickname']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }

  Future<User?> login(String email, String password) async {
    // Su web libsql non è disponibile: si usa l'API HTTP del backend.
    if (kIsWeb) return _loginViaApi(email, password);
    try {
      print('Starting login for email: $email');
      final client = await _getClient();

      final result = await client.query(
        'SELECT * FROM users WHERE email = ?',
        positional: [email],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final storedPassword = row['password'] as String;
        
        // Verifica la password criptata
        if (await _verifyPassword(password, storedPassword)) {
          final user = User(
            id: row['id'] as int,
            email: row['email'] as String,
            password: storedPassword, // Mantieni la password criptata
            nickname: row['nickname'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          );
          print('Login successful for user: $email');
          // Salva la sessione offline
          await SessionService.saveSession(user);
          return user;
        }
      }

      print('Login failed: user not found or wrong password');
      return null;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Login via API HTTP (usato su web dove libsql non è disponibile).
  Future<User?> _loginViaApi(String email, String password) async {
    try {
      print('Starting login via API for email: $email');
      final response = await http.post(
        Uri.parse('$_authBase/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final userJson = data['user'];
        if (userJson is Map<String, dynamic>) {
          final user = _userFromApi(userJson);
          print('Login successful via API for user: $email');
          await SessionService.saveSession(user);
          final token = data['token']?.toString();
          if (token != null && token.isNotEmpty) {
            await SessionService.saveAuthToken(token);
          }
          return user;
        }
      }
      print('Login via API failed: ${response.statusCode} ${response.body}');
      return null;
    } catch (e) {
      print('Login via API error: $e');
      return null;
    }
  }

  Future<User?> register(String email, String password, String nickname) async {
    // Su web libsql non è disponibile: si usa l'API HTTP del backend.
    if (kIsWeb) return _registerViaApi(email, password, nickname);
    try {
      print('Starting registration for email: $email');

      // Prima controlla se l'email esiste già
      if (await checkEmailExists(email)) {
        print('Registration failed: email already exists');
        throw Exception('Email già registrata');
      }

      final client = await _getClient();

      // Crea nuovo utente
      final newUser = User(
        email: email,
        password: await _hashPassword(password), // Cripta la password
        nickname: nickname,
        createdAt: DateTime.now(),
      );

      // Inserisci nel database
      await client.execute(
        'INSERT INTO users (email, password, nickname, created_at) VALUES (?, ?, ?, ?)',
        positional: [newUser.email, newUser.password, newUser.nickname, newUser.createdAt?.toIso8601String()],
      );

      // Recupera l'utente appena creato usando l'email
      final result = await client.query(
        'SELECT * FROM users WHERE email = ?',
        positional: [email],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final createdUser = User(
          id: row['id'] as int,
          email: row['email'] as String,
          password: row['password'] as String,
          nickname: row['nickname'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );

        print('Registration successful for user: $email');
        return createdUser;
      }

      throw Exception('Failed to retrieve created user');
    } catch (e) {
      print('Registration error: $e');
      rethrow;
    }
  }

  /// Registrazione via API HTTP (usata su web dove libsql non è disponibile).
  Future<User?> _registerViaApi(
      String email, String password, String nickname) async {
    print('Starting registration via API for email: $email');
    final response = await http.post(
      Uri.parse('$_authBase/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
          {'email': email.trim(), 'password': password, 'nickname': nickname}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final userJson = data['user'];
      if (userJson is Map<String, dynamic>) {
        final user = _userFromApi(userJson);
        print('Registration successful via API for user: $email');
        final token = data['token']?.toString();
        if (token != null && token.isNotEmpty) {
          await SessionService.saveAuthToken(token);
        }
        return user;
      }
      throw Exception('Failed to retrieve created user');
    }
    if (response.statusCode == 409) {
      throw Exception('Email già registrata');
    }
    print(
        'Registration via API failed: ${response.statusCode} ${response.body}');
    throw Exception('Registrazione fallita (${response.statusCode})');
  }

  Future<bool> checkEmailExists(String email) async {
    // Su web non c'è un endpoint dedicato: il conflitto viene rilevato
    // dalla registrazione (409 Email già registrata).
    if (kIsWeb) return false;
    try {
      print('Checking if email exists: $email');
      final client = await _getClient();

      final result = await client.query(
        'SELECT COUNT(*) as count FROM users WHERE email = ?',
        positional: [email],
      );

      final count = result.first['count'] as int;
      final exists = count > 0;

      print('Email ${exists ? 'exists' : 'does not exist'}: $email');
      return exists;
    } catch (e) {
      print('Check email error: $e');
      return false;
    }
  }

  Future<User?> getUserById(int id) async {
    // Su web la sessione viene ripristinata da SessionService
    // (SharedPreferences); il lookup diretto richiede libsql.
    if (kIsWeb) return null;
    try {
      print('Getting user by ID: $id');
      final client = await _getClient();

      final result = await client.query(
        'SELECT * FROM users WHERE id = ?',
        positional: [id],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final user = User(
          id: row['id'] as int,
          email: row['email'] as String,
          password: row['password'] as String,
          nickname: row['nickname'] as String?,
          createdAt: DateTime.parse(row['created_at'] as String),
        );

        print('User found: ${user.email}');
        return user;
      }

      print('User not found with ID: $id');
      return null;
    } catch (e) {
      print('Get user by ID error: $e');
      return null;
    }
  }

  /// Carica la sessione offline se disponibile
  Future<User?> loadOfflineSession() async {
    try {
      print('Attempting to load offline session');
      final user = await SessionService.loadSession();
      if (user != null) {
        print('Offline session loaded for: ${user.email}');
      }
      return user;
    } catch (e) {
      print('Load offline session error: $e');
      return null;
    }
  }

  /// Cancella la sessione offline
  Future<void> clearOfflineSession() async {
    try {
      await SessionService.clearSession();
      print('Offline session cleared');
    } catch (e) {
      print('Clear offline session error: $e');
    }
  }

  /// Aggiorna la password dell'utente
  Future<bool> updatePassword(int userId, String oldPassword, String newPassword) async {
    try {
      print('Updating password for user ID: $userId');
      final client = await _getClient();

      // Recupera l'utente
      final result = await client.query(
        'SELECT * FROM users WHERE id = ?',
        positional: [userId],
      );

      if (result.isEmpty) {
        print('User not found');
        return false;
      }

      final row = result.first;
      final storedPassword = row['password'] as String;

      // Verifica la vecchia password
      if (!await _verifyPassword(oldPassword, storedPassword)) {
        print('Old password verification failed');
        return false;
      }

      // Cripta la nuova password
      final newHashedPassword = await _hashPassword(newPassword);

      // Aggiorna il database
      await client.execute(
        'UPDATE users SET password = ? WHERE id = ?',
        positional: [newHashedPassword, userId],
      );

      print('Password updated successfully for user: $userId');
      return true;
    } catch (e) {
      print('Update password error: $e');
      return false;
    }
  }
}
import 'package:libsql_dart/libsql_dart.dart';
import 'package:bcrypt/bcrypt.dart';
import '../models/user.dart';

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

  Future<User?> login(String email, String password) async {
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

  Future<User?> register(String email, String password, String nickname) async {
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

  Future<bool> checkEmailExists(String email) async {
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
}
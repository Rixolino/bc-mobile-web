import 'dart:convert';
import '../../../core/services/libsql_dart_web_stub.dart' if (dart.library.io) 'package:libsql_dart/libsql_dart.dart';
import '../models/favorite_item.dart';

class FavoritesRepository {
  static const String _tursoUrl = 'libsql://betacloud-transporter-rixolino.aws-eu-west-1.turso.io';
  static const String _tursoToken = 'eyJhbGciOiJFZERTQSIsInR5cCI6IkpXVCJ9.eyJhIjoicnciLCJpYXQiOjE3Njg2NTc3NDEsImlkIjoiMjI1ZTU0OTgtMmUxYS00ZWM3LTg0ZWUtMDlkMGRmM2YxOWMwIiwicmlkIjoiYWNkMDBiOGYtNTMxYS00MWMxLTk5YjQtYjg5ODc2YTJkMzVhIn0.nUl4jePNi0wZvxhdGvLlwk24EI9BL4jUvBoHKEMdGpatHD_bkn5V8PpcWvMujn4gwfNhmFmqNRH7JYjcjd9zBw';

  LibsqlClient? _client;

  Future<LibsqlClient> _getClient() async {
    if (_client != null) return _client!;

    try {
      print('Connecting to Turso database for favorites...');
      _client = LibsqlClient.remote(_tursoUrl, authToken: _tursoToken);
      await _client!.connect();
      await _initializeDatabase();
      print('Turso database connected successfully for favorites');
      return _client!;
    } catch (e) {
      print('Turso connection error for favorites: $e');
      rethrow;
    }
  }

  Future<void> _initializeDatabase() async {
    final client = await _getClient();
    await client.execute('''
      CREATE TABLE IF NOT EXISTS favorites (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        added_at TEXT NOT NULL
      )
    ''');
    print('Favorites table created/verified in Turso');
  }

  Future<List<FavoriteItem>> getFavorites(String userId) async {
    try {
      print('Getting favorites for user: $userId');
      final client = await _getClient();

      final result = await client.query(
        'SELECT * FROM favorites WHERE user_id = ? ORDER BY added_at DESC',
        positional: [userId],
      );

      final favorites = <FavoriteItem>[];
      for (final row in result) {
        try {
          final data = row['data'] as String;
          final jsonData = json.decode(data) as Map<String, dynamic>;

          // Aggiungi i campi mancanti dal database
          jsonData['id'] = row['id'];
          jsonData['userId'] = row['user_id'];
          jsonData['addedAt'] = row['added_at'];

          final favorite = FavoriteItem.fromJson(jsonData);
          favorites.add(favorite);
        } catch (e) {
          print('Error parsing favorite: $e');
        }
      }

      print('Retrieved ${favorites.length} favorites');
      return favorites;
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  Future<bool> addFavorite(FavoriteItem favorite) async {
    try {
      print('Adding favorite: ${favorite.id}');
      final client = await _getClient();

      // Converti l'oggetto in JSON rimuovendo i campi che sono già nel database
      final jsonData = favorite.toJson();
      jsonData.remove('id');
      jsonData.remove('userId');
      jsonData.remove('addedAt');

      await client.execute(
        'INSERT OR REPLACE INTO favorites (id, user_id, type, data, added_at) VALUES (?, ?, ?, ?, ?)',
        positional: [
          favorite.id,
          favorite.userId,
          favorite.type.name,
          json.encode(jsonData), // Salva come JSON string
          favorite.addedAt.toIso8601String(),
        ],
      );

      print('Favorite added successfully');
      return true;
    } catch (e) {
      print('Error adding favorite: $e');
      return false;
    }
  }

  Future<bool> removeFavorite(String favoriteId, String userId) async {
    try {
      print('Removing favorite: $favoriteId');
      final client = await _getClient();

      await client.execute(
        'DELETE FROM favorites WHERE id = ? AND user_id = ?',
        positional: [favoriteId, userId],
      );

      print('Favorite removed successfully');
      return true;
    } catch (e) {
      print('Error removing favorite: $e');
      return false;
    }
  }

  Future<bool> isFavorite(String favoriteId, String userId) async {
    try {
      final client = await _getClient();

      final result = await client.query(
        'SELECT COUNT(*) as count FROM favorites WHERE id = ? AND user_id = ?',
        positional: [favoriteId, userId],
      );

      final count = result.first['count'] as int;
      return count > 0;
    } catch (e) {
      print('Error checking if favorite: $e');
      return false;
    }
  }
}
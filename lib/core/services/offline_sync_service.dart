import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Service for managing offline caching of bus, train, and plane data.
/// Stores JSON data to local filesystem and metadata in SharedPreferences.
class OfflineSyncService {
  static const String _cacheDir = 'bc_transporter_offline_cache';
  static const String _metadataPrefix = 'offline_metadata_';
  static const String _lastSyncPrefix = 'offline_lastsync_';
  static const String _webDataPrefix = 'offline_webdata_';

  /// Saves transport data to local cache.
  /// [transportType] should be 'bus', 'train', or 'plane'.
  /// [identifier] is a unique key (e.g., city, station, route).
  static Future<void> saveTransportData({
    required String transportType,
    required String identifier,
    required dynamic data,
  }) async {
    try {
      if (kIsWeb) {
        await _saveTransportDataWeb(
          transportType: transportType,
          identifier: identifier,
          data: data,
        );
        return;
      }

      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${_safeFileName(identifier)}.json');
      
      final jsonStr = jsonEncode(data);
      await file.writeAsString(jsonStr);
      _logJson(
        label: 'SAVED $transportType/$identifier -> ${file.path}',
        jsonStr: jsonStr,
      );
      
      // Save metadata
      final prefs = await SharedPreferences.getInstance();
      final hash = jsonStr.hashCode.toString();
      await prefs.setString(
        '$_metadataPrefix${transportType}_$identifier',
        jsonEncode({'hash': hash, 'size': jsonStr.length}),
      );
      await prefs.setInt(
        '$_lastSyncPrefix${transportType}_$identifier',
        DateTime.now().millisecondsSinceEpoch,
      );
      
      debugPrint('[OfflineSync] Saved $transportType/$identifier (${jsonStr.length} bytes)');
    } catch (e) {
      debugPrint('[OfflineSync] Error saving data: $e');
    }
  }

  /// Retrieves cached transport data.
  /// Returns null if not cached or cache is corrupted.
  static Future<dynamic> getTransportData({
    required String transportType,
    required String identifier,
  }) async {
    try {
      if (kIsWeb) {
        return await _getTransportDataWeb(
          transportType: transportType,
          identifier: identifier,
        );
      }

      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${_safeFileName(identifier)}.json');
      
      if (!await file.exists()) {
        debugPrint('[OfflineSync] No cached data for $transportType/$identifier');
        return null;
      }
      
      final jsonStr = await file.readAsString();
      final data = jsonDecode(jsonStr);
      _logJson(
        label: 'LOADED $transportType/$identifier <- ${file.path}',
        jsonStr: jsonStr,
      );
      debugPrint('[OfflineSync] Retrieved cached $transportType/$identifier');
      return data;
    } catch (e) {
      debugPrint('[OfflineSync] Error retrieving data: $e');
      return null;
    }
  }

  /// Checks if data is cached for the given transport type and identifier.
  static Future<bool> isCached({
    required String transportType,
    required String identifier,
  }) async {
    try {
      if (kIsWeb) {
        return await _isCachedWeb(
          transportType: transportType,
          identifier: identifier,
        );
      }

      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${_safeFileName(identifier)}.json');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Deletes a single cached entry (file + metadata + last sync).
  /// Returns true if something was actually removed.
  static Future<bool> deleteTransportData({
    required String transportType,
    required String identifier,
  }) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        var removed = false;
        for (final key in [
          _webDataKey(transportType, identifier),
          '$_metadataPrefix${transportType}_${Uri.encodeComponent(identifier)}',
          '$_lastSyncPrefix${transportType}_${Uri.encodeComponent(identifier)}',
        ]) {
          if (prefs.containsKey(key)) {
            await prefs.remove(key);
            removed = true;
          }
        }
        debugPrint('[OfflineSync] Deleted $transportType/$identifier [web]: $removed');
        return removed;
      }

      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${_safeFileName(identifier)}.json');
      var removed = false;
      if (await file.exists()) {
        await file.delete();
        removed = true;
      }

      final prefs = await SharedPreferences.getInstance();
      for (final key in [
        '$_metadataPrefix${transportType}_$identifier',
        '$_lastSyncPrefix${transportType}_$identifier',
      ]) {
        if (prefs.containsKey(key)) {
          await prefs.remove(key);
          removed = true;
        }
      }

      debugPrint('[OfflineSync] Deleted $transportType/$identifier: $removed');
      return removed;
    } catch (e) {
      debugPrint('[OfflineSync] Error deleting data: $e');
      return false;
    }
  }

  /// Returns all cached identifiers for a specific transport type.
  static Future<List<String>> getAllCachedIdentifiers(String transportType) async {
    try {
      if (kIsWeb) {
        return await _getAllCachedIdentifiersWeb(transportType);
      }

      final cacheDir = await _getCacheDir();
      final dir = Directory(cacheDir.path);
      if (!await dir.exists()) return [];

      final files = dir.listSync();
      final List<String> identifiers = [];
      final prefix = '${transportType}_';

      for (var file in files) {
        if (file is File) {
          final fileName = file.path.split(Platform.pathSeparator).last;
          if (fileName.startsWith(prefix) && fileName.endsWith('.json')) {
            // Remove prefix and .json extension
            final id = fileName.substring(prefix.length, fileName.length - 5);
            identifiers.add(id);
          }
        }
      }
      return identifiers;
    } catch (e) {
      debugPrint('[OfflineSync] Error getting identifiers: $e');
      return [];
    }
  }

  /// Gets the last sync timestamp for cached data (milliseconds since epoch).
  /// Returns null if no cached data.
  static Future<int?> getLastSyncTime({
    required String transportType,
    required String identifier,
  }) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getInt('$_lastSyncPrefix${transportType}_${Uri.encodeComponent(identifier)}');
      }

      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt('$_lastSyncPrefix${transportType}_$identifier');
      return timestamp;
    } catch (e) {
      return null;
    }
  }

  /// Clears all cached data for a specific transport type.
  static Future<void> clearTransportCache(String transportType) async {
    try {
      if (kIsWeb) {
        await _clearTransportCacheWeb(transportType);
        return;
      }

      final cacheDir = await _getCacheDir();
      final dir = Directory(cacheDir.path);
      if (await dir.exists()) {
        final files = dir.listSync();
        for (var file in files) {
          if (file is File && file.path.contains('${transportType}_')) {
            await file.delete();
          }
        }
      }
      
      // Clear metadata
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.contains('${_metadataPrefix}${transportType}_') ||
            key.contains('${_lastSyncPrefix}${transportType}_')) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('[OfflineSync] Cleared cache for $transportType');
    } catch (e) {
      debugPrint('[OfflineSync] Error clearing cache: $e');
    }
  }

  /// Clears all cached data.
  static Future<void> clearAllCache() async {
    try {
      if (kIsWeb) {
        await _clearAllCacheWeb();
        return;
      }

      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
      
      // Clear all metadata from prefs
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (var key in keys) {
        if (key.startsWith(_metadataPrefix) || key.startsWith(_lastSyncPrefix)) {
          await prefs.remove(key);
        }
      }
      
      debugPrint('[OfflineSync] Cleared all cache');
    } catch (e) {
      debugPrint('[OfflineSync] Error clearing all cache: $e');
    }
  }

  /// Gets the total size of cached data in bytes.
  static Future<int> getCacheSize() async {
    try {
      if (kIsWeb) {
        return await _getCacheSizeWeb();
      }

      int totalSize = 0;
      final cacheDir = await _getCacheDir();
      if (await cacheDir.exists()) {
        final files = cacheDir.listSync(recursive: true);
        for (var file in files) {
          if (file is File) {
            totalSize += await file.length();
          }
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  static Future<Directory> _getCacheDir() async {
    if (kIsWeb) {
      throw UnsupportedError('Filesystem cache not available on web');
    }

    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  static String _safeFileName(String value) {
    return Uri.encodeComponent(value);
  }

  static String _webDataKey(String transportType, String identifier) {
    return '$_webDataPrefix${transportType}_${Uri.encodeComponent(identifier)}';
  }

  static Future<void> _saveTransportDataWeb({
    required String transportType,
    required String identifier,
    required dynamic data,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(data);
    final dataKey = _webDataKey(transportType, identifier);
    await prefs.setString(dataKey, jsonStr);
    await prefs.setString(
      '$_metadataPrefix${transportType}_${Uri.encodeComponent(identifier)}',
      jsonEncode({'hash': jsonStr.hashCode.toString(), 'size': jsonStr.length}),
    );
    await prefs.setInt(
      '$_lastSyncPrefix${transportType}_${Uri.encodeComponent(identifier)}',
      DateTime.now().millisecondsSinceEpoch,
    );
    _logJson(label: 'SAVED $transportType/$identifier -> $dataKey', jsonStr: jsonStr);
    debugPrint('[OfflineSync] Saved $transportType/$identifier (${jsonStr.length} bytes) [web]');
  }

  static Future<dynamic> _getTransportDataWeb({
    required String transportType,
    required String identifier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_webDataKey(transportType, identifier));
    if (jsonStr == null || jsonStr.isEmpty) {
      debugPrint('[OfflineSync] No cached data for $transportType/$identifier [web]');
      return null;
    }

    _logJson(label: 'LOADED $transportType/$identifier [web]', jsonStr: jsonStr);
    debugPrint('[OfflineSync] Retrieved cached $transportType/$identifier [web]');
    return jsonDecode(jsonStr);
  }

  static Future<bool> _isCachedWeb({
    required String transportType,
    required String identifier,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_webDataKey(transportType, identifier));
  }

  static Future<List<String>> _getAllCachedIdentifiersWeb(String transportType) async {
    final prefs = await SharedPreferences.getInstance();
    final prefix = '$_webDataPrefix${transportType}_';
    final identifiers = <String>[];

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      identifiers.add(Uri.decodeComponent(key.substring(prefix.length)));
    }

    return identifiers;
  }

  static Future<void> _clearTransportCacheWeb(String transportType) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final dataPrefix = '$_webDataPrefix${transportType}_';
    final metaPrefix = '$_metadataPrefix${transportType}_';
    final syncPrefix = '$_lastSyncPrefix${transportType}_';

    for (final key in keys) {
      if (key.startsWith(dataPrefix) || key.startsWith(metaPrefix) || key.startsWith(syncPrefix)) {
        await prefs.remove(key);
      }
    }

    debugPrint('[OfflineSync] Cleared cache for $transportType [web]');
  }

  static Future<void> _clearAllCacheWeb() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(_webDataPrefix) || key.startsWith(_metadataPrefix) || key.startsWith(_lastSyncPrefix)) {
        await prefs.remove(key);
      }
    }

    debugPrint('[OfflineSync] Cleared all cache [web]');
  }

  static Future<int> _getCacheSizeWeb() async {
    final prefs = await SharedPreferences.getInstance();
    int totalSize = 0;

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_webDataPrefix)) continue;
      final value = prefs.getString(key);
      if (value != null) {
        totalSize += value.length;
      }
    }

    return totalSize;
  }

  static void _logJson({
    required String label,
    required String jsonStr,
  }) {
    const chunkSize = 800;
    debugPrint('[OfflineSync][JSON] $label');

    for (var start = 0; start < jsonStr.length; start += chunkSize) {
      final end = (start + chunkSize < jsonStr.length)
          ? start + chunkSize
          : jsonStr.length;
      debugPrint('[OfflineSync][JSON] ${jsonStr.substring(start, end)}');
    }
  }
}

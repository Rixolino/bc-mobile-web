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

  /// Saves transport data to local cache.
  /// [transportType] should be 'bus', 'train', or 'plane'.
  /// [identifier] is a unique key (e.g., city, station, route).
  static Future<void> saveTransportData({
    required String transportType,
    required String identifier,
    required dynamic data,
  }) async {
    try {
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${identifier}.json');
      
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
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${identifier}.json');
      
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
      final cacheDir = await _getCacheDir();
      final file = File('${cacheDir.path}/${transportType}_${identifier}.json');
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// Gets the last sync timestamp for cached data (milliseconds since epoch).
  /// Returns null if no cached data.
  static Future<int?> getLastSyncTime({
    required String transportType,
    required String identifier,
  }) async {
    try {
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
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDir');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
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

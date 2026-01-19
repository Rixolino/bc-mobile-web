import 'dart:io';

import 'package:flutter/services.dart';

class AndroidBackgroundService {
  static const MethodChannel _channel = MethodChannel('com.example.bc_transporter_mobile/notifications');

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestPermission');
    } catch (e) {
      // ignore
    }
  }

  static Future<bool> hasNotificationPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final res = await _channel.invokeMethod('hasNotificationPermission');
      return res == true;
    } catch (e) {
      return true;
    }
  }

  static Future<void> scheduleWorkers() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleBackgroundWorkers');
    } catch (e) {
      // ignore
    }
  }

  static Future<void> cancelWorkers() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelBackgroundWorkers');
    } catch (e) {
      // ignore
    }
  }

  // Per-worker controls
  static Future<void> scheduleTrainsWorker({String? stationId, String? country, String? service, bool enableNotifications = true, String? endpoint, int? intervalSeconds}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleTrainsWorker', {
        'stationId': stationId,
        'country': country,
        'service': service,
        'enableNotifications': enableNotifications,
        'endpoint': endpoint,
        'intervalSeconds': intervalSeconds,
      });
    } catch (e) {}
  }

  static Future<void> cancelTrainsWorker() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelTrainsWorker');
    } catch (e) {}
  }

  static Future<void> scheduleBusesWorker({String? provider, String? baseUrl, bool enableNotifications = true, String? endpoint, int? intervalSeconds, String? stopId, String? stopName}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleBusesWorker', {
        'provider': provider,
        'baseUrl': baseUrl,
        'enableNotifications': enableNotifications,
        'endpoint': endpoint,
        'intervalSeconds': intervalSeconds,
        'stopId': stopId,
        'stopName': stopName,
      });
    } catch (e) {}
  }

  static Future<void> cancelBusesWorker() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelBusesWorker');
    } catch (e) {}
  }

  static Future<void> removeMonitoredStop(String stopId) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('removeMonitoredStop', {'stopId': stopId});
    } catch (e) {}
  }

  static Future<bool> isStopMonitored(String stopId) async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod('isStopMonitored', {'stopId': stopId});
      return res == true;
    } catch (e) {
      return false;
    }
  }

  static Future<void> scheduleFunctionsWorker({String? metric, String? baseUrl, bool enableNotifications = true, String? endpoint}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scheduleFunctionsWorker', {
        'metric': metric,
        'baseUrl': baseUrl,
        'enableNotifications': enableNotifications,
        'endpoint': endpoint,
      });
    } catch (e) {}
  }

  static Future<void> cancelFunctionsWorker() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelFunctionsWorker');
    } catch (e) {}
  }

  static Future<void> showNotification({required String channel, required String title, required String body, String? key}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('showNotification', {'channel': channel, 'title': title, 'body': body, 'key': key});
    } catch (e) {}
  }

  static Future<void> cancelNotification({required String key}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelNotification', {'key': key});
    } catch (e) {}
  }
}

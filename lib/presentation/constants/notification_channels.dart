class NotificationChannels {
  static const String trains = "trains_updates_channel";
  static const String buses = "buses_updates_channel";
  static const String functions = "functions_updates_channel";
  // New channel for proximity/station arrival alerts
  static const String trainProximity = "trains_proximity_channel";

  static const List<String> all = [trains, buses, functions, trainProximity];
}

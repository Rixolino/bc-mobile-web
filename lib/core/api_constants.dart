class ApiConstants {
  // 10.0.2.2 is the special alias to your host loopback interface (i.e., localhost) on the Android emulator.
  // Use your machine's local IP if testing on a real device.
  static const String baseUrl = "https://betacloud-transporter.is-cool.dev";
  
  static const String configEndpoint = "$baseUrl/api/config/transports";
  
  // Endpoint specifici (verranno sovrascritti dalla config dinamica se presente)
  static const String defaultTrainEndpoint = "https://prod.cuzimmartin.dev";
  static const String defaultAmtabEndpoint = "$baseUrl/api/it/bus/bari/bus-realtime";
  static const String defaultAtacEndpoint = "$baseUrl/api/rome-realtime";
  static const String defaultFlightRadarEndpoint = "$baseUrl/api/flightradar";
}

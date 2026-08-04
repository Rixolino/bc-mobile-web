import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
//  MODEL: Città dal geocoding
// ─────────────────────────────────────────────────────────────

class CityResult {
  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String? country;
  final String? region; // admin1

  const CityResult({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
    this.region,
  });

  factory CityResult.fromJson(Map<String, dynamic> j) => CityResult(
        id: j['id'] as int,
        name: j['name'] as String,
        latitude: (j['latitude'] as num).toDouble(),
        longitude: (j['longitude'] as num).toDouble(),
        country: j['country'] as String?,
        region: j['admin1'] as String?,
      );

  String get displayName {
    final parts = <String>[name];
    if (region != null && region!.isNotEmpty) parts.add(region!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }

  /// Salva questa città nelle preferenze
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('weather_city_id', id);
    await prefs.setString('weather_city_name', name);
    await prefs.setDouble('weather_city_lat', latitude);
    await prefs.setDouble('weather_city_lon', longitude);
    await prefs.setString('weather_city_display', displayName);
  }

  /// Carica l'ultima città salvata. Restituisce null se non esiste.
  static Future<CityResult?> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('weather_city_id');
    final name = prefs.getString('weather_city_name');
    final lat = prefs.getDouble('weather_city_lat');
    final lon = prefs.getDouble('weather_city_lon');
    if (id == null || name == null || lat == null || lon == null) return null;
    return CityResult(
      id: id,
      name: name,
      latitude: lat,
      longitude: lon,
      country: prefs.getString('weather_city_country'),
      region: prefs.getString('weather_city_region'),
    );
  }

  static Future<void> clearSaved() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('weather_city_id');
    await prefs.remove('weather_city_name');
    await prefs.remove('weather_city_lat');
    await prefs.remove('weather_city_lon');
    await prefs.remove('weather_city_display');
  }
}

// ─────────────────────────────────────────────────────────────
//  MODEL: Dati meteo correnti
// ─────────────────────────────────────────────────────────────

class WeatherData {
  final double temperature;
  final double windspeed;
  final int weathercode;
  final bool isDay;
  final double? precipitationProbability;
  final String cityName;

  const WeatherData({
    required this.temperature,
    required this.windspeed,
    required this.weathercode,
    required this.isDay,
    this.precipitationProbability,
    required this.cityName,
  });

  /// Descrizione testuale dal codice WMO
  String get condition {
    if (weathercode == 0) return 'Sereno';
    if (weathercode == 1) return 'Quasi sereno';
    if (weathercode == 2) return 'Parzialmente nuvoloso';
    if (weathercode == 3) return 'Nuvoloso';
    if (weathercode >= 45 && weathercode <= 48) return 'Nebbia';
    if (weathercode >= 51 && weathercode <= 55) return 'Pioggerella';
    if (weathercode >= 56 && weathercode <= 57) return 'Pioggerella gelata';
    if (weathercode >= 61 && weathercode <= 65) return 'Pioggia';
    if (weathercode >= 66 && weathercode <= 67) return 'Pioggia gelata';
    if (weathercode >= 71 && weathercode <= 77) return 'Neve';
    if (weathercode >= 80 && weathercode <= 82) return 'Rovesci';
    if (weathercode == 85 || weathercode == 86) return 'Neve a rovesci';
    if (weathercode >= 95 && weathercode <= 99) return 'Temporale';
    return 'Variabile';
  }

  /// Emoji icona dalla condizione + giorno/notte
  String get icon {
    if (weathercode == 0) return isDay ? '☀️' : '🌙';
    if (weathercode == 1) return isDay ? '🌤️' : '🌙';
    if (weathercode == 2) return '⛅';
    if (weathercode == 3) return '☁️';
    if (weathercode >= 45 && weathercode <= 48) return '🌫️';
    if (weathercode >= 51 && weathercode <= 55) return '🌦️';
    if (weathercode >= 56 && weathercode <= 65) return '🌧️';
    if (weathercode >= 66 && weathercode <= 67) return '🌨️';
    if (weathercode >= 71 && weathercode <= 77) return '❄️';
    if (weathercode >= 80 && weathercode <= 82) return '🌧️';
    if (weathercode == 85 || weathercode == 86) return '🌨️';
    if (weathercode >= 95 && weathercode <= 99) return '⛈️';
    return '🌈';
  }

  /// Colori gradient per la card meteo
  List<int> get gradientColors {
    if (weathercode == 0 && isDay) return [0xFFFF9A3C, 0xFFFFD700];
    if (weathercode == 0 && !isDay) return [0xFF1A237E, 0xFF311B92];
    if (weathercode <= 2) return [0xFF29B6F6, 0xFF0288D1];
    if (weathercode == 3) return [0xFF546E7A, 0xFF37474F];
    if (weathercode >= 45 && weathercode <= 48) return [0xFF90A4AE, 0xFF607D8B];
    if (weathercode >= 51 && weathercode <= 65) return [0xFF1565C0, 0xFF0D47A1];
    if (weathercode >= 71 && weathercode <= 77) return [0xFFB3E5FC, 0xFF81D4FA];
    if (weathercode >= 95) return [0xFF4A148C, 0xFF1A237E];
    return [0xFF1E88E5, 0xFF1565C0];
  }
}

// ─────────────────────────────────────────────────────────────
//  SERVICE: Geocoding (cerca città per nome)
// ─────────────────────────────────────────────────────────────

class GeocodingService {
  static const _geocodingUrl =
      'https://geocoding-api.open-meteo.com/v1/search';

  /// Cerca città per nome. Restituisce lista di risultati (massimo 10).
  static Future<List<CityResult>> searchCity(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final uri = Uri.parse(
        '$_geocodingUrl?name=${Uri.encodeComponent(query.trim())}'
        '&count=10&language=it&format=json',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final results = body['results'] as List<dynamic>?;
      if (results == null) return [];
      return results
          .map((e) => CityResult.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

// ─────────────────────────────────────────────────────────────
//  SERVICE: Meteo (fetch per coordinate)
// ─────────────────────────────────────────────────────────────

class WeatherService {
  static const _forecastUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch meteo per coordinate specifiche e nome città.
  static Future<WeatherData?> fetchWeatherForCoords({
    required double lat,
    required double lon,
    required String cityName,
  }) async {
    try {
      final uri = Uri.parse(
        '$_forecastUrl?latitude=$lat&longitude=$lon'
        '&current_weather=true'
        '&hourly=precipitation_probability'
        '&forecast_days=1'
        '&timezone=auto',
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final cw = json['current_weather'] as Map<String, dynamic>;

      double? precipProb;
      try {
        final hourly = json['hourly'] as Map<String, dynamic>;
        final probs = hourly['precipitation_probability'] as List<dynamic>;
        if (probs.isNotEmpty) {
          precipProb = (probs.first as num).toDouble();
        }
      } catch (_) {}

      return WeatherData(
        temperature: (cw['temperature'] as num).toDouble(),
        windspeed: (cw['windspeed'] as num).toDouble(),
        weathercode: (cw['weathercode'] as num).toInt(),
        isDay: (cw['is_day'] as num) == 1,
        precipitationProbability: precipProb,
        cityName: cityName,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetch meteo automatico:
  /// 1. Usa la città salvata (se presente)
  /// 2. Altrimenti usa GPS dell'utente
  /// 3. Fallback su Roma
  static Future<WeatherData?> fetchCurrentWeather() async {
    // 1. Città salvata?
    final savedCity = await CityResult.loadSaved();
    if (savedCity != null) {
      return fetchWeatherForCoords(
        lat: savedCity.latitude,
        lon: savedCity.longitude,
        cityName: savedCity.name,
      );
    }

    // 2. GPS
    double lat = 41.9028;
    double lon = 12.4964;
    String cityName = 'Roma';

    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 5),
        );
        lat = pos.latitude;
        lon = pos.longitude;
        cityName = 'La tua posizione';
      } else {
        final req = await Geolocator.requestPermission();
        if (req == LocationPermission.always ||
            req == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          lat = pos.latitude;
          lon = pos.longitude;
          cityName = 'La tua posizione';
        }
      }
    } catch (_) {}

    // 3. Fetch con le coordinate trovate
    return fetchWeatherForCoords(lat: lat, lon: lon, cityName: cityName);
  }
}

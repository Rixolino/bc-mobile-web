import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/api_constants.dart';
import '../models/regional_provider_model.dart';

class RegionalProvidersRepository {
  final Map<String, List<RegionalProvider>> _cache = {};

  Future<List<RegionalProvider>> fetchProviders(String country) async {
    if (_cache.containsKey(country)) {
      return _cache[country]!;
    }

    try {
      final url = '${ApiConstants.baseUrl}/api/train/regional_providers/$country';
      debugPrint('[RegionalProviders] Fetching: $url');
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final providersList = data['providers'] as List<dynamic>? ?? [];
        final providers = providersList
            .map((p) => RegionalProvider.fromJson(p))
            .toList();
        _cache[country] = providers;
        debugPrint('[RegionalProviders] Found ${providers.length} providers for $country');
        return providers;
      } else {
        debugPrint('[RegionalProviders] HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[RegionalProviders] Error: $e');
    }
    return [];
  }

  void clearCache() {
    _cache.clear();
  }
}

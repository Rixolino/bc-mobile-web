class BrandLogos {
  static const String _baseUrl = 'https://betacloud-transporter.is-cool.dev/assets/logos/autogrills';

  static const Map<String, String> _brandToFileName = {
    'autogrill': 'autogrill',
    'mychef': 'mychef',
    'my chef': 'mychef',
    'sarni': 'sarni',
    'chef express': 'chef express',
    'cigierre': 'cigierre',
    'roadhouse': 'roadhouse',
    'old wild west': 'old_wild_west',
    'bistrot': 'bistrot',
    'pizzeria': 'pizzeria',
    'caffè': 'caffe',
    'cafe': 'caffe',
    'bar': 'bar',
    'ristorante': 'ristorante',
    'restaurant': 'ristorante',
    'eni': 'eni',
    'enilive': 'eni',
    'q8': 'q8',
    'tamoil': 'tamoil',
    'ip': 'ip',
    'api': 'api',
    'total': 'total',
    'totalerg': 'total',
    'esso': 'esso',
    'shell': 'shell',
    'bp': 'bp',
    'free to x': 'free_to_x',
    'becharge': 'becharge',
    'enel x': 'enel_x',
    'enel': 'enel',
    'tesla': 'tesla',
    'ionity': 'ionity',
  };

  static String? getLogoUrl(String brandName) {
    final fileName = _getFileName(brandName);
    if (fileName != null) {
      return '$_baseUrl/$fileName.png';
    }
    return null;
  }

  static String? _getFileName(String brandName) {
    final normalized = brandName.toLowerCase().trim();
    
    for (final entry in _brandToFileName.entries) {
      if (normalized.contains(entry.key) || _normalizeForMatch(normalized).contains(_normalizeForMatch(entry.key))) {
        return entry.value;
      }
    }
    return null;
  }

  static String? getLocalLogoPath(String brandName) {
    final fileName = _getFileName(brandName);
    if (fileName != null) {
      return 'assets/logos/autogrills/$fileName.png';
    }
    return null;
  }

  static String _normalizeForMatch(String s) {
    return s.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  static bool hasLogo(String brandName) {
    return getLogoUrl(brandName) != null;
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:shimmer/shimmer.dart';
import 'package:marquee/marquee.dart';
import '../providers/train_provider.dart';
import '../../data/models/train_model.dart';
import '../../../../presentation/providers/settings_provider.dart';
import 'train_details_sheet.dart';
import '../../../../core/utils/country_time.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/design_system.dart';
import '../../../favorites/providers/favorites_provider.dart';
import '../../../favorites/models/favorite_stop.dart';
import '../../../auth/providers/auth_provider.dart';
import 'shimmer_and_toggle.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'routing_details_screen.dart';
import '../../../../core/services/tts_service.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../../../../core/services/train_presence_service.dart';
import 'regional_train_details_sheet.dart';
import '../../data/models/regional_provider_model.dart';
import '../../data/repositories/regional_providers_repository.dart';
import 'railway_station_stats_screen.dart' as station_stats;
import 'train_stats_screen.dart' as train_stats;
import 'package:intl/intl.dart';
import 'routing_search_screen.dart';

class TrainPanelContent extends StatefulWidget {
  final bool showModeToggle;
  const TrainPanelContent({super.key, this.showModeToggle = true});

  @override
  State<TrainPanelContent> createState() => _TrainPanelContentState();
}

class _TrainPanelContentState extends State<TrainPanelContent> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _trainSearchController = TextEditingController();
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  String _selectedCountry = '';
  String _selectedCity = '';
  String? _selectedPlatformFilter;

  List<Map<String, dynamic>> _dbTrainResults = [];
  bool _isSearchingDbTrain = false;
  Timer? _debounceTrainSearch;
  Timer? _refreshTimer;
  int _selectedIndex = 0;

  List<Map<String, String>> _countries = [];
  final Map<String, List<Map<String, String>>> _citiesByCountry = {};
  List<String> _countryOrder = [];
  bool _isOffline = false;
  Timer? _connectivityTimer;

  final Map<String, String> countryNames = {
    'AT': 'Austria',
    'BE': 'Belgio',
    'CH': 'Svizzera',
    'CZ': 'Rep. Ceca',
    'DE': 'Germania',
    'DK': 'Danimarca',
    'EE': 'Estonia',
    'ES': 'Spagna',
    'FI': 'Finlandia',
    'FR': 'Francia',
    'GB': 'Regno Unito',
    'GR': 'Grecia',
    'HU': 'Ungheria',
    'IE': 'Irlanda',
    'IT': 'Italia',
    'LU': 'Lussemburgo',
    'NL': 'Paesi Bassi',
    'NO': 'Norvegia',
    'PL': 'Polonia',
    'RO': 'Romania',
    'SE': 'Svezia',
    'SI': 'Slovenia',
    'FAL': 'Puglia (FAL)',
    'EU': 'Realtime EU',
  };

  bool _isMonitored = false;
  bool _checkingStatus = false;
  String? _lastCheckedStationId;

  List<dynamic> _cachedLiveTrains = [];
  bool _isLoadingLiveTrains = false;
  Timer? _liveTrainsRefreshTimer;
  bool _isFirstLiveLoad = true;

  // Treni più visualizzati adesso (classifica presence backend)
  List<Map<String, dynamic>> _mostViewedTrains = [];
  // Treni visti nell'ultima ora (storico backend 1h)
  List<Map<String, dynamic>> _recentTrains = [];
  // Totale utenti collegati adesso sui dettagli treno
  int _totalViewersLive = 0;
  // Sezioni comprimibili
  bool _mostViewedExpanded = true;
  bool _recentExpanded = false;

  bool _isSearchingRouting = false;
  Map<String, dynamic>? _routingData;
  TimeOfDay _selectedRoutingTime = TimeOfDay.now();
  DateTime _selectedRoutingDate = DateTime.now();
  String _selectedRoutingProvider = 'eurail';

  // Cache per i trip_id già cercati
  final Map<String, Map<String, dynamic>> _tripCache = {};

  // Firme per non ricostruire le liste se i dati non cambiano (anti-glitch).
  String _presenceSigLive = '';
  String _presenceSigRecent = '';
  String _liveSig = '';
  // Mutex + generazioni: niente poll sovrapposti e niente risposte
  // vecchie che sovrascrivono quelle nuove.
  bool _loadingLiveSection = false;
  int _liveSectionGen = 0;
  bool _loadingRecentSection = false;
  int _recentSectionGen = 0;
  bool _liveFetchActive = false;
  // Timer separati: live velocissimo (2s), recenti lenti (20s, cambiano piano).
  Timer? _recentRefreshTimer;
  Timer? _trainsCacheTimer;


  // Cache provider regionali per aprire la sheet giusta dai più visualizzati
  final Map<String, RegionalProvider> _regionalProvidersCache = {};
  final RegionalProvidersRepository _regionalProvidersRepo =
      RegionalProvidersRepository();

// TTS auto-annuncio: set di chiavi già annunciate (separato per arrivals/departures)
  final Set<String> _spokenDepartureKeys = {};
  final Set<String> _spokenArrivalKeys = {};
  final Set<String> _pendingDepartures = {};
  final Set<String> _pendingArrivals = {};
  bool? _lastArrivalMode;

  // Mappa dei fusi orari per paese
  static const Map<String, String> _timezoneMap = {
    'IT': 'Europe/Rome',
    'AT': 'Europe/Vienna',
    'CH': 'Europe/Zurich',
    'DE': 'Europe/Berlin',
    'FR': 'Europe/Paris',
    'ES': 'Europe/Madrid',
    'GB': 'Europe/London',
    'GR': 'Europe/Athens',
    'NL': 'Europe/Amsterdam',
    'BE': 'Europe/Brussels',
    'DK': 'Europe/Copenhagen',
    'NO': 'Europe/Oslo',
    'SE': 'Europe/Stockholm',
    'FI': 'Europe/Helsinki',
    'PL': 'Europe/Warsaw',
    'CZ': 'Europe/Prague',
    'HU': 'Europe/Budapest',
    'RO': 'Europe/Bucharest',
    'SI': 'Europe/Ljubljana',
    'LU': 'Europe/Luxembourg',
    'IE': 'Europe/Dublin',
    'EE': 'Europe/Tallinn',
    'LV': 'Europe/Riga',
    'LT': 'Europe/Vilnius',
    'SK': 'Europe/Bratislava',
    'HR': 'Europe/Zagreb',
    'RS': 'Europe/Belgrade',
    'BA': 'Europe/Sarajevo',
    'MK': 'Europe/Skopje',
    'AL': 'Europe/Tirane',
    'ME': 'Europe/Podgorica',
    'XK': 'Europe/Belgrade',
    'MT': 'Europe/Malta',
    'CY': 'Asia/Nicosia',
    'FAL': 'Europe/Rome',
    'EU': 'Europe/Rome',
  };

  String _getTimezoneForCountry(String countryCode) {
    if (countryCode == null || countryCode.isEmpty) return 'Europe/Rome';
    final upper = countryCode.toUpperCase();
    return _timezoneMap[upper] ?? 'Europe/Rome';
  }

  String _formatTimeWithTimezone(String timeStr, String? dateStr, String countryCode) {
    if (timeStr == null || timeStr.isEmpty || timeStr == '--:--') return '--:--';
    
    try {
      String datePart = dateStr ?? DateTime.now().toIso8601String().split('T').first;
      if (datePart.isEmpty) {
        datePart = DateTime.now().toIso8601String().split('T').first;
      }
      
      final fullDateStr = '$datePart $timeStr:00';
      final format = DateFormat('yyyy-MM-dd HH:mm:ss');
      
      DateTime utcTime;
      try {
        utcTime = format.parse(fullDateStr, true);
      } catch (e) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          final dateParts = datePart.split('-');
          if (dateParts.length == 3) {
            final year = int.tryParse(dateParts[0]) ?? DateTime.now().year;
            final month = int.tryParse(dateParts[1]) ?? DateTime.now().month;
            final day = int.tryParse(dateParts[2]) ?? DateTime.now().day;
            utcTime = DateTime.utc(year, month, day, hour, minute);
          } else {
            utcTime = DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, minute);
          }
        } else {
          return timeStr;
        }
      }
      
      final targetTime = utcTime.toLocal();
      return DateFormat('HH:mm').format(targetTime);
    } catch (e) {
      return timeStr;
    }
  }

  int _calculateDurationMinutes(String departureTime, String arrivalTime, String? departureDate, String? arrivalDate, String countryCode) {
    try {
      final dep = _formatTimeWithTimezone(departureTime, departureDate, countryCode);
      final arr = _formatTimeWithTimezone(arrivalTime, arrivalDate, countryCode);
      
      if (dep == '--:--' || arr == '--:--') return 0;
      
      final depParts = dep.split(':');
      final arrParts = arr.split(':');
      
      if (depParts.length < 2 || arrParts.length < 2) return 0;
      
      int depHour = int.tryParse(depParts[0]) ?? 0;
      int depMin = int.tryParse(depParts[1]) ?? 0;
      int arrHour = int.tryParse(arrParts[0]) ?? 0;
      int arrMin = int.tryParse(arrParts[1]) ?? 0;
      
      if (arrHour < depHour || (arrHour == depHour && arrMin < depMin)) {
        arrHour += 24;
      }
      
      int depTotalMin = depHour * 60 + depMin;
      int arrTotalMin = arrHour * 60 + arrMin;
      
      return arrTotalMin - depTotalMin;
    } catch (e) {
      return 0;
    }
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }

  // ==================== FUNZIONI HELPER PER NORMALIZZAZIONE DATI ====================

  String _extractTimeFromIso(dynamic isoValue) {
    if (isoValue == null) return '--:--';
    final isoString = isoValue.toString();
    if (isoString.isEmpty) return '--:--';
    try {
      final date = DateTime.parse(isoString);
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '--:--';
    }
  }

  String _extractDateFromIso(dynamic isoValue) {
    if (isoValue == null) return '';
    final isoString = isoValue.toString();
    if (isoString.isEmpty) return '';
    try {
      final date = DateTime.parse(isoString);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  int _calculateWaitMinutes(dynamic arrivalIso, dynamic departureIso) {
    if (arrivalIso == null || departureIso == null) return 0;
    try {
      final arrival = DateTime.parse(arrivalIso.toString());
      final departure = DateTime.parse(departureIso.toString());
      final diff = departure.difference(arrival);
      return diff.inMinutes > 0 ? diff.inMinutes : 0;
    } catch (_) {
      return 0;
    }
  }

  String _extractCountryFromTrain(dynamic train) {
    if (train == null) return 'EU';
    
    // Se train è una lista, prendi il primo elemento
    dynamic trainData = train;
    if (train is List && train.isNotEmpty) {
      trainData = train.first;
    }
    
    if (trainData is! Map<String, dynamic>) return 'EU';
    
    final country = trainData['country'] ?? trainData['countryCode'] ?? trainData['provider'];
    if (country != null && country is String && country.isNotEmpty) {
      if (country.length == 2) return country.toUpperCase();
    }
    
    final operator = trainData['operatorName'] ?? trainData['denomination'] ?? trainData['operator'] ?? '';
    final operatorMap = {
      'Trenitalia': 'IT',
      'Italo': 'IT',
      'ÖBB': 'AT',
      'DB': 'DE',
      'SNCF': 'FR',
      'Renfe': 'ES',
      'SBB': 'CH',
      'CFF': 'CH',
      'NS': 'NL',
      'SNCB': 'BE',
      'NMBS': 'BE',
      'DSB': 'DK',
      'VR': 'FI',
      'SJ': 'SE',
      'PKP': 'PL',
      'ČD': 'CZ',
      'MAV': 'HU',
      'CFR': 'RO',
      'FS': 'IT',
      'nationalExpress': 'DE',
      'ICE': 'DE',
      'IC': 'IT',
      'EC': 'EU',
      'RJ': 'AT',
      'NJ': 'AT',
      'WB': 'AT',
      'EN': 'EU',
      'TGV': 'FR',
      'AVE': 'ES',
      'Eurostar': 'GB',
      'FRECCIAROSSA': 'IT',
      'Frecciarossa': 'IT',
      'InterCityNotte': 'IT',
      'Intercity': 'IT',
      'EuroCity': 'EU',
      'Euro Night': 'EU',
      'Railjet': 'AT',
      'Night Jet': 'AT',
    };
    
    for (final entry in operatorMap.entries) {
      if (operator.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    final trainName = trainData['description'] ?? trainData['name'] ?? '';
    for (final entry in operatorMap.entries) {
      if (trainName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }
    
    return 'EU';
  }

  String _getCountryCodeForSolution(Map<String, dynamic> solution) {
    final percorso = solution['percorso'] as List? ?? [];
    if (percorso.isNotEmpty) {
      final firstLeg = percorso.first as Map<String, dynamic>?;
      if (firstLeg != null) {
        final country = firstLeg['country'] ?? firstLeg['countryCode'] ?? firstLeg['provider'] ?? firstLeg['operator'];
        if (country != null && country is String && country.isNotEmpty) {
          if (country.length == 2) return country.toUpperCase();
          final operatorMap = {
            'Trenitalia': 'IT',
            'Italo': 'IT',
            'ÖBB': 'AT',
            'DB': 'DE',
            'SNCF': 'FR',
            'Renfe': 'ES',
            'SBB': 'CH',
            'CFF': 'CH',
            'NS': 'NL',
            'SNCB': 'BE',
            'NMBS': 'BE',
            'DSB': 'DK',
            'VR': 'FI',
            'SJ': 'SE',
            'PKP': 'PL',
            'ČD': 'CZ',
            'MAV': 'HU',
            'CFR': 'RO',
            'FS': 'IT',
            'nationalExpress': 'DE',
            'ICE': 'DE',
            'IC': 'IT',
            'EC': 'EU',
            'RJ': 'AT',
            'NJ': 'AT',
            'WB': 'AT',
            'EN': 'EU',
            'TGV': 'FR',
            'AVE': 'ES',
            'Eurostar': 'GB',
          };
          final operator = firstLeg['operator'] ?? firstLeg['denomination'] ?? '';
          for (final entry in operatorMap.entries) {
            if (country.toLowerCase().contains(entry.key.toLowerCase()) ||
                operator.toLowerCase().contains(entry.key.toLowerCase())) {
              return entry.value;
            }
          }
        }
      }
    }
    return 'IT';
  }

  // ==================== NORMALIZZAZIONE DATI ROUTING ====================

  Map<String, dynamic> _normalizeRoutingData(Map<String, dynamic> rawData) {
    // Controlla se la risposta contiene un errore
    if (rawData['ok'] == false) {
      final errorMsg = rawData['error'] ?? 'Errore sconosciuto';
      debugPrint('❌ Errore dal backend: $errorMsg');
      return {
        'ok': false,
        'error': errorMsg,
        'totaleSoluzioni': 0,
        'soluzioni': [],
        'richiesta': {
          'from': _originController.text,
          'to': _destinationController.text,
        },
      };
    }

    final provider = rawData['provider'] ?? 'eurail';
    
    // Se è RFI (provider "rfi"), normalizza i dati dal campo 'data'
    if (provider == 'rfi' && rawData['data'] != null) {
      return _normalizeRfiData(rawData);
    }
    
    // Se è Eurail, normalizza i dati
    if (provider == 'eurail' && rawData['data'] != null) {
      return _normalizeEurailData(rawData);
    }
    
    // Fallback: se i dati sono già nel formato atteso (soluzioni)
    if (rawData['soluzioni'] != null) {
      return rawData;
    }
    
    // Se non riconosce il formato, restituisce array vuoto
    return {
      'ok': true,
      'provider': 'unknown',
      'totaleSoluzioni': 0,
      'soluzioni': [],
      'richiesta': {
        'from': _originController.text,
        'to': _destinationController.text,
      },
    };
  }

  Map<String, dynamic> _normalizeRfiData(Map<String, dynamic> rawData) {
    final rfiData = rawData['data'];
    if (rfiData == null) {
      return {
        'ok': true,
        'provider': 'rfi',
        'totaleSoluzioni': 0,
        'soluzioni': [],
        'richiesta': {
          'from': _originController.text,
          'to': _destinationController.text,
        },
      };
    }
    
    final rfiSolutions = rfiData['solutions'] as List? ?? [];
    final normalizedSolutions = <Map<String, dynamic>>[];
    
    for (int s = 0; s < rfiSolutions.length; s++) {
      final solutionWrapper = rfiSolutions[s];
      if (solutionWrapper is! Map<String, dynamic>) continue;
      
      final solution = solutionWrapper['solution'] as Map<String, dynamic>?;
      if (solution == null) continue;
      
      final nodes = solution['nodes'] as List? ?? [];
      final trains = solution['trains'] as List? ?? [];
      final percorso = <Map<String, dynamic>>[];
      
      for (int n = 0; n < nodes.length; n++) {
        final node = nodes[n];
        if (node is! Map<String, dynamic>) continue;
        
        final trainInfo = n < trains.length ? trains[n] : null;
        final trainInfoMap = (trainInfo is Map<String, dynamic>) ? trainInfo : null;
        final nodeTrain = node['train'] as Map<String, dynamic>?;
        
        final leg = <String, dynamic>{
          'da': node['origin']?.toString() ?? '--',
          'a': node['destination']?.toString() ?? '--',
          'partenza': _extractTimeFromIso(node['departureTime']),
          'arrivo': _extractTimeFromIso(node['arrivalTime']),
          'dataPartenza': _extractDateFromIso(node['departureTime']),
          'dataArrivo': _extractDateFromIso(node['arrivalTime']),
          'categoria': trainInfoMap?['trainCategory']?.toString() ?? nodeTrain?['trainCategory']?.toString() ?? 'TRN',
          'numeroTreno': trainInfoMap?['description']?.toString() ?? nodeTrain?['description']?.toString() ?? '',
          'durataLeggibile': node['duration']?.toString() ?? solution['duration']?.toString() ?? '--:--',
          'country': _extractCountryFromTrain(trainInfo ?? nodeTrain),
          'stops': (node['stops'] as List?)?.map((s) => s.toString()).toList() ?? [],
          'operator': trainInfoMap?['denomination']?.toString() ?? nodeTrain?['denomination']?.toString() ?? '',
          'platform': node['platform']?.toString() ?? '',
          'attesaCambioMinuti': 0,
        };
        
        // Calcola attesa cambio
        if (n < nodes.length - 1) {
          final nextNode = nodes[n + 1];
          if (nextNode is Map<String, dynamic>) {
            final waitMinutes = _calculateWaitMinutes(
              node['arrivalTime'],
              nextNode['departureTime'],
            );
            leg['attesaCambioMinuti'] = waitMinutes > 0 ? waitMinutes : 0;
          }
        }
        
        percorso.add(leg);
      }
      
      if (percorso.isEmpty) continue;
      
      // Calcola totale fermate
      int totalStops = 0;
      for (final node in nodes) {
        if (node is Map<String, dynamic>) {
          final stops = node['stops'] as List?;
          if (stops != null) totalStops += stops.length;
        }
      }
      
      // Estrai prezzo
      double price = 0;
      final priceData = solution['price'];
      if (priceData is num) {
        price = priceData.toDouble();
      } else if (priceData is Map) {
        final amount = priceData['amount'];
        if (amount is num) {
          price = amount.toDouble();
        }
      }
      
      normalizedSolutions.add({
        'percorso': percorso,
        'cambi': nodes.length - 1,
        'durataViaggioTotaleLeggibile': solution['duration']?.toString() ?? '--:--',
        'arrivoStimato': _extractTimeFromIso(solution['arrivalTime']),
        'dataArrivoStimata': _extractDateFromIso(solution['arrivalTime']),
        'totaleFermate': totalStops,
        'prezzo': price,
        'moneta': 'EUR',
        'id': solution['id']?.toString() ?? 'rfi_${DateTime.now().millisecondsSinceEpoch}',
      });
    }
    
    return {
      'ok': true,
      'provider': 'rfi',
      'totaleSoluzioni': normalizedSolutions.length,
      'soluzioni': normalizedSolutions,
      'richiesta': {
        'from': _originController.text,
        'to': _destinationController.text,
      },
    };
  }

Map<String, dynamic> _normalizeEurailData(Map<String, dynamic> rawData) {
  final eurailData = rawData['data'];
  
  if (eurailData == null) {
    return {
      'ok': true,
      'provider': 'eurail',
      'totaleSoluzioni': 0,
      'soluzioni': [],
      'richiesta': {
        'from': _originController.text,
        'to': _destinationController.text,
      },
    };
  }
  
  final journeys = (eurailData is List) 
      ? eurailData 
      : (eurailData['data'] as List? ?? eurailData['journeys'] as List? ?? []);
  
  if (journeys.isEmpty) {
    debugPrint('⚠️ Nessun viaggio trovato da Eurail');
    return {
      'ok': true,
      'provider': 'eurail',
      'totaleSoluzioni': 0,
      'soluzioni': [],
      'richiesta': {
        'from': _originController.text,
        'to': _destinationController.text,
      },
    };
  }
  
  final normalizedSolutions = <Map<String, dynamic>>[];
  
  for (int j = 0; j < journeys.length; j++) {
    final journey = journeys[j];
    
    if (journey is! Map<String, dynamic>) {
      debugPrint('⚠️ Journey $j non è una Map: ${journey.runtimeType}');
      continue;
    }
    
    final legs = journey['legs'] as List? ?? [];
    final percorso = <Map<String, dynamic>>[];
    
    for (int l = 0; l < legs.length; l++) {
      final leg = legs[l];
      
      if (leg is! Map<String, dynamic>) {
        debugPrint('⚠️ Leg $l non è una Map: ${leg.runtimeType}');
        continue;
      }
      
      final legType = leg['type'] as String? ?? '';
      if (legType == 'PLATFORM_CHANGE' || legType == 'STATION_CHANGE_WALK') {
        continue;
      }
      
      final start = leg['start'] as Map<String, dynamic>? ?? {};
      final end = leg['end'] as Map<String, dynamic>? ?? {};
      final transport = leg['transport'] as Map<String, dynamic>? ?? {};
      
      // ================================================================
      // LOGICA MIGLIORATA PER ESTRAZIONE CATEGORIA
      // ================================================================
      final rawCode = transport['code']?.toString() ?? transport['trainNumber']?.toString() ?? '';
      
      // 1. Prova a estrarre dal codice (es. "FR 8830" → "FR")
      String categoriaEstratta = '';
      if (rawCode.isNotEmpty) {
        final match = RegExp(r'^[a-zA-Z]+').stringMatch(rawCode);
        if (match != null && match.isNotEmpty) {
          categoriaEstratta = match;
        }
      }
      
      // 2. Se non è stata estratta, usa trainType o type
      if (categoriaEstratta.isEmpty) {
        final trainType = transport['trainType']?.toString() ?? transport['type']?.toString() ?? '';
        if (trainType.isNotEmpty && trainType != 'TRN') {
          categoriaEstratta = trainType;
        }
      }
      
      // 3. Se ancora vuota, prova dal serviceName
      if (categoriaEstratta.isEmpty) {
        final serviceName = transport['serviceName']?.toString() ?? transport['operatorName']?.toString() ?? '';
        if (serviceName.isNotEmpty) {
          final serviceMatch = RegExp(r'^[A-Z]+').stringMatch(serviceName);
          if (serviceMatch != null && serviceMatch.isNotEmpty) {
            categoriaEstratta = serviceMatch;
          }
        }
      }
      
      // 4. Fallback finale
      if (categoriaEstratta.isEmpty) {
        categoriaEstratta = 'TRN';
      }
      // ================================================================

      // Per il numero del treno, usa trainNumber o code o estrai dal codice
      String numeroTreno = transport['trainNumber']?.toString() ?? '';
      if (numeroTreno.isEmpty) {
        final code = transport['code']?.toString() ?? '';
        // Se il codice contiene numeri, estraili
        final numberMatch = RegExp(r'\d+').stringMatch(code);
        if (numberMatch != null && numberMatch.isNotEmpty) {
          numeroTreno = numberMatch;
        } else {
          numeroTreno = code;
        }
      }

      final legData = <String, dynamic>{
        'da': start['station']?.toString() ?? '--',
        'a': end['station']?.toString() ?? '--',
        'partenza': _extractTimeFromIso(start['dateTimeInISO']),
        'arrivo': _extractTimeFromIso(end['dateTimeInISO']),
        'dataPartenza': _extractDateFromIso(start['dateTimeInISO']),
        'dataArrivo': _extractDateFromIso(end['dateTimeInISO']),
        'categoria': categoriaEstratta,
        'numeroTreno': numeroTreno,
        'country': start['country']?.toString() ?? end['country']?.toString() ?? 'EU',
        'operator': transport['operatorName']?.toString() ?? transport['type']?.toString() ?? '',
        'platform': end['track']?.toString() ?? start['track']?.toString() ?? '',
        'attesaCambioMinuti': 0,
      };
      
      // Durata del leg
      final duration = leg['duration'] as Map<String, dynamic>?;
      if (duration != null) {
        final hours = duration['hours'] as int? ?? 0;
        final minutes = duration['minutes'] as int? ?? 0;
        legData['durataLeggibile'] = '$hours h $minutes m';
      } else {
        legData['durataLeggibile'] = '--:--';
      }
      
      // Stops
      final stopsData = leg['stops'] as Map<String, dynamic>?;
      if (stopsData != null) {
        final stopsList = stopsData['stops'] as List? ?? [];
        legData['stops'] = stopsList.map((s) {
          if (s is Map<String, dynamic>) {
            return s['station']?.toString() ?? '--';
          }
          return s.toString();
        }).toList();
      } else {
        legData['stops'] = [];
      }
      
      // Calcola attesa cambio
      if (percorso.isNotEmpty) {
        final prevLeg = percorso.last;
        final prevArrivo = prevLeg['arrivo'] as String? ?? '--:--';
        final prevData = prevLeg['dataArrivo'] as String? ?? '';
        final currPartenza = legData['partenza'] as String? ?? '--:--';
        final currData = legData['dataPartenza'] as String? ?? '';
        
        if (prevArrivo != '--:--' && currPartenza != '--:--') {
          try {
            final prevDateTime = DateTime.parse('$prevData $prevArrivo:00');
            final currDateTime = DateTime.parse('$currData $currPartenza:00');
            if (currDateTime.isAfter(prevDateTime)) {
              legData['attesaCambioMinuti'] = currDateTime.difference(prevDateTime).inMinutes;
            }
          } catch (_) {}
        }
      }
      
      percorso.add(legData);
    }
    
    if (percorso.isEmpty) continue;
    
    // Durata totale del viaggio
    final journeyDuration = journey['duration'] as Map<String, dynamic>?;
    String durataTotale = '--:--';
    if (journeyDuration != null) {
      final hours = journeyDuration['hours'] as int? ?? 0;
      final minutes = journeyDuration['minutes'] as int? ?? 0;
      durataTotale = '$hours h $minutes m';
    }
    
    // Calcola totale fermate
    int totalStops = 0;
    for (final leg in percorso) {
      final stops = leg['stops'] as List?;
      if (stops != null) totalStops += stops.length;
    }
    
    // Estrai il prezzo
    double price = 0;
    final priceData = journey['price'];
    if (priceData is num) {
      price = priceData.toDouble();
    } else if (priceData is Map) {
      final amount = priceData['amount'];
      if (amount is num) {
        price = amount.toDouble();
      }
    }
    
    normalizedSolutions.add({
      'percorso': percorso,
      'cambi': percorso.length - 1,
      'durataViaggioTotaleLeggibile': durataTotale,
      'arrivoStimato': _extractTimeFromIso(journey['arrival']),
      'dataArrivoStimata': _extractDateFromIso(journey['arrival']),
      'totaleFermate': totalStops,
      'prezzo': price,
      'moneta': 'EUR',
      'id': journey['id']?.toString() ?? 'eurail_${DateTime.now().millisecondsSinceEpoch}',
    });
  }
  
  return {
    'ok': true,
    'provider': 'eurail',
    'totaleSoluzioni': normalizedSolutions.length,
    'soluzioni': normalizedSolutions,
    'richiesta': {
      'from': _originController.text,
      'to': _destinationController.text,
    },
  };
}

  // ==================== FUNZIONI ESISTENTI ====================

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _startConnectivityMonitor();
    _startLiveTrainsRefresh();

    // Auto-TTS: ascolta i cambiamenti delle partenze
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<TrainProvider>(context, listen: false);
      provider.addListener(_onDeparturesChanged);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _trainSearchController.dispose();
    _originController.dispose();
    _destinationController.dispose();
    _connectivityTimer?.cancel();
    _debounceTrainSearch?.cancel();
    _liveTrainsRefreshTimer?.cancel();
    _recentRefreshTimer?.cancel();
    _trainsCacheTimer?.cancel();
    _refreshTimer?.cancel();

    // Sospendi TTS e svuota coda
    try {
      print('[TTS-Board] dispose → suspend()');
      TtsService().suspend();
    } catch (_) {}

    // Rimuovi listener TTS
    try {
      final provider = Provider.of<TrainProvider>(context, listen: false);
      provider.removeListener(_onDeparturesChanged);
    } catch (_) {}

    super.dispose();
  }

  void _onDeparturesChanged() {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    if (!settings.ttsEnabled) return;

    final provider = Provider.of<TrainProvider>(context, listen: false);
    final current = provider.departures;
    final isArrivals = provider.isArrivalMode;

    print('[TTS-Board] _onDeparturesChanged: ${current.length} treni, isArrivals=$isArrivals');

    // Se è cambiata la modalità, resetta
    if (_lastArrivalMode != null && _lastArrivalMode != isArrivals) {
      _spokenDepartureKeys.clear();
      _spokenArrivalKeys.clear();
      _pendingDepartures.clear();
      _pendingArrivals.clear();
    }
    _lastArrivalMode = isArrivals;

    final spokenKeys = isArrivals ? _spokenArrivalKeys : _spokenDepartureKeys;
    final pendingKeys = isArrivals ? _pendingArrivals : _pendingDepartures;
    final now = DateTime.now();

    String? textToSpeak;
    String? textTrainKey;

    // Helper: calcola ora effettiva e se è nella finestra
    bool isInWindow(TrainDeparture dep) {
      final schedTime = dep.scheduledTime;
      final estTime = dep.estimatedTime;
      final delay = dep.delayMinutes ?? 0;

      // L'orario "atteso" da scheduledTime + delay è sempre calcolato quando
      // possibile: è il valore più affidabile, perché 'delay' viene aggiornato
      // ad ogni refresh mentre 'estimatedTime' può arrivare nullo o non
      // allineato al ritardo più recente (es. dopo un aggiornamento parziale
      // che tocca solo il campo delay). Se scheduledTime manca, si usa
      // estimatedTime come fallback.
      DateTime? effectiveTime;
      if (schedTime != null) {
        effectiveTime = schedTime.add(Duration(minutes: delay));
        // Se l'API fornisce un estimatedTime esplicito che indica un ritardo
        // maggiore rispetto a scheduledTime + delay (es. delay non ancora
        // aggiornato ma estimatedTime sì), usa il più "tardivo" dei due per
        // non annunciare in anticipo.
        if (estTime != null && estTime.isAfter(effectiveTime)) {
          effectiveTime = estTime;
        }
      } else if (estTime != null) {
        effectiveTime = estTime;
      }

      if (effectiveTime == null) return false;
      final diff = effectiveTime.difference(now).inMinutes;
      // Annuncia circa 1 minuto prima dell'orario effettivo (±1 min per margine)
      return diff >= -2 && diff <= 1;
    }

    final currentKeys = current.map(_trainKey).toSet();

    // Aggiorna i treni attivi nel TTS service — scarta dalla coda quelli che non ci sono più
    final tts = TtsService();
    tts.updateActiveTrains(currentKeys);

    // Pulisci pending di treni che non sono più nella lista
    pendingKeys.removeWhere((k) => !currentKeys.contains(k));

    // 1. Controlla TUTTI i treni in attesa: se sono entrati nella finestra, annuncia
    for (final pendingKey in pendingKeys.toList()) {
      final dep = current.cast<TrainDeparture?>().firstWhere(
        (d) => _trainKey(d!) == pendingKey,
        orElse: () => null,
      );
      if (dep == null) {
        pendingKeys.remove(pendingKey);
        continue;
      }
      if (isInWindow(dep)) {
        pendingKeys.remove(pendingKey);
        spokenKeys.add(pendingKey);
        textToSpeak = _buildTtsText(dep, isArrivals, settings);
        textTrainKey = pendingKey;
        break;
      }
    }

    // 2. Se non c'è nulla da parlare, controlla treni nuovi
    if (textToSpeak == null) {
      for (final dep in current) {
        final key = _trainKey(dep);

        // Già annunciato o già in pending → skip
        if (spokenKeys.contains(key) || pendingKeys.contains(key)) {
          continue;
        }

        if (isInWindow(dep)) {
          // Nuovo treno in finestra: annuncia subito
          spokenKeys.add(key);
          textToSpeak = _buildTtsText(dep, isArrivals, settings);
          textTrainKey = key;
          break;
        } else {
          // Nuovo treno fuori finestra: metti in pending
          pendingKeys.add(key);
        }
      }
    }

    // Pulisci chiavi vecchie
    if (spokenKeys.length > 200) {
      spokenKeys.removeWhere((k) => !currentKeys.contains(k));
    }
    if (pendingKeys.length > 200) {
      pendingKeys.removeWhere((k) => !currentKeys.contains(k));
    }

    // Aggiorna TTS con le chiavi di ENTRAMBI i modi (departures + arrivals)
    // in modo che l'annuncio funzioni sia visualizzando arrivi sia partenze
    final allTrainKeys = <String>{};
    allTrainKeys.addAll(_spokenDepartureKeys);
    allTrainKeys.addAll(_spokenArrivalKeys);
    if (allTrainKeys.isNotEmpty) {
      tts.updateActiveTrains(allTrainKeys);
    }

    // Parla
    if (textToSpeak != null && textToSpeak.isNotEmpty) {
      print('[TTS-Board] announce: key=$textTrainKey');
      final langCode = settings.appLocale?.languageCode ?? 'it';
      tts.setLanguage(langCode);
      final voices = TtsService.getVoicesForLanguage(langCode);
      final selected = voices.firstWhere(
        (v) => v.name == settings.ttsVoiceForLang(langCode),
        orElse: () => voices.isNotEmpty ? voices.first : const OddcastVoice(name: 'Roberto', id: 7, engine: 2, gender: 'M'),
      );
      tts.setSelectedVoice(selected);
      tts.speak(textToSpeak, trainKey: textTrainKey);
    } else {
      print('[TTS-Board] niente da annunciare');
    }
  }

  String _trainKey(TrainDeparture dep) {
    final cat = dep.category ?? '';
    final num = dep.trainNumber ?? '';
    final time = dep.scheduledTime?.toIso8601String() ?? '';
    return '$cat|$num|$time';
  }

  String _buildTtsText(TrainDeparture dep, bool isArrivals, SettingsProvider settings) {
    final langCode = settings.appLocale?.languageCode ?? 'it';
    return TtsService.buildAnnouncement(
      category: dep.category,
      trainNumber: dep.trainNumber?.toString(),
      isArrival: isArrivals,
      origin: dep.origin,
      destination: dep.destination,
      scheduledTime: dep.scheduledTime,
      estimatedTime: dep.estimatedTime,
      delayMinutes: dep.delayMinutes ?? 0,
      platform: dep.platform?.toString(),
      langCode: langCode,
      operator: dep.operator,
    );
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _startConnectivityMonitor() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkConnectivity());
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    bool hasInternet = true;
    if (!kIsWeb) {
      Socket? socket;
      try {
        socket = await Socket.connect('1.1.1.1', 53, timeout: const Duration(seconds: 2));
        hasInternet = true;
      } catch (_) {
        hasInternet = false;
      } finally {
        socket?.destroy();
      }
    }
    if (mounted && _isOffline != !hasInternet) {
      final wasOffline = _isOffline;
      _safeSetState(() => _isOffline = !hasInternet);
      if (wasOffline && hasInternet) {
        final provider = Provider.of<TrainProvider>(context, listen: false);
        final displayedCountries = provider.selectedService == 'direct'
            ? _countries.where((c) => ['IT', 'FAL', 'EU'].contains(c['code'])).toList()
            : _countries;
        _onSearchChanged(_searchController.text, provider, displayedCountries);
        _loadLiveTrains(silent: true);
        _loadMostViewed();
      }
    }
  }

  // La lista /api/trains/live non è più mostrata (sostituita dalle sezioni
  // presence), ma resta caricata in sottofondo per risolvere i dati
  // completi al tap sulle card.
  Future<List<dynamic>> _loadLiveTrains({bool silent = false}) async {
    if (_isOffline) return [];
    if (!mounted) return [];
    // Niente fetch sovrapposti (poll ogni 5s, timeout 10s).
    if (_liveFetchActive) return _cachedLiveTrains;
    _liveFetchActive = true;

    if (!silent && _isFirstLiveLoad) {
      _safeSetState(() => _isLoadingLiveTrains = true);
    }

    try {
      final response = await http
          .get(Uri.parse('https://betacloud-transporter.is-cool.dev/api/trains/live'))
          .timeout(const Duration(seconds: 10));
      if (!mounted) return [];
      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data'] ?? [];
        // Stessi dati: nessun setState, nessun glitch.
        final sig = data is List
            ? data
                .map((e) => e is Map
                    ? "${e['trip_number']}:${e['delay']}:${e['trip_id']}"
                    : '')
                .join('|')
            : '';
        if (sig == _liveSig && !_isFirstLiveLoad) {
          return _cachedLiveTrains;
        }
        _liveSig = sig;
        _safeSetState(() {
          _cachedLiveTrains = data;
          _isLoadingLiveTrains = false;
          _isFirstLiveLoad = false;
        });
        return data;
      } else {
        _safeSetState(() => _isLoadingLiveTrains = false);
        return _cachedLiveTrains;
      }
    } catch (e) {
      debugPrint('Errore caricamento treni live: $e');
      _safeSetState(() => _isLoadingLiveTrains = false);
      return _cachedLiveTrains;
    } finally {
      _liveFetchActive = false;
    }
  }

  void _startLiveTrainsRefresh() {
    Future.microtask(() => _loadLiveTrains(silent: false));
    Future.microtask(() => _loadMostViewed());
    _liveTrainsRefreshTimer?.cancel();
    _recentRefreshTimer?.cancel();
    _trainsCacheTimer?.cancel();
    // Live velocissimo (2s): è la sezione tempo reale.
    _liveTrainsRefreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (_selectedIndex == 1 && _trainSearchController.text.isEmpty) {
        _loadLiveSection();
      }
    });
    // Recenti lenti (20s): cambiano piano (storico 1h).
    _recentRefreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (_selectedIndex == 1 && _trainSearchController.text.isEmpty) {
        _loadRecentSection();
      }
    });
    // Cache treni per il tap: basta ogni 15s.
    _trainsCacheTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_selectedIndex == 1 && _trainSearchController.text.isEmpty) {
        _loadLiveTrains(silent: true);
      }
    });
  }

  /// Entrambe le sezioni (usato ad apertura tab, pull-to-refresh, retry).
  Future<void> _loadMostViewed() async {
    await _loadLiveSection();
    await _loadRecentSection();
  }

  /// Sezione live velocissima (GET /live, top 5 + totale utenti).
  Future<void> _loadLiveSection() async {
    if (_isOffline || !mounted || _loadingLiveSection) return;
    _loadingLiveSection = true;
    final gen = ++_liveSectionGen;
    try {
      final live = await TrainPresenceService().fetchLiveData();
      if (!mounted || gen != _liveSectionGen) return;
      // Solo risposte riuscite aggiornano lo stato: un timeout/errore
      // non deve mai svuotare le sezioni senza motivo.
      if (live == null) return;
      // Niente grazia per la live: vuoto vero = si svuota subito e
      // i treni passano ai recenti. Gli errori restano null e non toccano nulla.
      final newMost = live.trains.take(5).toList();
      final newTotal = live.totalViewers;
      final sig =
          '$newTotal#${newMost.map((e) => '${e['trainKey']}:${e['viewers']}').join('|')}';
      // Dati identici: nessun setState, nessun glitch.
      if (sig == _presenceSigLive) return;
      _presenceSigLive = sig;
      _safeSetState(() {
        _mostViewedTrains = newMost;
        _totalViewersLive = newTotal;
      });
    } catch (_) {
    } finally {
      _loadingLiveSection = false;
    }
  }

  /// Sezione recenti (GET /recent, merge per chiave, scadenza 70').
  Future<void> _loadRecentSection() async {
    if (_isOffline || !mounted || _loadingRecentSection) return;
    _loadingRecentSection = true;
    final gen = ++_recentSectionGen;
    try {
      final recent =
          await TrainPresenceService().fetchRecentTrains(limit: 10);
      if (!mounted || gen != _recentSectionGen) return;
      if (recent == null) return;
      // Merge per chiave: un treno recente non sparisce di colpo se un
      // poll lo salta (multi-istanza, restart, bordo TTL). Scadenza 70'.
      final newRecent = _mergeRecent(_recentTrains, recent);
      final sig = newRecent
          .map((e) => '${e['trainKey']}:${e['viewers']}')
          .join('|');
      if (sig == _presenceSigRecent) return;
      _presenceSigRecent = sig;
      _safeSetState(() {
        _recentTrains = newRecent;
      });
    } catch (_) {
    } finally {
      _loadingRecentSection = false;
    }
  }

  /// Unisce i recenti vecchi e nuovi per trainKey (vince il lastSeen
  /// maggiore), scarta oltre 70 minuti. Così non spariscono di colpo.
  List<Map<String, dynamic>> _mergeRecent(
      List<Map<String, dynamic>> oldList,
      List<Map<String, dynamic>> fresh) {
    final map = <String, Map<String, dynamic>>{};
    for (final e in oldList) {
      final k = (e['trainKey'] ?? '').toString();
      if (k.isNotEmpty) map[k] = e;
    }
    for (final e in fresh) {
      final k = (e['trainKey'] ?? '').toString();
      if (k.isEmpty) continue;
      final prev = map[k];
      if (prev == null) {
        map[k] = e;
      } else {
        final pSeen =
            DateTime.tryParse((prev['lastSeen'] ?? '').toString());
        final nSeen = DateTime.tryParse((e['lastSeen'] ?? '').toString());
        if (nSeen != null && (pSeen == null || nSeen.isAfter(pSeen))) {
          map[k] = e;
        }
      }
    }
    final cutoff = DateTime.now().subtract(const Duration(minutes: 70));
    final out = map.values.where((e) {
      final seen = DateTime.tryParse((e['lastSeen'] ?? '').toString());
      if (seen == null) return true;
      return !seen.isBefore(cutoff);
    }).toList();
    out.sort((a, b) {
      final sa = DateTime.tryParse((a['lastSeen'] ?? '').toString());
      final sb = DateTime.tryParse((b['lastSeen'] ?? '').toString());
      if (sa == null && sb == null) return 0;
      if (sa == null) return 1;
      if (sb == null) return -1;
      return sb.compareTo(sa);
    });
    return out.take(10).toList();
  }

  /// Normalizza una entry presence /live nello stesso formato dei treni live,
  /// così la card della lista è identica (stesso stile, stesso tap dettagli).
  /// Usa tripId + tutte le fermate inviate dall'heartbeat: il dettaglio che
  /// si apre è completo come la visualizzazione normale.
  Map<String, dynamic> _normalizePresenceTrain(Map<String, dynamic> entry) {
    final t = entry['train'] is Map
        ? Map<String, dynamic>.from(entry['train'] as Map)
        : <String, dynamic>{};
    final origin = (t['origin'] ?? '').toString();
    final destination = (t['destination'] ?? '').toString();
    final scheduled = (t['scheduledTime'] ?? '').toString();
    final estimated = (t['estimatedTime'] ?? '').toString();
    final stops = <Map<String, dynamic>>[];
    final rawStops = t['stops'];
    if (rawStops is List && rawStops.isNotEmpty) {
      for (final s in rawStops) {
        if (s is Map) {
          stops.add(_normalizePresenceStop(Map<String, dynamic>.from(s)));
        }
      }
    }
    if (stops.isEmpty) {
      if (origin.isNotEmpty) {
        stops.add({
          'stationName': origin,
          'scheduledDeparture': scheduled,
          'estimatedDeparture': estimated,
        });
      }
      if (destination.isNotEmpty) {
        stops.add({
          'stationName': destination,
          'scheduledDeparture': '',
          'estimatedDeparture': '',
        });
      }
    }
    return {
      'category': (t['category'] ?? '').toString(),
      'trip_number': (t['trip_number'] ?? t['trainNumber'] ?? '').toString(),
      'trip_id': t['trip_id']?.toString() ?? t['tripId']?.toString(),
      'delay': t['delayMinutes'] ?? t['delay'] ?? 0,
      'operator': (t['operator'] ?? '').toString().isNotEmpty
          ? (t['operator'] ?? '').toString()
          : 'N/A',
      'country': (t['country'] ??
              (_selectedCountry.isNotEmpty ? _selectedCountry : 'IT'))
          .toString(),
      'origin': origin,
      'destination': destination,
      'scheduledTime': scheduled,
      'estimatedTime': estimated,
      'platform': (t['platform'] ?? '').toString(),
      'screen': entry['screen']?.toString(),
      'provider': (t['provider'] ?? '').toString(),
      'isArrival': t['isArrival'] == true,
      'stops': stops,
      'viewers': entry['viewers'] ?? 0,
    };
  }

  /// Risolve il RegionalProvider dalla chiave (es. 'trenord') nel paese
  /// indicato (non solo IT), con cache per paese+chiave.
  Future<RegionalProvider?> _resolveRegionalProvider(String key,
      {String country = 'it'}) async {
    final k = key.trim().toLowerCase();
    if (k.isEmpty) return null;
    var cc = country.trim().toLowerCase();
    if (cc.isEmpty) cc = 'it';
    final cacheKey = '$cc|$k';
    if (_regionalProvidersCache.containsKey(cacheKey)) {
      return _regionalProvidersCache[cacheKey];
    }
    try {
      final providers = await _regionalProvidersRepo.fetchProviders(cc);
      for (final p in providers) {
        for (final cand in [p.share.key, p.name, p.provider]) {
          if (cand.trim().toLowerCase() == k) {
            _regionalProvidersCache[cacheKey] = p;
            return p;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// True solo se screen è regional: apre la sheet regionale,
  /// altrimenti sempre quella nazionale normale.
  bool _isRegionalTrain(Map<String, dynamic> m) {
    return (m['screen'] ?? '').toString().toLowerCase() == 'regional';
  }

  /// Porta una fermata presence (formato board oppure TrainStop.toJson)
  /// nelle chiavi lette dalle card (stationName, scheduledDeparture,
  /// estimatedDeparture, platform).
  Map<String, dynamic> _normalizePresenceStop(Map<String, dynamic> s) {
    String str(dynamic v) => (v ?? '').toString();
    return {
      ...s,
      'stationName': str(s['stationName'] ?? s['station'] ?? s['name']),
      'scheduledDeparture': str(s['scheduledDeparture'] ??
          s['departure'] ??
          s['departureTime'] ??
          s['scheduledTime'] ??
          s['arrival'] ??
          s['time']),
      'estimatedDeparture': str(s['estimatedDeparture'] ?? s['actualDeparture']),
      'platform': str(s['platform'] ??
          s['actualPlatform'] ??
          s['plannedPlatform'] ??
          s['scheduledPlatform']),
    };
  }

  Future<void> _checkStationStatus(String stationId) async {
    if (!mounted) return;
    _safeSetState(() => _checkingStatus = true);
    try {
      final response = await http
          .get(Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/monitor/check/$stationId'))
          .timeout(const Duration(seconds: 5));
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _safeSetState(() => _isMonitored = data['isMonitored'] ?? false);
      }
    } catch (e) {
      debugPrint('Errore controllo monitoraggio: $e');
    } finally {
      _safeSetState(() => _checkingStatus = false);
    }
  }

  Future<void> _addStationToDb(String stationId, String name) async {
    try {
      final response = await http
          .post(
            Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/monitor/add'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'stationId': stationId,
              'name': name,
              'country': _selectedCountry.isEmpty ? 'GLOBAL' : _selectedCountry,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _checkStationStatus(stationId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stazione aggiunta al monitoraggio'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore aggiunta: ${response.statusCode}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _loadStatsAndNavigate(BuildContext context, String stationId) async {
    _safeSetState(() => _checkingStatus = true);
    try {
      final response = await http
          .get(Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/station/$stationId'))
          .timeout(const Duration(seconds: 10));
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => station_stats.TrainStatsScreen(rawStats: data, stationId: stationId),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nessun dato statistico disponibile.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Errore: $e")),
        );
      }
    } finally {
      _safeSetState(() => _checkingStatus = false);
    }
  }

  Future<void> _loadCountries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedCountries = prefs.getString('countries_cache');
      final freshData = await _fetchProvidersFromAPI();
      if (!mounted) return;
      if (freshData.isNotEmpty) {
        await prefs.setString('countries_cache', jsonEncode(freshData));
        _safeSetState(() => _countries = freshData);
        await _loadCountryOrder();
      } else if (cachedCountries != null) {
        final cached = List<Map<String, String>>.from(
            (jsonDecode(cachedCountries) as List).map((i) => Map<String, String>.from(i)));
        _safeSetState(() => _countries = cached);
        await _loadCountryOrder();
      }
    } catch (e) {
      if (mounted) _safeSetState(() => _countries = []);
    }
  }

  Future<List<Map<String, String>>> _fetchProvidersFromAPI() async {
    try {
      final response = await http
          .get(Uri.parse('https://prod.cuzimmartin.dev/api/providers'))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['success'] == true) {
          final providers = data['data']['providers'] as List;
          final Map<String, Map<String, String>> countriesMap = {};
          for (final p in providers) {
            final code = (p['countryCode'] as String).toUpperCase();
            if (!countriesMap.containsKey(code)) {
              countriesMap[code] = {'code': code, 'name': countryNames[code] ?? code};
            }
            if (p['city'] != null) {
              final cityData = {'name': p['city'].toString(), 'provider': p['id'].toString()};
              _citiesByCountry.putIfAbsent(code, () => []).add(cityData);
            }
          }
          return countriesMap.values.toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _loadCountryOrder() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final order = prefs.getStringList('country_order') ?? [];
    _safeSetState(() {
      _countryOrder = order;
      if (_countryOrder.isNotEmpty && _countries.isNotEmpty) {
        _countries.sort((a, b) {
          final ia = _countryOrder.indexOf(a['code']!);
          final ib = _countryOrder.indexOf(b['code']!);
          if (ia == -1) return 1;
          if (ib == -1) return -1;
          return ia.compareTo(ib);
        });
      }
    });
  }

  void _saveCountryOrder() async {
    final prefs = await SharedPreferences.getInstance();
    _countryOrder = _countries.map((c) => c['code']!).toList();
    await prefs.setStringList('country_order', _countryOrder);
  }

  void _onReorderCountries(List<Map<String, String>> currentList, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final moved = currentList[oldIndex];
    final movedCode = moved['code']!;
    final globalOld = _countries.indexWhere((c) => c['code'] == movedCode);
    if (globalOld != -1) _countries.removeAt(globalOld);
    int insertIndex;
    if (currentList.isEmpty) {
      insertIndex = _countries.length;
    } else if (newIndex <= 0) {
      final firstCode = currentList.first['code']!;
      insertIndex = _countries.indexWhere((c) => c['code'] == firstCode);
      if (insertIndex == -1) insertIndex = 0;
    } else {
      final prevCode = currentList[newIndex - 1]['code']!;
      insertIndex = _countries.indexWhere((c) => c['code'] == prevCode);
      if (insertIndex == -1) insertIndex = _countries.length;
      else insertIndex++;
    }
    if (insertIndex > _countries.length) insertIndex = _countries.length;
    _countries.insert(insertIndex, moved);
    _safeSetState(() {});
    _saveCountryOrder();
  }

  Future<void> _searchStationsMultipleCountries(
      String query, List<Map<String, String>> countries, TrainProvider provider) async {
    final codes = countries.map((c) => c['code']!).toList();
    try {
      final results = await Future.wait(codes.map((code) async {
        try {
          await provider.searchStations(query, country: code);
          return provider.stationSuggestions.toList();
        } catch (e) {
          debugPrint('Errore per $code: $e');
          return <TrainStation>[];
        }
      })).timeout(const Duration(seconds: 15), onTimeout: () => List.generate(codes.length, (_) => <TrainStation>[]));
      final all = results.expand((x) => x).toList();
      final seen = <String>{};
      if (mounted) {
        provider.setStationSuggestions(all.where((s) => seen.add('${s.id}-${s.country}')).toList());
      }
    } catch (e) {
      debugPrint('Errore ricerca stazioni multiple: $e');
    }
  }

  void _onSearchChanged(String query, TrainProvider provider, List<Map<String, String>> countries) {
    if (query.length < 2 && _selectedCountry.isEmpty) {
      provider.clearStationSuggestions();
      return;
    }
    if (_selectedCountry.isNotEmpty) {
      if (_selectedCountry == 'EU') {
        provider.searchTrainByNumber(query);
      } else if (_selectedCountry == 'GLOBAL') {
        provider.searchStations(query, country: 'GLOBAL');
      } else {
        String? cityProvider;
        if (_selectedCity.isNotEmpty && _selectedCity != 'Tutte le città') {
          cityProvider = _citiesByCountry[_selectedCountry]!
              .firstWhere((c) => c['name'] == _selectedCity)['provider'];
        }
        provider.searchStations(query, country: _selectedCountry, city: cityProvider);
      }
    } else {
      _searchStationsMultipleCountries(query, countries, provider);
    }
  }

  String? _getMostRecentTripId(Map<String, dynamic> trainData) {
    final directTripId = trainData['trip_id']?.toString();
    if (directTripId != null && directTripId.isNotEmpty) {
      final trainNumber = trainData['trainNumber']?.toString() ?? 
                          trainData['number']?.toString() ?? 
                          trainData['tripNumber']?.toString() ?? '';
      final isNumeric = int.tryParse(directTripId) != null;
      if (!(isNumeric && trainNumber.isNotEmpty && directTripId == trainNumber)) {
        return directTripId;
      }
    }

    final tripId = trainData['tripId']?.toString();
    if (tripId != null && tripId.isNotEmpty) {
      final trainNumber = trainData['trainNumber']?.toString() ?? 
                          trainData['number']?.toString() ?? '';
      final isNumeric = int.tryParse(tripId) != null;
      if (!(isNumeric && trainNumber.isNotEmpty && tripId == trainNumber)) {
        return tripId;
      }
    }

    final selectedTripId = trainData['selectedTripId']?.toString();
    if (selectedTripId != null && selectedTripId.isNotEmpty) {
      final trainNumber = trainData['trainNumber']?.toString() ?? 
                          trainData['number']?.toString() ?? '';
      final isNumeric = int.tryParse(selectedTripId) != null;
      if (!(isNumeric && trainNumber.isNotEmpty && selectedTripId == trainNumber)) {
        return selectedTripId;
      }
    }

    final runs = trainData['runs'] ?? trainData['trips'] ?? trainData['history'] ?? trainData['runsList'];
    if (runs is List && runs.isNotEmpty) {
      Map<String, dynamic>? mostRecentRun;
      DateTime? mostRecentDate;

      for (final run in runs) {
        if (run is Map<String, dynamic>) {
          final runTripId = run['trip_id']?.toString() ?? 
                            run['tripId']?.toString() ?? 
                            run['id']?.toString();
          if (runTripId != null && runTripId.isNotEmpty) {
            final dateVal = run['last_updated'] ?? 
                           run['lastRun'] ?? 
                           run['date'] ?? 
                           run['departureTime'] ?? 
                           run['time'] ?? 
                           run['timestamp'] ?? 
                           run['updatedAt'];
            DateTime? parsedDate;
            if (dateVal != null) {
              parsedDate = DateTime.tryParse(dateVal.toString());
              if (parsedDate == null) {
                final epoch = int.tryParse(dateVal.toString());
                if (epoch != null) {
                  parsedDate = DateTime.fromMillisecondsSinceEpoch(epoch < 1e11 ? epoch * 1000 : epoch);
                }
              }
            }

            if (mostRecentDate == null || (parsedDate != null && parsedDate.isAfter(mostRecentDate))) {
              mostRecentDate = parsedDate;
              mostRecentRun = run;
            }
          }
        }
      }

      if (mostRecentRun != null) {
        final id = mostRecentRun['trip_id']?.toString() ?? 
                   mostRecentRun['tripId']?.toString() ?? 
                   mostRecentRun['id']?.toString();
        if (id != null && id.isNotEmpty) {
          return id;
        }
      }
    }

    final otherIds = [
      'latestTripId',
      'lastTripId', 
      'id',
      'tripNumber',
      'number'
    ];
    
    for (final key in otherIds) {
      final val = trainData[key]?.toString();
      if (val != null && val.isNotEmpty) {
        final trainNumber = trainData['trainNumber']?.toString() ?? 
                            trainData['number']?.toString() ?? '';
        final isNumeric = int.tryParse(val) != null;
        if (!(isNumeric && trainNumber.isNotEmpty && val == trainNumber)) {
          return val;
        }
      }
    }

    final trainNumber = trainData['trainNumber']?.toString() ?? 
                        trainData['number']?.toString() ?? 
                        trainData['tripNumber']?.toString() ?? '';
    if (trainNumber.isNotEmpty) {
      return trainNumber;
    }

    return null;
  }

  Future<Map<String, dynamic>?> _fetchTripDataFromDb(String category, String number) async {
    final cacheKey = '$category|$number';
    
    if (_tripCache.containsKey(cacheKey)) {
      final cached = _tripCache[cacheKey];
      return cached;
    }

    if (category.isEmpty || number.isEmpty) {
      return null;
    }

    try {
      final trainProvider = Provider.of<TrainProvider>(context, listen: false);
      final client = await trainProvider.getDatabase();
      
      final result = await client.query(
        'SELECT trip_id, delay FROM train_trips WHERE category = ? AND trip_number = ? ORDER BY last_updated DESC LIMIT 1',
        positional: [category, number],
      );

      if (result.isNotEmpty) {
        final row = result.first;
        final tripId = row['trip_id']?.toString();
        final delay = row['delay'] as int? ?? 0;
        
        if (tripId != null && tripId.isNotEmpty) {
          final data = {
            'trip_id': tripId,
            'delay': delay,
          };
          _tripCache[cacheKey] = data;
          return data;
        }
      }
    } catch (e) {
      debugPrint('Errore query Turso: $e');
    }

    return null;
  }

  Future<void> _performTrainSearch(String query) async {
    if (query.length < 2) {
      _safeSetState(() {
        _dbTrainResults.clear();
        _isSearchingDbTrain = false;
      });
      return;
    }
    _debounceTrainSearch?.cancel();
    _debounceTrainSearch = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      _safeSetState(() => _isSearchingDbTrain = true);
      try {
        final response = await http
            .get(Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/search/train?q=$query'))
            .timeout(const Duration(seconds: 10));
        if (!mounted) return;
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final rawList = List<Map<String, dynamic>>.from(data['data']);

          final processedList = rawList.map((item) {
            final mostRecentTripId = _getMostRecentTripId(item);
            if (mostRecentTripId != null) {
              item['selectedTripId'] = mostRecentTripId;
            }
            return item;
          }).toList();

          _safeSetState(() => _dbTrainResults = processedList);
        }
      } catch (e) {
        debugPrint('Errore ricerca storico: $e');
      } finally {
        if (mounted) _safeSetState(() => _isSearchingDbTrain = false);
      }
    });
  }

  // ==================== ROUTING SEARCH CON SUPPORTO DUAL PROVIDER ====================

  Future<void> _performRoutingSearch() async {
    final origin = _originController.text.trim();
    final dest = _destinationController.text.trim();
    
    if (origin.length < 2 || dest.length < 2) return;
    
    _safeSetState(() {
      _isSearchingRouting = true;
      _routingData = null;
    });

    try {
      final String timeStr = "${_selectedRoutingTime.hour.toString().padLeft(2, '0')}:${_selectedRoutingTime.minute.toString().padLeft(2, '0')}";
      final String dateStr = "${_selectedRoutingDate.year}-${_selectedRoutingDate.month.toString().padLeft(2, '0')}-${_selectedRoutingDate.day.toString().padLeft(2, '0')}";
      
      // Costruisci il payload base
      final Map<String, dynamic> payload = {
        'provider': _selectedRoutingProvider,
        'from': origin,
        'to': dest,
        'date': dateStr,
        'time': timeStr,
      };

      // Parametri specifici per provider
      if (_selectedRoutingProvider == 'eurail') {
        // Eurail accetta tripsNumber tra 1 e 6
        payload['tripsNumber'] = 5;
        payload['includeStops'] = true;
        payload['travellers'] = 1;
        payload['currency'] = 'EUR';
        
        // Timestamp nel formato corretto per Eurail
        final dateTime = DateTime(
          _selectedRoutingDate.year,
          _selectedRoutingDate.month,
          _selectedRoutingDate.day,
          _selectedRoutingTime.hour,
          _selectedRoutingTime.minute,
        );
        payload['timestamp'] = dateTime.toUtc().toIso8601String();
        
        payload['arrival'] = false;
        payload['minChangeTime'] = 1;
        
      } else if (_selectedRoutingProvider == 'rfi') {
        payload['tripsNumber'] = 10;
        payload['includeStops'] = true;
        payload['adults'] = 1;
        payload['children'] = 0;
        payload['criteria'] = {
          'frecceOnly': false,
          'regionalOnly': false,
          'noChanges': false,
          'order': 'DEPARTURE_DATE',
          'limit': 10,
          'offset': 0,
        };
        payload['advancedSearchRequest'] = {
          'bestFare': false,
        };
      }

      debugPrint('📤 Payload inviato a /api/trains/routing: ${json.encode(payload)}');

      final response = await http.post(
        Uri.parse('https://betacloud-transporter.is-cool.dev/api/trains/routing'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(payload),
      ).timeout(const Duration(seconds: 40));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final rawData = json.decode(response.body);
        debugPrint('✅ Routing OK (${_selectedRoutingProvider})');
        final normalizedData = _normalizeRoutingData(rawData);
        _safeSetState(() => _routingData = normalizedData);
        
        final totaleSoluzioni = normalizedData['totaleSoluzioni'] ?? 0;
        if (totaleSoluzioni > 0) {
          debugPrint('  - $totaleSoluzioni soluzioni trovate');
          if (normalizedData['soluzioni'] != null && normalizedData['soluzioni'].isNotEmpty) {
            debugPrint('  - Prima soluzione: ${normalizedData['soluzioni'][0]['durataViaggioTotaleLeggibile']}');
          }
        } else {
          debugPrint('  - Nessuna soluzione trovata');
        }
      } else {
        String errorMessage = "Errore: ${response.statusCode}";
        try {
          final errorJson = json.decode(response.body);
          debugPrint('❌ Errore response: $errorJson');
          
          if (errorJson['error'] != null) {
            errorMessage = errorJson['error'].toString();
          }
          if (errorJson['details'] != null) {
            errorMessage += '\n${errorJson['details']}';
          }
          if (errorJson['resultMessage'] != null) {
            errorMessage = errorJson['resultMessage'].toString();
          }
        } catch (_) {}
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Errore ricerca soluzioni: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Errore: $e"),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) _safeSetState(() => _isSearchingRouting = false);
    }
  }

  Future<void> _selectRoutingTime(BuildContext context, ThemeProvider theme) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedRoutingTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              surface: theme.surfaceColor,
              onSurface: theme.textColor,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: theme.surfaceColor,
              hourMinuteTextColor: theme.textColor,
              dayPeriodTextColor: theme.textColor,
              dialHandColor: theme.primaryColor,
              dialBackgroundColor: theme.primaryColor.withValues(alpha: 0.1),
              hourMinuteColor: theme.primaryColor.withValues(alpha: 0.05),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              child!,
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _safeSetState(() {
                      _selectedRoutingTime = TimeOfDay.now();
                    });
                  },
                  child: Text(
                    RuntimeLocalizations.t(context, 'routing_time_now'),
                    style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != _selectedRoutingTime) {
      _safeSetState(() {
        _selectedRoutingTime = picked;
      });
    }
  }

  Future<void> _selectRoutingDate(BuildContext context, ThemeProvider theme) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRoutingDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: theme.primaryColor,
              onPrimary: Colors.white,
              surface: theme.surfaceColor,
              onSurface: theme.textColor,
            ),
            dialogBackgroundColor: theme.surfaceColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedRoutingDate) {
      _safeSetState(() {
        _selectedRoutingDate = picked;
      });
    }
  }

  void _showTrainDetails(BuildContext context, dynamic dep, int index, ThemeProvider theme) {
    if (index >= 0 && (dep.stops == null || dep.stops.isEmpty)) {
      Provider.of<TrainProvider>(context, listen: false).expandTrainDetails(index);
    }

    final effectiveCountry = (dep is TrainDeparture && dep.country != null && dep.country!.isNotEmpty)
        ? dep.country!
        : (_selectedCountry.isNotEmpty ? _selectedCountry : 'IT');

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrainDetailsSheet(
          departure: dep,
          isArrivalMode: Provider.of<TrainProvider>(context, listen: false).isArrivalMode,
          selectedCountry: effectiveCountry,
        ),
      ),
    );
  }

  void _showSavedStationsSheet(TrainProvider provider, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (ctx, sc) => StatefulBuilder(
          builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: theme.backgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.secondaryTextColor.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.savedTrainsOffline ?? 'Treni Salvati (Offline)',
                        style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      tooltip: RuntimeLocalizations.t(context, 'delete_all_offline_trains') ?? 'Elimina tutti',
                      icon: Icon(Icons.delete_sweep_outlined, color: theme.secondaryTextColor),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: ctx,
                          builder: (dctx) => AlertDialog(
                            title: Text(RuntimeLocalizations.t(ctx, 'delete_all_offline_trains_title') ?? 'Eliminare tutti i treni salvati?'),
                            content: Text(RuntimeLocalizations.t(ctx, 'delete_all_offline_trains_desc') ?? 'Verranno rimossi tutti i treni salvati offline su questo dispositivo.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, false),
                                child: Text(RuntimeLocalizations.t(ctx, 'cancel') ?? 'Annulla'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(dctx, true),
                                child: Text(
                                  RuntimeLocalizations.t(ctx, 'delete') ?? 'Elimina',
                                  style: const TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await provider.clearDownloadedTrains();
                          setModalState(() {});
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: provider.getDownloadedTrains().timeout(
                    const Duration(seconds: 10),
                    onTimeout: () => [],
                  ),
                  builder: (ctx, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Errore: ${snapshot.error}',
                          style: TextStyle(color: theme.secondaryTextColor),
                        ),
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          AppLocalizations.of(context)?.noOfflineData ?? 'Nessun dato salvato offline',
                          style: TextStyle(color: theme.secondaryTextColor),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: sc,
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final item = items[i];
                        final station = TrainStation.fromJson(item['station']);
                        final train = TrainDeparture.fromJson(item['train']);
                        return ListTile(
                          leading: Icon(Icons.train_rounded, color: theme.primaryColor),
                          title: Text(
                            '${train.category ?? ''} ${train.trainNumber ?? ''}',
                            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${train.origin ?? 'N/A'} → ${train.destination ?? 'N/A'}\n${station.name} (${item['mode'] == 'arrivals' ? (AppLocalizations.of(context)?.arrivals ?? 'Arrivi') : (AppLocalizations.of(context)?.departures ?? 'Partenze')})',
                            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: RuntimeLocalizations.t(context, 'delete') ?? 'Elimina',
                                icon: Icon(Icons.delete_outline_rounded, color: theme.secondaryTextColor),
                                onPressed: () async {
                                  final id = item['id'] as String? ?? '';
                                  await provider.deleteDownloadedTrain(id);
                                  setModalState(() {});
                                },
                              ),
                              Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.pop(ctx);
                            provider.selectSavedTrain(station, train, item['service'], item['mode']);
                            _showTrainDetails(context, train, -1, theme);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  void _openReorderSheet(TrainProvider provider, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: MediaQuery.of(ctx).size.height * 0.6,
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.secondaryTextColor.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.reorderCountries ?? 'Riordina nazioni',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textColor),
                  ),
                  TextButton(
                    onPressed: () {
                      _saveCountryOrder();
                      Navigator.of(ctx).pop();
                    },
                    child: Text(
                      AppLocalizations.of(context)?.save ?? 'Salva',
                      style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ReorderableListView(
                  onReorder: (oldIndex, newIndex) => _onReorderCountries(_countries, oldIndex, newIndex),
                  children: [
                    for (var i = 0; i < _countries.length; i++)
                      ListTile(
                        key: ValueKey(_countries[i]['code']),
                        title: Text(_countries[i]['name']!, style: TextStyle(color: theme.textColor)),
                        trailing: Icon(Icons.drag_handle, color: theme.secondaryTextColor),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trainProvider = Provider.of<TrainProvider>(context);
    final theme = Provider.of<ThemeProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    if (settings.vectorLogosEnabled && trainProvider.trainLogos.isEmpty) {
      debugPrint('[LogoPanel] Triggering logo load: vectorEnabled=${settings.vectorLogosEnabled} source=${settings.logoSource}');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) trainProvider.loadTrainLogos(source: settings.logoSource);
      });
    }

    final station = trainProvider.selectedStation;
    if (station != null && station.id != _lastCheckedStationId) {
      _lastCheckedStationId = station.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkStationStatus(station.id);
      });
    } else if (station == null && _lastCheckedStationId != null) {
      _lastCheckedStationId = null;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: station != null
          ? _buildTimetableResults(context, trainProvider, theme, station)
          : _buildSearchHome(context, trainProvider, theme),
    );
  }

  // ==================== WIDGET BUILD ====================

  Widget _buildSearchHome(BuildContext context, TrainProvider provider, ThemeProvider theme) {
    final displayedCountries = provider.selectedService == 'direct'
        ? _countries.where((c) => ['IT', 'FAL', 'EU'].contains(c['code'])).toList()
        : _countries;

    return Column(
      key: const ValueKey('search'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(
                    RuntimeLocalizations.t(context, 'stations') ?? 'Stazioni',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.location_city_rounded),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(
                    RuntimeLocalizations.t(context, 'trains') ?? 'Treni (Live)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.train_rounded),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text(
                    RuntimeLocalizations.t(context, 'solutions') ?? 'Soluzioni',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  icon: const Icon(Icons.route_rounded),
                ),
              ],
              selected: {_selectedIndex},
              onSelectionChanged: (newSelection) {
                final newIndex = newSelection.first;
                _safeSetState(() => _selectedIndex = newIndex);
                if (newIndex == 1 && _trainSearchController.text.isEmpty) {
                  Future.microtask(() => _loadLiveTrains(silent: false));
                  Future.microtask(() => _loadMostViewed());
                }
                 if (newIndex == 2) {
                // Naviga verso la schermata di ricerca soluzioni
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RoutingSearchScreen(),
                  ),
                ).then((_) {
                  // Quando si torna indietro, resetta la selezione al tab 0 (Stazioni)
                  if (mounted) {
                    _safeSetState(() => _selectedIndex = 0);
                  }
                });
              }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) return theme.primaryColor;
                  return theme.surfaceColor;
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                  if (states.contains(WidgetState.selected)) return Colors.white;
                  return theme.secondaryTextColor;
                }),
              ),
            ),
          ),
        ),
        Expanded(
          child: _selectedIndex == 0
              ? Column(
                  children: [
                    _buildSearchHeader(provider, theme, displayedCountries),
                    _buildFavoriteSection(provider, theme),
                    _buildSavedTrainsButton(provider, theme),
                    Expanded(
                      child: _isOffline
                          ? _buildOfflineError(theme)
                          : provider.isLoadingSuggestions
                              ? ShimmerLoading(baseColor: theme.secondaryTextColor)
                              : _buildStationSuggestionsList(provider, theme),
                    ),
                  ],
                )
              : _selectedIndex == 1
                  ? _buildTrainSearchContent(theme)
                  : _buildSolutionsContent(theme),
        ),
      ],
    );
  }

  // ==================== SEZIONE SOLUZIONI ====================

  Widget _buildSolutionsContent(ThemeProvider theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _originController,
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: RuntimeLocalizations.t(context, 'routing_origin_hint'),
                    hintStyle: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.trip_origin_rounded, color: theme.primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                Divider(height: 1, color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                TextField(
                  controller: _destinationController,
                  style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: RuntimeLocalizations.t(context, 'routing_destination_hint'),
                    hintStyle: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                    prefixIcon: Icon(Icons.location_on_rounded, color: Colors.redAccent),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                Divider(height: 1, color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                
                IntrinsicHeight(
                  child: Row(
                    children: [
                      // SELEZIONE PROVIDER
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedRoutingProvider,
                              isExpanded: true,
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              dropdownColor: theme.surfaceColor,
                              icon: Icon(Icons.arrow_drop_down_rounded, color: theme.primaryColor),
                              items: const [
                                DropdownMenuItem(value: 'eurail', child: Text('Eurail')),
                                DropdownMenuItem(value: 'rfi', child: Text('RFI / LeFrecce')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _safeSetState(() => _selectedRoutingProvider = value);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                      // SELEZIONE DATA
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectRoutingDate(context, theme),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today_rounded, color: theme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        RuntimeLocalizations.t(context, 'routing_date_label') ?? 'Data',
                                        style: TextStyle(
                                          color: theme.secondaryTextColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(_selectedRoutingDate),
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      VerticalDivider(width: 1, color: theme.secondaryTextColor.withValues(alpha: 0.2)),
                      // SELEZIONE ORA
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectRoutingTime(context, theme),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            child: Row(
                              children: [
                                Icon(Icons.access_time_rounded, color: theme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        RuntimeLocalizations.t(context, 'routing_time_label') ?? 'Ora',
                                        style: TextStyle(
                                          color: theme.secondaryTextColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        _selectedRoutingTime.format(context),
                                        style: TextStyle(
                                          color: theme.textColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                InkWell(
                  onTap: _performRoutingSearch,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    ),
                    child: Center(
                      child: _isSearchingRouting
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.primaryColor,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_rounded, color: theme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  RuntimeLocalizations.t(context, 'routing_search_btn'),
                                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.primaryColor.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _selectedRoutingProvider.toUpperCase(),
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _isSearchingRouting
              ? ShimmerLoading(baseColor: theme.secondaryTextColor)
              : _routingData == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.alt_route_rounded, size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
                            const SizedBox(height: 16),
                            Text(
                              RuntimeLocalizations.t(context, 'routing_empty'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Provider: ${_selectedRoutingProvider.toUpperCase()}',
                              style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildRoutingResultsList(theme),
        ),
      ],
    );
  }

 Widget _buildRoutingResultsList(ThemeProvider theme) {
  final totaleSoluzioni = _routingData?['totaleSoluzioni'] ?? 0;
  final provider = _routingData?['provider'] ?? 'eurail';
  
  if (totaleSoluzioni == 0) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: theme.secondaryTextColor.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              RuntimeLocalizations.t(context, 'routing_no_results') ?? 'Nessuna soluzione trovata',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Provider: ${provider.toUpperCase()}',
              style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  final solutions = _routingData?['soluzioni'] as List? ?? [];

  return ListView.builder(
    padding: const EdgeInsets.only(bottom: 100, top: 4),
    itemCount: solutions.length,
    itemBuilder: (ctx, i) {
      final sol = solutions[i] as Map<String, dynamic>;
      final percorso = sol['percorso'] as List? ?? [];
      final cambi = sol['cambi'] as int? ?? 0;
      final firstLeg = percorso.isNotEmpty ? percorso.first as Map<String, dynamic>? : null;
      final lastLeg = percorso.isNotEmpty ? percorso.last as Map<String, dynamic>? : null;
      final isDirect = cambi == 0;

      // Calcola durata totale
      String durataLeggibile = sol['durataViaggioTotaleLeggibile'] ?? '--:--';
      
      if (durataLeggibile == '--:--' && firstLeg != null && lastLeg != null) {
        final firstPartenza = firstLeg['partenza'] as String? ?? '--:--';
        final lastArrivo = lastLeg['arrivo'] as String? ?? '--:--';
        final firstData = firstLeg['dataPartenza'] as String? ?? '';
        final lastData = lastLeg['dataArrivo'] as String? ?? '';
        
        // Per Eurail usa il calcolo diretto senza conversione timezone
        if (provider == 'eurail') {
          // Calcola durata direttamente
          try {
            final firstDateTime = DateTime.parse('$firstData $firstPartenza:00');
            final lastDateTime = DateTime.parse('$lastData $lastArrivo:00');
            final diff = lastDateTime.difference(firstDateTime);
            if (diff.inMinutes > 0) {
              durataLeggibile = _formatDuration(diff.inMinutes);
            }
          } catch (_) {
            durataLeggibile = '--:--';
          }
        } else {
          // Per RFI usa la conversione con timezone
          final countryCode = _getCountryCodeForSolution(sol);
          final durationMinutes = _calculateDurationMinutes(
            firstPartenza,
            lastArrivo,
            firstData,
            lastData,
            countryCode
          );
          durataLeggibile = _formatDuration(durationMinutes);
        }
      }

      // Calcola fermate totali
      final totalStops = percorso.fold<int>(
        0,
        (sum, leg) {
          final legMap = leg as Map<String, dynamic>;
          final stops = legMap['stops'] as List?;
          return sum + (stops?.length ?? 0);
        },
      );

      // Formatta orario di arrivo - per Eurail usa il valore diretto
      String arrivoFormattato = sol['arrivoStimato'] as String? ?? '--:--';
      if (lastLeg != null) {
        final arrivoRaw = lastLeg['arrivo'] as String? ?? '--:--';
        if (provider == 'eurail') {
          // Per Eurail usa il tempo già nel formato corretto
          arrivoFormattato = arrivoRaw;
        } else {
          // Per RFI usa la conversione con timezone
          arrivoFormattato = _formatTimeWithTimezone(
            arrivoRaw,
            lastLeg['dataArrivo'] as String?,
            _getCountryCodeForSolution(sol)
          );
        }
      }

      // Formatta orario di partenza - per Eurail usa il valore diretto
      String partenzaFormattata = '--:--';
      String dataPartenzaFormattata = '';
      if (firstLeg != null) {
        final partenzaRaw = firstLeg['partenza'] as String? ?? '--:--';
        if (provider == 'eurail') {
          // Per Eurail usa il tempo già nel formato corretto
          partenzaFormattata = partenzaRaw;
        } else {
          // Per RFI usa la conversione con timezone
          partenzaFormattata = _formatTimeWithTimezone(
            partenzaRaw,
            firstLeg['dataPartenza'] as String?,
            _getCountryCodeForSolution(sol)
          );
        }
        dataPartenzaFormattata = firstLeg['dataPartenza'] as String? ?? '';
      }

      // Estrai prezzo
      String prezzoText = '';
      final prezzo = sol['prezzo'] ?? 0;
      if (prezzo is num && prezzo > 0) {
        prezzoText = '€${prezzo.toStringAsFixed(2)}';
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RoutingDetailsScreen(
                routingData: _routingData!,
                selectedSolutionIndex: i,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.secondaryTextColor.withOpacity(0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDirect ? theme.successColor : Colors.orange).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isDirect
                              ? (RuntimeLocalizations.t(context, 'routing_direct') ?? 'Diretto')
                              : (RuntimeLocalizations.t(context, 'routing_changes', params: {'count': cambi.toString()}) ?? '$cambi cambi'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDirect ? theme.successColor : Colors.orange,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (firstLeg != null)
                        _buildColorBadge(
                          firstLeg['categoria'] as String? ?? 'TRN',
                          firstLeg['numeroTreno'] as String? ?? '',
                          theme,
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      if (prezzoText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            prezzoText,
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        durataLeggibile,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        partenzaFormattata,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        dataPartenzaFormattata,
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_rounded, color: theme.primaryColor, size: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        arrivoFormattato,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                        ),
                      ),
                      Text(
                        sol['dataArrivoStimata'] as String? ?? '',
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (totalStops > 0) ...[
                    Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: theme.secondaryTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '$totalStops fermate',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (percorso.length > 1) ...[
                    Icon(Icons.train_rounded, size: 14, color: theme.secondaryTextColor),
                    const SizedBox(width: 4),
                    Text(
                      '${percorso.length} treni',
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Dettagli →',
                      style: TextStyle(
                        color: theme.primaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (provider == 'rfi')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'RFI',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (provider == 'eurail')
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Eurail',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}

  // ==================== FUNZIONI DI BUILD AUSILIARIE ====================

  Widget _buildSearchHeader(TrainProvider provider, ThemeProvider theme, List<Map<String, String>> countries) {
    final hasCities = _selectedCountry.isNotEmpty && _citiesByCountry.containsKey(_selectedCountry);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: hasCities ? 180 : 135,
        borderRadius: 24,
        blur: 20,
        alignment: Alignment.center,
        border: 1,
        linearGradient: LinearGradient(
          colors: [theme.surfaceColor.withValues(alpha: 0.9), theme.surfaceColor.withValues(alpha: 0.5)],
        ),
        borderGradient: LinearGradient(
          colors: [theme.primaryColor.withValues(alpha: 0.3), Colors.transparent],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => _onSearchChanged(val, provider, countries),
                      style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)?.searchStationOrTrain ?? 'Cerca stazione...',
                        hintStyle: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.reorder, color: theme.primaryColor),
                    onPressed: () => _openReorderSheet(provider, theme),
                    tooltip: AppLocalizations.of(context)?.reorderCountries ?? 'Riordina nazioni',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _buildGlobalChip(provider, theme, countries),
                  ),
                  ...countries.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: _buildCountryChip(c, provider, theme, countries),
                      )),
                ],
              ),
            ),
            if (hasCities) ...[
              const Divider(height: 1),
              SizedBox(
                height: 45,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _buildCityChip(
                      {'name': AppLocalizations.of(context)?.allCities ?? 'Tutte le città', 'provider': ''},
                      provider,
                      theme,
                      countries,
                    ),
                    ..._citiesByCountry[_selectedCountry]!.map((city) => _buildCityChip(city, provider, theme, countries)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountryChip(Map<String, String> c, TrainProvider provider, ThemeProvider theme,
      List<Map<String, String>> countries) {
    final isSelected = _selectedCountry == c['code'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          c['name']!,
          style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : theme.secondaryTextColor),
        ),
        selected: isSelected,
        onSelected: (val) {
          _safeSetState(() {
            _selectedCountry = val ? c['code']! : '';
            _selectedCity = '';
          });
          _onSearchChanged(_searchController.text, provider, countries);
        },
        selectedColor: theme.primaryColor,
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildGlobalChip(TrainProvider provider, ThemeProvider theme, List<Map<String, String>> countries) {
    final isSelected = _selectedCountry == 'GLOBAL';
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            RuntimeLocalizations.t(context, 'global_label'),
            style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : theme.secondaryTextColor),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : theme.primaryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              RuntimeLocalizations.t(context, 'beta'),
              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : theme.primaryColor),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        _safeSetState(() {
          _selectedCountry = val ? 'GLOBAL' : '';
          _selectedCity = '';
        });
        _onSearchChanged(_searchController.text, provider, countries);
      },
      selectedColor: theme.primaryColor,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      showCheckmark: false,
    );
  }

  Widget _buildCityChip(Map<String, String> city, TrainProvider provider, ThemeProvider theme,
      List<Map<String, String>> countries) {
    final isSelected = _selectedCity == city['name'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(
          city['name']!,
          style: TextStyle(fontSize: 10, color: isSelected ? theme.primaryColor : theme.secondaryTextColor),
        ),
        selected: isSelected,
        onSelected: (val) {
          _safeSetState(() => _selectedCity = val ? city['name']! : '');
          _onSearchChanged(_searchController.text, provider, countries);
        },
        selectedColor: theme.primaryColor.withValues(alpha: 0.15),
        backgroundColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? theme.primaryColor : Colors.transparent),
        ),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildFavoriteSection(TrainProvider provider, ThemeProvider theme) {
    return Consumer2<FavoritesProvider, AuthProvider>(
      builder: (ctx, favs, auth, _) {
        if (!auth.isAuthenticated) return const SizedBox.shrink();
        final list = favs.favoriteStops.where((s) => s.stopType == StopType.trainStation).toList();
        if (list.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: list.length,
            itemBuilder: (ctx, i) => _buildFavoriteCard(list[i], provider, theme),
          ),
        );
      },
    );
  }

  Widget _buildFavoriteCard(FavoriteStop stop, TrainProvider provider, ThemeProvider theme) {
    return GestureDetector(
      onTap: () => provider.selectStation(
        TrainStation(id: stop.code, name: stop.name, country: stop.country ?? '', type: 'train'),
      ),
      child: Container(
        width: 110,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: theme.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, color: theme.primaryColor, size: 18),
            const SizedBox(height: 4),
            Text(
              stop.name,
              style: TextStyle(color: theme.textColor, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedTrainsButton(TrainProvider provider, ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _showSavedStationsSheet(provider, theme),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: _isOffline ? 0.2 : 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.download_done_rounded, color: theme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.savedTrains ?? 'Treni Salvati',
                      style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      AppLocalizations.of(context)?.accessOfflineData ?? 'Accedi ai dati scaricati offline',
                      style: TextStyle(color: theme.secondaryTextColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.secondaryTextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineError(ThemeProvider theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_rounded, size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)?.youAreOffline ?? 'Sei offline',
            style: TextStyle(color: theme.textColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)?.connectToSearchStations ?? 'Connettiti per cercare nuove stazioni',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStationSuggestionsList(TrainProvider provider, ThemeProvider theme) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: provider.stationSuggestions.length,
      itemBuilder: (ctx, i) {
        final s = provider.stationSuggestions[i];
        return _StationListTile(
          station: s,
          provider: provider,
          theme: theme,
          onLoadStats: _loadStatsAndNavigate,
          onAddStation: _addStationToDb,
        );
      },
    );
  }

  Widget _buildTrainSearchContent(ThemeProvider theme) {
    final query = _trainSearchController.text;
    final showLiveTrains = query.isEmpty && !_isSearchingDbTrain;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: TextField(
              controller: _trainSearchController,
              keyboardType: TextInputType.text,
              style: TextStyle(color: theme.textColor, fontSize: 17, fontWeight: FontWeight.bold),
              onChanged: (val) {
                _performTrainSearch(val);
                if (val.isEmpty) {
                  Future.microtask(() => _loadLiveTrains(silent: true));
                }
              },
              decoration: InputDecoration(
                hintText: 'Cerca treno (es. 9600)',
                hintStyle: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search_rounded, color: theme.primaryColor),
                suffixIcon: _trainSearchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: theme.secondaryTextColor),
                        onPressed: () {
                          _trainSearchController.clear();
                          _safeSetState(() {
                            _dbTrainResults.clear();
                            _isSearchingDbTrain = false;
                          });
                          Future.microtask(() => _loadLiveTrains(silent: true));
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
        ),
        Expanded(
          child: _isSearchingDbTrain
              ? ShimmerLoading(baseColor: theme.secondaryTextColor)
              : showLiveTrains
                  ? _buildLiveTrainsList(theme)
                  : _buildTrainSearchResults(theme),
        ),
      ],
    );
  }

  Widget _buildLiveTrainsList(ThemeProvider theme) {
    if (_isLoadingLiveTrains && _isFirstLiveLoad) {
      return ShimmerLoading(baseColor: theme.secondaryTextColor);
    }
    
    final mostViewed =
        _mostViewedTrains.map(_normalizePresenceTrain).toList();
    // Recenti non già live (evita duplicati con la sezione sopra).
    final recent = _recentTrains
        .where((e) =>
            (e['viewers'] is int ? e['viewers'] as int : 0) == 0)
        .take(5)
        .map(_normalizePresenceTrain)
        .toList();

    // Le sezioni presence sostituiscono la vecchia lista /api/trains/live
    // (niente più conflitti/duplicati tra le due fonti).
    if (mostViewed.isEmpty && recent.isEmpty) {
      if (_isLoadingLiveTrains) {
        return ShimmerLoading(baseColor: theme.secondaryTextColor);
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.train_rounded, size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Nessun treno seguito al momento',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'I dati vengono aggiornati automaticamente',
              style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      );
    }
    
    final children = <Widget>[];
    if (mostViewed.isNotEmpty) {
      children.add(_buildSectionHeader(
        theme,
        titleKey: 'most_viewed_trains',
        fallback: 'Treni con spettatori',
        total: _totalViewersLive,
        expanded: _mostViewedExpanded,
        onToggle: () =>
            _safeSetState(() => _mostViewedExpanded = !_mostViewedExpanded),
      ));
      if (_mostViewedExpanded) {
        for (final t in mostViewed) {
          children.add(_buildTrainListCard(t, theme));
        }
      }
    }
    if (recent.isNotEmpty) {
      children.add(_buildSectionHeader(
        theme,
        titleKey: 'recent_trains',
        fallback: 'Treni recenti',
        expanded: _recentExpanded,
        onToggle: () =>
            _safeSetState(() => _recentExpanded = !_recentExpanded),
      ));
      if (_recentExpanded) {
        for (final t in recent) {
          children.add(_buildTrainListCard(t, theme));
        }
      }
    }
    return RefreshIndicator(
      onRefresh: () async {
        await _loadLiveTrains(silent: false);
        await _loadMostViewed();
      },
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 100, top: 4),
        itemCount: children.length,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: theme.dividerColor),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }

  /// Titolo sezione comprimibile (più visualizzati / recenti) con
  /// eventuale badge del totale utenti collegati adesso.
  Widget _buildSectionHeader(
    ThemeProvider theme, {
    required String titleKey,
    required String fallback,
    int? total,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  RuntimeLocalizations.t(context, titleKey) ?? fallback,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: theme.secondaryTextColor,
                  ),
                ),
              ),
              if (total != null && total > 0) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$total',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Icon(
                expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
                color: theme.secondaryTextColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cerca il treno presence nella lista live (dati completi: tripId +
  /// tutte le fermate). Così il dettaglio aperto dai "più visualizzati"
  /// è completo come la vista normale invece di mostrare solo origine
  /// e destinazione.
  Map<String, dynamic>? _findLiveTrainForPresence(Map<String, dynamic> p) {
    final number = (p['trip_number'] ?? p['trainNumber'] ?? '').toString();
    if (number.isEmpty || _cachedLiveTrains.isEmpty) {
      debugPrint('[MostViewed] skip resolve: num="$number" liveCount=${_cachedLiveTrains.length}');
      return null;
    }
    final origin = (p['origin'] ?? '').toString().toLowerCase();
    final destination = (p['destination'] ?? '').toString().toLowerCase();
    Map<String, dynamic>? fallback;
    for (final e in _cachedLiveTrains) {
      if (e is! Map) continue;
      if ((e['trip_number'] ?? '').toString() != number) continue;
      final live = Map<String, dynamic>.from(e);
      fallback ??= live;
      final stops = live['stops'];
      if (stops is List && stops.isNotEmpty) {
        final first = stops.first is Map
            ? ((stops.first as Map)['stationName'] ?? '').toString().toLowerCase()
            : '';
        final last = stops.last is Map
            ? ((stops.last as Map)['stationName'] ?? '').toString().toLowerCase()
            : '';
        final originOk = origin.isEmpty || first == origin;
        final destOk = destination.isEmpty || last == destination;
        if (originOk && destOk) {
          debugPrint('[MostViewed] resolve num="$number": match ${live['trip_number']} (tripId=${live['trip_id']}, stops=${(live['stops'] as List?)?.length})');
          return live;
        }
      }
    }
    debugPrint('[MostViewed] resolve num="$number": ${fallback == null ? 'nessun match' : 'fallback senza match origine/dest'}');
    return fallback;
  }

  /// Costruisce una TrainDeparture completa da una mappa live/presence
  /// (usato dal tap con fallback su live freschi).
  TrainDeparture _buildDepartureFromMap(Map<String, dynamic> m) {
    final stopsRaw = m['stops'];
    final stopsList = stopsRaw is List ? stopsRaw : <dynamic>[];
    String origin = 'N/A';
    String destination = 'N/A';
    if (stopsList.isNotEmpty &&
        stopsList[0] is Map &&
        (stopsList[0] as Map)['stationName'] != null) {
      origin = (stopsList[0] as Map)['stationName'].toString();
    }
    if (stopsList.isNotEmpty &&
        stopsList.last is Map &&
        (stopsList.last as Map)['stationName'] != null) {
      destination = (stopsList.last as Map)['stationName'].toString();
    }
    int delay = 0;
    final dRaw = m['delay'] ?? m['delayMinutes'];
    if (dRaw is int) delay = dRaw;
    if (dRaw is double) delay = dRaw.round();
    if (dRaw is String) delay = int.tryParse(dRaw) ?? 0;
    DateTime? scheduled;
    final sRaw = (m['scheduledTime'] ?? '').toString();
    if (sRaw.isNotEmpty) scheduled = DateTime.tryParse(sRaw);
    DateTime? estimated;
    final eRaw = (m['estimatedTime'] ?? '').toString();
    if (eRaw.isNotEmpty) estimated = DateTime.tryParse(eRaw);
    if (stopsList.isNotEmpty && stopsList[0] is Map) {
      final s0 = stopsList[0] as Map;
      if (scheduled == null) {
        final t0 = (s0['scheduledDeparture'] ?? '').toString();
        if (t0.isNotEmpty) scheduled = DateTime.tryParse(t0);
      }
      if (estimated == null) {
        final t1 = (s0['estimatedDeparture'] ?? '').toString();
        if (t1.isNotEmpty) estimated = DateTime.tryParse(t1);
      }
    }
    final platformStr = (m['platform'] ?? '').toString();
    return TrainDeparture(
      tripId: m['trip_id']?.toString() ?? m['tripId']?.toString(),
      trainNumber: (m['trip_number'] ?? m['trainNumber'] ?? '').toString(),
      category: (m['category'] ?? '').toString(),
      origin: origin,
      destination: destination,
      scheduledTime: scheduled,
      estimatedTime: estimated,
      platform: platformStr.isNotEmpty ? platformStr : null,
      delayMinutes: delay,
      status: delay > 0 ? 'DELAYED' : 'ON_TIME',
      country: (m['country'] ?? m['countryCode'] ?? m['provider'] ?? 'EU').toString(),
      operator: (m['operator'] ?? 'N/A').toString(),
      stops: stopsList
          .whereType<Map>()
          .map((s) => TrainStop.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }

  /// Tap su una card: se è un treno presence senza tripId cerca i dati
  /// completi prima di aprire il dettaglio (stesso flusso della ricerca
  /// normale): 1) cache live, 2) live freschi, 3) tripId dal DB storico.
  /// Con il tripId la sheet carica il trip completo (tutte le fermate).
  Future<void> _openTrainCard(BuildContext context, TrainDeparture dep,
      dynamic train, ThemeProvider theme) async {
    // Treni regionali: sheet regionale, mai quella nazionale.
    if (train is Map) {
      final tmap = Map<String, dynamic>.from(train);
      final tripId = (tmap['trip_id'] ?? tmap['tripId'] ?? '').toString();
      if (_isRegionalTrain(tmap) && tripId.isNotEmpty) {
        final provider = await _resolveRegionalProvider(
          (tmap['provider'] ?? '').toString(),
          country: (tmap['country'] ?? 'IT').toString(),
        );
        if (provider != null && context.mounted) {
          debugPrint(
              '[MostViewed] apro sheet regionale ${provider.name} $tripId');
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => RegionalTrainDetailsSheet(
                provider: provider,
                tripId: tripId,
                trainNumber:
                    (tmap['trip_number'] ?? tmap['trainNumber'] ?? '')
                        .toString(),
                isArrivalMode: tmap['isArrival'] == true,
              ),
            ),
          );
          return;
        }
        debugPrint(
            '[MostViewed] provider regionale non risolto, fallback nazionale');
      }
    }
    var openDep = dep;
    if (train is Map &&
        train['viewers'] is int &&
        (train['trip_id'] == null && train['tripId'] == null)) {
      final tmap = Map<String, dynamic>.from(train);
      final tnum = (tmap['trip_number'] ?? tmap['trainNumber'] ?? '').toString();
      final tcat = (tmap['category'] ?? '').toString();
      debugPrint('[MostViewed] tap num=$tnum: provo live freschi');
      try {
        final response = await http
            .get(Uri.parse(
                'https://betacloud-transporter.is-cool.dev/api/trains/live'))
            .timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          final data = json.decode(response.body)['data'];
          if (data is List) {
            final savedCache = _cachedLiveTrains;
            _cachedLiveTrains = data;
            final live = _findLiveTrainForPresence(tmap);
            _cachedLiveTrains = savedCache;
            if (live != null) {
              final full = {...live, 'viewers': tmap['viewers']};
              openDep = _buildDepartureFromMap(full);
              debugPrint('[MostViewed] tap risolto: tripId=${full['trip_id']}, stops=${(full['stops'] as List?)?.length}');
            } else {
              debugPrint('[MostViewed] tap: treno non nei live freschi');
            }
          }
        }
      } catch (e) {
        debugPrint('[MostViewed] tap errore live freschi: $e');
      }
      // Fallback come la ricerca normale: tripId dal DB storico così la
      // sheet carica il trip completo invece di mostrare solo origine/dest.
      if (identical(openDep, dep) && tnum.isNotEmpty) {
        debugPrint('[MostViewed] tap num=$tnum: provo tripId dal DB');
        try {
          final tripData = await _fetchTripDataFromDb(tcat, tnum);
          final dbTripId = tripData?['trip_id']?.toString();
          if (dbTripId != null && dbTripId.isNotEmpty) {
            final full = {...tmap, 'trip_id': dbTripId, 'stops': []};
            openDep = _buildDepartureFromMap(full);
            debugPrint('[MostViewed] tap risolto dal DB: tripId=$dbTripId');
          } else {
            debugPrint('[MostViewed] tap: nessun tripId nel DB per $tcat $tnum');
          }
        } catch (e) {
          debugPrint('[MostViewed] tap errore DB: $e');
        }
      }
    }
    if (!context.mounted) return;
    _showTrainDetails(context, openDep, -1, theme);
  }

  /// Card treno della lista (stesso stile per live e più visualizzati).
  Widget _buildTrainListCard(dynamic train, ThemeProvider theme) {
          if (train is Map &&
              train['viewers'] is int &&
              (train['trip_id'] == null && train['tripId'] == null)) {
            final live = _findLiveTrainForPresence(
                Map<String, dynamic>.from(train));
            if (live != null) {
              // screen/provider originali restano: decidono la sheet giusta.
              train = {
                ...live,
                'viewers': train['viewers'],
                'screen': train['screen'],
                'provider': train['provider'],
              };
              debugPrint('[MostViewed] card num=${train['trip_number']}: uso dati live completi');
            } else {
              debugPrint('[MostViewed] card num=${train['trip_number']}: solo dati presence parziali');
            }
          }
          final m = train is Map
              ? Map<String, dynamic>.from(train)
              : <String, dynamic>{};
          final dep = _buildDepartureFromMap(m);
          final viewers = m['viewers'] is int ? m['viewers'] as int : 0;

          final cat = (dep.category ?? '').trim();
          final num = (dep.trainNumber ?? '').trim();
          final delay = dep.delayMinutes ?? 0;
          final origin = (dep.origin ?? '').trim();
          final dest = (dep.destination ?? '').trim();
          final route = origin.isNotEmpty &&
                  origin != 'N/A' &&
                  dest.isNotEmpty &&
                  dest != 'N/A'
              ? '$origin → $dest'
              : (dest.isNotEmpty && dest != 'N/A'
                  ? dest
                  : (origin.isNotEmpty ? origin : '--'));
          String? platform = dep.platform;
          DateTime? scheduled = dep.scheduledTime;
          DateTime? estimated = dep.estimatedTime;
          if (dep.stops != null && dep.stops!.isNotEmpty) {
            final s0 = dep.stops!.first;
            scheduled ??= s0.departure ?? s0.arrival;
            estimated ??= s0.estimatedDeparture ?? s0.estimatedArrival;
            if (platform == null || platform.isEmpty) platform = s0.platform;
          }
          final country = dep.country.isNotEmpty ? dep.country : 'EU';
          final isHighSpeed = cat.toLowerCase().contains('fr') ||
              cat.toLowerCase().contains('freccia') ||
              cat.toLowerCase().contains('ec') ||
              cat.toLowerCase().contains('ice') ||
              cat.toLowerCase().contains('tgv');
          final color = isHighSpeed ? Colors.redAccent : AppTokens.trainColor;

          final trainProvider =
              Provider.of<TrainProvider>(context, listen: false);
          final settings =
              Provider.of<SettingsProvider>(context, listen: false);
          String? logoUrl;
          if (settings.vectorLogosEnabled) {
            final key = cat.toUpperCase().replaceAll(' ', '_');
            final logo = trainProvider.trainLogos[key];
            logoUrl = logo != null ? (logo['png'] ?? logo['svg']) : null;
          }

          final timeStr = formatCountryTime(scheduled, country);
          final estStr =
              estimated != null ? formatCountryTime(estimated, country) : null;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openTrainCard(context, dep, m, theme),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    if (logoUrl != null)
                      Container(
                        height: 24,
                        constraints: const BoxConstraints(maxWidth: 50),
                        padding: theme.isDark
                            ? const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2)
                            : EdgeInsets.zero,
                        decoration: theme.isDark
                            ? BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                              )
                            : null,
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.contain,
                          alignment: Alignment.centerLeft,
                          errorBuilder: (_, __, ___) => Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '$cat $num',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.textColor,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (delay > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '+$delay\'',
                                    style: const TextStyle(
                                        color: Colors.orange,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ] else if (delay < 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$delay\'',
                                    style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                              if (viewers > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$viewers',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            route,
                            style: TextStyle(
                                color: theme.secondaryTextColor, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (platform != null && platform.isNotEmpty) ...[
                          _buildPlatformBox(platform, theme),
                          const SizedBox(width: 10),
                        ],
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Builder(
                              builder: (_) {
                                Color timeColor;
                                if (delay <= 0) {
                                  timeColor = Colors.green;
                                } else if (delay <= 5) {
                                  timeColor = Colors.orange;
                                } else if (delay <= 15) {
                                  timeColor = Colors.deepOrange;
                                } else {
                                  timeColor = Colors.red;
                                }
                                return Text(
                                  estStr != null && estStr != timeStr
                                      ? estStr
                                      : timeStr,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: estStr != null && estStr != timeStr
                                        ? timeColor
                                        : theme.textColor,
                                    fontSize: 15,
                                  ),
                                );
                              },
                            ),
                            if (estStr != null && estStr != timeStr)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  color: theme.secondaryTextColor,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildTrainSearchResults(ThemeProvider theme) {
    final query = _trainSearchController.text;
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded, size: 64, color: theme.secondaryTextColor.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'Ricerca nello storico',
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Inserisci il numero del treno per vederne le statistiche',
              style: TextStyle(color: theme.secondaryTextColor.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (_dbTrainResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 56, color: theme.secondaryTextColor.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(
                RuntimeLocalizations.t(context, 'search_train_no_results', params: {'query': query}),
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 4),
      itemCount: _dbTrainResults.length,
      itemBuilder: (ctx, i) {
        final train = _dbTrainResults[i];
        final category = (train['category'] ?? '').toString().trim();
        final number = (train['trainNumber'] ?? '').toString().trim();
        final destination = (train['destination'] ?? 'N/A').toString();
        final origin = (train['origin'] ?? '').toString();

        final country = (train['country'] ??
                train['countryCode'] ??
                train['provider'] ??
                (_selectedCountry.isNotEmpty ? _selectedCountry : 'IT'))
            .toString();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.surfaceColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.secondaryTextColor.withValues(alpha: 0.08)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3))],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () async {
              String? recentTripId = _getMostRecentTripId(train);

              final isNumeric = recentTripId != null ? int.tryParse(recentTripId) != null : false;
              final isTrainNumberOnly = isNumeric && recentTripId == number;
              
              if (recentTripId == null || recentTripId.isEmpty || isTrainNumberOnly) {
                showDialog(
                  context: context,
                  barrierColor: Colors.black12,
                  barrierDismissible: false,
                  builder: (ctx) => Center(
                    child: CircularProgressIndicator(
                      color: theme.primaryColor,
                    ),
                  ),
                );
                
                final tripData = await _fetchTripDataFromDb(category, number);
                
                if (tripData != null) {
                  recentTripId = tripData['trip_id'] as String?;
                  final delayFromDb = tripData['delay'] as int? ?? 0;
                  train['delay'] = delayFromDb;
                }
                
                if (mounted) Navigator.pop(context);
              }

              if (recentTripId == null || recentTripId.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Impossibile identificare il treno'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              final finalCountry = (train['country'] ??
                      train['countryCode'] ??
                      train['provider'] ??
                      country)
                  .toString();

              final int delayFromDb = train['delay'] as int? ?? 0;

              final dep = TrainDeparture(
                tripId: recentTripId,
                trainNumber: number,
                category: category,
                origin: origin,
                destination: destination,
                country: finalCountry,
                delayMinutes: delayFromDb,
              );

              if (mounted) {
                _showTrainDetails(context, dep, -1, theme);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          category,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.primaryColor),
                        ),
                        Text(
                          number,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: theme.textColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (origin.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.radio_button_unchecked, size: 12, color: theme.secondaryTextColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  origin,
                                  style: TextStyle(fontSize: 12, color: theme.secondaryTextColor),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded, size: 14, color: theme.primaryColor),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                destination,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.bar_chart_rounded, color: theme.primaryColor),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => train_stats.TrainStatsScreen(
                            category: category,
                            tripNumber: number,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimetableResults(
      BuildContext context, TrainProvider provider, ThemeProvider theme, TrainStation station) {
    final List<String> availablePlatforms = provider.departures
        .map((e) => e.platform?.toString().trim() ?? '-')
        .where((e) => e != '-')
        .toSet()
        .toList();
    availablePlatforms.sort();

    final filteredDepartures = _selectedPlatformFilter == null
        ? provider.departures
        : provider.departures
            .where((e) => e.platform.toString().trim() == _selectedPlatformFilter)
            .toList();

    return Column(
      key: const ValueKey('results'),
      children: [
        _buildTimetableHeader(provider, theme, station),
        if (availablePlatforms.isNotEmpty && !provider.isLoadingDepartures)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip(
                  AppLocalizations.of(context)?.allPlatforms ?? 'Tutti i Binari',
                  _selectedPlatformFilter == null,
                  theme,
                  () => _safeSetState(() => _selectedPlatformFilter = null),
                ),
                ...availablePlatforms.map((p) => _buildFilterChip(
                      '${AppLocalizations.of(context)?.platform ?? 'Binario'} $p',
                      _selectedPlatformFilter == p,
                      theme,
                      () => _safeSetState(() => _selectedPlatformFilter = p),
                    )),
              ],
            ),
          ),
        Expanded(
          child: provider.isLoadingDepartures
              ? ShimmerLoading(baseColor: theme.secondaryTextColor)
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: filteredDepartures.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (ctx, i) => _buildTrainCard(ctx, filteredDepartures[i], i, theme),
                ),
        ),
      ],
    );
  }

  Widget _buildTimetableHeader(TrainProvider provider, ThemeProvider theme, TrainStation station) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor, size: 20),
                onPressed: () => provider.clearSelection(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (_) {
                        // Più il nome è lungo, più il font si rimpicciolisce (20 → 9);
                        // il FittedBox garantisce che entri comunque, senza "…"
                        final size = (20.0 - (station.name.length - 20) * 0.25).clamp(9.0, 20.0);
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            station.name,
                            style: TextStyle(color: theme.textColor, fontSize: size, fontWeight: FontWeight.w900),
                            maxLines: 1,
                          ),
                        );
                      },
                    ),
                    Text(
                      station.country,
                      style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              _checkingStatus
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      icon: Icon(Icons.bar_chart_rounded,
                          color: _isMonitored ? theme.primaryColor : theme.secondaryTextColor),
                      onPressed: () async {
                        if (_isMonitored) {
                          await _loadStatsAndNavigate(context, station.id);
                        } else {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: theme.surfaceColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              title: Text(
                                RuntimeLocalizations.t(context, 'stats_monitoring_title'),
                                style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
                              ),
                              content: Text(
                                RuntimeLocalizations.t(context, 'stats_monitoring_msg'),
                                style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, height: 1.4),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(
                                    RuntimeLocalizations.t(context, 'cancel'),
                                    style: TextStyle(color: theme.secondaryTextColor),
                                  ),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: theme.primaryColor,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(ctx);
                                    await _addStationToDb(station.id, station.name);
                                  },
                                  child: Text(
                                    RuntimeLocalizations.t(context, 'add_now'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      tooltip: 'Statistiche e Monitoraggio Stazione',
                    ),
              _buildFavoriteToggle(station, theme),
            ],
          ),
          const SizedBox(height: 16),
          _buildDepartureArrivalToggle(provider, theme),
        ],
      ),
    );
  }

  Widget _buildTrainCard(BuildContext context, dynamic dep, int index, ThemeProvider theme) {
    // Stesso layout riga di StationDetailsScreen._buildDepartureItem,
    // con in più il tap per aprire i dettagli del treno.
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final isArrival = trainProvider.isArrivalMode;
    final cat = (dep.category?.toString() ?? '').trim();
    final num = (dep.trainNumber?.toString() ?? '').trim();
    // Arrivi: mostra la provenienza (la destinazione è la stazione stessa).
    // Partenze: mostra la destinazione.
    final dest = isArrival
        ? (dep.origin?.toString() ?? '').trim()
        : (dep.destination?.toString() ?? '').trim();
    final delay = dep.delayMinutes ?? 0;
    final scheduled = dep.scheduledTime;
    final estimated = dep.estimatedTime;
    final platform = dep.platform?.toString();
    final country = dep.country?.toString().isNotEmpty == true
        ? dep.country.toString()
        : trainProvider.selectedStation?.country;
    final isHighSpeed = cat.toLowerCase().contains('fr') ||
        cat.toLowerCase().contains('freccia') ||
        cat.toLowerCase().contains('ec') ||
        cat.toLowerCase().contains('ice') ||
        cat.toLowerCase().contains('tgv');
    final color = isHighSpeed ? Colors.redAccent : AppTokens.trainColor;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    String? logoUrl;
    if (settings.vectorLogosEnabled) {
      final key = cat.toUpperCase().replaceAll(' ', '_');
      final logo = trainProvider.trainLogos[key];
      logoUrl = logo != null ? (logo['png'] ?? logo['svg']) : null;
    }

    final timeStr = formatCountryTime(scheduled, country);
    final estStr = estimated != null ? formatCountryTime(estimated, country) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showTrainDetails(context, dep, index, theme),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (logoUrl != null)
                Container(
                  height: 24,
                  constraints: const BoxConstraints(maxWidth: 50),
                  padding: theme.isDark
                      ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                      : EdgeInsets.zero,
                  decoration: theme.isDark
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                        )
                      : null,
                  child: Image.network(
                    logoUrl,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    errorBuilder: (_, __, ___) => Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$cat $num',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                            fontSize: 14,
                          ),
                        ),
                        if (delay > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '+$delay\'',
                              style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ] else if (delay < 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$delay\'',
                              style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dest.isNotEmpty ? dest : '--',
                      style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (platform != null && platform.isNotEmpty) ...[
                    _buildPlatformBox(platform, theme),
                    const SizedBox(width: 10),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Builder(
                        builder: (_) {
                          Color timeColor;
                          if (delay <= 0) {
                            timeColor = Colors.green;
                          } else if (delay <= 5) {
                            timeColor = Colors.orange;
                          } else if (delay <= 15) {
                            timeColor = Colors.deepOrange;
                          } else {
                            timeColor = Colors.red;
                          }
                          return Text(
                            estStr != null && estStr != timeStr ? estStr : timeStr,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: estStr != null && estStr != timeStr ? timeColor : theme.textColor,
                              fontSize: 15,
                            ),
                          );
                        },
                      ),
                      if (estStr != null && estStr != timeStr)
                        Text(
                          timeStr,
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrainTypeBadge(dynamic dep, ThemeProvider theme) {
    if (dep == null) return const SizedBox.shrink();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final trainProvider = Provider.of<TrainProvider>(context, listen: false);
    final category = (dep.category?.toString() ?? 'TRN').trim();
    final number = (dep.trainNumber?.toString() ?? '').trim();

    if (settings.vectorLogosEnabled) {
      final key = category.toUpperCase().replaceAll(' ', '_');
      final logo = trainProvider.trainLogos[key];
      String? logoUrl;
      if (logo != null) {
        logoUrl = logo['png'] ?? logo['svg'];
      }
      debugPrint('[LogoBadge2] key="$key" found=${logo != null} url=$logoUrl');
      if (logoUrl != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 20,
              constraints: const BoxConstraints(maxWidth: 60),
              padding: theme.isDark
                  ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
                  : EdgeInsets.zero,
              decoration: theme.isDark
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    )
                  : null,
              child: Image.network(
                logoUrl,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                errorBuilder: (_, __, ___) => _buildColorBadge(category, number, theme),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return SizedBox(
                    width: 20,
                    child: Center(
                      child: SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 6),
            Text(number, style: TextStyle(fontWeight: FontWeight.bold, color: theme.textColor)),
          ],
        );
      }
    }
    return _buildColorBadge(category, number, theme);
  }

  Widget _buildColorBadge(String category, String number, ThemeProvider theme) {
    final isHighSpeed = category.toLowerCase().contains('fr') || category.toLowerCase().contains('freccia');
    final color = isHighSpeed ? Colors.redAccent : theme.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$category $number',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  /// Cartello binario stile "ticket" (come da riferimento): riquadro scuro
  /// con numero bianco e tacche laterali, a sinistra degli orari.
  Widget _buildPlatformBox(String bin, ThemeProvider theme) {
    final bg = theme.isDark ? const Color(0xFF5A5A5A) : const Color(0xFF4A4A4A);
    return Semantics(
      label: '${RuntimeLocalizations.t(context, 'platform')} $bin',
      child: Container(
        width: 32,
        height: 36,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  bin,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.0,
                  ),
                ),
              ),
            ),
            Positioned(
              left: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, ThemeProvider theme, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: theme.primaryColor,
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
      ),
    );
  }

  Widget _buildDepartureArrivalToggle(TrainProvider provider, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.secondaryTextColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleBtn(
              AppLocalizations.of(context)?.departures ?? 'PARTENZE',
              !provider.isArrivalMode,
              theme,
              () => provider.setArrivalMode(false),
            ),
          ),
          Expanded(
            child: _buildToggleBtn(
              AppLocalizations.of(context)?.arrivals ?? 'ARRIVI',
              provider.isArrivalMode,
              theme,
              () => provider.setArrivalMode(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleBtn(String label, bool active, ThemeProvider theme, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? theme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: active ? Colors.white : theme.secondaryTextColor,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildFavoriteToggle(TrainStation station, ThemeProvider theme) {
    return Consumer2<FavoritesProvider, AuthProvider>(
      builder: (ctx, favs, auth, _) {
        if (!auth.isAuthenticated) return const SizedBox.shrink();
        final isFav = favs.isStopFavorite(station.id, StopType.trainStation, country: station.country);
        return IconButton(
          icon: Icon(
            isFav ? Icons.favorite : Icons.favorite_border,
            color: isFav ? Colors.red : theme.secondaryTextColor,
          ),
          onPressed: () {
            if (isFav) {
              favs.removeStopFavorite(station.id, StopType.trainStation, country: station.country);
            } else {
              favs.addStopFavorite(
                favs.createFavoriteStop(
                  userId: auth.currentUser?.id.toString() ?? '',
                  name: station.name,
                  code: station.id,
                  stopType: StopType.trainStation,
                  country: station.country,
                ),
              );
            }
          },
        );
      },
    );
  }
}

class _SmartTrainRouteText extends StatefulWidget {
  final dynamic departure;
  final int index;
  final ThemeProvider theme;
  final bool isArrivalMode;
  const _SmartTrainRouteText({
    required this.departure,
    required this.index,
    required this.theme,
    required this.isArrivalMode,
  });

  @override
  State<_SmartTrainRouteText> createState() => _SmartTrainRouteTextState();
}

class _SmartTrainRouteTextState extends State<_SmartTrainRouteText> {
  @override
  void initState() {
    super.initState();
    if (widget.isArrivalMode && (widget.departure.origin == null || widget.departure.origin.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<TrainProvider>(context, listen: false).expandTrainDetails(widget.index);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String text = widget.isArrivalMode
        ? (widget.departure.origin ?? AppLocalizations.of(context)?.loading ?? 'Caricamento...')
        : (widget.departure.destination ?? 'N/A');
    // Più il nome è lungo, più il font si rimpicciolisce (17 → 9, senza limite intermedio)
    final double size = (17.0 - (text.length - 20) * 0.25).clamp(9.0, 17.0);
    final style = TextStyle(fontSize: size, fontWeight: FontWeight.bold, color: widget.theme.textColor);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textPainter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        if (textPainter.size.width > constraints.maxWidth) {
          return SizedBox(
            height: 25,
            child: Marquee(
              text: text,
              style: style,
              scrollAxis: Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              blankSpace: 30.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 1),
              startPadding: 0.0,
              accelerationDuration: const Duration(seconds: 1),
              accelerationCurve: Curves.linear,
              decelerationDuration: const Duration(milliseconds: 500),
              decelerationCurve: Curves.easeOut,
            ),
          );
        } else {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(text, style: style, maxLines: 1),
          );
        }
      },
    );
  }
}

class _StationListTile extends StatefulWidget {
  final TrainStation station;
  final TrainProvider provider;
  final ThemeProvider theme;
  final Future<void> Function(BuildContext, String) onLoadStats;
  final Future<void> Function(String, String) onAddStation;

  const _StationListTile({
    required this.station,
    required this.provider,
    required this.theme,
    required this.onLoadStats,
    required this.onAddStation,
  });

  @override
  State<_StationListTile> createState() => _StationListTileState();
}

class _StationListTileState extends State<_StationListTile> {
  bool _isMonitored = false;
  bool _checkingStatus = true;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    _checkStatus();
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (_isMounted) {
      setState(fn);
    }
  }

  Future<void> _checkStatus() async {
    if (!_isMounted) return;
    try {
      final response = await http
          .get(
            Uri.parse('https://betacloud-transporter.is-cool.dev/api/stats/monitor/check/${widget.station.id}'),
          )
          .timeout(const Duration(seconds: 5));
      if (!_isMounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _safeSetState(() {
          _isMonitored = data['isMonitored'] ?? false;
          _checkingStatus = false;
        });
      } else {
        _safeSetState(() => _checkingStatus = false);
      }
    } catch (e) {
      if (_isMounted) {
        _safeSetState(() => _checkingStatus = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(Icons.location_on_outlined, color: widget.theme.primaryColor),
      title: Text(
        widget.station.name,
        style: TextStyle(color: widget.theme.textColor, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        widget.station.country,
        style: TextStyle(color: widget.theme.secondaryTextColor, fontSize: 12),
      ),
      trailing: _checkingStatus
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: _isMonitored ? widget.theme.primaryColor : widget.theme.secondaryTextColor,
              ),
              onPressed: () async {
                if (_isMonitored) {
                  await widget.onLoadStats(context, widget.station.id);
                } else {
                  _showManualAddDialog();
                }
              },
            ),
      onTap: () => widget.provider.selectStation(widget.station),
    );
  }

  void _showManualAddDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.theme.surfaceColor,
        title: Text(
          RuntimeLocalizations.t(context, 'activate_monitoring'),
          style: TextStyle(color: widget.theme.textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          RuntimeLocalizations.t(context, 'station_not_monitored_msg'),
          style: TextStyle(color: widget.theme.secondaryTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              RuntimeLocalizations.t(context, 'cancel'),
              style: TextStyle(color: widget.theme.secondaryTextColor),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.theme.primaryColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.onAddStation(widget.station.id, widget.station.name);
              _checkStatus();
            },
            child: Text(
              RuntimeLocalizations.t(context, 'add_now'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
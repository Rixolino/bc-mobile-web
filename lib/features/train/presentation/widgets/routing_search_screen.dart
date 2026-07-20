// lib/presentation/trains/widgets/routing_search_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/services/runtime_localizations.dart';
import 'routing_details_screen.dart';
import 'routing_ui_components.dart';
import 'shimmer_and_toggle.dart';

class RoutingSearchScreen extends StatefulWidget {
  const RoutingSearchScreen({super.key});

  @override
  State<RoutingSearchScreen> createState() => _RoutingSearchScreenState();
}

class _RoutingSearchScreenState extends State<RoutingSearchScreen>
    with TickerProviderStateMixin {
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  bool _isSearchingRouting = false;
  Map<String, dynamic>? _routingData;
  TimeOfDay _selectedRoutingTime = TimeOfDay.now();
  DateTime _selectedRoutingDate = DateTime.now();
  String _selectedRoutingProvider = 'eurail';
  bool _isFormCompact = false;

  // Animazioni
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late AnimationController _searchAnimationController;
  late Animation<double> _searchSlideAnimation;
  late Animation<double> _searchScaleAnimation;
  late Animation<double> _formFadeAnimation;
  late Animation<double> _chipFadeAnimation;
  late Animation<double> _dateOpacityAnimation;
  late Animation<Offset> _dateSlideAnimation;
  
  // Nuova animazione per l'altezza dinamica
  late Animation<double> _containerHeightAnimation;

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

  // Date picker controller per scroll orizzontale
  late ScrollController _dateScrollController;
  final List<DateTime> _availableDates = [];

  @override
  void initState() {
    super.initState();
    
    _generateAvailableDates();
    _dateScrollController = ScrollController();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    
    _searchSlideAnimation = Tween<double>(
      begin: 0,
      end: -1,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _searchScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _formFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _chipFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: const Interval(0.2, 0.8, curve: Curves.easeIn),
    ));

    // Animazione dinamica per gestire lo spazio verticale
    _containerHeightAnimation = Tween<double>(
      begin: 190.0,
      end: 45.0, // Altezza ridotta della chip
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _dateOpacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    ));
    
    _dateSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    ));
    
    _animationController.forward();
  }

  void _generateAvailableDates() {
    _availableDates.clear();
    for (int i = -1; i < 90; i++) {
      _availableDates.add(DateTime.now().add(Duration(days: i)));
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _animationController.dispose();
    _searchAnimationController.dispose();
    _dateScrollController.dispose();
    super.dispose();
  }

  String _getTimezoneForCountry(String countryCode) {
    if (countryCode.isEmpty) return 'Europe/Rome';
    final upper = countryCode.toUpperCase();
    return _timezoneMap[upper] ?? 'Europe/Rome';
  }

  String _formatTimeWithTimezone(String timeStr, String? dateStr, String countryCode) {
    if (timeStr.isEmpty || timeStr == '--:--') return '--:--';
    
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

  String _extractCountryFromTrain(dynamic train) {
    if (train == null) return 'EU';
    
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

  Map<String, dynamic> _normalizeRoutingData(Map<String, dynamic> rawData) {
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
    
    if (provider == 'rfi' && rawData['data'] != null) {
      return _normalizeRfiData(rawData);
    }
    
    if (provider == 'eurail' && rawData['data'] != null) {
      return _normalizeEurailData(rawData);
    }
    
    if (rawData['soluzioni'] != null) {
      return rawData;
    }
    
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
        
        if (n < nodes.length - 1) {
          final nextNode = nodes[n + 1];
          if (nextNode is Map<String, dynamic>) {
            try {
              final arrival = DateTime.parse(node['arrivalTime']?.toString() ?? '');
              final departure = DateTime.parse(nextNode['departureTime']?.toString() ?? '');
              final diff = departure.difference(arrival);
              leg['attesaCambioMinuti'] = diff.inMinutes > 0 ? diff.inMinutes : 0;
            } catch (_) {}
          }
        }
        
        percorso.add(leg);
      }
      
      if (percorso.isEmpty) continue;
      
      int totalStops = 0;
      for (final node in nodes) {
        if (node is Map<String, dynamic>) {
          final stops = node['stops'] as List?;
          if (stops != null) totalStops += stops.length;
        }
      }
      
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
      // Salta leg di tipo PLATFORM_CHANGE o STATION_CHANGE_WALK
      // ma mantieni i leg di tipo TRAIN_TRAVEL
      if (legType == 'PLATFORM_CHANGE' || legType == 'STATION_CHANGE_WALK') {
        continue;
      }
      
      final start = leg['start'] as Map<String, dynamic>? ?? {};
      final end = leg['end'] as Map<String, dynamic>? ?? {};
      final transport = leg['transport'] as Map<String, dynamic>? ?? {};
      
      // Estrai categoria e numero treno in modo robusto
      final rawCode = transport['code']?.toString() ?? transport['trainNumber']?.toString() ?? '';
      final fallbackCategory = transport['trainType']?.toString() ?? transport['type']?.toString() ?? 'TRN';
      String categoriaEstratta = RegExp(r'^[a-zA-Z]+').stringMatch(rawCode) ?? fallbackCategory;
      
      // Normalizzazione categorie per Eurail
      final categoryMap = {
        'INI': 'ICN',
        'NI': 'ICN',
        'FR': 'FR',
        'EN': 'EN',
        'EC': 'EC',
        'RJ': 'RJ',
        'RJX': 'RJX',
        'NJ': 'NJ',
        'RE': 'RE',
        'IC': 'IC',
        'S': 'S',
        'SBA': 'S',
        'TGV': 'TGV',
        'AVE': 'AVE',
        'EXP': 'EXP',
        'BUS': 'BUS',
        'TRN': 'TRN',
      };
      
      if (categoryMap[categoriaEstratta] != null) {
        categoriaEstratta = categoryMap[categoriaEstratta]!;
      }
      
      // Per il numero del treno
      String numeroTreno = transport['trainNumber']?.toString() ?? '';
      if (numeroTreno.isEmpty) {
        final code = transport['code']?.toString() ?? '';
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
      
      // STOPS - FIX PER EURAIL
      // Gestisce sia il caso in cui stops è una lista di oggetti che di stringhe
      final stopsData = leg['stops'] as Map<String, dynamic>?;
      if (stopsData != null) {
        final stopsList = stopsData['stops'] as List? ?? [];
        legData['stops'] = stopsList.map((s) {
          if (s is Map<String, dynamic>) {
            // Caso RFI: oggetto con campo 'station'
            return s['station']?.toString() ?? s['name']?.toString() ?? s.toString();
          }
          // Caso Eurail: stringa diretta
          return s.toString();
        }).toList();
      } else {
        legData['stops'] = [];
      }
      
      // Calcola attesa cambio (differenza tra arrivo di questo leg e partenza del precedente)
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

  Future<void> _performRoutingSearch() async {
    final origin = _originController.text.trim();
    final dest = _destinationController.text.trim();
    
    if (origin.length < 2 || dest.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RuntimeLocalizations.t(context, 'routing_enter_origin_dest') ?? 'Inserisci origine e destinazione'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    
    setState(() {
      _isSearchingRouting = true;
      _routingData = null;
    });

    try {
      final String timeStr = '${_selectedRoutingTime.hour.toString().padLeft(2, '0')}:${_selectedRoutingTime.minute.toString().padLeft(2, '0')}';
      final String dateStr = '${_selectedRoutingDate.year}-${_selectedRoutingDate.month.toString().padLeft(2, '0')}-${_selectedRoutingDate.day.toString().padLeft(2, '0')}';
      
      final Map<String, dynamic> payload = {
        'provider': _selectedRoutingProvider,
        'from': origin,
        'to': dest,
        'date': dateStr,
        'time': timeStr,
      };

      if (_selectedRoutingProvider == 'eurail') {
        payload['tripsNumber'] = 5;
        payload['includeStops'] = true;
        payload['travellers'] = 1;
        payload['currency'] = 'EUR';
        
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
        setState(() {
          _routingData = normalizedData;
          _isSearchingRouting = false;
        });
        
        _searchAnimationController.forward();
        _isFormCompact = true;
        
        final totaleSoluzioni = normalizedData['totaleSoluzioni'] ?? 0;
        if (totaleSoluzioni > 0) {
          debugPrint('  - $totaleSoluzioni soluzioni trovate');
          _animationController.reset();
          _animationController.forward();
        } else {
          debugPrint('  - Nessuna soluzione trovata');
        }
      } else {
        String errorMessage = 'Errore: ${response.statusCode}';
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
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        setState(() => _isSearchingRouting = false);
      }
    } catch (e) {
      debugPrint('❌ Errore ricerca soluzioni: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      setState(() => _isSearchingRouting = false);
    }
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedRoutingDate = date;
    });
    final index = _availableDates.indexOf(date);
    if (index >= 0) {
      final double targetOffset = (index * 70) - (MediaQuery.of(context).size.width / 2) + 35;
      _dateScrollController.animateTo(
        targetOffset.clamp(0, _dateScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
                    setState(() {
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
      setState(() {
        _selectedRoutingTime = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        foregroundColor: theme.textColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          RuntimeLocalizations.t(context, 'solutions') ?? 'Soluzioni',
          style: TextStyle(
            color: theme.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.secondaryTextColor.withValues(alpha: 0.1),
          ),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          
          // NUOVO ANIMATED BUILDER CON ALTEZZA DINAMICA
          AnimatedBuilder(
            animation: _searchAnimationController,
            builder: (context, child) {
              final double scaleValue = _searchScaleAnimation.value;
              final double formOpacity = _formFadeAnimation.value;
              final double chipOpacity = _chipFadeAnimation.value;
              final double containerHeight = _containerHeightAnimation.value;
              
              return Container(
                height: containerHeight,
                clipBehavior: Clip.none, // Permette alle ombre di non essere tagliate
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // --- FORM DI RICERCA ESTESO ---
                    IgnorePointer(
                      ignoring: _isFormCompact, // Disabilita i tap quando è nascosto
                      child: Opacity(
                        opacity: formOpacity,
                        child: Transform.scale(
                          scale: scaleValue,
                          alignment: Alignment.topCenter,
                          child: _buildSearchForm(theme),
                        ),
                      ),
                    ),
                    
                    // --- CHIP COMPATTO (RIASSUNTO) ---
                    IgnorePointer(
                      ignoring: !_isFormCompact, // Disabilita i tap quando è nascosto
                      child: Opacity(
                        opacity: chipOpacity,
                        child: _buildSearchChip(theme),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          AnimatedBuilder(
            animation: _searchAnimationController,
            builder: (context, child) {
              return SlideTransition(
                position: _dateSlideAnimation,
                child: FadeTransition(
                  opacity: _dateOpacityAnimation,
                  child: child,
                ),
              );
            },
            child: _buildDatePicker(theme),
          ),
          Expanded(
            child: _isSearchingRouting
                ? _buildLoadingState(theme)
                : _routingData == null
                    ? _buildEmptyState(theme)
                    : FadeTransition(
                        opacity: _fadeAnimation,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: _buildRoutingResultsList(theme),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchChip(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.trip_origin_rounded, color: theme.primaryColor, size: 14),
          const SizedBox(width: 4),
          Expanded(
            flex: 1,
            child: Text(
              _originController.text.isNotEmpty 
                  ? _originController.text 
                  : 'Origine',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(Icons.arrow_forward_rounded, color: theme.primaryColor, size: 14),
          ),
          Expanded(
            flex: 1,
            child: Text(
              _destinationController.text.isNotEmpty 
                  ? _destinationController.text 
                  : 'Destinazione',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: theme.secondaryTextColor.withValues(alpha: 0.2),
          ),
          Row(
            children: [
              Icon(Icons.access_time_rounded, color: theme.primaryColor, size: 12),
              const SizedBox(width: 2),
              Text(
                _selectedRoutingTime.format(context),
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Container(
            width: 1,
            height: 18,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: theme.secondaryTextColor.withValues(alpha: 0.2),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _selectedRoutingProvider == 'rfi' 
                  ? Colors.blue.withValues(alpha: 0.1) 
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _selectedRoutingProvider.toUpperCase(),
              style: TextStyle(
                color: _selectedRoutingProvider == 'rfi' 
                    ? Colors.blue 
                    : Colors.green,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              _searchAnimationController.reverse();
              _isFormCompact = false;
            },
            icon: Icon(
              Icons.expand_more_rounded,
              color: theme.secondaryTextColor,
              size: 18,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            splashRadius: 16,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchForm(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSearchField(
            controller: _originController,
            hintText: RuntimeLocalizations.t(context, 'routing_origin_hint') ?? 'Origine',
            icon: Icons.trip_origin_rounded,
            iconColor: theme.primaryColor,
            theme: theme,
          ),
          const Divider(height: 1),
          _buildSearchField(
            controller: _destinationController,
            hintText: RuntimeLocalizations.t(context, 'routing_destination_hint') ?? 'Destinazione',
            icon: Icons.location_on_rounded,
            iconColor: Colors.redAccent,
            theme: theme,
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedRoutingProvider,
                        isExpanded: true,
                        style: TextStyle(
                          color: theme.textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        dropdownColor: theme.surfaceColor,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: theme.primaryColor, size: 20),
                        items: const [
                          DropdownMenuItem(value: 'eurail', child: Text('Eurail')),
                          DropdownMenuItem(value: 'rfi', child: Text('RFI / LeFrecce')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedRoutingProvider = value);
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  color: theme.secondaryTextColor.withValues(alpha: 0.15),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectRoutingTime(context, theme),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.access_time_rounded, color: theme.primaryColor, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _selectedRoutingTime.format(context),
                              style: TextStyle(
                                color: theme.textColor,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down_rounded, color: theme.secondaryTextColor, size: 18),
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
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.primaryColor,
                    theme.primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Center(
                child: _isSearchingRouting
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            RuntimeLocalizations.t(context, 'routing_search_btn') ?? 'Cerca Soluzioni',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _selectedRoutingProvider.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 8,
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
    );
  }

  Widget _buildDatePicker(ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.builder(
        controller: _dateScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _availableDates.length,
        itemBuilder: (context, index) {
          final date = _availableDates[index];
          final isSelected = date.year == _selectedRoutingDate.year &&
              date.month == _selectedRoutingDate.month &&
              date.day == _selectedRoutingDate.day;
          final isToday = date.year == DateTime.now().year &&
              date.month == DateTime.now().month &&
              date.day == DateTime.now().day;
          final dayName = DateFormat('E').format(date).substring(0, 3);
          final dayNumber = date.day.toString().padLeft(2, '0');
          final month = DateFormat('MMM').format(date);

          return GestureDetector(
            onTap: () => _selectDate(date),
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: isSelected 
                    ? theme.primaryColor 
                    : theme.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected 
                      ? theme.primaryColor 
                      : theme.secondaryTextColor.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayName.toUpperCase(),
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white 
                          : theme.secondaryTextColor,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dayNumber,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white 
                          : theme.textColor,
                      fontSize: 15,
                      fontWeight: isSelected 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white70 
                          : theme.secondaryTextColor,
                      fontSize: 7,
                    ),
                  ),
                  if (isToday && !isSelected)
                    Container(
                      margin: const EdgeInsets.only(top: 1),
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    required ThemeProvider theme,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: theme.textColor,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: theme.secondaryTextColor.withValues(alpha: 0.5),
        ),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: Icon(Icons.clear_rounded, color: theme.secondaryTextColor, size: 18),
                onPressed: () {
                  controller.clear();
                  setState(() {});
                },
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildLoadingState(ThemeProvider theme) {
    return ShimmerLoading(
      baseColor: theme.secondaryTextColor.withValues(alpha: 0.1),
    );
  }

  Widget _buildEmptyState(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.alt_route_rounded,
                size: 56,
                color: theme.primaryColor.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              RuntimeLocalizations.t(context, 'routing_empty') ?? 'Cerca Soluzioni',
              style: TextStyle(
                color: theme.textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Inserisci origine e destinazione per trovare\nle migliori soluzioni di viaggio',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.secondaryTextColor,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFeatureChip(
                  icon: Icons.train_rounded,
                  label: 'Treni',
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildFeatureChip(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Cambi',
                  theme: theme,
                ),
                const SizedBox(width: 8),
                _buildFeatureChip(
                  icon: Icons.access_time_rounded,
                  label: 'Orari',
                  theme: theme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureChip({
    required IconData icon,
    required String label,
    required ThemeProvider theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.secondaryTextColor.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.primaryColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
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
              Icon(Icons.search_off_rounded, size: 56, color: theme.secondaryTextColor.withValues(alpha: 0.4)),
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

    return RefreshIndicator(
      onRefresh: _performRoutingSearch,
      color: theme.primaryColor,
      backgroundColor: theme.surfaceColor,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 20, top: 4),
        itemCount: solutions.length,
        itemBuilder: (ctx, i) {
          final sol = solutions[i] as Map<String, dynamic>;
          final percorso = sol['percorso'] as List? ?? [];
          final changes = sol['cambi'] as int? ?? 0;
          final firstLeg = percorso.isNotEmpty ? percorso.first as Map<String, dynamic>? : null;
          final lastLeg = percorso.isNotEmpty ? percorso.last as Map<String, dynamic>? : null;
          final isDirect = changes == 0;

          String durataLeggibile = sol['durataViaggioTotaleLeggibile'] ?? '--:--';
          
          if (durataLeggibile == '--:--' && firstLeg != null && lastLeg != null) {
            final firstPartenza = firstLeg['partenza'] as String? ?? '--:--';
            final lastArrivo = lastLeg['arrivo'] as String? ?? '--:--';
            final firstData = firstLeg['dataPartenza'] as String? ?? '';
            final lastData = lastLeg['dataArrivo'] as String? ?? '';
            
            if (provider == 'eurail') {
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

          final totalStops = percorso.fold<int>(
            0,
            (sum, leg) {
              final legMap = leg as Map<String, dynamic>;
              final stops = legMap['stops'] as List?;
              return sum + (stops?.length ?? 0);
            },
          );

          String arrivoFormattato = sol['arrivoStimato'] as String? ?? '--:--';
          if (lastLeg != null) {
            final arrivoRaw = lastLeg['arrivo'] as String? ?? '--:--';
            if (provider == 'eurail') {
              arrivoFormattato = arrivoRaw;
            } else {
              arrivoFormattato = _formatTimeWithTimezone(
                arrivoRaw,
                lastLeg['dataArrivo'] as String?,
                _getCountryCodeForSolution(sol)
              );
            }
          }

          String partenzaFormattata = '--:--';
          String dataPartenzaFormattata = '';
          if (firstLeg != null) {
            final partenzaRaw = firstLeg['partenza'] as String? ?? '--:--';
            if (provider == 'eurail') {
              partenzaFormattata = partenzaRaw;
            } else {
              partenzaFormattata = _formatTimeWithTimezone(
                partenzaRaw,
                firstLeg['dataPartenza'] as String?,
                _getCountryCodeForSolution(sol)
              );
            }
            dataPartenzaFormattata = firstLeg['dataPartenza'] as String? ?? '';
          }

          String prezzoText = '';
          final prezzo = sol['prezzo'] ?? 0;
          if (prezzo is num && prezzo > 0) {
            prezzoText = '€${prezzo.toStringAsFixed(2)}';
          }

          return GestureDetector(
            onTap: () {
              _searchAnimationController.reverse();
              _isFormCompact = false;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutingDetailsScreen(
                    routingData: _routingData!,
                    selectedSolutionIndex: i,
                  ),
                ),
              ).then((_) {
                if (_routingData != null && (_routingData?['totaleSoluzioni'] ?? 0) > 0) {
                  _searchAnimationController.forward();
                  _isFormCompact = true;
                }
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: theme.surfaceColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: theme.secondaryTextColor.withValues(alpha: 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _searchAnimationController.reverse();
                    _isFormCompact = false;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoutingDetailsScreen(
                          routingData: _routingData!,
                          selectedSolutionIndex: i,
                        ),
                      ),
                    ).then((_) {
                      if (_routingData != null && (_routingData?['totaleSoluzioni'] ?? 0) > 0) {
                        _searchAnimationController.forward();
                        _isFormCompact = true;
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildStatusChip(
                                  isDirect: isDirect,
                                  changes: changes,
                                  theme: theme,
                                ),
                                const SizedBox(width: 8),
                                if (firstLeg != null)
                                  _buildTrainBadge(
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
                                      color: theme.primaryColor.withValues(alpha: 0.1),
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
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded,
                                        size: 14, color: theme.secondaryTextColor),
                                    const SizedBox(width: 4),
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
                                    fontSize: 24,
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.arrow_forward_rounded,
                                      color: theme.primaryColor, size: 16),
                                  if (changes > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Text(
                                        '$changes',
                                        style: TextStyle(
                                          color: theme.primaryColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  arrivoFormattato,
                                  style: TextStyle(
                                    color: theme.textColor,
                                    fontSize: 24,
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
                              Icon(Icons.subdirectory_arrow_right_rounded,
                                  size: 14, color: theme.secondaryTextColor),
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
                              Icon(Icons.train_rounded,
                                  size: 14, color: theme.secondaryTextColor),
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
                                color: theme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    'Dettagli',
                                    style: TextStyle(
                                      color: theme.primaryColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 10, color: theme.primaryColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        _buildProviderBadge(provider, theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusChip({
    required bool isDirect,
    required int changes,
    required ThemeProvider theme,
  }) {
    final Color color = isDirect ? theme.successColor : Colors.orange;
    final String label = isDirect
        ? (RuntimeLocalizations.t(context, 'routing_direct') ?? 'Diretto')
        : (RuntimeLocalizations.t(context, 'routing_changes', params: {'count': changes.toString()}) ?? '$changes cambi');
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDirect ? Icons.check_circle_rounded : Icons.swap_horiz_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderBadge(String provider, ThemeProvider theme) {
    final Color color = provider == 'rfi' ? Colors.blue : Colors.green;
    final String label = provider == 'rfi' ? 'RFI / LeFrecce' : 'Eurail';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTrainBadge(String category, String number, ThemeProvider theme) {
    final bool isHighSpeed = category.toLowerCase().contains('fr') ||
        category.toLowerCase().contains('freccia') ||
        category.toLowerCase().contains('ec') ||
        category.toLowerCase().contains('ic') ||
        category.toLowerCase().contains('rj') ||
        category.toLowerCase().contains('tgv') ||
        category.toLowerCase().contains('ave');
    
    final Color color = isHighSpeed ? Colors.redAccent : theme.primaryColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isHighSpeed)
            Icon(Icons.speed_rounded, size: 10, color: color),
          Text(
            '$category $number',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
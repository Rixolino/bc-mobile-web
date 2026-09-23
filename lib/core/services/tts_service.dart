import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:just_audio/just_audio.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:http/http.dart' as http;

/// Voci italiane Oddcast (engine 2 = Loquendo/DiVoX)
class OddcastVoice {
  final String name;
  final int id;
  final int engine;
  final String gender;

  const OddcastVoice({
    required this.name,
    required this.id,
    required this.engine,
    required this.gender,
  });
}

class _QueueEntry {
  final String text;
  final String trainKey;
  _QueueEntry(this.text, this.trainKey);
}

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final _TrainAudioPlayer _player = _TrainAudioPlayer();
  double _speechRate = 1.0;

  /// Velocità lettura 0.5–1.5 (default 1.0). Si applica al player audio.
  double get speechRate => _speechRate;

  Future<void> setSpeechRate(double value) async {
    _speechRate = value.clamp(0.5, 1.5);
    print('[TTS] setSpeechRate: $_speechRate');
    try {
      await _player.setSpeed(_speechRate);
      print('[TTS] setSpeed ok, player.speed=${_player.speed}');
    } catch (e) {
      print('[TTS] setSpeed ERRORE: $e');
    }
  }
  bool _initialized = false;
  bool _enabled = false;

  /// Voci italiane Oddcast disponibili
  static const List<OddcastVoice> italianVoices = [
    OddcastVoice(name: 'Paola', id: 1, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Silvana', id: 2, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Valentina', id: 3, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Luca', id: 5, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Marcello', id: 6, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Roberto', id: 7, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Matteo', id: 8, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Giulia', id: 9, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Federica', id: 10, engine: 2, gender: 'F'),
  ];

  /// Mappa codici lingua Flutter -> Oddcast language ID
  static const Map<String, int> _langIdMap = {
    'it': 7,
    'en': 1,
    'de': 3,
    'fr': 4,
  };

  /// Mappa codici lingua -> voce predefinita
  static const Map<String, OddcastVoice> _defaultVoiceMap = {
    'it': OddcastVoice(name: 'Paola', id: 1, engine: 2, gender: 'F'),
    'en': OddcastVoice(name: 'Daniel', id: 5, engine: 4, gender: 'M'),
    'de': OddcastVoice(name: 'Anna', id: 3, engine: 4, gender: 'F'),
    'fr': OddcastVoice(name: 'Thomas', id: 5, engine: 4, gender: 'M'),
  };

  /// Mappa categorie treni -> nomi pronunciati per lingua
  static const Map<String, Map<String, String>> _categoryNames = {
    // Italia — Trenitalia
    'FR': {'it': 'Frecciarossa', 'en': 'Frecciarossa', 'de': 'Frecciarossa', 'fr': 'Frecciarossa'},
    'FA': {'it': 'Frecciargento', 'en': 'Frecciargento', 'de': 'Frecciargento', 'fr': 'Frecciargento'},
    'FB': {'it': 'Frecciabianca', 'en': 'Frecciabianca', 'de': 'Frecciabianca', 'fr': 'Frecciabianca'},
    'FRV': {'it': 'Frecciarossa', 'en': 'Frecciarossa', 'de': 'Frecciarossa', 'fr': 'Frecciarossa'},
    'IC': {'it': 'Intercity', 'en': 'Intercity', 'de': 'Intercity', 'fr': 'Intercité'},
    'ICN': {'it': 'Intercity Notte', 'en': 'Intercity Night', 'de': 'Intercity Nacht', 'fr': 'Intercité Nuit'},
    'EC': {'it': 'Eurocity', 'en': 'Eurocity', 'de': 'Eurocity', 'fr': 'Eurocity'},
    'EN': {'it': 'EuroNight', 'en': 'EuroNight', 'de': 'EuroNight', 'fr': 'EuroNight'},
    'ES': {'it': 'Eurostar Italia', 'en': 'Eurostar Italia', 'de': 'Eurostar Italien', 'fr': 'Eurostar Italie'},
    'RV': {'it': 'Regionale Veloce', 'en': 'Fast Regional', 'de': 'Schnell regional', 'fr': 'Régional express'},
    'R': {'it': 'Regionale', 'en': 'Regional', 'de': 'Regional', 'fr': 'Régional'},
    'REG': {'it': 'Regionale', 'en': 'Regional', 'de': 'Regional', 'fr': 'Régional'},
    'RM': {'it': 'Regionale Metropolitano', 'en': 'Metro Regional', 'de': 'S-Bahn', 'fr': 'Régional métro'},
    'PM': {'it': 'Pendolino', 'en': 'Pendolino', 'de': 'Pendolino', 'fr': 'Pendolino'},
    'AV': {'it': 'Alta Velocità', 'en': 'High Speed', 'de': 'Hochgeschwindigkeit', 'fr': 'Grande vitesse'},
    'ETR': {'it': 'Alta Velocità', 'en': 'High Speed', 'de': 'Hochgeschwindigkeit', 'fr': 'Grande vitesse'},
    'NTV': {'it': 'Italo', 'en': 'Italo', 'de': 'Italo', 'fr': 'Italo'},
    'TRD': {'it': 'Trenitalia', 'en': 'Trenitalia', 'de': 'Trenitalia', 'fr': 'Trenitalia'},
    'RE': {'it': 'Regionale Veloce', 'en': 'Regional Express', 'de': 'RegionalExpress', 'fr': 'Regional Express'},
    // Francia — SNCF
    'TGV': {'it': 'TGV', 'en': 'TGV', 'de': 'TGV', 'fr': 'TGV'},
    'TGVIN': {'it': 'TGV InOui', 'en': 'TGV InOui', 'de': 'TGV InOui', 'fr': 'TGV InOui'},
    'OUIGO': {'it': 'OUIGO', 'en': 'OUIGO', 'de': 'OUIGO', 'fr': 'OUIGO'},
    'TER': {'it': 'TER', 'en': 'TER', 'de': 'TER', 'fr': 'TER'},
    'ICE': {'it': 'InterCity Express', 'en': 'InterCity Express', 'de': 'InterCity Express', 'fr': 'InterCity Express'},
    'THL': {'it': 'Thalys', 'en': 'Thalys', 'de': 'Thalys', 'fr': 'Thalys'},
    'THA': {'it': 'Thalys', 'en': 'Thalys', 'de': 'Thalys', 'fr': 'Thalys'},
    'EUROSTAR': {'it': 'Eurostar', 'en': 'Eurostar', 'de': 'Eurostar', 'fr': 'Eurostar'},
    'FRET': {'it': 'Fret SNCF', 'en': 'SNCF Freight', 'de': 'SNCF Fracht', 'fr': 'Fret SNCF'},
    // Germania — DB
    'RB': {'it': 'Regionale', 'en': 'Regional Bahn', 'de': 'RegionalBahn', 'fr': 'RegionalBahn'},
    'S': {'it': 'Suburbano', 'en': 'S-Bahn', 'de': 'S-Bahn', 'fr': 'S-Bahn'},
    'D': {'it': 'Eurocity', 'en': 'Eurocity', 'de': 'Eurocity', 'fr': 'Eurocity'},
    'HKX': {'it': 'Hamburg-Köln Express', 'en': 'Hamburg-Köln Express', 'de': 'Hamburg-Köln-Express', 'fr': 'Hamburg-Köln Express'},
    // Austria — ÖBB
    'RJ': {'it': 'Railjet', 'en': 'Railjet', 'de': 'Railjet', 'fr': 'Railjet'},
    'RJX': {'it': 'Railjet Express', 'en': 'Railjet Express', 'de': 'Railjet Express', 'fr': 'Railjet Express'},
    'NJ': {'it': 'Nightjet', 'en': 'Nightjet', 'de': 'Nightjet', 'fr': 'Nightjet'},
    'WEST': {'it': 'Westbahn', 'en': 'Westbahn', 'de': 'Westbahn', 'fr': 'Westbahn'},
    // Spagna — Renfe
    'AVE': {'it': 'AVE', 'en': 'AVE', 'de': 'AVE', 'fr': 'AVE'},
    'ALV': {'it': 'AVE', 'en': 'AVE', 'de': 'AVE', 'fr': 'AVE'},
    'AVLO': {'it': 'AVLO', 'en': 'AVLO', 'de': 'AVLO', 'fr': 'AVLO'},
    'MD': {'it': 'Media Distancia', 'en': 'Medium Distance', 'de': 'Mittelstrecke', 'fr': 'Moyenne distance'},
    'AR': {'it': 'Cercanías', 'en': 'Commuter', 'de': 'Cercanías', 'fr': 'Cercanías'},
    'IR': {'it': 'InterRegio', 'en': 'InterRegio', 'de': 'InterRegio', 'fr': 'InterRegio'},
    // Svizzera — SBB/CFF
    'SC': {'it': 'Swiss City', 'en': 'Swiss City', 'de': 'Swiss City', 'fr': 'S-Bahn Suisse'},
    'FL': {'it': 'SBB', 'en': 'SBB', 'de': 'SBB', 'fr': 'CFF'},
    // UK
    'GWR': {'it': 'Great Western', 'en': 'Great Western Railway', 'de': 'Great Western', 'fr': 'Great Western'},
    'VT': {'it': 'Virgin Trains', 'en': 'Virgin Trains', 'de': 'Virgin Trains', 'fr': 'Virgin Trains'},
    'LM': {'it': 'London Midland', 'en': 'London Midland', 'de': 'London Midland', 'fr': 'London Midland'},
    'GR': {'it': 'Govia Thameslink', 'en': 'Thameslink', 'de': 'Thameslink', 'fr': 'Thameslink'},
    'XC': {'it': 'CrossCountry', 'en': 'CrossCountry', 'de': 'CrossCountry', 'fr': 'CrossCountry'},
    'SW': {'it': 'South Western', 'en': 'South Western Railway', 'de': 'South Western', 'fr': 'South Western'},
    'SE': {'it': 'Southeastern', 'en': 'Southeastern', 'de': 'Southeastern', 'fr': 'Southeastern'},
    'LE': {'it': 'LNER', 'en': 'LNER', 'de': 'LNER', 'fr': 'LNER'},
    'HX': {'it': 'Heathrow Express', 'en': 'Heathrow Express', 'de': 'Heathrow Express', 'fr': 'Heathrow Express'},
    'EE': {'it': 'Emirates Airline', 'en': 'Emirates Airline', 'de': 'Emirates Airline', 'fr': 'Emirates Airline'},
    // Giappone
    'SH': {'it': 'Shinkansen', 'en': 'Shinkansen', 'de': 'Shinkansen', 'fr': 'Shinkansen'},
    // Portogallo
    'ALFA': {'it': 'Alfa Pendular', 'en': 'Alfa Pendular', 'de': 'Alfa Pendular', 'fr': 'Alfa Pendular'},
    'INT': {'it': 'Intercidades', 'en': 'Intercities', 'de': 'Intercidades', 'fr': 'Intercidades'},
    'ICB': {'it': 'Intercity Direct', 'en': 'Intercity Direct', 'de': 'Intercity Direct', 'fr': 'Intercity Direct'},
    // Nordics
    'SJ': {'it': 'SJ', 'en': 'SJ', 'de': 'SJ', 'fr': 'SJ'},
    'OX': {'it': 'Oresundståg', 'en': 'Oresund Train', 'de': 'Oresund-Zug', 'fr': 'Train Oresund'},
    'PE': {'it': "People's Train", 'en': "People's Train", 'de': 'Volkszug', 'fr': 'Train populaire'},
    'SJN': {'it': 'SJ Night', 'en': 'SJ Night', 'de': 'SJ Nacht', 'fr': 'SJ Nuit'},
    // Polonia
    'EIP': {'it': 'EIP Pendolino', 'en': 'EIP Pendolino', 'de': 'EIP Pendolino', 'fr': 'EIP Pendolino'},
    'EIC': {'it': 'EIC', 'en': 'EIC', 'de': 'EIC', 'fr': 'EIC'},
    'TLK': {'it': 'TLK', 'en': 'TLK', 'de': 'TLK', 'fr': 'TLK'},
    // Corea
    'KTX': {'it': 'KTX', 'en': 'KTX', 'de': 'KTX', 'fr': 'KTX'},
    'KTXS': {'it': 'KTX-Sancheon', 'en': 'KTX-Sancheon', 'de': 'KTX-Sancheon', 'fr': 'KTX-Sancheon'},
    // Generici
    'FLI': {'it': 'FlixTrain', 'en': 'FlixTrain', 'de': 'FlixTrain', 'fr': 'FlixTrain'},
    'MET': {'it': 'Metropolitano', 'en': 'Metro', 'de': 'U-Bahn', 'fr': 'Métro'},
    'L': {'it': 'Locale', 'en': 'Local', 'de': 'Lokal', 'fr': 'Local'},
    'M': {'it': 'Metropolitano', 'en': 'Metro', 'de': 'U-Bahn', 'fr': 'Métro'},
    'X': {'it': 'Express', 'en': 'Express', 'de': 'Express', 'fr': 'Express'},
    'N': {'it': 'Notturno', 'en': 'Night', 'de': 'Nacht', 'fr': 'Nuit'},
    'B': {'it': 'Bus', 'en': 'Bus', 'de': 'Bus', 'fr': 'Bus'},
    'BUS': {'it': 'Autobus', 'en': 'Bus', 'de': 'Bus', 'fr': 'Bus'},
    'TR': {'it': 'Tram', 'en': 'Tram', 'de': 'Straßenbahn', 'fr': 'Tramway'},
    'U': {'it': 'U-Bahn', 'en': 'Underground', 'de': 'U-Bahn', 'fr': 'Métro'},
    'Z': {'it': 'Zug', 'en': 'Train', 'de': 'Zug', 'fr': 'Train'},
    'F': {'it': 'Traghetto', 'en': 'Ferry', 'de': 'Fähre', 'fr': 'Ferry'},
    'WBL': {'it': 'Wiesel', 'en': 'Wiesel', 'de': 'Wiesel', 'fr': 'Wiesel'},
  };

  /// Risolve il nome pronunciato di una categoria treno
  static String resolveCategory(String? category, String langCode) {
    if (category == null || category.isEmpty) return '';
    final upper = category.toUpperCase();
    final names = _categoryNames[upper];
    if (names != null) {
      return names[langCode] ?? names['en'] ?? upper;
    }
    return category;
  }

  /// Pronuncia un numero come cifre singole (es. 95→"nove cinque", 14→"uno quattro")
  /// Usato per numeri treno che in Trenitalia vengono detti a spelling
  static String speakDigits(String? number, String langCode) {
    if (number == null || number.isEmpty) return '';
    final digits = {
      'it': ['zero', 'uno', 'due', 'tre', 'quattro', 'cinque', 'sei', 'sette', 'otto', 'nove'],
      'en': ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine'],
      'de': ['null', 'eins', 'zwei', 'drei', 'vier', 'fünf', 'sechs', 'sieben', 'acht', 'neun'],
      'fr': ['zéro', 'un', 'deux', 'trois', 'quatre', 'cinq', 'six', 'sept', 'huit', 'neuf'],
    };
    final langDigits = digits[langCode] ?? digits['it']!;
    final parts = <String>[];
    for (final ch in number.split('')) {
      final idx = int.tryParse(ch);
      if (idx != null && idx >= 0 && idx <= 9) {
        parts.add(langDigits[idx]);
      } else {
        parts.add(ch);
      }
    }
    return parts.join(' ');
  }

  /// Restituisce le stringhe TTS localizzate per un dato codice lingua
  /// Formato stile Trenitalia/SNCF/DB/UK
  static Map<String, String> getTtsStrings(String langCode) {
    switch (langCode) {
      case 'en':
        return {
          'train': 'The',
          'of_oper': 'service',
          'arriving': 'arriving at',
          'from': 'from',
          'direction': 'to',
          'arrival': 'arriving at',
          'departure': 'departing at',
          'delay': 'delayed by approximately',
          'minutes': 'minutes',
          'ontime': 'on time',
          'next_stop': 'Next stop:',
          'at_time': 'at',
          'hours': "o'clock",
          'platform': 'Platform',
          'calling_at': 'Calling at',
          'is_departing': 'is departing from',
          'is_arriving': 'is arriving at',
          'attention': 'Attention please,',
          'service_to': 'service to',
          'service_from': 'service from',
        };
      case 'de':
        return {
          'train': 'Der',
          'of_oper': 'Zug',
          'arriving': 'ankommend auf',
          'from': 'aus',
          'direction': 'nach',
          'arrival': 'Ankunft auf Gleis',
          'departure': 'Abfahrt auf Gleis',
          'delay': 'verzögert sich um etwa',
          'minutes': 'Minuten',
          'ontime': 'pünktlich',
          'next_stop': 'Nächster Halt:',
          'at_time': 'um',
          'hours': 'Uhr',
          'platform': 'Gleis',
          'calling_at': 'Hält in',
          'is_departing': 'fährt ab von Gleis',
          'is_arriving': 'kommt an auf Gleis',
          'attention': 'Bitte beachten Sie,',
          'service_to': 'Verbindung nach',
          'service_from': 'Verbindung aus',
        };
      case 'fr':
        return {
          'train': 'Le',
          'of_oper': 'train',
          'arriving': 'arrivée au',
          'from': 'en provenance de',
          'direction': 'à destination de',
          'arrival': 'arrivée au quai',
          'departure': 'départ du quai',
          'delay': 'retardé d\'environ',
          'minutes': 'minutes',
          'ontime': 'à l\'heure',
          'next_stop': 'Prochain arrêt:',
          'at_time': 'à',
          'hours': 'heure',
          'platform': 'quai',
          'calling_at': 'desservant',
          'is_departing': 'part du quai',
          'is_arriving': 'arrive au quai',
          'attention': 'Votre attention s\'il vous plaît,',
          'service_to': 'desservant',
          'service_from': 'en provenance de',
        };
      default: // it
        return {
          'train': 'Il treno',
          'of_oper': 'di',
          'arriving': 'in arrivo al binario',
          'from': 'proveniente da',
          'direction': 'diretto a',
          'arrival': 'è in arrivo al binario',
          'departure': 'è in partenza dal binario',
          'delay': 'è in ritardo di',
          'minutes': 'minuti',
          'ontime': 'è in orario',
          'next_stop': 'Prossima fermata:',
          'at_time': 'delle ore',
          'hours': '',
          'platform': 'binario',
          'calling_at': 'ferma a',
          'is_departing': 'è in partenza dal binario',
          'is_arriving': 'è in arrivo al binario',
          'attention': 'Attenzione,',
          'service_to': 'per',
          'service_from': 'proveniente da',
        };
    }
  }

  /// Formatta un'ora DateTime per il TTS nella lingua corrente
  /// IT: "delle ore 19 e 25", EN: "at 7:25 PM", DE: "um 19 Uhr 25", FR: "à 19 heures 25"
  static String formatTtsTime(DateTime dateTime, String langCode) {
    final local = dateTime.toLocal();
    final hour = local.hour;
    final minute = local.minute;
    final ttsStrings = getTtsStrings(langCode);
    final atTime = ttsStrings['at_time'] ?? '';

    switch (langCode) {
      case 'en': {
        final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
        final ampm = hour < 12 ? 'AM' : 'PM';
        return '$atTime $h:${minute.toString().padLeft(2, '0')} $ampm';
      }
      case 'de':
        return '$atTime $hour ${ttsStrings['hours']} ${minute.toString().padLeft(2, '0')}';
      case 'fr':
        return '$atTime $hour ${ttsStrings['hours']} ${minute.toString().padLeft(2, '0')}';
      default: // it — stile Trenitalia: "delle ore 19 e 25" o "delle ore 19"
        if (minute == 0) return '$atTime $hour';
        return '$atTime $hour e $minute';
    }
  }

  /// Costruisce la frase TTS completa in stile stazione ferroviaria
  static String buildAnnouncement({
    required String? category,
    required String? trainNumber,
    required bool isArrival,
    required String? origin,
    required String? destination,
    required DateTime? scheduledTime,
    required DateTime? estimatedTime,
    required int delayMinutes,
    required String? platform,
    required String langCode,
    String? operator,
  }) {
    final s = getTtsStrings(langCode);
    final cat = resolveCategory(category, langCode);
    final num = speakDigits(trainNumber, langCode);
    final dir = isArrival ? (origin ?? '') : (destination ?? '');
    final timeSource = estimatedTime ?? scheduledTime;
    final op = (operator != null && operator.isNotEmpty) ? operator : '';

    final buffer = StringBuffer();

    if (langCode == 'it') {
      // IT — stile Trenitalia
      buffer.write('${s['train']} ');
      if (cat.isNotEmpty || num.isNotEmpty) {
        buffer.write('$cat $num ${s['of_oper']}${op.isNotEmpty ? ' $op' : ''} ');
      }
      if (isArrival) {
        buffer.write('${s['service_from']} $dir ');
      } else {
        buffer.write('${s['service_to']} $dir ');
      }
      if (timeSource != null) {
        // formatTtsTime già include s['at_time']
        buffer.write('${formatTtsTime(timeSource, langCode)} ');
      }
      buffer.write('${s[isArrival ? 'is_arriving' : 'is_departing']} ');
      if (platform != null && platform.isNotEmpty && platform != '-') {
        buffer.write('$platform. ');
      } else {
        buffer.write('. ');
      }
      if (delayMinutes > 0) {
        buffer.write('${s['attention']} ${s['delay']} $delayMinutes ${s['minutes']}. ');
      } else {
        buffer.write('${s['ontime']}. ');
      }
    } else if (langCode == 'en') {
      // EN — stile UK (National Rail)
      buffer.write('${s['attention']} ');
      buffer.write('${s['train']} $cat $num ${s['of_oper']}${op.isNotEmpty ? ' $op' : ''} ');
      if (isArrival) {
        buffer.write('${s['service_from']} $dir ');
      } else {
        buffer.write('${s['service_to']} $dir ');
      }
      if (timeSource != null) {
        // formatTtsTime già include s['at_time']
        buffer.write('${formatTtsTime(timeSource, langCode)}. ');
      }
      if (platform != null && platform.isNotEmpty && platform != '-') {
        buffer.write('${s[isArrival ? 'is_arriving' : 'is_departing']} ${s['platform']} $platform. ');
      }
      if (delayMinutes > 0) {
        buffer.write('This train is ${s['delay']} $delayMinutes ${s['minutes']}. ');
      } else {
        buffer.write('This train is ${s['ontime']}. ');
      }
    } else if (langCode == 'de') {
      // DE — stile Deutsche Bahn
      buffer.write('${s['train']} $cat $num ${s['of_oper']}${op.isNotEmpty ? ' $op' : ''} ');
      if (isArrival) {
        buffer.write('${s['service_from']} $dir ');
      } else {
        buffer.write('${s['service_to']} $dir ');
      }
      if (timeSource != null) {
        // formatTtsTime già include s['at_time']
        buffer.write('${formatTtsTime(timeSource, langCode)}. ');
      }
      if (platform != null && platform.isNotEmpty && platform != '-') {
        buffer.write('${s[isArrival ? 'is_arriving' : 'is_departing']} $platform. ');
      }
      if (delayMinutes > 0) {
        buffer.write('${s['attention']} ${s['delay']} $delayMinutes ${s['minutes']}. ');
      } else {
        buffer.write('${s['ontime']}. ');
      }
    } else {
      // FR — stile SNCF
      buffer.write('${s['attention']} ');
      buffer.write('${s['train']} $cat $num ${s['of_oper']}${op.isNotEmpty ? ' $op' : ''} ');
      if (isArrival) {
        buffer.write('${s['service_from']} $dir ');
      } else {
        buffer.write('${s['service_to']} $dir ');
      }
      if (timeSource != null) {
        // formatTtsTime già include s['at_time']
        buffer.write('${formatTtsTime(timeSource, langCode)}. ');
      }
      if (platform != null && platform.isNotEmpty && platform != '-') {
        buffer.write('${s[isArrival ? 'is_arriving' : 'is_departing']} ${s['platform']} $platform. ');
      }
      if (delayMinutes > 0) {
        buffer.write('Ce train est ${s['delay']} $delayMinutes ${s['minutes']}. ');
      } else {
        buffer.write('Ce train est ${s['ontime']}. ');
      }
    }

    return buffer.toString().trim();
  }

  String _currentLangCode = 'it';
  OddcastVoice? _selectedVoice;
  bool? _apiOnline;
  final List<_QueueEntry> _queue = [];
  bool _isSpeaking = false;
  final Set<String> _activeTrainKeys = {}; // treni attualmente nel tabellone

  /// Inizializza il servizio
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await checkApiStatus();
  }

  /// Verifica se l'API Oddcast è raggiungibile
  Future<bool> checkApiStatus() async {
    try {
      // Test con una frase corta e una voce qualsiasi
      final fragments = '<engineID>2</engineID><voiceID>1</voiceID><langID>7</langID><ext>mp3</ext>test';
      final hash = md5.convert(utf8.encode(fragments)).toString();
      final url = 'https://cache-a.oddcast.com/c_fs/$hash.mp3?engine=2&language=7&voice=1&text=test&useUTF8=1';

      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );
      _apiOnline = response.statusCode == 200;
    } catch (_) {
      _apiOnline = false;
    }
    return _apiOnline!;
  }

  bool? get apiOnline => _apiOnline;

  /// Abilita/disabilita il TTS
  void setEnabled(bool enabled) {
    print('[TTS] setEnabled($enabled)');
    _enabled = enabled;
    if (!enabled) {
      stop();
    }
  }

  /// Imposta la lingua e la voce corrispondente
  void setLanguage(String languageCode) {
    _currentLangCode = languageCode;
  }

  /// Seleziona una voce italiana specifica
  void setSelectedVoice(OddcastVoice voice) {
    _selectedVoice = voice;
  }

  /// Costruisce l'URL Oddcast con MD5 hash
  String _buildOddcastUrl(String text, OddcastVoice voice) {
    final langId = _langIdMap[_currentLangCode] ?? 7;

    // MD5 hash dei frammenti XML (formato Oddcast)
    final fragments = [
      '<engineID>${voice.engine}</engineID>',
      '<voiceID>${voice.id}</voiceID>',
      '<langID>$langId</langID>',
      '<ext>mp3</ext>',
      text,
    ].join('');

    final hash = md5.convert(utf8.encode(fragments)).toString();

    return 'https://cache-a.oddcast.com/c_fs/$hash.mp3'
        '?engine=${voice.engine}'
        '&language=$langId'
        '&voice=${voice.id}'
        '&text=${Uri.encodeComponent(text)}'
        '&useUTF8=1';
  }

  /// Aggiunge un annuncio in coda per un treno specifico
  Future<void> speak(String text, {String? trainKey}) async {
    if (!_enabled || text.isEmpty) {
      print('[TTS] speak() skip: enabled=$_enabled, empty=${text.isEmpty}');
      return;
    }
    // Se il treno non è più attivo, scarta
    if (trainKey != null && !_activeTrainKeys.contains(trainKey)) {
      print('[TTS] speak() skip: treno $trainKey non attivo');
      return;
    }
    print('[TTS] speak() coda+1: key=$trainKey, coda=${_queue.length}, testo=${text.substring(0, text.length > 50 ? 50 : text.length)}...');
    _queue.add(_QueueEntry(text, trainKey ?? ''));
    if (!_isSpeaking) {
      await _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
      _isSpeaking = false;
      return;
    }
    _isSpeaking = true;

    // Scarta entry di treni non più attivi
    final prima = _queue.length;
    _queue.removeWhere((e) => e.trainKey.isNotEmpty && !_activeTrainKeys.contains(e.trainKey));
    if (_queue.length != prima) {
      print('[TTS] _processQueue() scartati ${prima - _queue.length} treni non attivi');
    }
    if (_queue.isEmpty) {
      print('[TTS] _processQueue() coda vuota dopo pulizia');
      _isSpeaking = false;
      return;
    }

    final entry = _queue.removeAt(0);

    // Verifica ancora che il treno sia attivo
    if (entry.trainKey.isNotEmpty && !_activeTrainKeys.contains(entry.trainKey)) {
      print('[TTS] _processQueue() skip ${entry.trainKey} non attivo');
      await _processQueue();
      return;
    }

    final voice = _selectedVoice ?? _defaultVoiceMap[_currentLangCode];
    if (voice == null) {
      print('[TTS] _processQueue() skip: nessuna voce');
      await _processQueue();
      return;
    }

    print('[TTS] _processQueue() parlo: key=${entry.trainKey}, voice=${voice.name}, coda rimasta=${_queue.length}');
    try {
      await _player.stop();
      if (!_isSpeaking) {
        print('[TTS] _processQueue() interrotto dopo stop()');
        return;
      }

      final url = _buildOddcastUrl(entry.text, voice);

      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (!_isSpeaking) {
        print('[TTS] _processQueue() interrotto dopo HTTP check');
        return;
      }

      if (response.statusCode != 200) {
        print('[TTS] Oddcast HTTP error: ${response.statusCode}');
        await _processQueue();
        return;
      }

      print('[TTS] _processQueue() riproduco audio...');
      await _player.setUrl(url);
      try {
        await _player.setSpeed(_speechRate);
      } catch (_) {}
      await _player.play();

      // Aspetta che finisca di parlare
      await _player.waitCompleted();
      print('[TTS] _processQueue() audio finito');
    } catch (e) {
      print('[TTS] _processQueue() errore: $e');
    }
    if (_isSpeaking) {
      await _processQueue();
    }
  }

  /// Aggiorna i treni attivi nel tabellone — scarta dalla coda quelli che non ci sono più
  void updateActiveTrains(Set<String> activeKeys) {
    final removed = _activeTrainKeys.difference(activeKeys);
    final added = activeKeys.difference(_activeTrainKeys);
    print('[TTS] updateActiveTrains: +${added.length} -${removed.length}, coda=${_queue.length}');
    if (removed.isNotEmpty) {
      print('[TTS]   rimossi: ${removed.take(5).join(", ")}');
    }
    _activeTrainKeys
      ..clear()
      ..addAll(activeKeys);
    // Pulisci subito la coda
    final prima = _queue.length;
    _queue.removeWhere((e) => e.trainKey.isNotEmpty && !_activeTrainKeys.contains(e.trainKey));
    if (_queue.length != prima) {
      print('[TTS]   coda: $prima -> ${_queue.length}');
    }
  }

  /// Ferma tutto e sospende fino a nuova statione
  void suspend() {
    print('[TTS] suspend() — coda=${_queue.length}, active=${_activeTrainKeys.length}');
    _queue.clear();
    _activeTrainKeys.clear();
    _isSpeaking = false;
    _player.stop();
  }

  /// Ferma la lettura, svuota coda e pulisci treni attivi
  Future<void> stop() async {
    print('[TTS] stop() — coda=${_queue.length}, active=${_activeTrainKeys.length}');
    _queue.clear();
    _activeTrainKeys.clear();
    _isSpeaking = false;
    await _player.stop();
  }

  /// Testa una voce: interrompe la coda e parla subito
  Future<void> testSpeak(String text) async {
    if (text.isEmpty) return;

    final voice = _selectedVoice ?? _defaultVoiceMap[_currentLangCode];
    if (voice == null) return;

    // Svuota la coda e ferma tutto
    _queue.clear();
    _isSpeaking = false;

    try {
      await _player.stop();

      final url = _buildOddcastUrl(text, voice);

      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode != 200) {
        print('Oddcast TTS test error: HTTP ${response.statusCode}');
        return;
      }

      await _player.setUrl(url);
      try {
        await _player.setSpeed(_speechRate);
        print('[TTS] testSpeak speed=${_player.speed} (wanted $_speechRate)');
      } catch (e) {
        print('[TTS] testSpeak setSpeed ERRORE: $e');
      }
      await _player.play();
    } catch (e) {
      print('Oddcast TTS test error: $e');
    }
  }

  /// Pausa la lettura
  Future<void> pause() async {
    await _player.pause();
  }

  bool get isEnabled => _enabled;
  String get currentLanguage => _currentLangCode;
  OddcastVoice? get selectedVoice => _selectedVoice;

  /// Lista voci per una lingua
  static List<OddcastVoice> getVoicesForLanguage(String langCode) {
    if (langCode == 'it') return italianVoices;
    // Per altre lingue, restituisci solo la voce predefinita
    final voice = _defaultVoiceMap[langCode];
    return voice != null ? [voice] : [];
  }
}

/// Player audio con stessa interfaccia su tutte le piattaforme:
/// just_audio dove supportato (Android/iOS/macOS/web),
/// audioplayers su Windows/Linux (just_audio non esiste lì).
class _TrainAudioPlayer {
  static bool get _useAp =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  final AudioPlayer? _ja;
  final ap.AudioPlayer? _ap;
  double _speed = 1.0;

  _TrainAudioPlayer()
      : _ja = _useAp ? null : AudioPlayer(),
        _ap = _useAp ? ap.AudioPlayer() : null {
    print('[TTS] player backend: ${_useAp ? 'audioplayers' : 'just_audio'}');
  }

  double get speed => _speed;

  Future<void> setSpeed(double v) async {
    _speed = v;
    if (_useAp) {
      await _ap!.setPlaybackRate(v);
    } else {
      await _ja!.setSpeed(v);
    }
  }

  Future<void> setUrl(String url) async {
    if (_useAp) {
      await _ap!.setSourceUrl(url);
    } else {
      await _ja!.setUrl(url);
    }
  }

  Future<void> play() async {
    if (_useAp) {
      await _ap!.resume();
    } else {
      await _ja!.play();
    }
  }

  Future<void> stop() async {
    if (_useAp) {
      await _ap!.stop();
    } else {
      await _ja!.stop();
    }
  }

  Future<void> pause() async {
    if (_useAp) {
      await _ap!.pause();
    } else {
      await _ja!.pause();
    }
  }

  /// Attende la fine della riproduzione (con timeout di sicurezza,
  /// così uno stop() concorrente non lascia future appesi).
  Future<void> waitCompleted() async {
    if (_useAp) {
      try {
        await _ap!.onPlayerComplete.first
            .timeout(const Duration(minutes: 10));
      } catch (_) {}
      return;
    }
    await _ja!.playerStateStream.firstWhere(
      (state) =>
          state.processingState == ProcessingState.completed ||
          state.processingState == ProcessingState.idle,
    );
  }
}

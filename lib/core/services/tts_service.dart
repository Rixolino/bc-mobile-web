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
  final bool force;
  final double? rate;
  final bool bullhorn;
  _QueueEntry(this.text, this.trainKey,
      {this.force = false, this.rate, this.bullhorn = false});
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
  // Effetto megafono (bullhorn) Oddcast FX_TYPE=R FX_LEVEL=3 — default ON
  bool _bullhorn = true;

  bool get bullhorn => _bullhorn;

  void setBullhorn(bool value) {
    _bullhorn = value;
    print('[TTS] setBullhorn: $value');
  }

  /// Voci Oddcast dal catalogo ufficiale ttsdemo.com
  /// (engine 8 escluso: HTTP 400). Roberto vero = id 2 engine 3
  /// (il vecchio id 7 engine 2 era Raffaele!).
// Italian: 15 voci
  static const List<OddcastVoice> italianVoices = [
    OddcastVoice(name: 'Paola', id: 1, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Federica', id: 10, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Silvana', id: 2, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Valentina', id: 3, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Luca', id: 5, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Marcello', id: 6, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Raffaele', id: 7, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Matteo', id: 8, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Giulia', id: 9, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Elisa', id: 1, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Roberto', id: 2, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Paolo', id: 1, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Silvia', id: 2, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Bianca', id: 1, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Alessandro', id: 2, engine: 7, gender: 'M'),
  ];

// English: 51 voci
  static const List<OddcastVoice> englishVoices = [
    OddcastVoice(name: 'Susan (US)', id: 1, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Grace (Australian)', id: 10, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Veena (Indian)', id: 11, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Dave (US)', id: 2, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Elizabeth (UK)', id: 4, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Simon (UK)', id: 5, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Catherine (UK)', id: 6, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Allison (US)', id: 7, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Steven (US)', id: 8, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Alan (Australian)', id: 9, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Kate (US)', id: 1, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Paul (US)', id: 2, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Julie (US)', id: 3, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Bridget (UK)', id: 4, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Hugh (UK)', id: 5, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Ashley (US)', id: 6, engine: 3, gender: 'F'),
    OddcastVoice(name: 'James (US)', id: 7, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Beth (US)', id: 8, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Lee (Australian)', id: 10, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Samantha (US)', id: 11, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Fiona (Scottish)', id: 12, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Tessa (South African)', id: 13, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Jill (US)', id: 2, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Tom (US)', id: 3, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Karen (Australian)', id: 4, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Daniel (UK)', id: 5, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Serena (UK)', id: 7, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Moira (Irish)', id: 8, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Sangeeta (Indian)', id: 9, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Colossus', id: 10, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Mellow Yellow I', id: 11, engine: 6, gender: 'F'),
    OddcastVoice(name: 'Crisper', id: 13, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Fast Fred', id: 15, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Troll', id: 16, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Nerd', id: 17, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Milk Toast', id: 18, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Tipsy', id: 19, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Giant', id: 2, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Choirboy I', id: 20, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Choirboy II', id: 21, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Old Woman', id: 6, engine: 6, gender: 'F'),
    OddcastVoice(name: 'Robotoid', id: 7, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Martian', id: 8, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Munchkin', id: 9, engine: 6, gender: 'M'),
    OddcastVoice(name: 'Olivia (UK)', id: 1, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Oliver (UK)', id: 2, engine: 7, gender: 'M'),
    OddcastVoice(name: 'Matilda (Australian)', id: 3, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Lakshmi (Indian)', id: 5, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Prashant (Indian)', id: 6, engine: 7, gender: 'M'),
    OddcastVoice(name: 'Brenda (US)', id: 7, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Gilbert (UK)', id: 9, engine: 7, gender: 'M'),
  ];

// German: 9 voci
  static const List<OddcastVoice> germanVoices = [
    OddcastVoice(name: 'Stefan', id: 2, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Katrin', id: 3, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Lena', id: 1, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Tim', id: 2, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Steffi', id: 1, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Yannick', id: 2, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Anna', id: 3, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Hilda', id: 1, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Heinz', id: 2, engine: 7, gender: 'M'),
  ];

// French: 18 voci
  static const List<OddcastVoice> frenchVoices = [
    OddcastVoice(name: 'Bernard', id: 2, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Jolie', id: 3, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Florence', id: 4, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Charlotte (Canadian)', id: 5, engine: 2, gender: 'F'),
    OddcastVoice(name: 'Olivier (Canadian)', id: 6, engine: 2, gender: 'M'),
    OddcastVoice(name: 'Chloe (Canadian)', id: 1, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Leo (Canadian)', id: 2, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Roxane', id: 3, engine: 3, gender: 'F'),
    OddcastVoice(name: 'Louis', id: 4, engine: 3, gender: 'M'),
    OddcastVoice(name: 'Felix (Canadian)', id: 1, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Julie (Canadian)', id: 2, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Sebastien', id: 3, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Virginie', id: 4, engine: 4, gender: 'F'),
    OddcastVoice(name: 'Thomas', id: 5, engine: 4, gender: 'M'),
    OddcastVoice(name: 'Beatrice', id: 1, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Antoine', id: 2, engine: 7, gender: 'M'),
    OddcastVoice(name: 'Leonie (Canadian)', id: 3, engine: 7, gender: 'F'),
    OddcastVoice(name: 'Gaspard (Canadian)', id: 4, engine: 7, gender: 'M'),
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

  /// Pronuncia un numero come cifre singole (es. 95→"nove cinque").
  /// Usato per EN/DE/FR (SNCF "numéro" cifra per cifra, DB/NR spelling).
  /// Per l'italiano vedi [speakMasTrainNumber] (regole ufficiali MAS).
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

  /// Parole italiane 0-99 per la lettura dei numeri (MAS, "diciannove", "ventitré").
  static String _itWords99(int n) {
    const units = [
      'zero', 'uno', 'due', 'tre', 'quattro',
      'cinque', 'sei', 'sette', 'otto', 'nove'
    ];
    const teens = [
      'dieci', 'undici', 'dodici', 'tredici', 'quattordici', 'quindici',
      'sedici', 'diciassette', 'diciotto', 'diciannove'
    ];
    const roots = {
      2: 'vent', 3: 'trent', 4: 'quarant', 5: 'cinquant',
      6: 'sessant', 7: 'settant', 8: 'ottant', 9: 'novant',
    };
    if (n < 10) return units[n];
    if (n < 20) return teens[n - 10];
    final t = n ~/ 10;
    final u = n % 10;
    final r = roots[t]!;
    if (u == 0) return t == 2 ? 'venti' : '${r}a';
    if (u == 1 || u == 8) return '$r${units[u]}';
    if (u == 3) return '${r}tré';
    return '$r${units[u]}';
  }

  /// Lettura del numero treno secondo il MAS RFI ufficiale, sez. "Numero del treno":
  /// - 2 cifre: lettura integrale ("84" → "ottantaquattro")
  /// - 3 cifre: per singola cifra ("753" → "sette cinque tre")
  /// - 4 cifre: a gruppi di due ("9448" → "novantaquattro quarantotto")
  /// - 5 cifre: coppia iniziale + singole ("12156" → "dodici uno cinque sei")
  static String speakMasTrainNumber(String? number) {
    if (number == null || number.isEmpty) return '';
    final d = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.isEmpty) return number;
    String pair(String p) => _itWords99(int.parse(p));
    String single(String c) => _itWords99(int.parse(c));
    if (d.length == 2) return pair(d);
    if (d.length == 3) return d.split('').map(single).join(' ');
    if (d.length == 4) {
      return '${pair(d.substring(0, 2))} ${pair(d.substring(2, 4))}';
    }
    if (d.length == 5) {
      return '${pair(d.substring(0, 2))} ${single(d[2])} '
          '${single(d[3])} ${single(d[4])}';
    }
    return d.split('').map(single).join(' ');
  }

  /// Restituisce le stringhe TTS localizzate per un dato codice lingua
  /// Formato stile Trenitalia (IT) / National Rail (EN) / DB (DE) / SNCF (FR)
  static Map<String, String> getTtsStrings(String langCode) {
    switch (langCode) {
      case 'en':
        return {
          'greeting': 'Ladies and gentlemen,',
          'train': 'The',
          'of_oper': 'service',
          'arriving': 'arriving at',
          'from': 'from',
          'direction': 'to',
          'arrival': 'arriving at',
          'departure': 'departing at',
          'minutes': 'minutes',
          'ontime': 'on time',
          'next_stop': 'Next stop:',
          'at_time': 'at',
          'hours': "o'clock",
          'platform': 'Platform',
          'platform_from': 'from platform',
          'platform_to': 'into platform',
          'calling_at': 'Calling at',
          'is_departing': 'is departing from',
          'is_arriving': 'is arriving at',
          'attention': 'Attention please,',
          'service_to': 'bound for',
          'service_from': 'arriving from',
          'late': 'This train is delayed by approximately',
          'arriving_now': 'We are now arriving at',
          'next_arriving_at': 'The next train to arrive at',
          'will_depart': 'will now depart from',
          'will_arrive': 'will arrive at',
          'delay': 'This train is delayed by approximately',
          'platform_notice': 'This is a platform announcement for',
        };
      case 'de':
        return {
          'greeting': 'Meine Damen und Herren,',
          'train': 'Der Zug',
          'of_oper': 'der',
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
          'platform_from': 'von Gleis',
          'platform_to': 'auf Gleis',
          'calling_at': 'Hält in',
          'is_departing': 'fährt ab von',
          'is_arriving': 'kommt an auf',
          'attention': 'Bitte beachten Sie,',
          'service_to': 'nach',
          'service_from': 'aus',
          'late': 'hat Verspätung von',
          'arriving_now': 'Wir erreichen in Kürze',
          'dep_ab': 'ab',
          'will_depart': 'fährt ab von',
          'will_arrive': 'kommt an auf',
          'delay_today': 'Dieser Zug ist heute circa',
        };
      case 'fr':
        return {
          'greeting': 'Mesdames, Messieurs,',
          'train': 'Le train',
          'of_oper': 'de',
          'arriving': 'arrivée au',
          'from': 'en provenance de',
          'direction': 'à destination de',
          'arrival': 'arrivée au quai',
          'departure': 'départ du quai',
          'delay': 'retardé d\'environ',
          'minutes': 'minutes',
          'ontime': 'à l\'heure',
          'next_stop': 'Prochain arrêt :',
          'at_time': 'à',
          'hours': 'heures',
          'platform': 'voie',
          'platform_from': 'de la voie',
          'platform_to': 'sur la voie',
          'calling_at': ' desservant',
          'is_departing': 'part de la voie',
          'is_arriving': 'arrive en voie',
          'attention': 'Votre attention s\'il vous plaît,',
          'service_to': 'à destination de',
          'service_from': 'en provenance de',
          'late': 'a subi un retard de',
          'arriving_now': 'Nous arrivons à',
          'dep_fr': 'départ',
          'will_depart': 'partira',
          'will_arrive': 'entrera en gare',
          'numero': 'numéro',
          'retard_subi': 'a subi un retard de',
          'quai_safety':
              'Éloignez-vous de la bordure du quai, s\'il vous plaît.',
        };
      default: // it — stile Trenitalia ("Gentili viaggiatori, …")
        return {
          'greeting': 'Gentili viaggiatori,',
          'train': 'il treno',
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
          'platform_from': 'dal binario',
          'platform_to': 'al binario',
          'calling_at': 'ferma a',
          'is_departing': 'è in partenza dal binario',
          'is_arriving': 'è in arrivo al binario',
          'attention': 'Attenzione,',
          'service_to': 'diretto a',
          'service_from': 'proveniente da',
          'late': 'è in ritardo di',
          'arriving_now': 'Siamo in arrivo a',
          'departure_only': 'è in partenza',
          'arriving_short': 'è in arrivo',
          // Formule MAS RFI (testo ufficiale)
          'annuncio_ritardo': 'Annuncio ritardo!',
          'partira_ritardo': 'partirà con un ritardo previsto di',
          'arrivera_ritardo': 'arriverà con un ritardo previsto di',
          'scuse': 'Ci scusiamo per il disagio.',
          'sicurezza': 'Attenzione! Allontanarsi dalla linea gialla.',
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

  /// Costruisce la frase TTS in stile TABELLONE/stazione (board).
  /// Formule da fonti reali, non inventate:
  /// - IT: MAS RFI "Manuale degli Annunci Sonori" (rfi.it, ufficiale):
  ///   P1 "IL TRENO [CAT NUM] [DI IF] DELLE ORE [ORA] PER [DEST]
  ///   DAL BINARIO [N] È IN PARTENZA",
  ///   A1 "IL TRENO [CAT NUM] [DI IF] DELLE ORE [ORA] PROVENIENTE DA [X]
  ///   [E DIRETTO A Y] È IN ARRIVO AL BINARIO [N]. ATTENZIONE!
  ///   ALLONTANARSI DALLA LINEA GIALLA",
  ///   P5 "ANNUNCIO RITARDO! IL TRENO … DELLE ORE … PER … CON UN
  ///   RITARDO PREVISTO DI [X] MINUTI PARTIRÀ",
  ///   A3 "ANNUNCIO RITARDO! IL TRENO … ARRIVERÀ CON UN RITARDO
  ///   PREVISTO DI [X] MINUTI", scuse oltre i 15'.
  ///   Numeri letti secondo MAS ("84"→ottantaquattro, "9448"→
  ///   novantaquattro quarantotto): [speakMasTrainNumber].
  /// - EN: National Rail (trascrizioni British Council):
  ///   "The next train to arrive at Platform 2 is the 12.20 to Bristol",
  ///   "The train will now depart from Platform 9",
  ///   "This train is delayed by approximately 8 minutes".
  /// - DE: adattato dal vocabolario ufficiale tabelloni DB IRIS
  ///   ("ca. X Minuten später", "Heute Gleis N").
  /// - FR: formule del personale SNCF (forum cheminots.net):
  ///   "Le train TER numéro X, à destination de Y, départ …, partira
  ///   voie N", "en provenance de X … entrera en gare voie N.
  ///   Éloignez-vous de la bordure du quai", "a subi un retard de…".
  /// Nessuna salutazione "a bordo": quella è solo nei details sheet.
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
    final num = langCode == 'it'
        ? speakMasTrainNumber(trainNumber)
        : speakDigits(trainNumber, langCode);
    final timeSource = estimatedTime ?? scheduledTime;
    final op = (operator != null && operator.isNotEmpty) ? operator : '';
    final hasTrain = cat.isNotEmpty || num.isNotEmpty;
    final hasPlatform =
        platform != null && platform.isNotEmpty && platform != '-';
    final from = (origin ?? '').trim();
    final to = (destination ?? '').trim();
    final sameEnds = from.isNotEmpty &&
        to.isNotEmpty &&
        from.toLowerCase() == to.toLowerCase();
    final buffer = StringBuffer();

    switch (langCode) {
      case 'it': {
        // --- MAS P1 / A1 / P5 / A3, ordine ufficiale ---
        final head = StringBuffer('${s['train']} ');
        if (hasTrain) {
          head.write(op.isNotEmpty
              ? '$cat $num ${s['of_oper']} $op '
              : '$cat $num ');
        }
        final headStr = head.toString();
        final when =
            timeSource != null ? formatTtsTime(timeSource, langCode) : '';
        String provenienza() {
          final b = StringBuffer();
          if (from.isNotEmpty) {
            b.write('${s['service_from']} $from ');
            if (to.isNotEmpty && !sameEnds) b.write('e diretto a $to ');
          }
          return b.toString();
        }

        if (delayMinutes > 0) {
          // P5 (partenze) / A3 (arrivi)
          buffer.write('${s['annuncio_ritardo']} $headStr');
          if (!isArrival && hasPlatform) {
            buffer.write('dal binario $platform ');
          }
          if (when.isNotEmpty) buffer.write('$when ');
          if (isArrival) {
            buffer.write(provenienza());
            buffer.write(
                '${s['arrivera_ritardo']} $delayMinutes ${s['minutes']}. ');
          } else {
            if (to.isNotEmpty) buffer.write('per $to ');
            buffer.write(
                '${s['partira_ritardo']} $delayMinutes ${s['minutes']}. ');
          }
          if (delayMinutes > 15) buffer.write('${s['scuse']} ');
        } else {
          // P1 (partenze) / A1 (arrivi)
          buffer.write(headStr);
          if (when.isNotEmpty) buffer.write('$when ');
          if (isArrival) {
            buffer.write(provenienza());
            if (hasPlatform) {
              buffer.write('${s['is_arriving']} $platform. ');
            } else {
              buffer.write('${s['arriving_short']}. ');
            }
            buffer.write('${s['sicurezza']}');
          } else {
            if (to.isNotEmpty) buffer.write('per $to ');
            if (hasPlatform) {
              // MAS P1: "… PER DEST DAL BINARIO N È IN PARTENZA"
              buffer.write(
                  '${s['platform_from']} $platform ${s['departure_only']}. ');
            } else {
              buffer.write('${s['departure_only']}. ');
            }
          }
        }
        break;
      }

      case 'en': {
        // --- National Rail ---
        String timeEn() {
          if (timeSource == null) return '';
          final l = timeSource.toLocal();
          final h = l.hour == 0 ? 12 : (l.hour > 12 ? l.hour - 12 : l.hour);
          final ap = l.hour < 12 ? 'AM' : 'PM';
          return '$h:${l.minute.toString().padLeft(2, '0')} $ap';
        }

        final t = timeEn();
        final id = StringBuffer();
        if (hasTrain) id.write('$cat $num ');
        final idStr = id.toString();
        if (isArrival) {
          if (hasPlatform) {
            buffer.write(
                '${s['next_arriving_at']} ${s['platform']} $platform ');
            buffer.write('is the ${t.isNotEmpty ? '$t ' : ''}$idStr');
          } else {
            buffer.write('The next train to arrive ');
            buffer.write('is the ${t.isNotEmpty ? '$t ' : ''}$idStr');
          }
          if (from.isNotEmpty) {
            buffer.write('service ${s['from']} $from. ');
          } else {
            buffer.write('service. ');
          }
        } else {
          buffer.write('${s['platform_notice']} ');
          buffer.write('the ${t.isNotEmpty ? '$t ' : ''}$idStr');
          if (to.isNotEmpty) {
            buffer.write('service ${s['direction']} $to. ');
          } else {
            buffer.write('service. ');
          }
          if (hasPlatform) {
            buffer.write(
                'The train ${s['will_depart']} ${s['platform']} $platform. ');
          }
        }
        if (delayMinutes > 0) {
          buffer.write('${s['late']} $delayMinutes ${s['minutes']}.');
        }
        break;
      }

      case 'de': {
        // --- DB (vocabolario tabelloni ufficiali) ---
        final when =
            timeSource != null ? formatTtsTime(timeSource, langCode) : '';
        buffer.write('${s['train']} ');
        if (hasTrain) buffer.write('$cat $num ');
        if (isArrival) {
          if (from.isNotEmpty) buffer.write('${s['service_from']} $from ');
          if (when.isNotEmpty) buffer.write('Ankunft $when ');
          if (hasPlatform) {
            buffer.write('${s['will_arrive']} ${s['platform']} $platform. ');
          } else {
            buffer.write('kommt an. ');
          }
        } else {
          if (to.isNotEmpty) buffer.write('${s['service_to']} $to ');
          if (when.isNotEmpty) buffer.write('Abfahrt $when ');
          if (hasPlatform) {
            buffer.write('von ${s['platform']} $platform. ');
          } else {
            buffer.write('. ');
          }
        }
        if (delayMinutes > 0) {
          buffer.write(
              '${s['delay_today']} $delayMinutes ${s['minutes']} später. ');
        }
        break;
      }

      default: {
        // --- FR: formule personale SNCF ---
        final when =
            timeSource != null ? formatTtsTime(timeSource, langCode) : '';
        buffer.write('${s['train']} ');
        if (cat.isNotEmpty) buffer.write('$cat ');
        if (num.isNotEmpty) buffer.write('${s['numero']} $num ');
        if (isArrival) {
          if (from.isNotEmpty) buffer.write('${s['service_from']} $from ');
          if (to.isNotEmpty && !sameEnds) {
            buffer.write('et à destination de $to ');
          }
          if (when.isNotEmpty) buffer.write('${s['dep_fr']} $when ');
          if (hasPlatform) {
            buffer.write('${s['will_arrive']} ${s['platform']} $platform. ');
          } else {
            buffer.write('. ');
          }
          if (delayMinutes > 0) {
            buffer.write(
                'Ce train ${s['retard_subi']} $delayMinutes ${s['minutes']}. ');
          }
          buffer.write('${s['quai_safety']}');
        } else {
          if (to.isNotEmpty) buffer.write('${s['service_to']} $to ');
          if (when.isNotEmpty) buffer.write('${s['dep_fr']} $when ');
          if (hasPlatform) {
            buffer.write('${s['will_depart']} ${s['platform']} $platform. ');
          } else {
            buffer.write('. ');
          }
          if (delayMinutes > 0) {
            buffer.write(
                'Ce train ${s['retard_subi']} $delayMinutes ${s['minutes']}. ');
          }
        }
        break;
      }
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// ANNUNCI A BORDO stile Trenitalia — solo details sheet.
  /// Testi adattati IT/EN/DE/FR, non usati dal tabellone.
  /// Esempio IT: "Gentili viaggiatori, il treno FR 9612 di Trenitalia,
  /// diretto a Milano Centrale, in partenza delle ore 14 e 35 dal
  /// binario 7. Attenzione, il treno è in ritardo di 15 minuti."
  static String buildOnboardAnnouncement({
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
    final num = langCode == 'it'
        ? speakMasTrainNumber(trainNumber)
        : speakDigits(trainNumber, langCode);
    final dir = isArrival ? (origin ?? '') : (destination ?? '');
    final timeSource = estimatedTime ?? scheduledTime;
    final op = (operator != null && operator.isNotEmpty) ? operator : '';
    final hasTrain = cat.isNotEmpty || num.isNotEmpty;
    final hasPlatform =
        platform != null && platform.isNotEmpty && platform != '-';
    final buffer = StringBuffer();

    // Formula a bordo Trenitalia (salutazione localizzata)
    buffer.write('${s['greeting']} ');
    buffer.write('${s['train']} ');
    if (hasTrain) {
      if (op.isNotEmpty) {
        buffer.write('$cat $num ${s['of_oper']} $op ');
      } else {
        buffer.write('$cat $num ');
      }
    }
    if (dir.isNotEmpty) {
      buffer.write('${isArrival ? s['service_from'] : s['service_to']} $dir ');
    }
    if (timeSource != null) {
      // "in partenza delle ore…" / "departing at…" / "um… " / "partant à…"
      final when = langCode == 'it'
          ? '${isArrival ? 'in arrivo ' : 'in partenza '}${formatTtsTime(timeSource, langCode)}'
          : langCode == 'en'
              ? '${isArrival ? 'arriving ' : 'departing '}${formatTtsTime(timeSource, langCode)}'
              : langCode == 'fr'
                  ? '${isArrival ? 'arrivant ' : 'partant '}${formatTtsTime(timeSource, langCode)}'
                  : formatTtsTime(timeSource, langCode);
      buffer.write('$when ');
    } else {
      buffer.write('${s[isArrival ? 'is_arriving' : 'is_departing']} ');
    }
    if (hasPlatform) {
      final platKey = isArrival ? 'platform_to' : 'platform_from';
      buffer.write('${s[platKey] ?? s['platform']} $platform. ');
    } else {
      buffer.write('. ');
    }

    if (delayMinutes > 0) {
      buffer.write(
          '${s['attention']} ${s['late']} $delayMinutes ${s['minutes']}.');
    } else {
      buffer.write('${s['ontime']}.');
    }

    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Prossima fermata in stile a bordo Trenitalia (solo details sheet):
  /// "Prossima fermata: Roma delle ore 19 e 25" — preposizione già in
  /// formatTtsTime, niente "alle" hardcodato.
  static String appendNextStop({
    required String baseText,
    required String stopName,
    required DateTime time,
    required String langCode,
  }) {
    if (stopName.isEmpty) return baseText;
    final s = getTtsStrings(langCode);
    final label = s['next_stop'] ?? 'Next stop:';
    final timeStr = formatTtsTime(time, langCode);
    return '$baseText. $label $stopName $timeStr';
  }

  /// Elenco fermate successive in stile a bordo ("Ferma a A, B e C.").
  /// Usa la chiave 'calling_at' ufficiale per lingua.
  static String appendCallingAt({
    required String baseText,
    required List<String> stopNames,
    required String langCode,
  }) {
    final names =
        stopNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    if (names.isEmpty) return baseText;
    final s = getTtsStrings(langCode);
    final calling = (s['calling_at'] ?? 'Stops at').trim();
    final conj = switch (langCode) {
      'en' => 'and',
      'de' => 'und',
      'fr' => 'et',
      _ => 'e',
    };
    final list = names.length == 1
        ? names.first
        : '${names.sublist(0, names.length - 1).join(', ')} $conj ${names.last}';
    return '$baseText. $calling $list.';
  }

  /// Avviso di arrivo imminente in stazione ("Siamo in arrivo a Roma.").
  /// Parlato quando mancano pochi minuti all'arrivo effettivo.
  static String buildArrivingNow({
    required String stopName,
    required String langCode,
  }) {
    final s = getTtsStrings(langCode);
    final prefix = s['arriving_now'] ?? 'Now arriving at';
    return '$prefix $stopName.';
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

  /// Costruisce l'URL Oddcast.
  /// Con bullhorn=true (e setting attivo) usa gen.php + FX_TYPE=R/FX_LEVEL=3.
  /// Altrimenti il classico c_fs con MD5 dei frammenti XML.
  String _buildOddcastUrl(String text, OddcastVoice voice,
      {bool bullhorn = false}) {
    final langId = _langIdMap[_currentLangCode] ?? 7;

    if (_bullhorn && bullhorn) {
      return _buildGenUrlWithFx(text, voice, langId);
    }

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

  /// gen.php con checksum CS e parametri effetto (come sitepalPlayer/ttsdemo).
  /// CS = md5(EID+LID+VID+TXT+'1'+'mp3'+FX_TYPE+FX_LEVEL+FNAME+ACC+SECRET)
  String _buildGenUrlWithFx(String text, OddcastVoice voice, int langId) {
    const acc = 5883747;
    const secret = 'uetivb9tb8108wfj';
    const fxType = 'R';
    const fxLevel = '3';
    const fname = '';

    final csInput = '${voice.engine}$langId${voice.id}$text'
        '1mp3'
        '$fxType$fxLevel'
        '$fname$acc$secret';
    final cs = md5.convert(utf8.encode(csInput)).toString();

    return Uri.https('cache-a.oddcast.com', '/tts/gen.php', {
      'EID': voice.engine.toString(),
      'LID': langId.toString(),
      'VID': voice.id.toString(),
      'TXT': text,
      'IS_UTF8': '1',
      'EXT': 'mp3',
      'FNAME': fname,
      'ACC': '$acc',
      'API': '',
      'SESSION': '',
      'FX_TYPE': fxType,
      'FX_LEVEL': fxLevel,
      'CS': cs,
    }).toString();
  }

  /// Aggiunge un annuncio in coda per un treno specifico.
  /// Con force=true salta il controllo treno-attivo (dettagli sheet).
  /// Con rate si sovrascrive la velocità per questo annuncio solo.
  /// Con bullhorn=true applica l'effetto megafono (solo apertura dettaglio).
  Future<void> speak(String text,
      {String? trainKey,
      bool force = false,
      double? rate,
      bool bullhorn = false}) async {
    if (!_enabled || text.isEmpty) {
      print('[TTS] speak() skip: enabled=$_enabled, empty=${text.isEmpty}');
      return;
    }
    // Se il treno non è più attivo, scarta (salvo force)
    if (!force &&
        trainKey != null &&
        !_activeTrainKeys.contains(trainKey)) {
      print('[TTS] speak() skip: treno $trainKey non attivo');
      return;
    }
    print('[TTS] speak() coda+1: key=$trainKey, bullhorn=$bullhorn, coda=${_queue.length}, testo=${text.substring(0, text.length > 50 ? 50 : text.length)}...');
    _queue.add(_QueueEntry(text, trainKey ?? '',
        force: force, rate: rate, bullhorn: bullhorn));
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

    // Scarta entry di treni non più attivi (salvo force)
    final prima = _queue.length;
    _queue.removeWhere((e) =>
        !e.force &&
        e.trainKey.isNotEmpty &&
        !_activeTrainKeys.contains(e.trainKey));
    if (_queue.length != prima) {
      print('[TTS] _processQueue() scartati ${prima - _queue.length} treni non attivi');
    }
    if (_queue.isEmpty) {
      print('[TTS] _processQueue() coda vuota dopo pulizia');
      _isSpeaking = false;
      return;
    }

    final entry = _queue.removeAt(0);

    // Verifica ancora che il treno sia attivo (salvo force)
    if (!entry.force &&
        entry.trainKey.isNotEmpty &&
        !_activeTrainKeys.contains(entry.trainKey)) {
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

      final url = _buildOddcastUrl(entry.text, voice,
          bullhorn: entry.bullhorn);

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
      final rate = entry.rate ?? _speechRate;
      try {
        await _player.setSpeed(rate);
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
    // Pulisci subito la coda (salvo force)
    final prima = _queue.length;
    _queue.removeWhere((e) =>
        !e.force &&
        e.trainKey.isNotEmpty &&
        !_activeTrainKeys.contains(e.trainKey));
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

  /// Testa una voce: interrompe la coda e parla subito.
  /// Con rate si sovrascrive la velocità per questo test solo.
  Future<void> testSpeak(String text, {double? rate}) async {
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

      final speed = rate ?? _speechRate;
      await _player.setUrl(url);
      try {
        await _player.setSpeed(speed);
        print('[TTS] testSpeak speed=${_player.speed} (wanted $speed)');
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

  /// Lista voci per una lingua (catalogo completo ufficiale)
  static List<OddcastVoice> getVoicesForLanguage(String langCode) {
    switch (langCode) {
      case 'it':
        return italianVoices;
      case 'en':
        return englishVoices;
      case 'de':
        return germanVoices;
      case 'fr':
        return frenchVoices;
      default:
        return [];
    }
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

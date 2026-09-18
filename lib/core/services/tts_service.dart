import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:just_audio/just_audio.dart';
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

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final AudioPlayer _player = AudioPlayer();
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
    'FR': {'it': 'Frecciarossa', 'en': 'Frecciarossa', 'de': 'Frecciarossa', 'fr': 'Frecciarossa'},
    'FA': {'it': 'Frecciargento', 'en': 'Frecciargento', 'de': 'Frecciargento', 'fr': 'Frecciargento'},
    'FB': {'it': 'Frecciabianca', 'en': 'Frecciabianca', 'de': 'Frecciabianca', 'fr': 'Frecciabianca'},
    'IC': {'it': 'Intercity', 'en': 'Intercity', 'de': 'Intercity', 'fr': 'Intercité'},
    'ICN': {'it': 'Intercity Notte', 'en': 'Night Intercity', 'de': 'Intercity Nacht', 'fr': 'Intercité Nuit'},
    'EC': {'it': 'Eurocity', 'en': 'Eurocity', 'de': 'Eurocity', 'fr': 'Eurocity'},
    'EN': {'it': 'EuroNight', 'en': 'EuroNight', 'de': 'EuroNight', 'fr': 'EuroNight'},
    'ES': {'it': 'Eurostar Italia', 'en': 'Eurostar Italia', 'de': 'Eurostar Italien', 'fr': 'Eurostar Italie'},
    'RV': {'it': 'Regionale Veloce', 'en': 'Fast Regional', 'de': 'Schnell regional', 'fr': 'Régional express'},
    'R': {'it': 'Regionale', 'en': 'Regional', 'de': 'Regional', 'fr': 'Régional'},
    'REG': {'it': 'Regionale', 'en': 'Regional', 'de': 'Regional', 'fr': 'Régional'},
    'RM': {'it': 'Regionale Metropolitano', 'en': 'Metro Regional', 'de': 'S-Bahn', 'fr': 'Régional métro'},
    'PM': {'it': 'Pendolino', 'en': 'Pendolino', 'de': 'Pendolino', 'fr': 'Pendolino'},
    'AV': {'it': 'Alta Velocità', 'en': 'High Speed', 'de': 'Hochgeschwindigkeit', 'fr': 'Grande vitesse'},
    'TGV': {'it': 'TGV', 'en': 'TGV', 'de': 'TGV', 'fr': 'TGV'},
    'TER': {'it': 'TER', 'en': 'TER', 'de': 'TER', 'fr': 'TER'},
    'ICE': {'it': 'ICE', 'en': 'ICE', 'de': 'ICE', 'fr': 'ICE'},
    'THL': {'it': 'Thalys', 'en': 'Thalys', 'de': 'Thalys', 'fr': 'Thalys'},
    'AVE': {'it': 'AVE', 'en': 'AVE', 'de': 'AVE', 'fr': 'AVE'},
    'RE': {'it': 'Regionale Express', 'en': 'Regional Express', 'de': 'RegionalExpress', 'fr': 'Regional Express'},
    'RB': {'it': 'Regionale Bahn', 'en': 'Regional Bahn', 'de': 'RegionalBahn', 'fr': 'RegionalBahn'},
    'S': {'it': 'S-Bahn', 'en': 'S-Bahn', 'de': 'S-Bahn', 'fr': 'S-Bahn'},
    'RJ': {'it': 'Railjet', 'en': 'Railjet', 'de': 'Railjet', 'fr': 'Railjet'},
    'NJ': {'it': 'Nightjet', 'en': 'Nightjet', 'de': 'Nightjet', 'fr': 'Nightjet'},
    'SC': {'it': 'Swiss City', 'en': 'Swiss City', 'de': 'Swiss City', 'fr': 'S-Bahn Suisse'},
    'IR': {'it': 'InterRegio', 'en': 'InterRegio', 'de': 'InterRegio', 'fr': 'InterRegio'},
    'PE': {'it': "People's Train", 'en': "People's Train", 'de': 'Volkszug', 'fr': 'Train populaire'},
    'SJ': {'it': 'SJ', 'en': 'SJ', 'de': 'SJ', 'fr': 'SJ'},
    'OX': {'it': 'Oresundståg', 'en': 'Oresund Train', 'de': 'Oresund-Zug', 'fr': 'Train Oresund'},
    'GWR': {'it': 'Great Western', 'en': 'Great Western Railway', 'de': 'Great Western', 'fr': 'Great Western'},
    'VT': {'it': 'Virgin Trains', 'en': 'Virgin Trains', 'de': 'Virgin Trains', 'fr': 'Virgin Trains'},
    'LM': {'it': 'London Midland', 'en': 'London Midland', 'de': 'London Midland', 'fr': 'London Midland'},
    'GR': {'it': 'Govia Thameslink', 'en': 'Thameslink', 'de': 'Thameslink', 'fr': 'Thameslink'},
    'XC': {'it': 'CrossCountry', 'en': 'CrossCountry', 'de': 'CrossCountry', 'fr': 'CrossCountry'},
    'SW': {'it': 'South Western', 'en': 'South Western Railway', 'de': 'South Western', 'fr': 'South Western'},
    'SE': {'it': 'Southeastern', 'en': 'Southeastern', 'de': 'Southeastern', 'fr': 'Southeastern'},
    'LE': {'it': 'LNER', 'en': 'LNER', 'de': 'LNER', 'fr': 'LNER'},
    'HX': {'it': 'Heathrow Express', 'en': 'Heathrow Express', 'de': 'Heathrow Express', 'fr': 'Heathrow Express'},
    'SH': {'it': 'Shinkansen', 'en': 'Shinkansen', 'de': 'Shinkansen', 'fr': 'Shinkansen'},
    'ALV': {'it': 'AVE', 'en': 'AVE', 'de': 'AVE', 'fr': 'AVE'},
    'TRD': {'it': 'Trenitalia', 'en': 'Trenitalia', 'de': 'Trenitalia', 'fr': 'Trenitalia'},
    'MD': {'it': 'Media Distancia', 'en': 'Medium Distance', 'de': 'Mittelstrecke', 'fr': 'Moyenne distance'},
    'AR': {'it': 'Cercanías', 'en': 'Commuter', 'de': 'Cercanías', 'fr': 'Cercanías'},
    'ALFA': {'it': 'Alfa Pendular', 'en': 'Alfa Pendular', 'de': 'Alfa Pendular', 'fr': 'Alfa Pendular'},
    'INT': {'it': 'Intercidades', 'en': 'Intercities', 'de': 'Intercidades', 'fr': 'Intercidades'},
    'ICB': {'it': 'Intercity Direct', 'en': 'Intercity Direct', 'de': 'Intercity Direct', 'fr': 'Intercity Direct'},
    'THA': {'it': 'Thalys', 'en': 'Thalys', 'de': 'Thalys', 'fr': 'Thalys'},
    'FLI': {'it': 'FlixBus', 'en': 'FlixBus', 'de': 'FlixBus', 'fr': 'FlixBus'},
    'EIP': {'it': 'EIP Pendolino', 'en': 'EIP Pendolino', 'de': 'EIP Pendolino', 'fr': 'EIP Pendolino'},
    'EIC': {'it': 'EIC', 'en': 'EIC', 'de': 'EIC', 'fr': 'EIC'},
    'TLK': {'it': 'TLK', 'en': 'TLK', 'de': 'TLK', 'fr': 'TLK'},
    'KTX': {'it': 'KTX', 'en': 'KTX', 'de': 'KTX', 'fr': 'KTX'},
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

  /// Restituisce le stringhe TTS localizzate per un dato codice lingua
  static Map<String, String> getTtsStrings(String langCode) {
    switch (langCode) {
      case 'en':
        return {
          'train': 'Train',
          'arriving': 'arriving',
          'from': 'From',
          'direction': 'Bound for',
          'arrival': 'Arrival at',
          'departure': 'Departure at',
          'delay': 'Delay',
          'minutes': 'minutes',
          'ontime': 'On time',
          'next_stop': 'Next stop:',
        };
      case 'de':
        return {
          'train': 'Zug',
          'arriving': 'ankommend',
          'from': 'Aus',
          'direction': 'Richtung',
          'arrival': 'Ankunft um',
          'departure': 'Abfahrt um',
          'delay': 'Verspätung',
          'minutes': 'Minuten',
          'ontime': 'Pünktlich',
          'next_stop': 'Nächster Halt:',
        };
      case 'fr':
        return {
          'train': 'Train',
          'arriving': 'en provenance',
          'from': 'Depuis',
          'direction': 'À destination de',
          'arrival': 'Arrivée à',
          'departure': 'Départ à',
          'delay': 'Retard',
          'minutes': 'minutes',
          'ontime': "À l'heure",
          'next_stop': 'Prochain arrêt:',
        };
      default: // it
        return {
          'train': 'Treno',
          'arriving': 'in arrivo',
          'from': 'Provenienza',
          'direction': 'Direzione',
          'arrival': 'Arrivo alle',
          'departure': 'Partenza alle',
          'delay': 'Ritardo',
          'minutes': 'minuti',
          'ontime': 'In orario',
          'next_stop': 'Prossima fermata:',
        };
    }
  }

  String _currentLangCode = 'it';
  OddcastVoice? _selectedVoice;
  bool? _apiOnline;

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

  /// Legge un testo ad alta voce usando Oddcast TTS
  Future<void> speak(String text) async {
    if (!_enabled || text.isEmpty) return;

    final voice = _selectedVoice ?? _defaultVoiceMap[_currentLangCode];
    if (voice == null) return;

    try {
      // Ferma eventuali letture in corso
      await _player.stop();

      final url = _buildOddcastUrl(text, voice);

      // Verifica che l'URL sia raggiungibile
      final response = await http.head(Uri.parse(url)).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Timeout'),
      );

      if (response.statusCode != 200) {
        print('Oddcast TTS error: HTTP ${response.statusCode}');
        return;
      }

      // Riproduci l'MP3
      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      print('Oddcast TTS error: $e');
    }
  }

  /// Ferma la lettura
  Future<void> stop() async {
    await _player.stop();
  }

  /// Testa una voce senza controllare se il TTS è abilitato
  Future<void> testSpeak(String text) async {
    if (text.isEmpty) return;

    final voice = _selectedVoice ?? _defaultVoiceMap[_currentLangCode];
    if (voice == null) return;

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

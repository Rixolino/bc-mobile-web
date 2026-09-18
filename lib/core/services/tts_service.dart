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

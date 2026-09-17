import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cursore virtuale per telecomandi (Amazon Fire Stick, Google TV):
/// frecce muovono il cursore, OK centrale tocca nel punto.
/// Nessuna dipendenza extra: tap sintetizzato via pointer event.
class TvCursorService extends ChangeNotifier {
  static const String keyTvCursor = 'ui_tv_cursor';
  static const double step = 22;

  bool _enabled = false;
  bool _autoShown = false;
  bool _tvDetected = false;
  Offset _position = Offset.zero;
  bool _hasPosition = false;
  Size _screenSize = Size.zero;
  Timer? _edgeScrollTimer;

  // Fascia bordi che attiva lo scroll automatico + passo scroll
  static const double edgeZone = 100;
  static const double scrollStep = 50;
  static const Duration edgeTick = Duration(milliseconds: 130);

  bool get enabled => _enabled;
  bool get tvDetected => _tvDetected;
  bool get visible => _enabled || _autoShown;
  Offset get position => _position;

  static const MethodChannel _tvChannel =
      MethodChannel('bc_transporter/tv');

  /// Rileva se il dispositivo è una TV (Android TV / Fire TV).
  /// Su altre piattaforme ritorna sempre false.
  static Future<bool> detectTelevision() async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
      final result = await _tvChannel.invokeMethod<bool>('isTv');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(keyTvCursor) ?? false;
    } catch (_) {}
    // Se è una TV, attiva assolutamente il cursore a ogni avvio.
    try {
      _tvDetected = await detectTelevision().timeout(
        const Duration(seconds: 3),
        onTimeout: () => false,
      );
    } catch (_) {
      _tvDetected = false;
    }
    if (_tvDetected && !_enabled) {
      _enabled = true;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(keyTvCursor, true);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(keyTvCursor, value);
    } catch (_) {}
  }

  void ensurePosition(Size screen) {
    _screenSize = screen;
    if (!_hasPosition) {
      _position = Offset(screen.width / 2, screen.height / 2);
      _hasPosition = true;
    } else {
      move(0, 0, screen);
    }
    _ensureEdgeScrollTimer();
  }

  /// Timer che, a cursore visibile, trascina il contenuto sotto il cursore
  /// quando sta nelle fasce alta/bassa dello schermo (scroll su/giù).
  void _ensureEdgeScrollTimer() {
    if (!visible || _edgeScrollTimer != null) return;
    _edgeScrollTimer =
        Timer.periodic(edgeTick, (_) => _edgeScrollTick());
  }

  void _stopEdgeScrollTimer() {
    _edgeScrollTimer?.cancel();
    _edgeScrollTimer = null;
  }

  /// Tick di scroll: segnale rotella sintetico nel punto del cursore.
  /// Lo Scrollable sotto il cursore (qualsiasi: liste, sliver, dialog,
  /// sheet, in qualunque schermata) scorre senza gesture arena né tap.
  void _edgeScrollTick() {
    if (!visible || _screenSize == Size.zero) {
      if (!visible) _stopEdgeScrollTimer();
      return;
    }
    final y = _position.dy;
    if (y < edgeZone) {
      _scrollBy(const Offset(0, -scrollStep)); // mostra contenuto sopra
    } else if (y > _screenSize.height - edgeZone) {
      _scrollBy(const Offset(0, scrollStep)); // mostra contenuto sotto
    }
  }

  void _scrollBy(Offset delta) {
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(position: _position, scrollDelta: delta),
    );
  }

  void move(double dx, double dy, Size screen) {
    _screenSize = screen;
    final nx = (_position.dx + dx).clamp(0.0, screen.width);
    final ny = (_position.dy + dy).clamp(0.0, screen.height);
    final next = Offset(nx, ny);
    if (next != _position) {
      _position = next;
      notifyListeners();
    }
    _ensureEdgeScrollTimer();
  }

  /// Mostra il cursore alla prima pressione delle frecce (telecomando).
  void autoShow(Size screen) {
    ensurePosition(screen);
    if (!_autoShown) {
      _autoShown = true;
      notifyListeners();
    }
  }

  /// Tocca nel punto del cursore (down + up sintetizzati).
  Future<void> tapAtCursor() async {
    final binding = WidgetsBinding.instance;
    final pos = _position;
    binding.handlePointerEvent(PointerDownEvent(position: pos));
    await Future<void>.delayed(const Duration(milliseconds: 90));
    binding.handlePointerEvent(PointerUpEvent(position: pos));
  }

  /// Gestisce i tasti del telecomando. Ritorna true se consumati.
  /// Non intercetta nulla quando si scrive in un campo di testo.
  bool handleKey(KeyEvent event, Size screen) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) {
      final widget = focus.context!.widget;
      if (widget is EditableText) return false;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      autoShow(screen);
      move(0, -step, screen);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      autoShow(screen);
      move(0, step, screen);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      autoShow(screen);
      move(-step, 0, screen);
      return true;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      autoShow(screen);
      move(step, 0, screen);
      return true;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (!visible) return false;
      unawaited(tapAtCursor());
      return true;
    }
    return false;
  }
}

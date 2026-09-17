import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  Timer? _scanTimer;
  Timer? _hideTimer;
  List<ViewportInfo> _viewports = const [];

  /// Ultimo scan con viewport trovati: le frecce restano finché
  /// non spariscono davvero (grazia per transizioni/sheet in chiusura).
  static const Duration hideGrace = Duration(milliseconds: 1500);

  /// Viewport rilevati a schermo (per frecce dedicate a ciascuno).
  List<ViewportInfo> get viewports => _viewports;

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
    _ensureScanTimer();
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

  /// Muove DIRETTAMENTE lo scrollabile indicato (niente hit-test al tap:
  /// ogni freccia comanda proprio il suo oggetto).
  Future<void> scrollViewport(ViewportInfo vp, double delta) async {
    try {
      if (!vp.alive) return;
      final pos = vp.state.position;
      final target = (pos.pixels + delta)
          .clamp(pos.minScrollExtent, pos.maxScrollExtent);
      await pos.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } catch (_) {}
  }

  /// Scroll in un punto preciso (per compatibilità edge-scroll).
  void scrollAt(Offset at, double dx, double dy) {
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(position: at, scrollDelta: Offset(dx, dy)),
    );
  }

  /// Scroll dal centro schermo (per compatibilità).
  void scrollFromCenter(double dx, double dy) {
    if (_screenSize == Size.zero) return;
    scrollAt(
      Offset(_screenSize.width / 2, _screenSize.height / 2),
      dx,
      dy,
    );
  }

  void _scrollBy(Offset delta) {
    // Il cursore nelle fasce bordo spesso sta sopra chrome non scrollabile
    // (AppBar, nav bar, maniglie sheet): invia il segnale più dentro,
    // sul contenuto scrollabile, altrimenti si perde.
    var dispatch = _position;
    if (_position.dy < edgeZone) {
      dispatch = Offset(
        _position.dx,
        (edgeZone + 40).clamp(0.0, _screenSize.height),
      );
    } else if (_position.dy > _screenSize.height - edgeZone) {
      dispatch = Offset(
        _position.dx,
        (_screenSize.height - edgeZone - 40).clamp(0.0, _screenSize.height),
      );
    }
    WidgetsBinding.instance.handlePointerEvent(
      PointerScrollEvent(position: dispatch, scrollDelta: delta),
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
    _ensureScanTimer();
  }

  void _ensureScanTimer() {
    if (!visible || _scanTimer != null) return;
    scanViewportTree();
    _scanTimer =
        Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!visible) {
        _scanTimer?.cancel();
        _scanTimer = null;
        _hideTimer?.cancel();
        _hideTimer = null;
        if (_viewports.isNotEmpty) {
          _viewports = const [];
          notifyListeners();
        }
        return;
      }
      scanViewportTree();
    });
  }

  /// Scansione a elementi: trova TUTTI gli Scrollable montati con bounds
  /// e stato diretto (uno per oggetto indipendente, anche annidati).
  void scanViewportTree() {
    if (!visible) return;
    final found = <ViewportInfo>[];
    try {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      final screen = _screenSize;
      final full = Rect.fromLTWH(
          0, 0, screen.width == 0 ? 4096 : screen.width, screen.height == 0 ? 4096 : screen.height);
      void visit(Element el) {
        if (el is StatefulElement && el.state is ScrollableState) {
          final st = el.state as ScrollableState;
          try {
            final ro = st.context.findRenderObject();
            if (ro is RenderBox && ro.hasSize && ro.attached) {
              final Offset offset = ro.localToGlobal(Offset.zero);
              final rect = Rect.fromLTWH(
                      offset.dx, offset.dy, ro.size.width, ro.size.height)
                  .intersect(full);
              // Solo oggetti visibili e abbastanza grandi (niente micro-scroller)
              if (!rect.isEmpty && rect.width >= 80 && rect.height >= 80) {
                found.add(ViewportInfo(st, rect, st.position.axis));
              }
            }
          } catch (_) {}
        }
        try {
          el.visitChildren(visit);
        } catch (_) {}
      }
  
      root.visitChildren(visit);
    } catch (_) {
      return;
    }
    // Aggiorna solo se cambiato (evita rebuild continui).
    // Se vuoto: non nascondere subito, dai la grazia (transizioni/sheet).
    if (found.isEmpty) {
      if (_viewports.isNotEmpty && _hideTimer == null) {
        _hideTimer = Timer(hideGrace, () {
          _hideTimer = null;
          _viewports = const [];
          notifyListeners();
        });
      }
      return;
    }
    _hideTimer?.cancel();
    _hideTimer = null;
    bool same = found.length == _viewports.length;
    if (same) {
      for (int i = 0; i < found.length; i++) {
        if (found[i].rect != _viewports[i].rect) {
          same = false;
          break;
        }
      }
    }
    if (!same) {
      _viewports = found;
      notifyListeners();
    }
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

/// Scrollable rilevato con stato diretto (niente hit-test al tap:
/// le frecce muovono proprio questo oggetto).
class ViewportInfo {
  final ScrollableState state;
  final Rect rect;
  final Axis axis;
  const ViewportInfo(this.state, this.rect, this.axis);

  bool get alive {
    try {
      return state.mounted;
    } catch (_) {
      return false;
    }
  }
}

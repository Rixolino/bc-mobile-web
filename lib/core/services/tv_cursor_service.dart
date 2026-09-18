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
  Timer? _scanTimer;
  List<ViewportInfo> _viewports = const [];
  int _lastScanCount = -1;
  // identityHashCode(ScrollableState) -> ID stabile (mai duplicato,
  // mai riassegnato a un altro oggetto finché vive).
  final Map<int, int> _viewportIds = {};
  int _nextViewportId = 1;
  bool _dragging = false;
  DateTime? _selectDownAt;

  /// trascinamento attivo (OK lungo): le frecce muovono il "dito".
  bool get dragging => _dragging;

  /// Soglia pressione lunga per entrare in drag.
  static const Duration longPress = Duration(milliseconds: 500);

  /// Viewport rilevati a schermo (per frecce dedicate a ciascuno).
  List<ViewportInfo> get viewports => _viewports;

  /// Il viewport sotto il cursore (il più interno in caso di annidati).
  /// Fallback: il più vicino al cursore, così le frecce compaiono anche
  /// quando il cursore sta su zone fisse (header, chip, dock).
  ViewportInfo? viewportAtCursor() {
    ViewportInfo? best;
    double bestArea = double.infinity;
    for (final vp in _viewports) {
      try {
        if (!vp.alive) continue;
        if (!vp.rect.contains(_position)) continue;
        final area = vp.rect.width * vp.rect.height;
        if (area < bestArea) {
          bestArea = area;
          best = vp;
        }
      } catch (_) {}
    }
    if (best != null) return best;
    double bestDist = double.infinity;
    for (final vp in _viewports) {
      try {
        if (!vp.alive) continue;
        final d = (vp.rect.center - _position).distance;
        if (d < bestDist) {
          bestDist = d;
          best = vp;
        }
      } catch (_) {}
    }
    return best;
  }

  // Passo scroll frecce
  static const double scrollStep = 50;

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
    _ensureScanTimer();
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

  void move(double dx, double dy, Size screen) {
    _screenSize = screen;
    final nx = (_position.dx + dx).clamp(0.0, screen.width);
    final ny = (_position.dy + dy).clamp(0.0, screen.height);
    final next = Offset(nx, ny);
    if (next != _position) {
      _position = next;
      notifyListeners();
      if (_dragging) {
        // In drag: il dito segue il cursore
        WidgetsBinding.instance.handlePointerEvent(
          PointerMoveEvent(position: next),
        );
      }
    }
    _ensureScanTimer();
  }

  void _startDrag() {
    if (_dragging) return;
    _dragging = true;
    WidgetsBinding.instance.handlePointerEvent(
      PointerDownEvent(position: _position),
    );
    notifyListeners();
  }

  void _endDrag() {
    if (!_dragging) return;
    _dragging = false;
    WidgetsBinding.instance.handlePointerEvent(
      PointerUpEvent(position: _position),
    );
    notifyListeners();
  }

  void _ensureScanTimer() {
    if (!visible || _scanTimer != null) return;
    scanViewportTree();
    _scanTimer =
        Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!visible) {
        _scanTimer?.cancel();
        _scanTimer = null;
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
    int skippedOffRoute = 0;
    int skippedSmall = 0;
    try {
      final root = WidgetsBinding.instance.rootElement;
      if (root == null) return;
      final screen = _screenSize;
      final full = Rect.fromLTWH(
          0, 0, screen.width == 0 ? 4096 : screen.width, screen.height == 0 ? 4096 : screen.height);
      void visit(Element el) {
        final String elType = el.widget.runtimeType.toString();
        // Mappe (flutter_map) e WebView (es. mapbox.html): non si scende
        // nel sottoalbero (niente frecce interne, il cursore non resta
        // inchiodato lì). Tap/drag restano liberi e naturali.
        if (elType == 'FlutterMap' ||
            elType == 'MapWidget' ||
            elType == 'WebViewWidget') {
          return;
        }
        if (el is StatefulElement && el.state is ScrollableState) {
          final st = el.state as ScrollableState;
          // Solo route corrente: mai contenuti delle schermate sotto.
          if (!_isInCurrentRoute(st)) {
            skippedOffRoute++;
            return;
          }
          try {
            final ro = st.context.findRenderObject();
            if (ro is RenderBox && ro.hasSize && ro.attached) {
              // Escludi viewport di schermate coperte (route sotto/offstage):
              // altrimenti a ogni push i numeri si accumulano.
              if (_isHiddenByAncestor(ro)) {
                skippedOffRoute++;
                return;
              }
              final Offset offset = ro.localToGlobal(Offset.zero);
              final rect = Rect.fromLTWH(
                      offset.dx, offset.dy, ro.size.width, ro.size.height)
                  .intersect(full);
              // Solo oggetti visibili e abbastanza grandi: liste/griglie
              // oppure strisce orizzontali (chip), niente micro-scroller.
              final bool bigEnough =
                  (rect.width >= 80 && rect.height >= 80) ||
                  (rect.width >= 240 && rect.height >= 44);
              if (!rect.isEmpty && bigEnough) {
                final hash = identityHashCode(st);
                final id = _viewportIds.putIfAbsent(hash, () => _nextViewportId++);
                found.add(ViewportInfo(id, st, rect, st.position.axis));
              } else {
                skippedSmall++;
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
    // Log solo se cambia qualcosa (niente spam ogni 900ms).
    if (found.length != _lastScanCount) {
      debugPrint(
          '[TvScan] trovati=${found.length} (prima ${_lastScanCount}) scartatiOffRoute=$skippedOffRoute scartatiPiccoli=$skippedSmall');
      _lastScanCount = found.length;
    }
    // Aggiorna solo se cambiato (evita rebuild continui).
    // Se la scansione torna vuota NON nascondere: le frecce restano
    // finché non cambia schermata (solo clearViewports le azzera).
    if (found.isEmpty) {
      return;
    }
    // Pulisci gli ID degli oggetti spariti (mai riassegnati ad altri).
    _viewportIds.removeWhere((hash, _) =>
        !found.any((vp) => identityHashCode(vp.state) == hash));
    bool same = found.length == _viewports.length;
    if (same) {
      for (int i = 0; i < found.length; i++) {
        if (found[i].id != _viewports[i].id ||
            found[i].rect != _viewports[i].rect) {
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

  /// true se il render object è sotto un antenato nascosto
  /// (route coperta/offstage): i suoi viewport non vanno contati.
  bool _isHiddenByAncestor(RenderObject ro) {
    try {
      dynamic node = ro.parent;
      while (node is RenderObject) {
        if (node is RenderOffstage && node.offstage) return true;
        node = node.parent;
      }
    } catch (_) {}
    return false;
  }

  /// true solo se lo Scrollable sta nella route corrente (top-most):
  /// dopo un push, i contenuti delle schermate sotto vengono esclusi
  /// anche se ancora montati.
  bool _isInCurrentRoute(ScrollableState st) {
    try {
      final route = ModalRoute.of(st.context);
      if (route == null) return true;
      return route.isCurrent;
    } catch (_) {
      return true;
    }
  }

  /// Svuota subito i gestori (cambio schermata): la scansione
  /// li rigenera per la nuova route.
  void clearViewports() {
    if (_viewports.isNotEmpty) {
      _viewports = const [];
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
  /// L'hit-test dà già priorità agli elementi sopra (marker, pulsanti,
  /// popup); la superficie mappa ignora i tap semplici.
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
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.context != null) {
      final widget = focus.context!.widget;
      if (widget is EditableText) return false;
    }
    final key = event.logicalKey;
    final isOk = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA;
    // Pressione lunga OK = trascinamento (mappe, slider, reorder...)
    if (event is KeyDownEvent && isOk) {
      _selectDownAt = DateTime.now();
      return true;
    }
    if (event is KeyUpEvent && isOk) {
      final held = _selectDownAt != null
          ? DateTime.now().difference(_selectDownAt!)
          : Duration.zero;
      _selectDownAt = null;
      if (!visible) return false;
      if (held >= longPress) {
        if (_dragging) {
          _endDrag();
        } else {
          _startDrag();
        }
      } else {
        if (_dragging) {
          _endDrag();
        } else {
          unawaited(tapAtCursor());
        }
      }
      return true;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
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
    return false;
  }
}

/// Scrollable rilevato con stato diretto (niente hit-test al tap:
/// le frecce muovono proprio questo oggetto).
class ViewportInfo {
  /// ID univoco e stabile: stesso Scrollable = stesso ID tra scansioni.
  final int id;
  final ScrollableState state;
  final Rect rect;
  final Axis axis;
  const ViewportInfo(this.id, this.state, this.rect, this.axis);

  bool get alive {
    try {
      return state.mounted;
    } catch (_) {
      return false;
    }
  }
}

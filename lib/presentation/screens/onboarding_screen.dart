
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/theme_provider.dart';
import '../../core/design_system.dart';
import '../../core/services/runtime_localizations.dart';
import 'home_screen.dart';

class _FeatureTag {
  final IconData icon;
  final String key;
  final String fallback;

  const _FeatureTag({
    required this.icon,
    required this.key,
    required this.fallback,
  });
}

class _OnboardingFeature {
  final IconData icon;
  final String titleKey;
  final String titleFallback;
  final String descKey;
  final String descFallback;
  final List<_FeatureTag> tags;

  const _OnboardingFeature({
    required this.icon,
    required this.titleKey,
    required this.titleFallback,
    required this.descKey,
    required this.descFallback,
    this.tags = const [],
  });
}

const List<_OnboardingFeature> _onboardingFeatures = [
  _OnboardingFeature(
    icon: Icons.train_rounded,
    titleKey: 'onboarding_feat_trains_title',
    titleFallback: 'Treni',
    descKey: 'onboarding_feat_trains_desc',
    descFallback:
        'Orari in tempo reale con ritardi aggiornati, binari di partenza, dettaglio completo di ogni corsa con tutte le fermate, e monitoraggio del viaggio fino a destinazione.',
    tags: const [
      _FeatureTag(
        icon: Icons.public_rounded,
        key: 'onboarding_feat_trains_national',
        fallback: 'Nazionali',
      ),
      _FeatureTag(
        icon: Icons.location_city_rounded,
        key: 'onboarding_feat_trains_regional',
        fallback: 'Regionali',
      ),
    ],
  ),
  _OnboardingFeature(
    icon: Icons.directions_bus_rounded,
    titleKey: 'onboarding_feat_bus_title',
    titleFallback: 'Bus',
    descKey: 'onboarding_feat_bus_desc',
    descFallback:
        'Fermate sulla mappa, tempi di attesa in tempo reale e dettaglio delle corse attive nella tua zona, in città e fuori.',
    tags: const [
      _FeatureTag(
        icon: Icons.location_city_rounded,
        key: 'onboarding_feat_bus_urban',
        fallback: 'Urbani',
      ),
      _FeatureTag(
        icon: Icons.route_rounded,
        key: 'onboarding_feat_bus_extra',
        fallback: 'Extraurbani',
      ),
    ],
  ),
  _OnboardingFeature(
    icon: Icons.flight_rounded,
    titleKey: 'onboarding_feat_planes_title',
    titleFallback: 'Aerei',
    descKey: 'onboarding_feat_planes_desc',
    descFallback:
        'Voli in partenza e in arrivo, orari programmati e stimati, gate e stato del volo, con ricerca per aeroporto, compagnia o numero di volo.',
  ),
  _OnboardingFeature(
    icon: Icons.add_road_rounded,
    titleKey: 'onboarding_feat_roads_title',
    titleFallback: 'Autostrade',
    descKey: 'onboarding_feat_roads_desc',
    descFallback:
        'Tratte autostradali con traffico in tempo reale, tratti chiusi o con lavori, tempi di percorrenza e pedaggi stimati prima di partire.',
  ),
  _OnboardingFeature(
    icon: Icons.notifications_active_rounded,
    titleKey: 'onboarding_feat_realtime_title',
    titleFallback: 'Tempo reale',
    descKey: 'onboarding_feat_realtime_desc',
    descFallback:
        'Attiva il monitoraggio delle tue corse e ricevi avvisi immediati su ritardi, cambi di binario, cancellazioni e fermate soppresse.',
  ),
  _OnboardingFeature(
    icon: Icons.bookmark_rounded,
    titleKey: 'onboarding_feat_saved_title',
    titleFallback: 'Salvati e offline',
    descKey: 'onboarding_feat_saved_desc',
    descFallback:
        'Salva treni, stazioni e fermate nei preferiti e scarica i dati per consultarli anche senza connessione, in galleria o all\u2019estero.',
  ),
];

/// Durata di un ciclo di vita di ogni scena (ms).
const int _sceneDurationMs = 3600;

// =============================================================================
// SCENA ANIMATA REALISTICA
// =============================================================================

/// Widget che ospita una "scena" cinematografica: paesaggio dipinto su canvas
/// con parallasse, fisica di moto e dettagli realistici. L'animazione gira
/// solo quando la pagina è (quasi) visibile, per non sprecare batteria.
class _AnimatedScene extends StatefulWidget {
  final int index;
  final bool active;
  final ThemeProvider theme;

  const _AnimatedScene({
    required this.index,
    required this.active,
    required this.theme,
  });

  @override
  State<_AnimatedScene> createState() => _AnimatedSceneState();
}

class _AnimatedSceneState extends State<_AnimatedScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _sceneDurationMs),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _AnimatedScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _ScenePainter(
                  scene: widget.index,
                  t: t,
                  primary: widget.theme.primaryColor,
                  surface: widget.theme.surfaceColor,
                ),
              ),
            ),
            if (widget.index == 4) _RealtimeOverlay(t: t),
          ],
        );
      },
    );
  }
}

// =============================================================================
// PAINTER DELLE SCENE
// =============================================================================

/// clamp(0,1) che restituisce sempre double (quello di Dart restituisce num).
double _c01(num x) => x.clamp(0.0, 1.0).toDouble();

class _ScenePainter extends CustomPainter {
  final int scene;
  final double t;
  final Color primary;
  final Color surface;

  _ScenePainter({
    required this.scene,
    required this.t,
    required this.primary,
    required this.surface,
  });

  // ---------- utilità ----------

  double lerp(double a, double b, double f) => a + (b - a) * f;

  double smooth(num x) {
    final c = _c01(x);
    return c * c * (3 - 2 * c);
  }


  void _text(
    Canvas canvas,
    String s,
    Offset o, {
    double size = 12,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFamily: 'Syne',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o);
  }

  Size _textSize(
    String s, {
    double size = 12,
    Color color = Colors.white,
    FontWeight weight = FontWeight.w600,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          fontFamily: 'Syne',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.size;
  }

  RRect _rr(Rect r, double rad) =>
      RRect.fromRectAndRadius(r, Radius.circular(rad));

  Paint get _fill => Paint()..style = PaintingStyle.fill;

  void _glowDot(Canvas canvas, Offset c, double r, Color color,
      {double blur = 6}) {
    final p = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawCircle(c, r, p);
    canvas.drawCircle(c, r * 0.55, _fill..color = color.withOpacity(0.9));
  }

  /// Profilo di distanza realistica: accelerazione, crociera, frenata, sosta.
  /// [knots] sono coppie (tempo, distanza) monotone; tra i nodi la curva è
  /// smooth, quindi il "mondo" scorre con accelerazioni credibili.
  double _distance(List<List<double>> knots, double t) {
    if (t <= knots.first[0]) return knots.first[1];
    for (var i = 0; i < knots.length - 1; i++) {
      final a = knots[i], b = knots[i + 1];
      if (t <= b[0]) {
        final f = smooth((t - a[0]) / (b[0] - a[0]));
        return lerp(a[1], b[1], f);
      }
    }
    return knots.last[1];
  }

  // ---------- entry point ----------

  @override
  void paint(Canvas canvas, Size size) {
    switch (scene) {
      case 0:
        _paintTrain(canvas, size);
        break;
      case 1:
        _paintBus(canvas, size);
        break;
      case 2:
        _paintPlane(canvas, size);
        break;
      case 3:
        _paintRoad(canvas, size);
        break;
      case 4:
        _paintRadar(canvas, size);
        break;
      default:
        _paintSaved(canvas, size);
    }
  }

  // =================================================================
  // SCENA 0 — TRENO AL TRAMONTO
  // =================================================================
  void _paintTrain(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final horizon = h * 0.60;

    // Cielo: tramonto viola-arancio
    final sky = Rect.fromLTRB(0, 0, w, horizon + 12);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF2E2A5C),
            Color(0xFF6B4E8E),
            Color(0xFFE8935C),
          ],
        ).createShader(sky),
    );

    // Sole basso con alone
    final sun = Offset(w * 0.76, horizon * 0.52);
    final sunGlow = Paint()
      ..shader = RadialGradient(
        colors: [const Color(0xFFFFD9A0).withOpacity(0.8), Colors.transparent],
      ).createShader(Rect.fromCircle(center: sun, radius: 60));
    canvas.drawCircle(sun, 60, sunGlow);
    canvas.drawCircle(sun, 15, _fill..color = const Color(0xFFFFE3B3));

    // Lunghezza "mondo" percorsa in un loop (in pixel di scenario)
    const totalPx = 1600.0;
    final d = _distance(const [
      [0.00, 0.00],
      [0.16, 0.12],
      [0.58, 0.72],
      [0.82, 0.97],
      [1.00, 1.00],
    ], t);
    final scroll = d * totalPx;

    // Montagne lontane (parallasse lento)
    _ridge(canvas, size, horizon, 0.22 * scroll, 90, const Color(0xFF4A3E73),
        seed: 11, tile: 340);
    _ridge(canvas, size, horizon, 0.45 * scroll, 55, const Color(0xFF372E58),
        seed: 27, tile: 260);

    // Terreno
    final ground = Rect.fromLTRB(0, horizon, w, h);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF2A2440), Color(0xFF1B1830)],
        ).createShader(ground),
    );

    // Pini e pali che scorrono a velocità piena
    _trees(canvas, size, scroll, horizon, h);

    // Binari
    final railY = h * 0.80;
    final sleeperPaint = _fill..color = const Color(0xFF3B3454);
    final spacing = 16.0;
    final off = scroll % spacing;
    for (var x = -off; x < w; x += spacing) {
      canvas.drawRect(Rect.fromLTWH(x, railY + 2, 10, 5), sleeperPaint);
    }
    final railPaint = Paint()
      ..color = const Color(0xFF8E88A8)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, railY), Offset(w, railY), railPaint);
    canvas.drawLine(Offset(0, railY + 9), Offset(w, railY + 9), railPaint);

    // Stazione: piattaforma che arriva da destra e si allinea col treno
    final stationWorldX = totalPx + w * 0.51;
    final stationX = stationWorldX - scroll;
    if (stationX < w + 240 && stationX > -320) {
      final plat = Rect.fromLTWH(stationX, railY - 34, 220, 34);
      canvas.drawRRect(
        _rr(plat, 4),
        _fill..color = const Color(0xFF453E63),
      );
      canvas.drawRect(
        Rect.fromLTWH(stationX, railY - 36, 220, 3),
        _fill..color = const Color(0xFF6E6591),
      );
      // Cartello stazione
      final poleX = stationX + 26;
      canvas.drawRect(
        Rect.fromLTWH(poleX, railY - 78, 3, 44),
        _fill..color = const Color(0xFF8E88A8),
      );
      final sign = Rect.fromLTWH(poleX - 22, railY - 100, 48, 24);
      canvas.drawRRect(_rr(sign, 5), _fill..color = const Color(0xFF141126));
      _text(canvas, '1', Offset(poleX - 3, railY - 96), size: 13);

      // Persona in attesa durante la sosta
      if (t > 0.84) {
        final px = stationX + 90;
        canvas.drawCircle(Offset(px, railY - 44), 4,
            _fill..color = const Color(0xFFE8E4F5));
        canvas.drawRRect(
          _rr(Rect.fromLTWH(px - 3.5, railY - 40, 7, 14), 3),
          _fill..color = const Color(0xFFB9B3D6),
        );
      }
    }

    // TRENO: fisso al centro, è il mondo che scorre. Beccheggio da
    // accelerazione/frenata, ruote che ruotano davvero col percorso.
    final trainX = w * 0.46;
    final baseY = railY - 6;
    final dwelling = t > 0.84;
    double tilt = 0;
    if (t < 0.16) {
      tilt = -0.035 * smooth(t / 0.16); // spinta in accelerazione
    } else if (t > 0.58 && t < 0.84) {
      tilt = 0.045 * smooth((t - 0.58) / 0.26); // assetto in frenata
    }

    canvas.save();
    canvas.translate(trainX, baseY);
    canvas.rotate(tilt);

    // Scia luminosa dei fari
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          const Color(0xFFFFE9B0).withOpacity(0.28),
          Colors.transparent
        ],
      ).createShader(Rect.fromLTWH(60, -20, 90, 22));
    canvas.drawRect(Rect.fromLTWH(60, -22, 90, 24), beam);

    // Carrozza
    final body = Rect.fromLTWH(-78, -50, 156, 38);
    canvas.drawRRect(
      _rr(body, 10),
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFFEF6B3E), Color(0xFFD8402E)],
        ).createShader(body),
    );
    // Finestrini con passeggeri sfumati
    for (var i = 0; i < 5; i++) {
      final win = Rect.fromLTWH(-64 + i * 27, -42, 20, 14);
      canvas.drawRRect(_rr(win, 4), _fill..color = const Color(0xFFFFE9C4));
      if (i == 2) {
        canvas.drawCircle(Offset(-54 + i * 27, -33), 3.4,
            _fill..color = const Color(0xFF4A3B5C));
      }
    }
    // Striscia decorativa
    canvas.drawRect(
      Rect.fromLTWH(-78, -22, 156, 4),
      _fill..color = Colors.white.withOpacity(0.75),
    );
    // Pantografo
    final pantograph = Paint()
      ..color = const Color(0xFF2B2440)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-24, -50), const Offset(-12, -66), pantograph);
    canvas.drawLine(const Offset(-12, -66), const Offset(4, -50), pantograph);
    canvas.drawLine(
        const Offset(-16, -66), const Offset(-8, -66), pantograph);

    // Ruote con raggi che ruotano in base alla distanza percorsa
    final wheelAngle = (scroll / 9) % (math.pi * 2);
    for (final wx in [-48.0, 48.0]) {
      canvas.save();
      canvas.translate(wx, -6);
      canvas.rotate(wheelAngle);
      canvas.drawCircle(
          Offset.zero, 10, _fill..color = const Color(0xFF1B1830));
      canvas.drawCircle(
          Offset.zero, 10, Paint()
            ..color = const Color(0xFF8E88A8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      final spoke = Paint()
        ..color = const Color(0xFF8E88A8)
        ..strokeWidth = 1.6;
      for (var k = 0; k < 3; k++) {
        final a = k * math.pi / 3;
        canvas.drawLine(Offset(-8 * math.cos(a), -8 * math.sin(a)),
            Offset(8 * math.cos(a), 8 * math.sin(a)), spoke);
      }
      canvas.restore();
    }

    // Fari
    _glowDot(canvas, const Offset(76, -30), 4, const Color(0xFFFFE9B0));
    canvas.drawCircle(
        const Offset(-77, -30), 3, _fill..color = const Color(0xFFFF5B4D));
    canvas.restore();

    // Badge ritardo: appare con rimbalzo solo in sosta (porta aperta)
    if (dwelling) {
      final pop = Curves.easeOutBack.transform(_c01((t - 0.84) / 0.10));
      final label = '+${4 + (2 * (t * 4).floor() % 3)}\'';
      final sz = _textSize(label, size: 12, weight: FontWeight.bold);
      final cw = sz.width + 22, ch = 24.0;
      canvas.save();
      canvas.translate(trainX + 40, baseY - 92);
      canvas.scale(0.6 + 0.4 * pop);
      canvas.drawRRect(
        _rr(Rect.fromLTWH(-cw / 2, 0, cw, ch), 12),
        _fill..color = const Color(0xFFFFB020).withOpacity(0.95),
      );
      _text(canvas, label, Offset(-sz.width / 2, 3.5),
          size: 12, color: const Color(0xFF3A2400), weight: FontWeight.bold);
      canvas.restore();
    }
  }

  void _ridge(Canvas canvas, Size size, double horizon, double offset,
      double maxH, Color color,
      {required int seed, required double tile}) {
    final w = size.width;
    final rnd = math.Random(seed);
    // Profilo della cresta campionato ogni tile px
    final pts = <double>[];
    for (var i = 0; i <= (w / tile).ceil() + 2; i++) {
      pts.add(horizon - rnd.nextDouble() * maxH - maxH * 0.3);
    }
    final path = Path()..moveTo(-offset % tile - tile, horizon + 4);
    var x = -offset % tile - tile;
    var idx = 0;
    while (x < w + tile) {
      final y = pts[idx % pts.length];
      path.lineTo(x, y);
      x += tile / 2;
      idx++;
    }
    path.lineTo(w + tile, horizon + 4);
    path.close();
    canvas.drawPath(path, _fill..color = color);
  }

  void _trees(Canvas canvas, Size size, double scroll, double horizon, double h) {
    final w = size.width;
    final spacing = 120.0;
    final start = -(scroll % spacing);
    final pine = Paint()..color = const Color(0xFF241F3D);
    for (var x = start - spacing; x < w + spacing; x += spacing) {
      final idx = ((x + scroll) / spacing).round();
      if (idx % 3 == 2) continue; // spazi aperti
      final baseY = horizon + 16;
      final s = 16.0 + (idx % 2) * 7;
      final p = Path()
        ..moveTo(x, baseY - s * 2.2)
        ..lineTo(x - s * 0.55, baseY - s)
        ..lineTo(x - s * 0.3, baseY - s)
        ..lineTo(x - s * 0.7, baseY)
        ..lineTo(x + s * 0.7, baseY)
        ..lineTo(x + s * 0.3, baseY - s)
        ..lineTo(x + s * 0.55, baseY - s)
        ..close();
      canvas.drawPath(p, pine);
    }
  }

  // =================================================================
  // SCENA 1 — BUS URBANO
  // =================================================================
  void _paintBus(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final sky = Rect.fromLTRB(0, 0, w, h * 0.66);

    // Cielo diurno caldo
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF6FA8DC), Color(0xFFBFD9EE), Color(0xFFF4E3C1)],
        ).createShader(sky),
    );

    // Nuvole lente
    final cloudPaint = _fill..color = Colors.white.withOpacity(0.75);
    for (var i = 0; i < 3; i++) {
      final cx = (w * (0.25 + i * 0.33) - t * w * (0.10 + i * 0.04)) % (w + 140) - 70;
      final cy = h * (0.14 + i * 0.08);
      canvas.drawRRect(
        _rr(Rect.fromLTWH(cx, cy, 64, 16), 9),
        cloudPaint,
      );
      canvas.drawRRect(
        _rr(Rect.fromLTWH(cx + 12, cy - 8, 36, 14), 8),
        cloudPaint,
      );
    }

    // Skyline: due file di palazzi con parallasse e finestre accese
    _skyline(canvas, size, h * 0.66, t * w * 0.35, 0.55,
        const Color(0xFF7E93B8), seed: 5);
    _skyline(canvas, size, h * 0.66, t * w * 0.7, 0.85,
        const Color(0xFF55688C), seed: 9, windows: true);

    // Strada
    final roadY = h * 0.72;
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.66, w, roadY),
      _fill..color = const Color(0xFFC9BFA9), // marciapiede
    );
    canvas.drawRect(
      Rect.fromLTRB(0, roadY - 3, w, roadY),
      _fill..color = const Color(0xFF9A917D),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, roadY, w, h),
      _fill..color = const Color(0xFF3E4149),
    );

    // Distanza percorsa: accelerazione, sosta alla fermata, ripartenza
    const totalPx = 1400.0;
    final d = _distance(const [
      [0.00, 0.00],
      [0.14, 0.10],
      [0.40, 0.42],
      [0.46, 0.50],
      [0.58, 0.50], // porte aperte
      [0.66, 0.60],
      [0.90, 0.92],
      [1.00, 1.00],
    ], t);
    final scroll = d * totalPx;

    // Strisce della corsia
    final dashPaint = _fill..color = const Color(0xFFF4EFD9);
    final dashOff = scroll % 42;
    for (var x = -dashOff; x < w; x += 42) {
      canvas.drawRRect(_rr(Rect.fromLTWH(x, h * 0.875, 22, 4), 2), dashPaint);
    }

    // Fermata (ancorata al punto in cui il bus si ferma)
    final stopX = (-0.18 + 1.36 * 0.50) * w;
    canvas.drawRect(
      Rect.fromLTWH(stopX - 2, roadY - 66, 4, 66),
      _fill..color = const Color(0xFF6E7686),
    );
    canvas.drawRRect(
      _rr(Rect.fromLTWH(stopX - 18, roadY - 84, 40, 22), 6),
      _fill..color = const Color(0xFF1F6E43),
    );
    _text(canvas, 'BUS', Offset(stopX - 12, roadY - 80),
        size: 11, weight: FontWeight.bold);
    // Pensilina
    canvas.drawRRect(
      _rr(Rect.fromLTWH(stopX + 14, roadY - 60, 52, 5), 2),
      _fill..color = const Color(0xFF6E7686),
    );
    canvas.drawRect(
      Rect.fromLTWH(stopX + 18, roadY - 55, 3, 55),
      _fill..color = const Color(0xFF6E7686),
    );
    // Passeggero che sale durante la sosta
    if (t > 0.46 && t < 0.62) {
      final walk = smooth((t - 0.46) / 0.16);
      final px = lerp(stopX + 30, stopX - 46, walk);
      canvas.drawCircle(
          Offset(px, roadY - 24), 4, _fill..color = const Color(0xFF3B3350));
      canvas.drawRRect(
        _rr(Rect.fromLTWH(px - 3.5, roadY - 20, 7, 16), 3),
        _fill..color = const Color(0xFF7A6FF0),
      );
    }

    // BUS: sospensioni realistiche (oscillazione smorzata a ogni spunto/frenata)
    final busX = (-0.18 + 1.36 * d) * w;
    double bounce = 0;
    for (final anchor in [0.14, 0.58, 0.66, 0.90]) {
      final dt = (t - anchor).abs();
      if (dt < 0.35) {
        bounce += math.sin(dt * 34) * math.exp(-dt * 11) * 2.4;
      }
    }
    final busY = roadY + 16 + bounce;
    final braking = (t > 0.36 && t < 0.46) || t > 0.88;

    canvas.save();
    canvas.translate(busX, busY);
    canvas.rotate(bounce * 0.004 + (braking ? 0.012 : 0));

    // Coda di sterzo opposta alla sospensione
    // Corpo
    final busBody = Rect.fromLTWH(-64, -52, 128, 44);
    canvas.drawRRect(
      _rr(busBody, 12),
      Paint()
        ..shader = LinearGradient(
          colors: const [Color(0xFF2FB47C), Color(0xFF1E8A5E)],
        ).createShader(busBody),
    );
    // Frontale arrotondato
    canvas.drawRRect(
      _rr(Rect.fromLTWH(46, -50, 20, 40), 10),
      _fill..color = const Color(0xFF1E8A5E),
    );
    // Finestrini
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        _rr(Rect.fromLTWH(-54 + i * 26, -44, 20, 16), 4),
        _fill..color = const Color(0xFFDCEEF7),
      );
    }
    // Parabrezza
    canvas.drawRRect(
      _rr(Rect.fromLTWH(48, -42, 14, 20), 5),
      _fill..color = const Color(0xFFBFE0EF),
    );
    // Display linea
    canvas.drawRRect(
      _rr(Rect.fromLTWH(48, -50, 14, 7), 3),
      _fill..color = const Color(0xFF10241A),
    );
    _text(canvas, '42', Offset(50.5, -50.5),
        size: 6.5, color: const Color(0xFF7CFFB2));
    // Porte: lampeggiano gialle quando il bus è in sosta
    final doorsOpen = t > 0.46 && t < 0.58;
    canvas.drawRRect(
      _rr(Rect.fromLTWH(18, -44, 14, 36), 3),
      _fill
        ..color = doorsOpen
            ? ((t * 8).floor().isEven
                ? const Color(0xFFFFD34D)
                : const Color(0xFF14704C))
            : const Color(0xFF14704C),
    );
    // Ruote
    final wAngle = (scroll / 7.5) % (math.pi * 2);
    for (final wx in [-40.0, 38.0]) {
      canvas.save();
      canvas.translate(wx, -6);
      canvas.rotate(wAngle);
      canvas.drawCircle(
          Offset.zero, 11, _fill..color = const Color(0xFF191C22));
      canvas.drawCircle(
          Offset.zero,
          11,
          Paint()
            ..color = const Color(0xFF9AA3B0)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2);
      final spoke = Paint()
        ..color = const Color(0xFF9AA3B0)
        ..strokeWidth = 1.6;
      for (var k = 0; k < 3; k++) {
        final a = k * math.pi / 3;
        canvas.drawLine(Offset(-8.5 * math.cos(a), -8.5 * math.sin(a)),
            Offset(8.5 * math.cos(a), 8.5 * math.sin(a)), spoke);
      }
      canvas.restore();
    }
    // Fanali
    _glowDot(canvas, const Offset(64, -16), 3.4, const Color(0xFFFFF3C4));
    canvas.drawCircle(
        const Offset(-63, -16), 2.6, _fill..color = const Color(0xFFFF4D3D));
    canvas.restore();

    // Pannello "attesa" alla fermata
    if (t > 0.30 && t < 0.62) {
      final alpha = t < 0.36
          ? smooth((t - 0.30) / 0.06)
          : (t > 0.56 ? 1 - smooth((t - 0.56) / 0.06) : 1.0);
      final label = doorsOpen ? 'Sale...' : 'Fermata';
      final sz = _textSize(label, size: 11, weight: FontWeight.bold);
      final cw = sz.width + 36;
      canvas.save();
      canvas.translate(stopX - cw / 2 + 20, roadY - 108);
      canvas.drawRRect(
        _rr(Rect.fromLTWH(0, 0, cw, 22), 11),
        _fill..color = const Color(0xFF14182B).withOpacity(0.82 * alpha),
      );
      _text(canvas, label, Offset(18, 4),
          size: 11, color: Colors.white.withOpacity(alpha));
      // pallino
      canvas.drawCircle(Offset(11, 11), 3.4,
          _fill..color = const Color(0xFF3DDC97).withOpacity(alpha));
      canvas.restore();
    }
  }

  void _skyline(Canvas canvas, Size size, double baseY, double offset,
      double scale, Color color,
      {required int seed, bool windows = false}) {
    final w = size.width;
    final rnd = math.Random(seed);
    final bw = 46.0 * scale + 18;
    final start = -(offset % bw) - bw;
    var x = start;
    var i = 0;
    while (x < w + bw) {
      final bh = (40 + rnd.nextDouble() * 80) * scale + 20;
      final rect = Rect.fromLTWH(x, baseY - bh, bw - 8, bh);
      canvas.drawRect(rect, _fill..color = color);
      if (windows) {
        final wr = math.Random(seed * 31 + i);
        final winPaint = _fill..color = const Color(0xFFFFD98A).withOpacity(0.85);
        for (var wy = baseY - bh + 8; wy < baseY - 10; wy += 14) {
          for (var wx = x + 6; wx < x + bw - 16; wx += 12) {
            if (wr.nextDouble() < 0.5) {
              canvas.drawRect(Rect.fromLTWH(wx, wy, 5, 7), winPaint);
            }
          }
        }
      }
      x += bw;
      i++;
    }
  }

  // =================================================================
  // SCENA 2 — VOLO
  // =================================================================
  Offset _planePos(double u, double w, double h) {
    double x, y;
    if (u < 0.28) {
      // Decollo: salita decisa
      final f = Curves.easeOutCubic.transform(u / 0.28);
      x = lerp(-0.08, 0.42, f);
      y = lerp(h * 0.86, h * 0.40, f);
    } else if (u < 0.72) {
      // Crociera: leggero dondolio
      final f = (u - 0.28) / 0.44;
      x = lerp(0.42, 0.72, f);
      y = h * 0.40 + math.sin(u * math.pi * 6) * 3.5;
    } else {
      // Discesa finale
      final f = Curves.easeInCubic.transform((u - 0.72) / 0.28);
      x = lerp(0.72, 1.10, f);
      y = lerp(h * 0.40, h * 0.82, f);
    }
    return Offset(x * w, y);
  }

  void _paintPlane(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Cielo in quota
    final sky = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF1D3E73),
            Color(0xFF3F6EA8),
            Color(0xFFA9C8E8),
          ],
        ).createShader(sky),
    );

    // Sole in alto a destra
    final sun = Offset(w * 0.82, h * 0.18);
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withOpacity(0.9), Colors.transparent],
      ).createShader(Rect.fromCircle(center: sun, radius: 90));
    canvas.drawCircle(sun, 90, glow);
    canvas.drawCircle(sun, 12, _fill..color = Colors.white);

    // Nuvole a tre profondità (parallasse)
    _cloudLayer(canvas, size, t * 26, 0.35, 0.18, 0.5);
    _cloudLayer(canvas, size, t * 60, 0.60, 0.42, 0.75);
    _cloudLayer(canvas, size, t * 110, 1.0, 0.66, 1.0);

    // Aereo lontano, in controvolo lento
    final farX = w * 0.85 - t * 60;
    canvas.save();
    canvas.translate(farX, h * 0.26);
    canvas.scale(0.35);
    canvas.rotate(0.06);
    _drawAircraftShape(canvas, const Color(0xFFD8E6F2), detail: false);
    canvas.restore();

    // Scia di condensazione: campiona la traiettoria reale fino a ora
    final trail = Path();
    final samples = 22;
    for (var i = 0; i <= samples; i++) {
      final u = _c01(t - 0.22 * (1 - i / samples));
      final p = _planePos(u, w, h);
      if (i == 0) {
        trail.moveTo(p.dx - 30, p.dy + 4);
      } else {
        trail.lineTo(p.dx - 30, p.dy + 4);
      }
    }
    final trailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [Colors.white.withOpacity(0.55), Colors.white.withOpacity(0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(trail, trailPaint);

    // Aereo principale: beccheggio dalla traiettoria
    final pos = _planePos(t, w, h);
    final ahead = _planePos((t + 0.012).clamp(0.0, 1.0), w, h);
    final pitch = math.atan2(ahead.dy - pos.dy, ahead.dx - pos.dx);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(pitch);
    _drawAircraftShape(canvas, Colors.white, detail: true);
    canvas.restore();

    // Etichetta volo in crociera
    if (t > 0.34 && t < 0.72) {
      final alpha = (t - 0.34 < 0.08)
          ? smooth((t - 0.34) / 0.08)
          : (t > 0.64 ? 1 - smooth((t - 0.64) / 0.08) : 1.0);
      final label = 'AZ 204 · FL370';
      final sz = _textSize(label, size: 10.5, weight: FontWeight.bold);
      canvas.drawRRect(
        _rr(Rect.fromLTWH(pos.dx + 26, pos.dy - 26, sz.width + 18, 20), 10),
        _fill..color = const Color(0xFF101A30).withOpacity(0.75 * alpha),
      );
      _text(canvas, label, Offset(pos.dx + 35, pos.dy - 22.5),
          size: 10.5, color: Colors.white.withOpacity(alpha));
      canvas.drawCircle(
          Offset(pos.dx + 31, pos.dy - 16), 2.4,
          _fill..color = const Color(0xFF7CFFB2).withOpacity(alpha));
    }
  }

  void _cloudLayer(Canvas canvas, Size size, double offset, double parallax,
      double yFrac, double scale) {
    final w = size.width;
    final spacing = 150.0 * scale + 60;
    final start = -(offset % spacing) - spacing;
    final paint = _fill..color = Colors.white.withOpacity(0.55 + 0.25 * parallax);
    for (var x = start; x < w + spacing; x += spacing) {
      final idx = ((x + offset) / spacing).round();
      final y = size.height * yFrac + (idx % 3) * 12.0;
      final s = 22.0 * scale;
      canvas.drawRRect(_rr(Rect.fromLTWH(x, y, s * 3.2, s), s / 2), paint);
      canvas.drawRRect(_rr(Rect.fromLTWH(x + s * 0.6, y - s * 0.45, s * 1.8, s * 0.9), s / 2), paint);
    }
  }

  void _drawAircraftShape(Canvas canvas, Color color, {required bool detail}) {
    final bodyPaint = _fill..color = color;
    // Fusoliera
    final fuselage = Rect.fromLTWH(-30, -6, 56, 12);
    canvas.drawRRect(_rr(fuselage, 6), bodyPaint);
    // Naso
    canvas.drawCircle(const Offset(27, 0), 6, bodyPaint);
    // Coda verticale
    final tail = Path()
      ..moveTo(-30, -6)
      ..lineTo(-38, -20)
      ..lineTo(-30, -20)
      ..lineTo(-22, -6)
      ..close();
    canvas.drawPath(tail, bodyPaint);
    // Ali (freccia)
    final wing = Path()
      ..moveTo(4, 0)
      ..lineTo(-14, 14)
      ..lineTo(-22, 14)
      ..lineTo(-8, 0)
      ..close();
    canvas.drawPath(wing, bodyPaint);
    final wing2 = Path()
      ..moveTo(4, 0)
      ..lineTo(-12, -13)
      ..lineTo(-19, -13)
      ..lineTo(-7, 0)
      ..close();
    canvas.drawPath(wing2, bodyPaint);
    // Motori
    canvas.drawRRect(
        _rr(Rect.fromLTWH(-4, 6, 12, 5), 2.5), _fill..color = color);
    canvas.drawRRect(
        _rr(Rect.fromLTWH(-2, -11, 12, 5), 2.5), _fill..color = color);
    if (detail) {
      // Finestrini
      final winPaint = _fill..color = const Color(0xFF2E5A8C);
      for (var i = 0; i < 6; i++) {
        canvas.drawCircle(Offset(18 - i * 7.5, -1.5), 1.5, winPaint);
      }
    }
  }

  // =================================================================
  // SCENA 3 — AUTOSTRADA AL CREPUSCOLO
  // =================================================================
  void _paintRoad(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Cielo
    final sky = Rect.fromLTWH(0, 0, w, h * 0.58);
    canvas.drawRect(
      sky,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFF22284B),
            Color(0xFF5A4A7D),
            Color(0xFFE88A5C),
          ],
        ).createShader(sky),
    );
    final sun = Offset(w * 0.30, h * 0.44);
    canvas.drawCircle(
      sun,
      46,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFC98A).withOpacity(0.9), Colors.transparent],
        ).createShader(Rect.fromCircle(center: sun, radius: 46)),
    );

    // Colline lontane
    _ridge(canvas, size, h * 0.58, t * 30, 30, const Color(0xFF3A3358),
        seed: 14, tile: 220);

    // Asfalto
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.58, w, h),
      _fill..color = const Color(0xFF2C2F38),
    );
    // Spartitraffico superiore (guard rail)
    canvas.drawRect(
      Rect.fromLTRB(0, h * 0.585, w, h * 0.60),
      _fill..color = const Color(0xFF8A8F9C),
    );

    // Corsie: quella lontana verso sinistra, quella vicina verso destra
    final farLaneY = h * 0.68, nearLaneY = h * 0.85;
    final scroll = t * 900;

    // Distanziali corsia vicina (scorrono a velocità propria)
    final dashPaint = _fill..color = const Color(0xFFF5E9C9).withOpacity(0.9);
    final off = scroll % 48;
    for (var x = -off; x < w; x += 48) {
      canvas.drawRRect(_rr(Rect.fromLTWH(x, h * 0.755, 24, 4), 2), dashPaint);
    }

    // Auto: ognuna ha velocità e fase proprie, come nel traffico vero
    // Corsia lontana: marcia opposta (verso sinistra), luci rosse
    final farCars = [
      [0.16, 0.30],
      [0.55, 0.24],
      [0.85, 0.33],
    ];
    for (final c in farCars) {
      final x = (1.15 - ((t * (c[0]) + c[1]) % 1.3)) * w;
      _drawCar(canvas, Offset(x, farLaneY), -1, 0.62, const Color(0xFF4E5A78));
    }
    // Corsia vicina: verso destra, fari accesi con cono luminoso
    final nearCars = <List<Object>>[
      [0.20, 0.05, const Color(0xFF7A4DE8)],
      [0.26, 0.45, const Color(0xFFD84A3A)], // più veloce: sorpassa
      [0.18, 0.75, const Color(0xFF3A6FD8)],
    ];
    for (final c in nearCars) {
      final x = (((t * (c[0] as double) + (c[1] as double)) % 1.25) - 0.12) * w;
      _drawCar(canvas, Offset(x, nearLaneY), 1, 1.0, c[2] as Color);
    }

    // Chip ETA: il conteggio scende realisticamente col progresso
    final eta = (12 - (6 * _distance(const [
          [0, 0],
          [0.25, 0.2],
          [0.7, 0.8],
          [1, 1]
        ], t))).round();
    final label = '$eta min';
    final sz = _textSize(label, size: 12, weight: FontWeight.bold);
    final cw = sz.width + 46.0;
    canvas.drawRRect(
      _rr(Rect.fromLTWH(14, 14, cw, 28), 14),
      _fill..color = const Color(0xFF10141F).withOpacity(0.78),
    );
    // icona orologio
    canvas.drawCircle(const Offset(29, 28), 7,
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8);
    final hand = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(29, 28), const Offset(29, 23.5), hand);
    canvas.drawLine(const Offset(29, 28), const Offset(32, 29), hand);
    _text(canvas, label, Offset(42, 21.5), size: 12);
  }

  void _drawCar(Canvas canvas, Offset pos, int dir, double scale, Color color) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.scale(dir * scale, scale);
    // Cono del faro
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [const Color(0xFFFFE9B0).withOpacity(0.30), Colors.transparent],
      ).createShader(const Rect.fromLTWH(24, -8, 46, 16));
    canvas.drawRect(const Rect.fromLTWH(24, -8, 46, 16), beam);
    // Corpo
    final body = Rect.fromLTWH(-26, -14, 52, 14);
    canvas.drawRRect(_rr(body, 6), _fill..color = color);
    canvas.drawRRect(
      _rr(const Rect.fromLTWH(-14, -24, 26, 12), 6),
      _fill..color = color.withOpacity(0.92),
    );
    // Vetri
    canvas.drawRRect(
      _rr(const Rect.fromLTWH(-10, -22, 18, 9), 4),
      _fill..color = const Color(0xFF1E2A44),
    );
    // Ruote
    for (final wx in [-14.0, 14.0]) {
      canvas.drawCircle(
          Offset(wx, 0), 6.5, _fill..color = const Color(0xFF11141C));
      canvas.drawCircle(
          Offset(wx, 0),
          6.5,
          Paint()
            ..color = const Color(0xFF6A7280)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }
    // Fari / fanali
    if (dir > 0) {
      _glowDot(canvas, const Offset(25, -8), 2.6, const Color(0xFFFFF3C4));
      canvas.drawCircle(
          const Offset(-26, -8), 2.2, _fill..color = const Color(0xFFFF4D3D));
    } else {
      _glowDot(canvas, const Offset(-26, -8), 2.4, const Color(0xFFFF5B4D));
    }
    canvas.restore();
  }

  // =================================================================
  // SCENA 4 — RADAR TEMPO REALE (sfondo; overlay in widget)
  // =================================================================
  void _paintRadar(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final c = Offset(w / 2, h / 2);

    final bg = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bg,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Color(0xFF0D1130), Color(0xFF181C3F)],
        ).createShader(bg),
    );

    // Griglia di punti
    final dot = _fill..color = Colors.white.withOpacity(0.05);
    for (var y = 8.0; y < h; y += 18) {
      for (var x = 8.0; x < w; x += 18) {
        canvas.drawCircle(Offset(x, y), 1, dot);
      }
    }

    // Anelli radar in espansione (eco stile sonar)
    final maxR = math.min(w, h) * 0.46;
    for (var i = 0; i < 3; i++) {
      final p = (t * 1.4 + i / 3) % 1.0;
      canvas.drawCircle(
        c,
        maxR * p,
        Paint()
          ..color = primary.withOpacity(0.28 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    }
    // Anelli fissi
    for (final f in [0.35, 0.7, 1.0]) {
      canvas.drawCircle(
        c,
        maxR * f,
        Paint()
          ..color = primary.withOpacity(0.10)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Fascio rotante (sweep)
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(t * math.pi * 2);
    final sweep = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [primary.withOpacity(0.35), Colors.transparent],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: maxR));
    canvas.drawCircle(Offset.zero, maxR, sweep);
    // Punta luminosa del fascio
    _glowDot(canvas, Offset(maxR, 0), 3, primary.withOpacity(0.9));
    canvas.restore();
  }

  // =================================================================
  // SCENA 5 — SALVATAGGIO E DOWNLOAD OFFLINE
  // =================================================================
  void _paintSaved(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    final bg = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bg,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withOpacity(0.20),
            const Color(0xFF1B1F3B).withOpacity(isDarkSafe ? 1 : 0.0),
            const Color(0xFF12152E),
          ],
        ).createShader(bg),
    );

    final c = Offset(w / 2, h * 0.44);

    // Fase 1 (0 → 0.42): tap + rimbalzo elastico del segnalibro
    // Fase 2 (0.42 → 0.85): anello di download che si riempie
    // Fase 3 (0.85 → 1): spunta finale
    final tappedT = (t / 0.42).clamp(0.0, 1.0);
    final on = t < 0.85;
    final bounceT = _c01(t / 0.14);
    final scale = on
        ? (t < 0.14 ? 0.7 + 0.3 * Curves.elasticOut.transform(bounceT) : 1.0)
        : 1.0;

    // Chip "offline" che scivola dentro a fine download
    final chipIn = smooth((t - 0.80) / 0.14);
    final chipLabel = 'Disponibile offline';
    final chipSz = _textSize(chipLabel, size: 12, weight: FontWeight.bold);
    final chipW = chipSz.width + 52;
    canvas.save();
    canvas.translate(c.dx - chipW / 2 + (1 - chipIn) * 30, h * 0.80);
    canvas.drawRRect(
      _rr(Rect.fromLTWH(0, 0, chipW, 28), 14),
      _fill..color = const Color(0xFFEAF7EF).withOpacity(0.96 * chipIn),
    );
    // nuvola-off stilizzata
    final cloud = _fill..color = const Color(0xFF1E8A5E);
    canvas.drawRRect(_rr(Rect.fromLTWH(12, 12, 20, 10), 5), cloud);
    canvas.drawCircle(Offset(18, 12), 5, cloud);
    canvas.drawCircle(Offset(25, 11), 6, cloud);
    final slash = Paint()
      ..color = const Color(0xFF1E8A5E)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(13, 8), const Offset(31, 24), slash);
    _text(canvas, chipLabel, Offset(42, 6.5),
        size: 12, color: const Color(0xFF14563B), weight: FontWeight.bold);
    canvas.restore();

    // Pulsante centrale
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(scale);

    // Anello di progresso (download)
    final prog = smooth(((t - 0.42) / 0.43).clamp(0.0, 1.0));
    if (t > 0.42 && t < 0.98) {
      canvas.drawCircle(
        Offset.zero,
        46,
        Paint()
          ..color = Colors.white.withOpacity(0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawArc(
        Rect.fromCircle(center: Offset.zero, radius: 46),
        -math.pi / 2,
        math.pi * 2 * prog,
        false,
        Paint()
          ..color = const Color(0xFF3DDC97)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round,
      );
      // Percentuale
      final pct = '${(prog * 100).round()}%';
      final ps = _textSize(pct, size: 13, weight: FontWeight.bold);
      _text(canvas, pct, Offset(-ps.width / 2, 54), size: 13);
    }

    // Pulsante con segnalibro
    canvas.drawCircle(
      Offset.zero,
      34,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: on
              ? [primary, const Color(0xFFD8402E)]
              : [Colors.white.withOpacity(0.22), Colors.white.withOpacity(0.12)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: 34)),
    );
    canvas.drawCircle(
      Offset.zero,
      34,
      Paint()
        ..color = Colors.white.withOpacity(on ? 0.35 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Segnalibro (forma standard)
    final bm = Path()
      ..moveTo(-10, -14)
      ..lineTo(10, -14)
      ..lineTo(10, 14)
      ..lineTo(0, 7)
      ..lineTo(-10, 14)
      ..close();
    canvas.drawPath(
      bm,
      _fill
        ..color = on
            ? Colors.white
            : Colors.white.withOpacity(0.55),
    );
    canvas.restore();

    // Spunta finale
    if (t > 0.85) {
      final checkT = Curves.easeOutBack.transform(_c01((t - 0.85) / 0.15));
      canvas.save();
      canvas.translate(c.dx + 34, c.dy - 30);
      canvas.scale(checkT);
      canvas.drawCircle(Offset.zero, 11, _fill..color = const Color(0xFF3DDC97));
      final tick = Paint()
        ..color = const Color(0xFF0B2E1F)
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(const Offset(-4.5, 0), const Offset(-1, 3.5), tick);
      canvas.drawLine(const Offset(-1, 3.5), const Offset(5, -4), tick);
      canvas.restore();
    }
  }

  bool get isDarkSafe => true;

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.t != t || old.scene != scene || old.primary != primary;
}

/// Overlay della scena "tempo reale": campanella che vibra quando arriva
/// la notifica + banner push che scende con molla iOS-style.
class _RealtimeOverlay extends StatelessWidget {
  final double t;
  const _RealtimeOverlay({required this.t});

  @override
  Widget build(BuildContext context) {
    // Due cicli di notifica per loop
    final c = (t * 2) % 1.0;
    final visible = c < 0.62;
    final inF = Curves.easeOutBack.transform(_c01(c / 0.16));
    final outF = Curves.easeIn.transform(_c01((c - 0.52) / 0.10));
    final y = -90 * (1 - inF) - 14 * outF;
    final opacity = visible ? (1 - outF) : 0.0;

    // Scuotimento della campanella solo all'arrivo del push
    final shakeWindow = _c01(c / 0.22);
    final shake = c < 0.22
        ? math.sin(shakeWindow * math.pi * 7) * (1 - shakeWindow) * 0.18
        : 0.0;

    return Stack(
      children: [
        Center(
          child: Transform.rotate(
            angle: shake,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                gradient: AppGradients.brandGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTokens.brandOrange.withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(0, y),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        gradient: AppGradients.brandGradient,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(Icons.train_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Aggiornamento viaggio',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15182B),
                              fontFamily: 'Syne',
                            ),
                          ),
                          SizedBox(height: 1),
                          Text(
                            'Il tuo treno viaggia con +8 min',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF5A6076),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'ora',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9AA0B4)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// HERO DELLA PAGINA DI BENVENUTO: rete di trasporto viva
// =============================================================================

class _HeroNetworkMap extends StatefulWidget {
  final bool active;
  const _HeroNetworkMap({required this.active});

  @override
  State<_HeroNetworkMap> createState() => _HeroNetworkMapState();
}

class _HeroNetworkMapState extends State<_HeroNetworkMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _HeroNetworkMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    widget.active ? _controller.repeat() : _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) =>
          CustomPaint(painter: _NetworkMapPainter(t: _controller.value)),
    );
  }
}

class _NetworkMapPainter extends CustomPainter {
  final double t;
  _NetworkMapPainter({required this.t});

  static const _nodes = [
    Offset(0.14, 0.70),
    Offset(0.30, 0.36),
    Offset(0.48, 0.54),
    Offset(0.66, 0.24),
    Offset(0.86, 0.48),
    Offset(0.40, 0.82),
    Offset(0.64, 0.76),
    Offset(0.18, 0.20),
    Offset(0.82, 0.14),
    Offset(0.90, 0.80),
  ];

  static const _edges = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [2, 5],
    [5, 6],
    [6, 4],
    [1, 7],
    [3, 8],
    [6, 9],
    [4, 9],
  ];

  static const _lineColors = [
    Color(0xFFFF7A3D), // arancio brand
    Color(0xFF3DDAD7), // teal
    Color(0xFFE85D9E), // rosa
    Color(0xFF6EA8FF), // blu
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Sfondo notturno con glow sfalsati
    final bg = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(
      bg,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFF151A38), Color(0xFF1E1540), Color(0xFF241A45)],
        ).createShader(bg),
    );

    // Bagliori ambientali che respirano
    for (final g in [
      [Offset(w * 0.2, h * 0.25), 0xFFFF7A3D, 0.20],
      [Offset(w * 0.85, h * 0.7), 0xFF3DDAD7, 0.16],
      [Offset(w * 0.55, h * 0.9), 0xFF7A5CFF, 0.14],
    ]) {
      canvas.drawCircle(
        g[0] as Offset,
        w * 0.5,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Color(g[1] as int).withOpacity((g[2] as double) * (0.8 + 0.2 * math.sin(t * math.pi * 2))),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: g[0] as Offset, radius: w * 0.5)),
      );
    }

    // Griglia puntinata
    final grid = Paint()..color = Colors.white.withOpacity(0.045);
    for (var y = 10.0; y < h; y += 20) {
      for (var x = 10.0; x < w; x += 20) {
        canvas.drawCircle(Offset(x, y), 1, grid);
      }
    }

    final pts = _nodes.map((n) => Offset(n.dx * w, n.dy * h)).toList();

    // Linee di rete curve
    for (var i = 0; i < _edges.length; i++) {
      final a = pts[_edges[i][0]], b = pts[_edges[i][1]];
      final mid = (a + b) / 2;
      final ctrl = mid + Offset(-(b.dy - a.dy), b.dx - a.dx) * 0.18;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = _lineColors[i % _lineColors.length].withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );

      // Impulsi che viaggiano sulla linea: un vero "treno" di dati
      final p = (t * 1.1 + i * 0.13) % 1.0;
      final pos = _quadAt(a, ctrl, b, p);
      final trail = Paint()
        ..color = _lineColors[i % _lineColors.length]
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(pos, 5.5, trail);
      canvas.drawCircle(pos, 3, Paint()..color = Colors.white);
      // scia
      final trailPos = _quadAt(a, ctrl, b, (p - 0.05 + 1) % 1.0);
      canvas.drawCircle(
          trailPos, 2, Paint()..color = _lineColors[i % _lineColors.length].withOpacity(0.6));
    }

    // Stazioni: nodi luminosi con alone pulsante
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i];
      final pulse = (t * 1.5 + i * 0.21) % 1.0;
      canvas.drawCircle(
        p,
        10 + pulse * 10,
        Paint()
          ..color = Colors.white.withOpacity(0.18 * (1 - pulse))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      canvas.drawCircle(
        p,
        5.5,
        Paint()
          ..color = Colors.white
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(p, 3.4, Paint()..color = Colors.white);
    }
  }

  Offset _quadAt(Offset a, Offset c, Offset b, double t) {
    final u = 1 - t;
    return Offset(
      u * u * a.dx + 2 * u * t * c.dx + t * t * b.dx,
      u * u * a.dy + 2 * u * t * c.dy + t * t * b.dy,
    );
  }

  @override
  bool shouldRepaint(covariant _NetworkMapPainter old) => old.t != t;
}

// =============================================================================
// SCHERMATA ONBOARDING
// =============================================================================

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _acceptedPrivacy = false;
  bool _acceptedEula = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static int get _totalPages => 2 + _onboardingFeatures.length;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeScreen(),
          transitionDuration: const Duration(milliseconds: 500),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    }
  }

  void _showPolicyDialog(String title, String content) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
        ),
        child: Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppGradients.brandGradient,
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Icon(
                      title.contains('EULA') ||
                              title.contains('Licenza') ||
                              title.contains('License') ||
                              title.contains('Lizenz')
                          ? Icons.gavel_rounded
                          : Icons.shield_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: _buildPolicyContent(theme, content),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  RuntimeLocalizations.t(context, 'close', fallback: 'Chiudi'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Testo con URL rilevati automaticamente e resi tappabili.
  TextSpan _linkifyText(String text, TextStyle style, Color linkColor) {
    final urlRegExp = RegExp(r'https?://[^\s)]+');
    final spans = <TextSpan>[];
    int start = 0;
    for (final match in urlRegExp.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: TextStyle(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri == null) return;
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {}
            },
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    return TextSpan(style: style, children: spans);
  }

  /// Renderizza il testo legale separando le sezioni (delimitate da righe
  /// di ━ nei testi) con veri separatori Flutter: titolo, Divider, corpo.
  Widget _buildPolicyContent(ThemeProvider theme, String content) {
    final bodyStyle = TextStyle(
      color: theme.textColor,
      fontSize: 13,
      height: 1.6,
    );
    final parts = content.split(RegExp(r'\n[━─=\-]{5,}\n'));
    if (parts.length < 3) {
      return RichText(
        text: _linkifyText(content, bodyStyle, theme.primaryColor),
      );
    }
    final widgets = <Widget>[
      RichText(
        textAlign: TextAlign.center,
        text: _linkifyText(
          parts[0].trim(),
          TextStyle(
            color: theme.textColor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            height: 1.5,
          ),
          theme.primaryColor,
        ),
      ),
    ];
    for (int i = 1; i < parts.length; i += 2) {
      final header = parts[i].trim();
      final body = (i + 1 < parts.length) ? parts[i + 1].trim() : '';
      widgets.addAll([
        const SizedBox(height: 14),
        Text(
          header,
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        Divider(
          color: theme.primaryColor.withOpacity(0.35),
          thickness: 1.5,
          height: 14,
        ),
        if (body.isNotEmpty)
          RichText(
            text: _linkifyText(body, bodyStyle, theme.primaryColor),
          ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final canProceed = _acceptedPrivacy && _acceptedEula;
    final isLast = _currentPage == _totalPages - 1;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              theme.primaryColor.withOpacity(theme.isDark ? 0.10 : 0.05),
              theme.backgroundColor,
              theme.surfaceColor.withOpacity(0.4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Pulsante salta (visibile finché non sei all'ultima pagina)
              if (!isLast)
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 6, 12, 0),
                    child: TextButton(
                      onPressed: () => _pageController.animateToPage(
                        _totalPages - 1,
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Text(
                        RuntimeLocalizations.t(context, 'skip',
                            fallback: 'Salta'),
                        style: TextStyle(
                          color: theme.secondaryTextColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  // Scorrimento a dito tra le slide con snap ed effetto molla;
                  // sull'ultima pagina nessuno scorrimento in avanti possibile:
                  // fisica rigida, lo swipe non muove nulla.
                  physics: _currentPage == _totalPages - 1
                      ? const ClampingScrollPhysics()
                      : const PageScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                  pageSnapping: true,
                  allowImplicitScrolling: true,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _buildWelcomePage(theme),
                    for (int i = 0; i < _onboardingFeatures.length; i++)
                      _buildFeaturePage(
                        theme,
                        _onboardingFeatures[i],
                        index: i,
                      ),
                    _buildPrivacyPage(theme),
                  ],
                ),
              ),
              _buildBottomNav(theme, isLast: isLast),
            ],
          ),
        ),
      ),
    );
  }

  // ===== PAGINA 1: Hero animato + benvenuto =====
  Widget _buildWelcomePage(ThemeProvider theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          // Rete di trasporto viva
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryColor.withOpacity(0.30),
                  blurRadius: 36,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
              child: _HeroNetworkMap(active: _currentPage == 0),
            ),
          ),
          const SizedBox(height: 28),
          ShaderMask(
            shaderCallback: (b) => AppGradients.brandGradient.createShader(b),
            child: Text(
              'BC.TRANSPORTER',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Syne',
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            RuntimeLocalizations.t(context, 'onboarding_welcome',
                fallback: 'Benvenuto in BC.TRANSPORTER'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            RuntimeLocalizations.t(context, 'onboarding_subtitle',
                fallback: 'Tutti i tuoi viaggi in un\u2019unica app.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: theme.secondaryTextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final m in [
                Icons.train_rounded,
                Icons.directions_bus_rounded,
                Icons.flight_rounded,
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.primaryColor.withOpacity(0.18),
                      ),
                    ),
                    child: Icon(m, size: 18, color: theme.primaryColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ===== PAGINE FUNZIONALITÀ =====
  Widget _buildFeaturePage(ThemeProvider theme, _OnboardingFeature feature,
      {required int index}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Card scena con bordo luminoso
              Container(
                height: 216,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: theme.primaryColor.withOpacity(0.28),
                      blurRadius: 30,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: _AnimatedScene(
                    index: index,
                    active: (_currentPage - (index + 1)).abs() <= 1,
                    theme: theme,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppGradients.brandGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(feature.icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      RuntimeLocalizations.t(context, feature.titleKey,
                          fallback: feature.titleFallback),
                      style: TextStyle(
                        fontFamily: 'Syne',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1} / ${_onboardingFeatures.length}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                RuntimeLocalizations.t(context, feature.descKey,
                    fallback: feature.descFallback),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: theme.secondaryTextColor,
                ),
              ),
              if (feature.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: feature.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(tag.icon,
                                    size: 14, color: theme.primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  RuntimeLocalizations.t(context, tag.key,
                                      fallback: tag.fallback),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ===== PAGINA FINALE: Privacy e termini =====
  Widget _buildPrivacyPage(ThemeProvider theme) {
    final canProceed = _acceptedPrivacy && _acceptedEula;

    final ppTitle = RuntimeLocalizations.t(context, 'onboarding_privacy_link',
        fallback: 'Privacy Policy');
    final ppText =
        RuntimeLocalizations.t(context, 'onboarding_privacy_text', fallback: '');
    final eulaTitle = RuntimeLocalizations.t(context, 'onboarding_eula_link',
        fallback: 'EULA');
    final eulaText =
        RuntimeLocalizations.t(context, 'onboarding_eula_text', fallback: '');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          _buildSectionHeader(
            theme,
            icon: Icons.shield_rounded,
            title: RuntimeLocalizations.t(
                context, 'onboarding_privacy_section',
                fallback: 'Privacy e termini'),
          ),
          const SizedBox(height: 12),
          Text(
            RuntimeLocalizations.t(context, 'onboarding_privacy_hint',
                fallback:
                    'Per continuare, leggi e accetta la Privacy Policy e i Termini di Licenza.'),
            style: TextStyle(
              fontSize: 13,
              color: theme.secondaryTextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTokens.radius2Xl),
              border: Border.all(
                color: theme.primaryColor.withOpacity(0.15),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildCheckboxTile(
                  prefix: RuntimeLocalizations.t(
                      context, 'onboarding_privacy_prefix',
                      fallback: 'Ho letto e accetto la '),
                  linkText: ppTitle,
                  value: _acceptedPrivacy,
                  onChanged: (val) =>
                      setState(() => _acceptedPrivacy = val ?? false),
                  onLinkTap: () => _showPolicyDialog(ppTitle, ppText),
                  theme: theme,
                ),
                Divider(
                    color: theme.primaryColor.withOpacity(0.1), height: 24),
                _buildCheckboxTile(
                  prefix: RuntimeLocalizations.t(
                      context, 'onboarding_eula_prefix',
                      fallback: "Ho letto e accetto l'"),
                  linkText: eulaTitle,
                  value: _acceptedEula,
                  onChanged: (val) =>
                      setState(() => _acceptedEula = val ?? false),
                  onLinkTap: () => _showPolicyDialog(eulaTitle, eulaText),
                  theme: theme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AnimatedOpacity(
            opacity: canProceed ? 1.0 : 0.45,
            duration: const Duration(milliseconds: 200),
            child: GestureDetector(
              onTap: canProceed ? _completeOnboarding : null,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  gradient: canProceed ? AppGradients.brandGradient : null,
                  color: canProceed
                      ? null
                      : theme.primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                  boxShadow: canProceed
                      ? [
                          BoxShadow(
                            color: AppTokens.brandOrange.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    RuntimeLocalizations.t(context, 'onboarding_start',
                        fallback: 'Inizia'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Syne',
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBottomNav(ThemeProvider theme, {required bool isLast}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: _currentPage > 0
                ? Container(
                    decoration: BoxDecoration(
                      color: theme.surfaceColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.secondaryTextColor.withOpacity(0.25),
                      ),
                    ),
                    child: IconButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      icon: Icon(Icons.arrow_back_rounded,
                          color: theme.textColor, size: 20),
                    ),
                  )
                : null,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _totalPages,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: i == _currentPage ? 22 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    gradient: i == _currentPage
                        ? AppGradients.brandGradient
                        : null,
                    color: i == _currentPage
                        ? null
                        : theme.secondaryTextColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 52,
            child: !isLast
                ? Container(
                    decoration: BoxDecoration(
                      gradient: AppGradients.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTokens.brandOrange.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: IconButton(
                      onPressed: () => _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 20),
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeProvider theme,
      {required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: theme.primaryColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxTile({
    required String prefix,
    required String linkText,
    required bool value,
    required ValueChanged<bool?> onChanged,
    required VoidCallback onLinkTap,
    required ThemeProvider theme,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.scale(
          scale: 1.1,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: theme.primaryColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            onTap: onLinkTap,
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                    color: theme.textColor, fontSize: 14, height: 1.4),
                children: [
                  TextSpan(text: prefix),
                  TextSpan(
                    text: linkText,
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                      decorationColor: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

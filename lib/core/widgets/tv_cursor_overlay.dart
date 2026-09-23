import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/tv_cursor_service.dart';

/// Contenitore radice: intercetta i tasti del telecomando e disegna
/// il cursore virtuale sopra l'app (Fire Stick / Google TV).
class TvRemoteHost extends StatelessWidget {
  final Widget? child;

  const TvRemoteHost({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final cursor = Provider.of<TvCursorService>(context, listen: false);
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final size = MediaQuery.sizeOf(node.context!);
        if (cursor.handleKey(event, size)) {
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Stack(
        children: [
          if (child != null) child!,
          // I comandi sotto, il cursore sempre sopra: solo lui li copre.
          const _TvScrollButtons(),
          const _TvCursor(),
        ],
      ),
    );
  }
}

class _TvCursor extends StatelessWidget {
  const _TvCursor();

  @override
  Widget build(BuildContext context) {
    return Consumer<TvCursorService>(
      builder: (context, cursor, _) {
        if (!cursor.visible) return const SizedBox.shrink();
        cursor.ensurePosition(MediaQuery.sizeOf(context));
        final dragging = cursor.dragging;
        final color = dragging
            ? Colors.orange
            : Theme.of(context).colorScheme.primary;
        // Solo layout: in landscape cursore leggermente più compatto.
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;
        final double diameter = isLandscape ? 28.0 : 32.0;
        final double dot = dragging ? (isLandscape ? 10.0 : 11.0) : (isLandscape ? 7.0 : 8.0);
        return Positioned(
          left: cursor.position.dx - diameter / 2,
          top: cursor.position.dy - diameter / 2,
          child: IgnorePointer(
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color,
                  width: dragging ? 4 : 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.45),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Observer che nasconde i gestori viewport a ogni cambio schermata
/// (push/pop/dialog): la scansione li rigenera per la nuova route.
class TvNavObserver extends NavigatorObserver {
  void _clear(NavigatorState? navigator) {
    try {
      final ctx = navigator?.context;
      if (ctx == null) return;
      Provider.of<TvCursorService>(ctx, listen: false).clearViewports();
    } catch (_) {}
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _clear(navigator);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _clear(navigator);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _clear(navigator);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    _clear(navigator);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

/// Frecce generate per OGNI oggetto scrollabile rilevato: mini controllo
/// su/giù sul bordo destro di ciascun viewport. Tappabili col cursore o al tocco.
class _TvScrollButtons extends StatelessWidget {
  const _TvScrollButtons();

  @override
  Widget build(BuildContext context) {
    return Consumer<TvCursorService>(
      builder: (context, cursor, _) {
        // Solo l'oggetto sotto il cursore ha le frecce (niente accatastamenti).
        final vp = cursor.viewportAtCursor();
        if (vp == null) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final screen = MediaQuery.sizeOf(context);
        final padding = MediaQuery.of(context).padding;
        final isLandscape = screen.width > screen.height;
        final double w = isLandscape ? 44 : 40;
        return _viewportArrows(scheme, screen, padding, vp, cursor, w, key: ValueKey('tv-vp-${vp.id}'));
      },
    );
  }

  Widget _viewportArrows(ColorScheme scheme, Size screen, EdgeInsets padding,
      ViewportInfo vp, TvCursorService cursor, double w, {Key? key}) {
    final r = vp.rect;
    // Solo layout landscape: rispetta safe-area e usa target compatti.
    final isLandscape = screen.width > screen.height;
    final double btnWidth = isLandscape ? 44.0 : w;
    // Bordo destro del viewport, centrato verticalmente, dentro lo schermo
    final double left = (r.right - btnWidth - 6)
        .clamp(4.0 + padding.left, screen.width - btnWidth - 4.0 - padding.right);
    final double top = (r.center.dy - 46)
        .clamp(4.0 + padding.top, (screen.height - 100.0 - padding.bottom).clamp(4.0, screen.height));
    Widget btn(IconData icon, double delta) {
      return Material(
        color: scheme.primaryContainer.withOpacity(0.92),
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => cursor.scrollViewport(vp, delta),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(icon, size: isLandscape ? 18 : 17, color: scheme.primary),
          ),
        ),
      );
    }

    const gap = TvCursorService.scrollStep * 3;
    final bool horizontal = vp.axis == Axis.horizontal;
    // In landscape con viewport orizzontale: frecce affiancate per non rubare altezza.
    return Positioned(
      key: key,
      left: left,
      top: top,
      width: horizontal && isLandscape ? btnWidth * 2 + 4 : btnWidth,
      child: horizontal && isLandscape
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                btn(Icons.keyboard_arrow_left_rounded, -gap),
                const SizedBox(width: 4),
                btn(Icons.keyboard_arrow_right_rounded, gap),
              ],
            )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: horizontal
            ? [
                btn(Icons.keyboard_arrow_left_rounded, -gap),
                const SizedBox(height: 4),
                btn(Icons.keyboard_arrow_right_rounded, gap),
              ]
            : [
                btn(Icons.keyboard_arrow_up_rounded, -gap),
                const SizedBox(height: 4),
                btn(Icons.keyboard_arrow_down_rounded, gap),
              ],
      ),
    );
  }
}

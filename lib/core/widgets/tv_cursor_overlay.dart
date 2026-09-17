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
        return Positioned(
          left: cursor.position.dx - 22,
          top: cursor.position.dy - 22,
          child: IgnorePointer(
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
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
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
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

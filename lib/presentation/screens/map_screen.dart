import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:provider/provider.dart';
import '../providers/map_state_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/map_widget.dart';
import '../../core/design_system.dart';

class MapScreen extends StatelessWidget {
  final int? initialCategory;
  final bool showBackButton;

  const MapScreen({
    super.key,
    this.initialCategory,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    // Set initial category if provided
    if (initialCategory != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<MapStateProvider>(context, listen: false).setCategory(initialCategory!);
      });
    }

    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape =
                orientation == Orientation.landscape;
            final padding = MediaQuery.of(context).padding;
            // In landscape l'altezza utile è ridotta: margini più compatti
            // e rispetto di notch/safe area laterali.
            final top = padding.top + (isLandscape ? 6 : 10);
            final left = (isLandscape ? padding.left + 12 : 16.0);
            return Stack(
              children: [
                const MapWidget(),
                if (showBackButton)
                  Positioned(
                    top: top,
                    left: left,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: GlassmorphicContainer(
                        width: 50,
                        height: 50,
                        borderRadius: 25,
                        blur: 20,
                        alignment: Alignment.center,
                        border: 2,
                        linearGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            theme.surfaceColor.withOpacity(0.6),
                            theme.surfaceColor.withOpacity(0.4),
                          ],
                        ),
                        borderGradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.3),
                            Colors.white.withOpacity(0.1),
                          ],
                        ),
                        child: Icon(Icons.arrow_back, color: theme.textColor),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

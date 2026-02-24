import 'package:flutter/material.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:provider/provider.dart';
import '../providers/map_state_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/map_widget.dart';

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
      body: Stack(
        children: [
          const MapWidget(),
          if (showBackButton)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
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
      ),
    );
  }
}

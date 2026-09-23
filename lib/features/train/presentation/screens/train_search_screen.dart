import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'train_tabs_screen.dart';
import '../../../../presentation/providers/theme_provider.dart';

class TrainSearchScreen extends StatelessWidget {
  const TrainSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        left: false,
        right: false,
        child: OrientationBuilder(
          builder: (context, orientation) {
            // Landscape: vincola la larghezza e sfrutta le safe area laterali.
            if (orientation != Orientation.landscape) {
              return const SafeArea(
                top: false,
                child: TrainTabsScreen(),
              );
            }
            final sidePadding = MediaQuery.of(context).padding;
            return Padding(
              padding: EdgeInsets.only(
                left: sidePadding.left > 0 ? sidePadding.left : 24,
                right: sidePadding.right > 0 ? sidePadding.right : 24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: const SafeArea(
                    top: false,
                    left: false,
                    right: false,
                    child: TrainTabsScreen(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

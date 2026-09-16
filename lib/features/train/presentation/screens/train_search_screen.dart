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
      body: const SafeArea(
        child: TrainTabsScreen(),
      ),
    );
  }
}

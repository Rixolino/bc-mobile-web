import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/train_panel_content.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../core/utils/navigation_helper.dart';

class TrainSearchScreen extends StatelessWidget {
  const TrainSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      // no AppBar: full-screen train search
      body: SafeArea(
        child: Stack(
          children: [
            const TrainPanelContent(),
            // keep map button floating at top-right
            
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/train_panel_content.dart';
import '../../../../presentation/providers/theme_provider.dart';

class TrainSearchScreen extends StatelessWidget {
  const TrainSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.primaryColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Ricerca Treni", 
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: TrainPanelContent(),
      ),
    );
  }
}

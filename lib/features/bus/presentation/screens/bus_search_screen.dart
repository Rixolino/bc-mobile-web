import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/bus_panel_content.dart';
import '../../../../presentation/providers/theme_provider.dart';

class BusSearchScreen extends StatelessWidget {
  const BusSearchScreen({super.key});

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
          "Ricerca Bus", 
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: const SafeArea(
        child: BusPanelContent(),
      ),
    );
  }
}

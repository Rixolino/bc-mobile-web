import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/bus_panel_content.dart';
import '../providers/bus_provider.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../../../../presentation/screens/map_screen.dart';
import '../../../../core/utils/navigation_helper.dart';

class BusSearchScreen extends StatelessWidget {
  const BusSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final busProvider = Provider.of<BusProvider>(context, listen: false);
    
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: theme.surfaceColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Ricerca Bus", 
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.map, color: theme.primaryColor),
            onPressed: () async {
              // Carica i dati dei bus e le fermate in tempo reale
              await busProvider.fetchVehicles();
              await busProvider.fetchStops();
              // Apri la mappa con categoria Bus
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapScreen(initialCategory: 1)));
            },
            tooltip: 'Vai alla mappa',
          ),
        ],
      ),
      body: const SafeArea(
        child: BusPanelContent(),
      ),
    );
  }
}


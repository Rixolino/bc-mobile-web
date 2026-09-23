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
    // Landscape: contenuto centrato a larghezza vincolata (il pannello
    // interno compone già controlli/risultati affiancati).
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      // no AppBar, map button as FAB
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isLandscape ? 1100 : 640),
            child: const BusPanelContent(),
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: isLandscape ? 16.0 : 90.0),
        child: FloatingActionButton(
          backgroundColor: theme.primaryColor,
          child: Icon(Icons.map, color: Colors.white),
          onPressed: () async {
            await busProvider.fetchVehicles();
            await busProvider.fetchStops();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapScreen(initialCategory: 1)));
          },
          tooltip: 'Vai alla mappa',
        ),
      ),
    );
  }
}


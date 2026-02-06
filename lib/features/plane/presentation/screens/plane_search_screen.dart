import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/plane_panel_content.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../providers/plane_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';

class PlaneSearchScreen extends StatelessWidget {
  const PlaneSearchScreen({super.key});

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
          "Ricerca Voli", 
          style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: PlanePanelContent(
          onRefresh: () {
            final planeProvider = Provider.of<PlaneProvider>(context, listen: false);
            final mapState = Provider.of<MapStateProvider>(context, listen: false);
            // Scansiona l'area visibile sulla mappa
            planeProvider.scanAreaForFlights(mapState.lat, mapState.lng, mapState.zoom);
          },
        ),
      ),
    );
  }
}

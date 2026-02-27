import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/plane_panel_content.dart';
import '../../../../presentation/providers/theme_provider.dart';
import '../providers/plane_provider.dart';
import '../../../../presentation/providers/map_state_provider.dart';
import '../../../../core/utils/navigation_helper.dart';

class PlaneSearchScreen extends StatelessWidget {
  const PlaneSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      // no AppBar, map access via FAB
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          backgroundColor: theme.primaryColor,
          child: Icon(Icons.map, color: Colors.white),
          onPressed: () => context.navigateToPlane(),
          tooltip: 'Vai alla mappa',
        ),
      ),
    );
  }
}

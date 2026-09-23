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
    // Solo layout responsive: in landscape centra e vincola la larghezza
    // per sfruttare lo spazio orizzontale ed evitare stretch/overflow.
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      // no AppBar, map access via FAB
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            final isLandscape = orientation == Orientation.landscape;
            if (!isLandscape) {
              return PlanePanelContent(
                onRefresh: () {
                  final planeProvider =
                      Provider.of<PlaneProvider>(context, listen: false);
                  final mapState =
                      Provider.of<MapStateProvider>(context, listen: false);
                  // Scansiona l'area visibile sulla mappa
                  planeProvider.scanAreaForFlights(
                      mapState.lat, mapState.lng, mapState.zoom);
                },
              );
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: PlanePanelContent(
                    onRefresh: () {
                      final planeProvider =
                          Provider.of<PlaneProvider>(context, listen: false);
                      final mapState = Provider.of<MapStateProvider>(
                          context,
                          listen: false);
                      // Scansiona l'area visibile sulla mappa
                      planeProvider.scanAreaForFlights(
                          mapState.lat, mapState.lng, mapState.zoom);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLandscape ? 16.0 : 90.0,
              right: isLandscape ? 16.0 : 0.0,
            ),
            child: FloatingActionButton(
              backgroundColor: theme.primaryColor,
              child: Icon(Icons.map, color: Colors.white),
              onPressed: () => context.navigateToPlane(),
              tooltip: 'Vai alla mappa',
            ),
          );
        },
      ),
    );
  }
}

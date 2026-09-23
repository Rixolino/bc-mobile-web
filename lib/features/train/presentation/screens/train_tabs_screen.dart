import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/runtime_localizations.dart';
import '../widgets/train_panel_content.dart';
import 'regional_providers_screen.dart';

class TrainTabsScreen extends StatefulWidget {
  const TrainTabsScreen({super.key});

  @override
  State<TrainTabsScreen> createState() => _TrainTabsScreenState();
}

class _TrainTabsScreenState extends State<TrainTabsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _country = 'IT';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCountry();
  }

  Future<void> _loadCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString('selected_country') ?? 'IT';
    if (mounted) {
      setState(() {
        _country = country;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = (String key) => RuntimeLocalizations.t(context, key);

    return Scaffold(
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            // Landscape: contenuti vincolati in larghezza e padding ariosi.
            final isLandscape = orientation == Orientation.landscape;
            final body = Column(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 32 : 16,
                    vertical: isLandscape ? 4 : 8,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 640 : double.infinity,
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: theme.colorScheme.primary,
                        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                        indicatorColor: theme.colorScheme.primary,
                        indicatorSize: TabBarIndicatorSize.label,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        tabs: [
                          Tab(text: t('tab_national')),
                          Tab(text: t('tab_regionale')),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isLandscape ? 1100 : double.infinity,
                      ),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          const TrainPanelContent(),
                          RegionalProvidersScreen(country: _country),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
            if (!isLandscape) return body;
            // Safe area laterali (notch) in orizzontale.
            final sidePadding = MediaQuery.of(context).padding;
            return Padding(
              padding: EdgeInsets.only(
                left: sidePadding.left > 0 ? 0 : 12,
                right: sidePadding.right > 0 ? 0 : 12,
              ),
              child: body,
            );
          },
        ),
      ),
    );
  }
}

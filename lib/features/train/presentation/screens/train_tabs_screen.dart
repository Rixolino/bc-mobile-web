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
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const TrainPanelContent(),
                  RegionalProvidersScreen(country: _country),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

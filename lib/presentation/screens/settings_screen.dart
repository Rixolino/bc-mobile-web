import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Provider.of<ThemeProvider>(context).textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Impostazioni',
          style: TextStyle(color: Provider.of<ThemeProvider>(context).textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer2<SettingsProvider, ThemeProvider>(
        builder: (context, settings, theme, child) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionTitle('Tema', theme),
              const SizedBox(height: 16),
              
              _buildThemeSelector(context, settings, theme).animate().fadeIn().slideX(),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('Aggiornamento Automatico', theme),
              const SizedBox(height: 16),
              
              _buildRefreshSlider(
                context, 
                'Treni', 
                Icons.train, 
                settings.trainRefreshSeconds,
                (val) => settings.setTrainRefreshSeconds(val.toInt()),
                theme
              ).animate().fadeIn(delay: 100.ms).slideX(),

              const SizedBox(height: 24),
              
              _buildRefreshSlider(
                context, 
                'Autobus', 
                Icons.directions_bus, 
                settings.busRefreshSeconds,
                (val) => settings.setBusRefreshSeconds(val.toInt()),
                theme
              ).animate().fadeIn(delay: 200.ms).slideX(),

              const SizedBox(height: 24),
              
              _buildRefreshSlider(
                context, 
                'Aerei', 
                Icons.flight, 
                settings.planeRefreshSeconds,
                (val) => settings.setPlaneRefreshSeconds(val.toInt()),
                theme
              ).animate().fadeIn(delay: 300.ms).slideX(),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Mappa', theme),
              const SizedBox(height: 16),
              
              _buildClusteringToggle(context, settings, theme).animate().fadeIn(delay: 400.ms).slideX(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeProvider theme) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: theme.secondaryTextColor.withOpacity(0.5),
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildThemeSelector(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.palette, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Tema',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildThemeOption(context, 'Chiaro', Icons.light_mode, ThemeMode.light, settings, theme),
              const SizedBox(width: 12),
              _buildThemeOption(context, 'Scuro', Icons.dark_mode, ThemeMode.dark, settings, theme),
              const SizedBox(width: 12),
              _buildThemeOption(context, 'Sistema', Icons.smartphone, ThemeMode.system, settings, theme),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, IconData icon, ThemeMode mode, SettingsProvider settings, ThemeProvider theme) {
    final isSelected = settings.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withOpacity(0.2) : theme.surfaceColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.primaryColor : theme.secondaryTextColor, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshSlider(
    BuildContext context, 
    String label, 
    IconData icon, 
    int currentValue, 
    Function(double) onChanged,
    ThemeProvider theme
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: currentValue > 0 ? theme.primaryColor.withOpacity(0.2) : theme.secondaryTextColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  currentValue > 0 ? '${currentValue}s' : 'Off',
                  style: TextStyle(
                    color: currentValue > 0 ? theme.primaryColor : theme.secondaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.primaryColor,
              inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.1),
              thumbColor: theme.textColor,
              overlayColor: theme.primaryColor.withOpacity(0.2),
              trackHeight: 4.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
            ),
            child: Slider(
              value: currentValue.toDouble(),
              min: 0,
              max: 300,
              divisions: 60, // 0, 5, 10... 300
              label: currentValue > 0 ? '$currentValue sec' : 'Disabilitato',
              onChanged: onChanged,
            ),
          ),
          Padding(
             padding: const EdgeInsets.symmetric(horizontal: 4),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text('Off', style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.3), fontSize: 10)),
                 Text('5m', style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.3), fontSize: 10)),
               ],
             ),
          )
        ],
      ),
    );
  }

  Widget _buildClusteringToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group_work, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Clustering Autobus',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Switch(
                value: settings.busClusteringEnabled,
                onChanged: (value) => settings.setBusClusteringEnabled(value),
                activeColor: theme.primaryColor,
                activeTrackColor: theme.primaryColor.withOpacity(0.3),
                inactiveThumbColor: theme.secondaryTextColor,
                inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Raggruppa gli autobus vicini in cluster per una visualizzazione più chiara',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

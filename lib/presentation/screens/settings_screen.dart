import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../../features/bus/presentation/providers/bus_provider.dart';
import '../../features/train/presentation/providers/train_provider.dart';
import '../../core/services/android_background_service.dart';
import '../../core/notification_channels.dart';

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
      body: Consumer3<SettingsProvider, ThemeProvider, BusProvider>(
        builder: (context, settings, theme, busProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSectionTitle('Tema', theme),
              const SizedBox(height: 16),
              
              _buildThemeSelector(context, settings, theme),
              
              const SizedBox(height: 32),
              
              _buildSectionTitle('Aggiornamento Automatico', theme),
              const SizedBox(height: 16),
              
              _buildRefreshSlider(
                context, 
                'Treni', 
                Icons.train, 
                settings.isTrainAuto ? settings.currentAutoTrainRate : settings.trainRefreshSeconds,
                (val) => settings.setTrainRefreshSeconds(val.toInt()),
                theme,
                isAuto: settings.isTrainAuto,
                autoRate: settings.currentAutoTrainRate,
                onAutoChanged: (isOn) => settings.setTrainRefreshSeconds(isOn ? SettingsProvider.AUTO_REFRESH : 15)
              ),

              const SizedBox(height: 24),
              
              _buildRefreshSlider(
                context, 
                'Autobus', 
                Icons.directions_bus, 
                settings.isBusAuto ? settings.currentAutoBusRate : settings.busRefreshSeconds,
                (val) => settings.setBusRefreshSeconds(val.toInt()),
                theme,
                isAuto: settings.isBusAuto,
                autoRate: settings.currentAutoBusRate,
                onAutoChanged: (isOn) => settings.setBusRefreshSeconds(isOn ? SettingsProvider.AUTO_REFRESH : 10)
              ),

              const SizedBox(height: 24),
              
              _buildRefreshSlider(
                context, 
                'Aerei', 
                Icons.flight, 
                settings.isPlaneAuto ? settings.currentAutoPlaneRate : settings.planeRefreshSeconds,
                (val) => settings.setPlaneRefreshSeconds(val.toInt()),
                theme,
                isAuto: settings.isPlaneAuto,
                autoRate: settings.currentAutoPlaneRate,
                onAutoChanged: (isOn) => settings.setPlaneRefreshSeconds(isOn ? SettingsProvider.AUTO_REFRESH : 15)
              ),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Configurazione', theme),
              const SizedBox(height: 16),
              
              _buildConfigUpdateSection(context, busProvider, theme),

              const SizedBox(height: 32),

              _buildSectionTitle('Test Notifiche', theme),
              const SizedBox(height: 16),
              _buildBackgroundNotificationControls(context, settings, theme),

              const SizedBox(height: 16),
              _buildTrainProximityNotice(context, settings, theme),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Experience UI', theme),
              const SizedBox(height: 16),
              
              _buildVectorLogosToggle(context, settings, theme),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Mappa', theme),
              const SizedBox(height: 16),
              
              _buildClusteringToggle(context, settings, theme),

              const SizedBox(height: 16),

              _buildStopsClusteringToggle(context, settings, theme),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Stile Mappa', theme),
              const SizedBox(height: 16),
              
              _buildMapStyleSelector(context, settings, theme),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Sincronizzazione Offline', theme),
              const SizedBox(height: 16),
              
              _buildOfflineSyncToggle(context, settings, theme),

              const SizedBox(height: 32),
              
              _buildSectionTitle('Informazioni e Disclaimer', theme),
              const SizedBox(height: 16),
              
              _buildDisclaimerSection(context, theme),

              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapStyleSelector(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
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
              Icon(Icons.map, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Stile Mappa',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Scrollable row for styles
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Mapbox built-in styles (URLs). The stored setting contains the
                // full URL so we can also support custom ones in the future.
                _buildMapStyleOption(context, 'Scuro', 'mapbox://styles/mapbox/dark-v11', Icons.nightlight_round, settings, theme),
                _buildMapStyleOption(context, 'Chiaro', 'mapbox://styles/mapbox/light-v11', Icons.wb_sunny_outlined, settings, theme),
                _buildMapStyleOption(context, 'Strade', 'mapbox://styles/mapbox/streets-v11', Icons.map_outlined, settings, theme),
                _buildMapStyleOption(context, 'Satellite', 'mapbox://styles/mapbox/satellite-v9', Icons.satellite, settings, theme),
                _buildMapStyleOption(context, 'Sat+Str', 'mapbox://styles/mapbox/satellite-streets-v11', Icons.satellite_outlined, settings, theme),

                // custom URL picker
                GestureDetector(
                  onTap: () => _showCustomStyleDialog(context, settings, theme),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: theme.surfaceColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.edit, color: theme.secondaryTextColor, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Altro',
                          style: TextStyle(
                            color: theme.secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapStyleOption(BuildContext context, String label, String value, IconData icon, SettingsProvider settings, ThemeProvider theme) {
    final isSelected = settings.mapStyle == value;
    return GestureDetector(
      onTap: () => settings.setMapStyle(value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
    );
  }

  // Show a dialog allowing the user to paste or type a custom Mapbox style URL
  void _showCustomStyleDialog(BuildContext ctx, SettingsProvider settings, ThemeProvider theme) {
    final controller = TextEditingController(text: settings.mapStyle);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text('URL stile personalizzato', style: TextStyle(color: theme.textColor)),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'mapbox://styles/…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                settings.setMapStyle(val);
              }
              Navigator.pop(ctx);
            },
            child: Text('Salva'),
          ),
        ],
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
    ThemeProvider theme,
    {
      required bool isAuto,
      required Function(bool) onAutoChanged,
      required int autoRate
    }
  ) {
    // If enabled (manual mode > 0) or auto mode is on
    final bool isEnabled = isAuto || currentValue > 0;
    
    // Display string: "Auto (15s)" or "15s" or "Off"
    String statusText;
    if (isAuto) {
      statusText = 'Auto (${autoRate}s)';
    } else {
      statusText = currentValue > 0 ? '${currentValue}s' : 'Off';
    }

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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (isAuto)
                      Text(
                        'Gestito dal server in base al traffico',
                        style: TextStyle(color: theme.secondaryTextColor, fontSize: 10),
                      ),
                  ],
                ),
              ),
              // Auto Switch
              Row(
                children: [
                  Text('Auto', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isAuto,
                      onChanged: onAutoChanged,
                      activeColor: theme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Slider is only active if NOT in auto mode
          IgnorePointer(
            ignoring: isAuto,
            child: Opacity(
              opacity: isAuto ? 0.5 : 1.0,
              child: Column(
                children: [
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
                      value: isAuto ? autoRate.toDouble() : currentValue.toDouble(),
                      min: 0,
                      max: 60, // Reduced max to 60s for better usability
                      divisions: 12, // 5s steps
                      label: statusText,
                      onChanged: onChanged,
                    ),
                  ),
                  Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 4),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('Off', style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.3), fontSize: 10)),
                         Text(statusText, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 12)),
                         Text('60s', style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.3), fontSize: 10)),
                       ],
                     ),
                  )
                ],
              ),
            ),
          ),
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

  Widget _buildStopsClusteringToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
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
              Icon(Icons.location_on, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Clustering Fermate',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Switch(
                value: settings.stopsClusteringEnabled,
                onChanged: (value) => settings.setStopsClusteringEnabled(value),
                activeColor: theme.primaryColor,
                activeTrackColor: theme.primaryColor.withOpacity(0.3),
                inactiveThumbColor: theme.secondaryTextColor,
                inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Raggruppa le fermate vicine in cluster per una visualizzazione più chiara',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundNotificationControls(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    // Simplified: remove toggles that enable/cancel background workers. Keep config and Test buttons.
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
              Icon(Icons.notifications_active, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Test Notifiche',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Treni - only config and test
          Row(
            children: [
              Expanded(child: Text('Treni', style: TextStyle(color: theme.textColor))),
              IconButton(
                icon: Icon(Icons.settings, color: theme.secondaryTextColor),
                onPressed: () => _showTrainConfigDialog(context, settings),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await AndroidBackgroundService.showNotification(channel: NotificationChannels.trains, title: 'Test Treni', body: 'Questo è un test notifica treni');
                },
                child: const Text('Test'),
              )
            ],
          ),

          if (settings.trainStationId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Stazione: ${settings.trainStationId} · Servizio: ${settings.trainService}', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
            ),

          const SizedBox(height: 8),

          // Autobus - only config and test
          Row(
            children: [
              Expanded(child: Text('Autobus', style: TextStyle(color: theme.textColor))),
              IconButton(
                icon: Icon(Icons.settings, color: theme.secondaryTextColor),
                onPressed: () => _showBusConfigDialog(context, settings),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await AndroidBackgroundService.showNotification(channel: NotificationChannels.buses, title: 'Test Bus', body: 'Questo è un test notifica bus');
                },
                child: const Text('Test'),
              )
            ],
          ),

          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Provider: ${settings.busProvider} · Base URL: ${settings.busBaseUrl}', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
          ),

          const SizedBox(height: 8),

          // Funzioni - test only
          Row(
            children: [
              Expanded(child: Text('Funzioni', style: TextStyle(color: theme.textColor))),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await AndroidBackgroundService.showNotification(channel: NotificationChannels.functions, title: 'Test Funzioni', body: 'Questo è un test notifica funzioni');
                },
                child: const Text('Test'),
              )
            ],
          ),
        ],
      ),
    );
  }


  void _showTrainConfigDialog(BuildContext context, SettingsProvider settings) {
    final stationController = TextEditingController(text: settings.trainStationId);
    String selectedService = settings.trainService;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Configura notifiche treni'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stationController,
                decoration: const InputDecoration(labelText: 'Station ID (es. S01700)'),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedService,
                items: const [
                  DropdownMenuItem(value: 'trainboardeu', child: Text('Trainboard (prod)')),
                  DropdownMenuItem(value: 'direct', child: Text('Direct (RFI)')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    selectedService = v;
                  }
                },
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                await settings.setTrainStationId(stationController.text.trim());
                await settings.setTrainService(selectedService);
                Navigator.of(ctx).pop();
                if (settings.trainsWorkerEnabled) {
                  await AndroidBackgroundService.scheduleTrainsWorker(
                    stationId: settings.trainStationId.isNotEmpty ? settings.trainStationId : null,
                    service: settings.trainService,
                    enableNotifications: true,
                  );
                }
              },
              child: const Text('Salva'),
            )
          ],
        );
      },
    );
  }
  Widget _buildTrainProximityNotice(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    final int current = settings.trainArrivalPreNoticeMinutes;
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(Icons.notifications_active, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text('Preavviso arrivo stazione', style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$current min', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: current.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            label: '$current min',
            onChanged: (v) => settings.setTrainArrivalPreNoticeMinutes(v.toInt()),
            activeColor: theme.primaryColor,
          ),
          const SizedBox(height: 6),
          Text('Ricevi un avviso N minuti prima dell\'arrivo stimato alla tua fermata (5–20 minuti).', style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVectorLogosToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
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
              Icon(Icons.style, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Loghi Treni Vettoriali',
                  style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              Switch(
                value: settings.vectorLogosEnabled,
                onChanged: (value) async {
                  await settings.setVectorLogosEnabled(value);
                  if (value && context.mounted) {
                     // Trigger download if enabled
                     try {
                       Provider.of<TrainProvider>(context, listen: false).loadTrainLogos();
                     } catch (_) {}
                  }
                },
                activeColor: theme.primaryColor,
                activeTrackColor: theme.primaryColor.withOpacity(0.3),
                inactiveThumbColor: theme.secondaryTextColor,
                inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scarica e visualizza loghi ufficiali per le categorie dei treni (es. Frecciarossa, Intercity) invece del testo semplice.',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  void _showBusConfigDialog(BuildContext context, SettingsProvider settings) {
    final providerController = TextEditingController(text: settings.busProvider);
    final baseController = TextEditingController(text: settings.busBaseUrl);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Configura notifiche autobus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerController,
                decoration: const InputDecoration(labelText: 'Provider (es. bari)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: baseController,
                decoration: const InputDecoration(labelText: 'Base URL (opzionale)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
            ElevatedButton(
              onPressed: () async {
                await settings.setBusProvider(providerController.text.trim());
                await settings.setBusBaseUrl(baseController.text.trim());
                Navigator.of(ctx).pop();
                if (settings.busesWorkerEnabled) {
                  await AndroidBackgroundService.scheduleBusesWorker(
                    provider: settings.busProvider,
                    baseUrl: settings.busBaseUrl,
                    enableNotifications: true,
                  );
                }
              },
              child: const Text('Salva'),
            )
          ],
        );
      },
    );
  }

  Widget _buildConfigUpdateSection(BuildContext context, BusProvider busProvider, ThemeProvider theme) {
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
              Icon(Icons.cloud_download, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Aggiorna Configurazione',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (busProvider.isUpdatingConfig)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor),
                  ),
                )
              else
                IconButton(
                  onPressed: () async {
                    await busProvider.updateConfiguration();
                    if (busProvider.configUpdateError != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(busProvider.configUpdateError!),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else if (busProvider.configUpdateError == null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Configurazione aggiornata con successo'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: Icon(Icons.refresh, color: theme.primaryColor),
                  tooltip: 'Aggiorna configurazione provider',
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Scarica l\'ultima configurazione dei provider di autobus dal server',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
          if (busProvider.configUpdateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                busProvider.configUpdateError!,
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfflineSyncToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
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
              Icon(Icons.cloud_download, color: theme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Sincronizzazione Offline',
                          style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.primaryColor.withOpacity(0.2),
                            border: Border.all(color: theme.primaryColor, width: 1.5),
                          ),
                          child: Text(
                            'BETA',
                            style: TextStyle(
                              color: theme.primaryColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.offlineSyncEnabled,
                onChanged: (value) => settings.setOfflineSyncEnabled(value),
                activeColor: theme.primaryColor,
                activeTrackColor: theme.primaryColor.withOpacity(0.3),
                inactiveThumbColor: theme.secondaryTextColor,
                inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Scarica automaticamente i dati di percorsi e orari quando sincronizzi da una città. I dati verranno salvati localmente e disponibili anche senza connessione.',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerSection(BuildContext context, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Informazioni Importanti',
                style: TextStyle(
                  color: theme.textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'BC Transporter Non Sostituisce i Canali Ufficiali',
            style: TextStyle(
              color: Colors.orange,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Questa applicazione non intende in alcun modo sostituire le piattaforme ufficiali delle compagnie ferroviarie o i loro canali di vendita. BC Transporter fornisce informazioni e dati di tracciamento a scopo puramente informativo.\n\n'
            'Per l\'acquisto dei biglietti e per verificare disponibilità, tariffe, condizioni di viaggio e conferme ufficiali, è necessario rivolgersi esclusivamente ai canali ufficiali delle compagnie ferroviarie (siti web, app ufficiali, agenzie autorizzate o rivenditori certificati).\n\n'
            'I biglietti devono essere acquistati tramite le piattaforme ufficiali; BC Transporter non vende biglietti e non sostituisce i canali ufficiali di vendita.\n\n'
            'Non ci assumiamo responsabilità per acquisti effettuati su canali non ufficiali o per informazioni di prezzo/condizioni non aggiornate. Eventuali link a siti di terze parti sono forniti a scopo di comodità e non implicano approvazione o partnership.',
            style: TextStyle(
              color: theme.secondaryTextColor,
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}


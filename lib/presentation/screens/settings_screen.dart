import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/theme_provider.dart';
import '../../features/bus/presentation/providers/bus_provider.dart';
import '../../features/train/presentation/providers/train_provider.dart';
import '../../core/services/android_background_service.dart';
import '../../core/notification_channels.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';
import '../../core/services/runtime_localizations.dart';
import 'dart:ui';
import '../../features/train/presentation/widgets/railway_station_stats_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Provider.of<ThemeProvider>(context).backgroundColor,
      body: Consumer3<SettingsProvider, ThemeProvider, BusProvider>(
        builder: (context, settings, theme, busProvider, child) {
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, theme),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSettingsHeader(context, settings, theme),
                    const SizedBox(height: 32),
                    
                    // SEZIONE: PREFERENZE DI SISTEMA
                    _buildSectionCard(
                      context,
                      theme,
                      title: RuntimeLocalizations.t(context, 'settings_system', fallback: 'Sistema'),
                      icon: Icons.tune_rounded,
                      children: [
                        _buildLanguageTile(context, settings, theme),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, thickness: 1),
                        ),
                        _buildThemeSelector(context, settings, theme),
                      ],
                    ),

                    // SEZIONE: SINCRONIZZAZIONE E DATI
                    _buildSectionCard(
                      context,
                      theme,
                      title: RuntimeLocalizations.t(context, 'settings_sync', fallback: 'Sincronizzazione'),
                      icon: Icons.sync_rounded,
                      children: [
                        _buildRefreshSlider(
                            context,
                            AppLocalizations.of(context)?.trains ?? 'Treni',
                            Icons.train_rounded,
                            settings.isTrainAuto ? settings.currentAutoTrainRate : settings.trainRefreshSeconds,
                            (val) => settings.setTrainRefreshSeconds(val.toInt()),
                            theme,
                            isAuto: settings.isTrainAuto,
                            autoRate: settings.currentAutoTrainRate,
                            onAutoChanged: (isOn) => settings.setTrainRefreshSeconds(isOn ? SettingsProvider.AUTO_REFRESH : 15)),
                        const SizedBox(height: 24),
                        _buildRefreshSlider(
                            context,
                            AppLocalizations.of(context)?.buses ?? 'Autobus',
                            Icons.directions_bus_rounded,
                            settings.isBusAuto ? settings.currentAutoBusRate : settings.busRefreshSeconds,
                            (val) => settings.setBusRefreshSeconds(val.toInt()),
                            theme,
                            isAuto: settings.isBusAuto,
                            autoRate: settings.currentAutoBusRate,
                            onAutoChanged: (isOn) => settings.setBusRefreshSeconds(isOn ? SettingsProvider.AUTO_REFRESH : 10)),
                        const SizedBox(height: 24),
                        _buildRefreshSlider(
                            context,
                            AppLocalizations.of(context)?.planes ?? 'Aerei',
                            Icons.flight_rounded,
                            settings.isPlaneAuto ? settings.currentAutoPlaneRate : settings.planeRefreshSeconds,
                            (val) => settings.setPlaneRefreshSeconds(val.toInt()),
                            theme,
                            isAuto: settings.isPlaneAuto,
                            autoRate: settings.currentAutoPlaneRate,
                            onAutoChanged: (isOn) => settings.setPlaneRefreshSeconds(isOn ? SettingsProvider.AUTO_REFRESH : 15)),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Divider(height: 1, thickness: 1),
                        ),
                        _buildConfigUpdateSection(context, busProvider, theme),
                        const SizedBox(height: 16),
                        _buildOfflineSyncToggle(context, settings, theme),
                      ],
                    ),

                    // SEZIONE: NOTIFICHE
                    _buildSectionCard(
                      context,
                      theme,
                      title: RuntimeLocalizations.t(context, 'settings_notifications'),
                      icon: Icons.notifications_active_rounded,
                      children: [
                        _buildBackgroundNotificationControls(context, settings, theme),
                        const SizedBox(height: 16),
                        _buildTrainProximityNotice(context, settings, theme),
                      ],
                    ),

                    // SEZIONE: MAPPA E INTERFACCIA
                    _buildSectionCard(
                      context,
                      theme,
                      title: RuntimeLocalizations.t(context, 'settings_map_ui', fallback: 'Mappa e UI'),
                      icon: Icons.map_rounded,
                      children: [
                        _buildVectorLogosToggle(context, settings, theme),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, thickness: 1),
                        ),
                        _buildClusteringToggle(context, settings, theme),
                        const SizedBox(height: 16),
                        _buildStopsClusteringToggle(context, settings, theme),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider(height: 1, thickness: 1),
                        ),
                        _buildMapStyleSelector(context, settings, theme),
                      ],
                    ),

                    // SEZIONE: INFORMAZIONI
                    _buildDisclaimerSection(context, theme),
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar(BuildContext context, ThemeProvider theme) {
    return SliverAppBar(
      backgroundColor: theme.backgroundColor.withValues(alpha: 0.9),
      elevation: 0,
      pinned: true,
      stretch: true,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(color: Colors.transparent),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textColor, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        RuntimeLocalizations.t(context, 'settings_header_title'),
        style: TextStyle(
          color: theme.textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildSectionCard(BuildContext context, ThemeProvider theme, {required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.surfaceColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTokens.radius3Xl),
        border: Border.all(color: theme.borderColor.withValues(alpha: 0.08)),
        boxShadow: theme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTokens.radius3Xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTokens.space8),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    ),
                    child: Icon(icon, color: theme.primaryColor, size: AppTokens.iconMd),
                  ),
                  const SizedBox(width: AppTokens.space12),
                  Text(
                    title.toUpperCase(),
                    style: AppTextStyle.labelLarge(color: theme.secondaryTextColor).copyWith(letterSpacing: 1.2),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    final languageLabel = settings.isLocaleAutomatic ? RuntimeLocalizations.t(context, 'automatic') : _languageName(context, settings.appLocale?.languageCode);
    final themeLabel = _themeName(context, settings.themeMode);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.primaryColor.withOpacity(0.8),
            theme.primaryColor.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: theme.primaryColor.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      RuntimeLocalizations.t(context, 'settings_header_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      RuntimeLocalizations.t(context, 'settings_header_subtitle'),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildInfoChip(theme, icon: Icons.language_rounded, label: languageLabel),
              _buildInfoChip(theme, icon: Icons.palette_rounded, label: themeLabel),
              _buildInfoChip(theme, icon: Icons.auto_graph_rounded, label: RuntimeLocalizations.t(context, 'settings_auto_refresh')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(ThemeProvider theme, {required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _languageName(BuildContext context, String? langCode) {
    switch (langCode) {
      case 'it': return RuntimeLocalizations.t(context, 'language_italian');
      case 'en': return RuntimeLocalizations.t(context, 'language_english');
      case 'de': return RuntimeLocalizations.t(context, 'language_german');
      default: return RuntimeLocalizations.t(context, 'automatic');
    }
  }

  String _themeName(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light: return RuntimeLocalizations.t(context, 'theme_light');
      case ThemeMode.dark: return RuntimeLocalizations.t(context, 'theme_dark');
      case ThemeMode.system: return RuntimeLocalizations.t(context, 'theme_system');
    }
  }

  // --- METODI AGGIORNATI PER LINGUA CON BANDIERE ---

  Widget _buildLanguageTile(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    final currentLangLabel = settings.isLocaleAutomatic
        ? RuntimeLocalizations.t(context, 'automatic')
        : _languageName(context, settings.appLocale?.languageCode);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _showLanguageDialog(context, settings, theme),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              RuntimeLocalizations.t(context, 'settings_language'),
              style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Text(
                  currentLangLabel,
                  style: TextStyle(color: theme.secondaryTextColor, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios_rounded, color: theme.secondaryTextColor, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            RuntimeLocalizations.t(ctx, 'settings_language'),
            style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold),
          ),
          contentPadding: const EdgeInsets.only(top: 16, bottom: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogLanguageOption(
                ctx, 
                RuntimeLocalizations.t(ctx, 'automatic'), 
                null, 
                settings, 
                theme, 
                Icon(
                  Icons.auto_awesome_rounded, 
                  size: 18, 
                  color: settings.isLocaleAutomatic ? theme.primaryColor : theme.secondaryTextColor,
                ),
              ),
              _buildDialogLanguageOption(
                ctx, 
                RuntimeLocalizations.t(ctx, 'language_italian'), 
                'it', 
                settings, 
                theme, 
                const Text('🇮🇹', style: TextStyle(fontSize: 18)),
              ),
              _buildDialogLanguageOption(
                ctx, 
                RuntimeLocalizations.t(ctx, 'language_english'), 
                'en', 
                settings, 
                theme, 
                const Text('🇬🇧', style: TextStyle(fontSize: 18)),
              ),
              _buildDialogLanguageOption(
                ctx, 
                RuntimeLocalizations.t(ctx, 'language_german'), 
                'de', 
                settings, 
                theme, 
                const Text('🇩🇪', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogLanguageOption(BuildContext ctx, String label, String? langCode, SettingsProvider settings, ThemeProvider theme, Widget leading) {
    final isSelected = langCode == null ? settings.isLocaleAutomatic : settings.appLocale?.languageCode == langCode;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : theme.surfaceColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: leading, // Ora accetta direttamente il Text con l'emoji o l'Icon di sistema
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? theme.primaryColor : theme.textColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 15,
        ),
      ),
      trailing: isSelected ? Icon(Icons.check_circle_rounded, color: theme.primaryColor) : null,
      onTap: () {
        settings.setAppLocale(langCode);
        Navigator.pop(ctx);
      },
    );
  }


  // --- FINE METODI PER LINGUA ---

  Widget _buildThemeSelector(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RuntimeLocalizations.t(context, 'settings_theme'),
          style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildThemeOption(context, RuntimeLocalizations.t(context, 'theme_light'), Icons.light_mode_rounded, ThemeMode.light, settings, theme),
            const SizedBox(width: 12),
            _buildThemeOption(context, RuntimeLocalizations.t(context, 'theme_dark'), Icons.dark_mode_rounded, ThemeMode.dark, settings, theme),
            const SizedBox(width: 12),
            _buildThemeOption(context, RuntimeLocalizations.t(context, 'theme_system'), Icons.smartphone_rounded, ThemeMode.system, settings, theme),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, IconData icon, ThemeMode mode, SettingsProvider settings, ThemeProvider theme) {
    final isSelected = settings.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? theme.primaryColor : theme.secondaryTextColor, size: 28),
              const SizedBox(height: 8),
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

  Widget _buildRefreshSlider(BuildContext context, String label, IconData icon, int currentValue, Function(double) onChanged, ThemeProvider theme, {required bool isAuto, required Function(bool) onAutoChanged, required int autoRate}) {
    String statusText = isAuto ? 'Auto (${autoRate}s)' : (currentValue > 0 ? '${currentValue}s' : AppLocalizations.of(context)?.off ?? 'Off');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(shape: BoxShape.circle, color: theme.primaryColor.withOpacity(0.1)),
              child: Icon(icon, color: theme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
                  if (isAuto)
                    Text(RuntimeLocalizations.t(context, 'managed_by_server'), style: TextStyle(color: theme.secondaryTextColor, fontSize: 11)),
                ],
              ),
            ),
            Row(
              children: [
                Text(RuntimeLocalizations.t(context, 'auto'), style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Switch(
                  value: isAuto,
                  onChanged: onAutoChanged,
                  activeColor: theme.primaryColor,
                  activeTrackColor: theme.primaryColor.withOpacity(0.3),
                  inactiveThumbColor: theme.secondaryTextColor,
                  inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.2),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isAuto ? 0.3 : 1.0,
          child: IgnorePointer(
            ignoring: isAuto,
            child: Column(
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.primaryColor,
                    inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.1),
                    thumbColor: theme.primaryColor,
                    overlayColor: theme.primaryColor.withOpacity(0.1),
                    trackHeight: 6.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 20.0),
                  ),
                  child: Slider(
                    value: isAuto ? autoRate.toDouble() : currentValue.toDouble(),
                    min: 0,
                    max: 60,
                    divisions: 12,
                    label: statusText,
                    onChanged: onChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(RuntimeLocalizations.t(context, 'off'), style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.5), fontSize: 11)),
                      Text(statusText, style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(RuntimeLocalizations.t(context, 'seconds_60'), style: TextStyle(color: theme.secondaryTextColor.withOpacity(0.5), fontSize: 11)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigUpdateSection(BuildContext context, BusProvider busProvider, ThemeProvider theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                RuntimeLocalizations.t(context, 'update_configuration'),
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                RuntimeLocalizations.t(context, 'configuration_update_desc'),
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
              ),
              if (busProvider.configUpdateError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(busProvider.configUpdateError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        if (busProvider.isUpdatingConfig)
          SizedBox(
            width: 48,
            height: 48,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(theme.primaryColor)),
            ),
          )
        else
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () async {
              await busProvider.updateConfiguration();
              if (busProvider.configUpdateError != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(busProvider.configUpdateError!), backgroundColor: Colors.redAccent));
              } else if (busProvider.configUpdateError == null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(RuntimeLocalizations.t(context, 'configuration_updated_success')), backgroundColor: Colors.green));
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.cloud_sync_rounded, color: theme.primaryColor),
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineSyncToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    RuntimeLocalizations.t(context, 'offline_sync_title'),
                    style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('BETA', style: TextStyle(color: theme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                RuntimeLocalizations.t(context, 'offline_sync_desc'),
                style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
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
    );
  }

  Widget _buildBackgroundNotificationControls(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildNotificationTile(
          context, 
          theme,
          title: AppLocalizations.of(context)?.trains ?? RuntimeLocalizations.t(context, 'filter_trains'),
          subtitle: settings.trainStationId.isNotEmpty ? '${RuntimeLocalizations.t(context, "station_id")}: ${settings.trainStationId} · ${settings.trainService}' : null,
          onConfig: () => _showTrainConfigDialog(context, settings),
          onTest: () => AndroidBackgroundService.showNotification(
            channel: NotificationChannels.trains,
            title: AppLocalizations.of(context)?.testTrains ?? RuntimeLocalizations.t(context, 'test_notifications'),
            body: RuntimeLocalizations.t(context, 'test_notifications'),
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationTile(
          context, 
          theme,
          title: AppLocalizations.of(context)?.buses ?? RuntimeLocalizations.t(context, 'filter_buses'),
          subtitle: '${RuntimeLocalizations.t(context, "provider")}: ${settings.busProvider}',
          onConfig: () => _showBusConfigDialog(context, settings),
          onTest: () => AndroidBackgroundService.showNotification(
            channel: NotificationChannels.buses,
            title: AppLocalizations.of(context)?.testBuses ?? RuntimeLocalizations.t(context, 'test_notifications'),
            body: RuntimeLocalizations.t(context, 'test_notifications'),
          ),
        ),
        const SizedBox(height: 12),
        _buildNotificationTile(
          context, 
          theme,
          title: RuntimeLocalizations.t(context, 'functions', fallback: 'Funzioni'),
          subtitle: null,
          onConfig: null,
          onTest: () => AndroidBackgroundService.showNotification(
            channel: NotificationChannels.functions,
            title: RuntimeLocalizations.t(context, 'test_notifications'),
            body: RuntimeLocalizations.t(context, 'test_notifications'),
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationTile(BuildContext context, ThemeProvider theme, {required String title, String? subtitle, VoidCallback? onConfig, required VoidCallback onTest}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: theme.textColor, fontSize: 15, fontWeight: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
                ]
              ],
            ),
          ),
          if (onConfig != null)
            IconButton(
              icon: Icon(Icons.settings_rounded, color: theme.secondaryTextColor),
              onPressed: onConfig,
              splashRadius: 20,
            ),
          TextButton(
            onPressed: onTest,
            style: TextButton.styleFrom(
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              foregroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context)?.test ?? RuntimeLocalizations.t(context, 'test_notifications'), style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildTrainProximityNotice(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    final int current = settings.trainArrivalPreNoticeMinutes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)?.trainArrivalPreNotice ?? 'Preavviso arrivo stazione',
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$current min', style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: theme.primaryColor,
            inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.1),
            thumbColor: theme.primaryColor,
            trackHeight: 6.0,
          ),
          child: Slider(
            value: current.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            label: '$current min',
            onChanged: (v) => settings.setTrainArrivalPreNoticeMinutes(v.toInt()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            AppLocalizations.of(context)?.trainArrivalPreNoticeDesc ?? 'Ricevi un avviso N minuti prima dell\'arrivo stimato alla tua fermata (5–20 minuti).',
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVectorLogosToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSimpleToggle(
          context,
          theme,
          title: AppLocalizations.of(context)?.vectorTrainLogos ?? 'Loghi Treni Vettoriali',
          description: AppLocalizations.of(context)?.vectorTrainLogosDesc ?? 'Scarica e visualizza loghi ufficiali per le categorie dei treni (es. Frecciarossa, Intercity).',
          value: settings.vectorLogosEnabled,
          onChanged: (value) async {
            await settings.setVectorLogosEnabled(value);
            if (value && context.mounted) {
              try {
                Provider.of<TrainProvider>(context, listen: false).loadTrainLogos(source: settings.logoSource);
              } catch (_) {}
            }
          },
        ),
        if (settings.vectorLogosEnabled) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  RuntimeLocalizations.t(context, 'logo_source', fallback: 'Fonte Loghi'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildLogoSourceOption(
                        context, theme, settings,
                        label: RuntimeLocalizations.t(context, 'logos_official', fallback: 'Ufficiali'),
                        icon: Icons.verified_rounded,
                        source: 'official',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLogoSourceOption(
                        context, theme, settings,
                        label: RuntimeLocalizations.t(context, 'logos_custom', fallback: 'Custom'),
                        icon: Icons.palette_rounded,
                        source: 'custom',
                      ),
                    ),
                  ],
                ),
                if (settings.logoSource == 'official') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.secondaryTextColor.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: theme.secondaryTextColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            RuntimeLocalizations.t(context, 'logos_official_disclaimer'),
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.4,
                              color: theme.secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLogoSourceOption(
    BuildContext context,
    ThemeProvider theme,
    SettingsProvider settings, {
    required String label,
    required IconData icon,
    required String source,
  }) {
    final isSelected = settings.logoSource == source;

    return GestureDetector(
      onTap: () async {
        await settings.setLogoSource(source);
        if (context.mounted) {
          try {
            Provider.of<TrainProvider>(context, listen: false)
              ..resetLogos()
              ..loadTrainLogos(source: source);
          } catch (_) {}
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryColor.withOpacity(0.1)
              : theme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? theme.primaryColor : theme.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.primaryColor : theme.secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClusteringToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return _buildSimpleToggle(
      context,
      theme,
      title: AppLocalizations.of(context)?.busClustering ?? 'Clustering Autobus',
      description: AppLocalizations.of(context)?.busClusteringDesc ?? 'Raggruppa gli autobus vicini in cluster.',
      value: settings.busClusteringEnabled,
      onChanged: (value) => settings.setBusClusteringEnabled(value),
    );
  }

  Widget _buildStopsClusteringToggle(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return _buildSimpleToggle(
      context,
      theme,
      title: AppLocalizations.of(context)?.stopClustering ?? 'Clustering Fermate',
      description: AppLocalizations.of(context)?.stopClusteringDesc ?? 'Raggruppa le fermate vicine in cluster.',
      value: settings.stopsClusteringEnabled,
      onChanged: (value) => settings.setStopsClusteringEnabled(value),
    );
  }

  Widget _buildSimpleToggle(BuildContext context, ThemeProvider theme, {required String title, required String description, required bool value, required Function(bool) onChanged}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description, style: TextStyle(color: theme.secondaryTextColor, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: theme.primaryColor,
          activeTrackColor: theme.primaryColor.withOpacity(0.3),
          inactiveThumbColor: theme.secondaryTextColor,
          inactiveTrackColor: theme.secondaryTextColor.withOpacity(0.2),
        ),
      ],
    );
  }

  Widget _buildMapStyleSelector(BuildContext context, SettingsProvider settings, ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          RuntimeLocalizations.t(context, 'settings_map_style'),
          style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildMapStyleOption(context, RuntimeLocalizations.t(context, 'map_style_dark'), 'mapbox://styles/mapbox/dark-v11', Icons.nightlight_round, settings, theme),
              _buildMapStyleOption(context, RuntimeLocalizations.t(context, 'map_style_light'), 'mapbox://styles/mapbox/light-v11', Icons.wb_sunny_rounded, settings, theme),
              _buildMapStyleOption(context, RuntimeLocalizations.t(context, 'map_style_streets'), 'mapbox://styles/mapbox/streets-v11', Icons.map_rounded, settings, theme),
              _buildMapStyleOption(context, RuntimeLocalizations.t(context, 'map_style_satellite'), 'mapbox://styles/mapbox/satellite-v9', Icons.satellite_alt_rounded, settings, theme),
              _buildMapStyleOption(context, RuntimeLocalizations.t(context, 'map_style_satellite_streets'), 'mapbox://styles/mapbox/satellite-streets-v11', Icons.satellite_alt_outlined, settings, theme),
              GestureDetector(
                onTap: () => _showCustomStyleDialog(context, settings, theme),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.secondaryTextColor.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.edit_rounded, color: theme.secondaryTextColor, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        RuntimeLocalizations.t(context, 'other'),
                        style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapStyleOption(BuildContext context, String label, String value, IconData icon, SettingsProvider settings, ThemeProvider theme) {
    final isSelected = settings.mapStyle == value;
    return GestureDetector(
      onTap: () => settings.setMapStyle(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isSelected ? theme.primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? theme.primaryColor : theme.secondaryTextColor.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? theme.primaryColor : theme.secondaryTextColor, size: 28),
            const SizedBox(height: 8),
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

  void _showCustomStyleDialog(BuildContext ctx, SettingsProvider settings, ThemeProvider theme) {
    final controller = TextEditingController(text: settings.mapStyle);
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: theme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(RuntimeLocalizations.t(ctx, 'custom_style_url'), style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          style: TextStyle(color: theme.textColor),
          decoration: InputDecoration(
            hintText: RuntimeLocalizations.t(ctx, 'custom_style_hint'),
            hintStyle: TextStyle(color: theme.secondaryTextColor),
            filled: true,
            fillColor: theme.backgroundColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx)?.cancel ?? 'Annulla', style: TextStyle(color: theme.secondaryTextColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final val = controller.text.trim();
              if (val.isNotEmpty) settings.setMapStyle(val);
              Navigator.pop(ctx);
            },
            child: Text(AppLocalizations.of(ctx)?.save ?? 'Salva'),
          ),
        ],
      ),
    );
  }

  void _showTrainConfigDialog(BuildContext context, SettingsProvider settings) {
    final stationController = TextEditingController(text: settings.trainStationId);
    String selectedService = settings.trainService;
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(AppLocalizations.of(context)?.trainNotificationsConfig ?? RuntimeLocalizations.t(context, 'train_notifications_config'), style: TextStyle(color: theme.textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stationController,
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  labelText: RuntimeLocalizations.t(context, 'station_id'),
                  labelStyle: TextStyle(color: theme.secondaryTextColor),
                  filled: true,
                  fillColor: theme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: theme.backgroundColor, borderRadius: BorderRadius.circular(16)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedService,
                    dropdownColor: theme.surfaceColor,
                    isExpanded: true,
                    style: TextStyle(color: theme.textColor),
                    items: [
                      DropdownMenuItem(value: 'trainboardeu', child: Text(RuntimeLocalizations.t(context, 'trainboard_prod'))),
                      DropdownMenuItem(value: 'direct', child: Text(RuntimeLocalizations.t(context, 'direct_rfi'))),
                    ],
                    onChanged: (v) {
                      if (v != null) selectedService = v;
                    },
                  ),
                ),
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Annulla', style: TextStyle(color: theme.secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
              child: Text(AppLocalizations.of(context)?.save ?? 'Salva'),
            )
          ],
        );
      },
    );
  }

  void _showBusConfigDialog(BuildContext context, SettingsProvider settings) {
    final providerController = TextEditingController(text: settings.busProvider);
    final baseController = TextEditingController(text: settings.busBaseUrl);
    final theme = Provider.of<ThemeProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(AppLocalizations.of(context)?.busNotificationsConfig ?? 'Configura notifiche autobus', style: TextStyle(color: theme.textColor)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: providerController,
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  labelText: 'Provider (es. bari)',
                  labelStyle: TextStyle(color: theme.secondaryTextColor),
                  filled: true,
                  fillColor: theme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: baseController,
                style: TextStyle(color: theme.textColor),
                decoration: InputDecoration(
                  labelText: 'Base URL (opzionale)',
                  labelStyle: TextStyle(color: theme.secondaryTextColor),
                  filled: true,
                  fillColor: theme.backgroundColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Annulla', style: TextStyle(color: theme.secondaryTextColor)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
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
              child: Text(AppLocalizations.of(context)?.save ?? 'Salva'),
            )
          ],
        );
      },
    );
  }

  Widget _buildDisclaimerSection(BuildContext context, ThemeProvider theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orangeAccent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 24),
              const SizedBox(width: 12),
              Text(
                RuntimeLocalizations.t(context, 'importantInfo', fallback: 'Informazioni Importanti'),
                style: TextStyle(color: theme.textColor, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            RuntimeLocalizations.t(context, 'disclaimer_title'),
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            RuntimeLocalizations.t(context, 'disclaimer_text'),
            style: TextStyle(color: theme.secondaryTextColor, fontSize: 12, height: 1.6),
          ),
        ],
      ),
    );
  }
}
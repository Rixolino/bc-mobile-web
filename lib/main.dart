import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/bus/presentation/providers/bus_provider.dart';
import 'features/plane/presentation/providers/plane_provider.dart';
import 'features/train/presentation/providers/train_provider.dart';
import 'features/favorites/providers/favorites_provider.dart';
import 'presentation/providers/config_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/providers/map_state_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'core/services/tv_cursor_service.dart';
import 'core/widgets/tv_cursor_overlay.dart';
import 'core/services/android_background_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:bc_transporter/l10n/app_localizations.dart';

void main() {
  runApp(const BcTransporterApp());
}

/// App principale BC Transporter con gestione del salvataggio posizione mappa.
///
/// Modifiche implementate per il salvataggio posizione:
/// - ✅ StatefulWidget invece di StatelessWidget per gestire il lifecycle
/// - ✅ WidgetsBindingObserver per monitorare lo stato dell'app
/// - ✅ Salvataggio automatico della posizione quando l'app va in background
/// - ✅ Salvataggio quando l'app viene chiusa o messa in pausa
class BcTransporterApp extends StatefulWidget {
  const BcTransporterApp({super.key});

  @override
  State<BcTransporterApp> createState() => _BcTransporterAppState();
}

class _BcTransporterAppState extends State<BcTransporterApp>
    with WidgetsBindingObserver {
  MapStateProvider? _mapStateProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Android: richiedi permessi notifiche e pianifica i worker nativi
    // (Usiamo chiamate native via MethodChannel)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AndroidBackgroundService.requestPermission();
        final settings = Provider.of<SettingsProvider>(context, listen: false);
        if (settings.trainsWorkerEnabled)
          await AndroidBackgroundService.scheduleTrainsWorker(
              intervalSeconds: settings.trainRefreshSeconds,
              stationId: settings.trainStationId.isNotEmpty
                  ? settings.trainStationId
                  : null,
              service: settings.trainService);
        if (settings.busesWorkerEnabled)
          await AndroidBackgroundService.scheduleBusesWorker(
              intervalSeconds: settings.busRefreshSeconds,
              provider: settings.busProvider,
              baseUrl: settings.busBaseUrl);
        if (settings.functionsWorkerEnabled)
          await AndroidBackgroundService.scheduleFunctionsWorker();
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Salva la posizione della mappa quando l'app viene messa in background o chiusa
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached ||
            state == AppLifecycleState.inactive) &&
        _mapStateProvider != null) {
      _mapStateProvider!.saveCurrentPosition();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, ThemeProvider>(
          create: (_) => ThemeProvider(),
          update: (_, settings, theme) {
            theme!.setThemeMode(settings.themeMode);
            return theme;
          },
        ),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, TrainProvider>(
          create: (_) => TrainProvider(),
          update: (_, settings, train) {
            train!.updateAutoRefresh(
              settings.trainRefreshSeconds,
              offlineSyncEnabled: settings.offlineSyncEnabled,
            );
            return train;
          },
        ),
        ChangeNotifierProxyProvider<SettingsProvider, BusProvider>(
          create: (_) => BusProvider(),
          update: (_, settings, bus) {
            bus!.updateAutoRefresh(settings.busRefreshSeconds);
            return bus;
          },
        ),
        ChangeNotifierProxyProvider<SettingsProvider, PlaneProvider>(
          create: (_) => PlaneProvider(),
          update: (_, settings, plane) {
            plane!.updateAutoRefresh(
              settings.planeRefreshSeconds,
              offlineSyncEnabled: settings.offlineSyncEnabled,
            );
            return plane;
          },
        ),
        ChangeNotifierProvider(create: (_) => MapStateProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => TvCursorService()..load()),
      ],
      child: Consumer2<ThemeProvider, SettingsProvider>(
        builder: (context, theme, settings, child) {
          // Salva riferimento al MapStateProvider per il lifecycle
          _mapStateProvider =
              Provider.of<MapStateProvider>(context, listen: false);

          return Consumer<AuthProvider>(
            builder: (context, auth, child) {
              return MaterialApp(
                title: 'BC Transporter',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: theme.themeMode,
                locale: settings.appLocale,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('it'), // Italiano (default)
                  Locale('en'), // Inglese
                  Locale('de'), // Tedesco
                  Locale('fr'), // Francese
                ],
                builder: (context, child) {
                  // Zoom testi app da impostazioni (non tocca la mappa)
                  final scale = Provider.of<SettingsProvider>(context).textScale;
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: TvRemoteHost(child: child),
                  );
                },
                navigatorObservers: [TvNavObserver()],
                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

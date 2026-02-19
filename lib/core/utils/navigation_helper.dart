import 'package:flutter/material.dart';
import '../../presentation/screens/home_screen.dart';

class NavigationHelper {
  // Naviga alla home screen in modalità Viaggio (mappa)
  static void navigateToMap(BuildContext context) {
    _navigateToHome(context, 0);
  }

  // Naviga alla home screen in modalità Treno
  static void navigateToTrain(BuildContext context) {
    _navigateToHome(context, 1);
  }

  // Naviga alla home screen in modalità Bus
  static void navigateToBus(BuildContext context) {
    _navigateToHome(context, 2);
  }

  // Naviga alla home screen in modalità Aereo
  static void navigateToPlane(BuildContext context) {
    _navigateToHome(context, 3);
  }

  // Metodo privato per navigare alla home screen con modalità specifica
  static void _navigateToHome(BuildContext context, int mode) {
    // Controlla se siamo già nella home screen
    final currentRoute = ModalRoute.of(context);
    if (currentRoute?.settings.name == '/home') {
      // Se siamo già nella home screen, non facciamo nulla per ora
      // In futuro potremmo implementare un modo per cambiare modalità
      return;
    }

    // Altrimenti naviga alla home screen con la modalità specificata
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(initialMode: mode),
        settings: const RouteSettings(name: '/home'),
      ),
      (route) => false, // Rimuove tutte le route precedenti
    );
  }
}

// Estensione per accedere facilmente ai metodi di navigazione
extension NavigationHelperExtension on BuildContext {
  void navigateToMap() => NavigationHelper.navigateToMap(this);
  void navigateToTrain() => NavigationHelper.navigateToTrain(this);
  void navigateToBus() => NavigationHelper.navigateToBus(this);
  void navigateToPlane() => NavigationHelper.navigateToPlane(this);
}
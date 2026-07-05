// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'BC Transporter';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get language => 'Lingua';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get theme => 'Tema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get selectedStop => 'Fermata Selezionata';

  @override
  String get stop => 'Fermata';

  @override
  String get close => 'Chiudi';

  @override
  String get quickActions => 'Azioni Rapide';

  @override
  String get mapStyle => 'Stile Mappa';

  @override
  String get mapStyleDesc => 'Cambia l\'aspetto della cartina';

  @override
  String get favorites => 'Preferiti';

  @override
  String get favoritesDesc => 'I tuoi treni e bus salvati';

  @override
  String get notifications => 'Notifiche';

  @override
  String get notificationsDesc => 'Gestisci i monitoraggi';

  @override
  String get settingsDesc => 'Configura l\'applicazione';

  @override
  String get searchTrainNumberHint => 'Numero Treno (es: 9610)';

  @override
  String get searchStationHint => 'Stazione (es: Roma Termini)';

  @override
  String get searchBusStopHint => 'Cerca fermata bus...';

  @override
  String get searchAirportHint => 'Cerca volo o aeroporto...';

  @override
  String get searchDestinationHint => 'Cerca destinazione...';

  @override
  String get autoUpdate => 'Aggiornamento Automatico';

  @override
  String get trains => 'Treni';

  @override
  String get buses => 'Autobus';

  @override
  String get planes => 'Aerei';

  @override
  String get configuration => 'Configurazione';

  @override
  String get testNotifications => 'Test Notifiche';

  @override
  String get experienceUi => 'Experience UI';

  @override
  String get vectorTrainLogos => 'Loghi Treni Vettoriali';

  @override
  String get map => 'Mappa';

  @override
  String get busClustering => 'Clustering Autobus';

  @override
  String get busClusteringDesc =>
      'Raggruppa gli autobus vicini in cluster per una visualizzazione più chiara';

  @override
  String get stopClustering => 'Clustering Fermate';

  @override
  String get stopClusteringDesc =>
      'Raggruppa le fermate vicine in cluster per una visualizzazione più chiara';

  @override
  String get offlineSync => 'Sincronizzazione Offline';

  @override
  String get infoDisclaimer => 'Informazioni e Disclaimer';

  @override
  String get managedByServer => 'Gestito dal server in base al traffico';

  @override
  String get goToMap => 'Vai alla mappa';

  @override
  String get operator => 'Operatore';

  @override
  String get reorderProviders => 'Riordina provider';

  @override
  String get stops => 'Fermate';

  @override
  String get lines => 'Linee';

  @override
  String get solutions => 'Soluzioni';

  @override
  String get searchLineHint => 'Cerca linea...';

  @override
  String get searchStopHint => 'Cerca fermata...';

  @override
  String get nearYou => 'Vicini a te';

  @override
  String get refresh => 'Aggiorna';

  @override
  String get planJourney => 'Pianifica Viaggio';

  @override
  String get departure => 'Partenza';

  @override
  String get arrival => 'Arrivo';

  @override
  String get searchSolutions => 'Cerca Soluzioni';

  @override
  String get select => 'Seleziona';

  @override
  String get noLinesLoaded => 'Nessuna linea caricata';

  @override
  String get noLinesFound => 'Nessuna linea trovata';

  @override
  String get loadLines => 'Carica Linee';

  @override
  String get searchTravelSolution => 'Cerca una soluzione di viaggio';

  @override
  String get noStopsFound => 'Nessuna fermata trovata';

  @override
  String get showOnMap => 'Mostra su mappa';

  @override
  String noActiveBusFound(String city) {
    return 'Nessun autobus attivo trovato\nper $city';
  }

  @override
  String get inTransit => 'In viaggio';

  @override
  String get routeTowards => 'Percorso verso';

  @override
  String get cancel => 'Annulla';

  @override
  String get searchStation => 'Cerca stazione...';

  @override
  String get searchFlight => 'Cerca volo o aeroporto...';

  @override
  String get station => 'Stazione';

  @override
  String get train => 'Treno';

  @override
  String get flight => 'Volo';

  @override
  String get error => 'Errore';

  @override
  String get loading => 'Caricamento...';

  @override
  String get noResults => 'Nessun risultato trovato';

  @override
  String get showOnMapTitle => 'Mostra su Mappa';

  @override
  String get searchByNumber => 'Cerca per numero';

  @override
  String get searchByStation => 'Cerca per stazione';

  @override
  String get globalBeta => 'Globale';

  @override
  String get trainNumber => 'Numero Treno';

  @override
  String get allPlatforms => 'Tutti i Binari';

  @override
  String get platform => 'Binario';

  @override
  String get onTime => 'In orario';

  @override
  String get youAreOffline => 'Sei offline';

  @override
  String get connectToSearchStations => 'Connettiti per cercare nuove stazioni';

  @override
  String get savedTrains => 'Treni Salvati';

  @override
  String get accessOfflineData => 'Accedi ai dati scaricati offline';

  @override
  String get savedTrainsOffline => 'Treni Salvati (Offline)';

  @override
  String get noOfflineData => 'Nessun dato salvato offline';

  @override
  String get arrivals => 'ARRIVI';

  @override
  String get departures => 'PARTENZE';

  @override
  String get searchStationOrTrain => 'Cerca stazione o treno...';

  @override
  String get reorderCountries => 'Riordina nazioni';

  @override
  String get allCities => 'Tutte le città';

  @override
  String get save => 'Salva';

  @override
  String get flightRadar => 'Radar Voli';

  @override
  String get airports => 'AEROPORTI';

  @override
  String get searchAirportIcaoHint => 'Cerca aeroporto (ICAO/IATA)...';

  @override
  String get noFlightsInRadar => 'Nessun volo nel raggio radar';

  @override
  String get searchResult => 'RISULTATO RICERCA';

  @override
  String get nearbyAirports => 'AEROPORTI VICINI';

  @override
  String get airport => 'Aeroporto';

  @override
  String get departures2 => 'Partenze';

  @override
  String get arrivals2 => 'Arrivi';

  @override
  String get noFlightsForAirport =>
      'Nessun volo disponibile per questo aeroporto.';

  @override
  String get back => 'Torna indietro';

  @override
  String get login => 'Accedi';

  @override
  String get register => 'Registrati';

  @override
  String get welcomeTitle => 'Benvenuto su\nBC Transporter';

  @override
  String get loginSubtitle => 'Accedi al tuo account';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'Inserisci la tua email';

  @override
  String get emailRequired => 'Inserisci l\'email';

  @override
  String get emailInvalid => 'Inserisci un\'email valida';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Inserisci la password';

  @override
  String get passwordRequired => 'Inserisci la password';

  @override
  String get passwordMin6 => 'La password deve essere di almeno 6 caratteri';

  @override
  String get noAccount => 'Non hai un account?';

  @override
  String get createAccountTitle => 'Crea il tuo\nAccount';

  @override
  String get registerSubtitle => 'Unisciti alla comunita BC Transporter';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Scegli un nickname';

  @override
  String get nicknameRequired => 'Inserisci un nickname';

  @override
  String get nicknameMin3 => 'Il nickname deve essere di almeno 3 caratteri';

  @override
  String get createPasswordHint => 'Crea una password sicura';

  @override
  String get confirmPassword => 'Conferma Password';

  @override
  String get repeatPassword => 'Ripeti la password';

  @override
  String get confirmPasswordRequired => 'Conferma la password';

  @override
  String get passwordsDoNotMatch => 'Le password non coincidono';

  @override
  String get alreadyHaveAccount => 'Hai gia un account?';

  @override
  String get registrationSuccess => 'Registrazione completata con successo!';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get logout => 'Esci';

  @override
  String welcomeUser(String nickname) {
    return 'Benvenuto$nickname!';
  }

  @override
  String get publicTransportExplore => 'Esplora i trasporti pubblici';

  @override
  String get findBuses => 'Trova autobus';

  @override
  String get trainTimes => 'Orari treni';

  @override
  String get flights => 'Voli';

  @override
  String get flightInfo => 'Informazioni voli';

  @override
  String get viewRoutes => 'Visualizza percorsi';

  @override
  String get yourProfile => 'Il tuo Profilo';

  @override
  String get memberSince => 'Membro dal';

  @override
  String get notAvailable => 'N/A';

  @override
  String get security => 'Sicurezza';

  @override
  String get changePassword => 'Cambia Password';

  @override
  String get currentPassword => 'Password Attuale';

  @override
  String get newPassword => 'Nuova Password';

  @override
  String get atLeast8Chars => 'Almeno 8 caratteri';

  @override
  String get update => 'Aggiorna';

  @override
  String get currentPasswordRequired => 'Inserisci la password attuale';

  @override
  String get passwordMin8 => 'La password deve avere almeno 8 caratteri';

  @override
  String get newPasswordMustDiffer =>
      'La nuova password deve essere diversa da quella attuale';

  @override
  String get passwordChanged => 'Password cambiata con successo!';

  @override
  String get currentPasswordWrong => 'Password attuale non corretta';

  @override
  String get changePasswordSubtitle => 'Modifica la tua password di accesso';

  @override
  String get comingSoon => 'Prossimamente';

  @override
  String get newFeaturesComing => 'Nuove funzionalita in arrivo!';

  @override
  String get newFeaturesBody =>
      'Stiamo lavorando per offrirti un\'esperienza ancora migliore con nuove features esclusive.';

  @override
  String get statistics => 'Statistiche';

  @override
  String get alerts => 'Avvisi';

  @override
  String get sharing => 'Condivisione';

  @override
  String get backup => 'Backup';

  @override
  String get notificationsManager => 'Gestore notifiche';

  @override
  String get refreshAll => 'Aggiorna tutto';

  @override
  String get refreshCompleted => 'Aggiornamento completato';

  @override
  String get monitorStopsStations => 'Monitora fermate e stazioni';

  @override
  String get monitoredStops => 'Fermate monitorate';

  @override
  String get noMonitoredStops => 'Nessuna fermata monitorata';

  @override
  String get removeMonitoring => 'Rimuovi monitoraggio';

  @override
  String removeStopQuestion(String name) {
    return 'Rimuovere la fermata $name?';
  }

  @override
  String removeTrainQuestion(String name) {
    return 'Rimuovere il monitoraggio per il treno $name?';
  }

  @override
  String removeStationQuestion(String name) {
    return 'Rimuovere la stazione $name?';
  }

  @override
  String get remove => 'Rimuovi';

  @override
  String get forceRefresh => 'Aggiornamento forzato';

  @override
  String get notificationCancelled => 'Notifica cancellata';

  @override
  String get cancelNotification => 'Cancella notifica';

  @override
  String get monitoredStations => 'Stazioni monitorate';

  @override
  String get noMonitoredStations => 'Nessuna stazione monitorata';

  @override
  String get monitoredTrains => 'Treni monitorati';

  @override
  String get noMonitoredTrains => 'Nessun treno monitorato';

  @override
  String get noData => 'Nessun dato';

  @override
  String updatedAt(String value) {
    return 'Aggiornato: $value';
  }

  @override
  String stationWithId(String id) {
    return 'Stazione $id';
  }

  @override
  String get customStyleUrl => 'URL stile personalizzato';

  @override
  String get other => 'Altro';

  @override
  String get dark => 'Scuro';

  @override
  String get light => 'Chiaro';

  @override
  String get streets => 'Strade';

  @override
  String get satellite => 'Satellite';

  @override
  String get satelliteStreets => 'Sat+Str';

  @override
  String get auto => 'Auto';

  @override
  String get off => 'Off';

  @override
  String get trainNotificationsConfig => 'Configura notifiche treni';

  @override
  String get busNotificationsConfig => 'Configura notifiche autobus';

  @override
  String get stationIdExample => 'Station ID (es. S01700)';

  @override
  String get providerExample => 'Provider (es. bari)';

  @override
  String get optionalBaseUrl => 'Base URL (opzionale)';

  @override
  String get test => 'Test';

  @override
  String get testTrains => 'Test Treni';

  @override
  String get testBuses => 'Test Bus';

  @override
  String get testFunctions => 'Test Funzioni';

  @override
  String get trainArrivalPreNotice => 'Preavviso arrivo stazione';

  @override
  String get trainArrivalPreNoticeDesc =>
      'Ricevi un avviso N minuti prima dell\'arrivo stimato alla tua fermata (5–20 minuti).';

  @override
  String get vectorTrainLogosDesc =>
      'Scarica e visualizza loghi ufficiali per le categorie dei treni (es. Frecciarossa, Intercity) invece del testo semplice.';

  @override
  String get updateConfiguration => 'Aggiorna Configurazione';

  @override
  String get configurationUpdateDesc =>
      'Scarica l\'ultima configurazione dei provider di autobus dal server';

  @override
  String get updateProviderConfiguration => 'Aggiorna configurazione provider';

  @override
  String get offlineSyncDesc =>
      'Scarica automaticamente i dati di percorsi e orari quando sincronizzi da una città. I dati verranno salvati localmente e disponibili anche senza connessione.';

  @override
  String get disclaimerTitle =>
      'BC Transporter Non Sostituisce i Canali Ufficiali';

  @override
  String get disclaimerText =>
      'Questa applicazione non intende in alcun modo sostituire le piattaforme ufficiali delle compagnie ferroviarie o i loro canali di vendita. BC Transporter fornisce informazioni e dati di tracciamento a scopo puramente informativo.\n\nPer l\'acquisto dei biglietti e per verificare disponibilità, tariffe, condizioni di viaggio e conferme ufficiali, è necessario rivolgersi esclusivamente ai canali ufficiali delle compagnie ferroviarie (siti web, app ufficiali, agenzie autorizzate o rivenditori certificati).\n\nI biglietti devono essere acquistati tramite le piattaforme ufficiali; BC Transporter non vende biglietti e non sostituisce i canali ufficiali di vendita.\n\nNon ci assumiamo responsabilità per acquisti effettuati su canali non ufficiali o per informazioni di prezzo/condizioni non aggiornate. Eventuali link a siti di terze parti sono forniti a scopo di comodità e non implicano approvazione o partnership.';

  @override
  String get user => 'Utente';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'BC Transporter';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get theme => 'Design';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeSystem => 'System';

  @override
  String get selectedStop => 'Ausgewählte Haltestelle';

  @override
  String get stop => 'Haltestelle';

  @override
  String get close => 'Schließen';

  @override
  String get quickActions => 'Schnellaktionen';

  @override
  String get mapStyle => 'Kartenstil';

  @override
  String get mapStyleDesc => 'Kartenbild ändern';

  @override
  String get favorites => 'Favoriten';

  @override
  String get favoritesDesc => 'Ihre gespeicherten Züge und Busse';

  @override
  String get notifications => 'Benachrichtigungen';

  @override
  String get notificationsDesc => 'Tracking verwalten';

  @override
  String get settingsDesc => 'Anwendung konfigurieren';

  @override
  String get searchTrainNumberHint => 'Zugnummer (z. B. 9610)';

  @override
  String get searchStationHint => 'Bahnhof (z. B. Roma Termini)';

  @override
  String get searchBusStopHint => 'Bushaltestelle suchen...';

  @override
  String get searchAirportHint => 'Flug oder Flughafen suchen...';

  @override
  String get searchDestinationHint => 'Ziel suchen...';

  @override
  String get autoUpdate => 'Automatisches Update';

  @override
  String get trains => 'Züge';

  @override
  String get buses => 'Busse';

  @override
  String get planes => 'Flugzeuge';

  @override
  String get configuration => 'Konfiguration';

  @override
  String get testNotifications => 'Benachrichtigungstest';

  @override
  String get experienceUi => 'Benutzeroberfläche';

  @override
  String get vectorTrainLogos => 'Vektor-Zuglogos';

  @override
  String get map => 'Karte';

  @override
  String get busClustering => 'Bus-Clustering';

  @override
  String get busClusteringDesc =>
      'Raggruppa gli autobus vicini in cluster per una visualizzazione più chiara';

  @override
  String get stopClustering => 'Haltestellen-Clustering';

  @override
  String get stopClusteringDesc =>
      'Raggruppa le fermate vicine in cluster per una visualizzazione più chiara';

  @override
  String get offlineSync => 'Offline-Synchronisation';

  @override
  String get infoDisclaimer => 'Info & Haftungsausschluss';

  @override
  String get managedByServer => 'Vom Server nach Verkehr verwaltet';

  @override
  String get goToMap => 'Zur Karte';

  @override
  String get operator => 'Betreiber';

  @override
  String get reorderProviders => 'Anbieter neu anordnen';

  @override
  String get stops => 'Haltestellen';

  @override
  String get lines => 'Linien';

  @override
  String get solutions => 'Lösungen';

  @override
  String get searchLineHint => 'Linie suchen...';

  @override
  String get searchStopHint => 'Haltestelle suchen...';

  @override
  String get nearYou => 'In deiner Nähe';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get planJourney => 'Reise planen';

  @override
  String get departure => 'Abfahrt';

  @override
  String get arrival => 'Ankunft';

  @override
  String get searchSolutions => 'Lösungen suchen';

  @override
  String get select => 'Auswählen';

  @override
  String get noLinesLoaded => 'Keine Linien geladen';

  @override
  String get noLinesFound => 'Keine Linien gefunden';

  @override
  String get loadLines => 'Linien laden';

  @override
  String get searchTravelSolution => 'Nach einer Reiselösung suchen';

  @override
  String get noStopsFound => 'Keine Haltestellen gefunden';

  @override
  String get showOnMap => 'Auf Karte anzeigen';

  @override
  String noActiveBusFound(String city) {
    return 'Kein aktiver Bus gefunden\nfür $city';
  }

  @override
  String get inTransit => 'Unterwegs';

  @override
  String get routeTowards => 'Route Richtung';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get searchStation => 'Bahnhof suchen...';

  @override
  String get searchFlight => 'Flug oder Flughafen suchen...';

  @override
  String get station => 'Bahnhof';

  @override
  String get train => 'Zug';

  @override
  String get flight => 'Flug';

  @override
  String get error => 'Fehler';

  @override
  String get loading => 'Laden...';

  @override
  String get noResults => 'Keine Ergebnisse gefunden';

  @override
  String get showOnMapTitle => 'Auf Karte anzeigen';

  @override
  String get searchByNumber => 'Nach Nummer suchen';

  @override
  String get searchByStation => 'Nach Bahnhof suchen';

  @override
  String get globalBeta => 'Global';

  @override
  String get trainNumber => 'Zugnummer';

  @override
  String get allPlatforms => 'Alle Gleise';

  @override
  String get platform => 'Gleis';

  @override
  String get onTime => 'Pünktlich';

  @override
  String get youAreOffline => 'Sie sind offline';

  @override
  String get connectToSearchStations =>
      'Verbinden Sie sich, um neue Bahnhöfe zu suchen';

  @override
  String get savedTrains => 'Gespeicherte Züge';

  @override
  String get accessOfflineData =>
      'Auf heruntergeladene Offline-Daten zugreifen';

  @override
  String get savedTrainsOffline => 'Gespeicherte Züge (Offline)';

  @override
  String get noOfflineData => 'Keine Offline-Daten gespeichert';

  @override
  String get arrivals => 'ANKÜNFTE';

  @override
  String get departures => 'ABFAHRTEN';

  @override
  String get searchStationOrTrain => 'Bahnhof oder Zug suchen...';

  @override
  String get reorderCountries => 'Länder neu anordnen';

  @override
  String get allCities => 'Alle Städte';

  @override
  String get save => 'Speichern';

  @override
  String get flightRadar => 'Flug-Radar';

  @override
  String get airports => 'FLUGHÄFEN';

  @override
  String get searchAirportIcaoHint => 'Flughafen suchen (ICAO/IATA)...';

  @override
  String get noFlightsInRadar => 'Keine Flüge im Radarbereich';

  @override
  String get searchResult => 'SUCHERGEBNIS';

  @override
  String get nearbyAirports => 'NAHE FLUGHÄFEN';

  @override
  String get airport => 'Flughafen';

  @override
  String get departures2 => 'Abfahrten';

  @override
  String get arrivals2 => 'Ankünfte';

  @override
  String get noFlightsForAirport =>
      'Keine Flüge für diesen Flughafen verfügbar.';

  @override
  String get back => 'Zurueck';

  @override
  String get login => 'Anmelden';

  @override
  String get register => 'Registrieren';

  @override
  String get welcomeTitle => 'Willkommen bei\nBC Transporter';

  @override
  String get loginSubtitle => 'Melden Sie sich bei Ihrem Konto an';

  @override
  String get email => 'E-Mail';

  @override
  String get emailHint => 'E-Mail eingeben';

  @override
  String get emailRequired => 'E-Mail eingeben';

  @override
  String get emailInvalid => 'Gueltige E-Mail eingeben';

  @override
  String get password => 'Passwort';

  @override
  String get passwordHint => 'Passwort eingeben';

  @override
  String get passwordRequired => 'Passwort eingeben';

  @override
  String get passwordMin6 => 'Das Passwort muss mindestens 6 Zeichen lang sein';

  @override
  String get noAccount => 'Noch kein Konto?';

  @override
  String get createAccountTitle => 'Konto\nerstellen';

  @override
  String get registerSubtitle => 'Treten Sie der BC Transporter Community bei';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Nickname waehlen';

  @override
  String get nicknameRequired => 'Nickname eingeben';

  @override
  String get nicknameMin3 => 'Der Nickname muss mindestens 3 Zeichen lang sein';

  @override
  String get createPasswordHint => 'Sicheres Passwort erstellen';

  @override
  String get confirmPassword => 'Passwort bestaetigen';

  @override
  String get repeatPassword => 'Passwort wiederholen';

  @override
  String get confirmPasswordRequired => 'Passwort bestaetigen';

  @override
  String get passwordsDoNotMatch => 'Passwoerter stimmen nicht ueberein';

  @override
  String get alreadyHaveAccount => 'Bereits ein Konto?';

  @override
  String get registrationSuccess => 'Registrierung erfolgreich abgeschlossen!';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get logout => 'Abmelden';

  @override
  String welcomeUser(String nickname) {
    return 'Willkommen$nickname!';
  }

  @override
  String get publicTransportExplore => 'Oeffentliche Verkehrsmittel erkunden';

  @override
  String get findBuses => 'Busse finden';

  @override
  String get trainTimes => 'Zugzeiten';

  @override
  String get flights => 'Fluege';

  @override
  String get flightInfo => 'Fluginformationen';

  @override
  String get viewRoutes => 'Routen anzeigen';

  @override
  String get yourProfile => 'Ihr Profil';

  @override
  String get memberSince => 'Mitglied seit';

  @override
  String get notAvailable => 'N/V';

  @override
  String get security => 'Sicherheit';

  @override
  String get changePassword => 'Passwort aendern';

  @override
  String get currentPassword => 'Aktuelles Passwort';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get atLeast8Chars => 'Mindestens 8 Zeichen';

  @override
  String get update => 'Aktualisieren';

  @override
  String get currentPasswordRequired => 'Aktuelles Passwort eingeben';

  @override
  String get passwordMin8 => 'Das Passwort muss mindestens 8 Zeichen lang sein';

  @override
  String get newPasswordMustDiffer =>
      'Das neue Passwort muss sich vom aktuellen unterscheiden';

  @override
  String get passwordChanged => 'Passwort erfolgreich geaendert!';

  @override
  String get currentPasswordWrong => 'Aktuelles Passwort ist falsch';

  @override
  String get changePasswordSubtitle => 'Aendern Sie Ihr Login-Passwort';

  @override
  String get comingSoon => 'Demnaechst';

  @override
  String get newFeaturesComing => 'Neue Funktionen kommen!';

  @override
  String get newFeaturesBody =>
      'Wir arbeiten daran, Ihnen mit neuen exklusiven Funktionen ein noch besseres Erlebnis zu bieten.';

  @override
  String get statistics => 'Statistiken';

  @override
  String get alerts => 'Hinweise';

  @override
  String get sharing => 'Teilen';

  @override
  String get backup => 'Backup';

  @override
  String get notificationsManager => 'Benachrichtigungsmanager';

  @override
  String get refreshAll => 'Alle aktualisieren';

  @override
  String get refreshCompleted => 'Aktualisierung abgeschlossen';

  @override
  String get monitorStopsStations => 'Haltestellen und Bahnhoefe ueberwachen';

  @override
  String get monitoredStops => 'Ueberwachte Haltestellen';

  @override
  String get noMonitoredStops => 'Keine ueberwachte Haltestellen';

  @override
  String get removeMonitoring => 'Ueberwachung entfernen';

  @override
  String removeStopQuestion(String name) {
    return 'Haltestelle $name entfernen?';
  }

  @override
  String removeTrainQuestion(String name) {
    return 'Ueberwachung fuer Zug $name entfernen?';
  }

  @override
  String removeStationQuestion(String name) {
    return 'Bahnhof $name entfernen?';
  }

  @override
  String get remove => 'Entfernen';

  @override
  String get forceRefresh => 'Aktualisierung erzwungen';

  @override
  String get notificationCancelled => 'Benachrichtigung geloescht';

  @override
  String get cancelNotification => 'Benachrichtigung loeschen';

  @override
  String get monitoredStations => 'Ueberwachte Bahnhoefe';

  @override
  String get noMonitoredStations => 'Keine ueberwachte Bahnhoefe';

  @override
  String get monitoredTrains => 'Ueberwachte Zuege';

  @override
  String get noMonitoredTrains => 'Keine ueberwachte Zuege';

  @override
  String get noData => 'Keine Daten';

  @override
  String updatedAt(String value) {
    return 'Aktualisiert: $value';
  }

  @override
  String stationWithId(String id) {
    return 'Bahnhof $id';
  }

  @override
  String get customStyleUrl => 'Benutzerdefinierte Stil-URL';

  @override
  String get other => 'Andere';

  @override
  String get dark => 'Dunkel';

  @override
  String get light => 'Hell';

  @override
  String get streets => 'Strassen';

  @override
  String get satellite => 'Satellit';

  @override
  String get satelliteStreets => 'Sat+Strassen';

  @override
  String get auto => 'Auto';

  @override
  String get off => 'Aus';

  @override
  String get trainNotificationsConfig => 'Zugbenachrichtigungen konfigurieren';

  @override
  String get busNotificationsConfig => 'Busbenachrichtigungen konfigurieren';

  @override
  String get stationIdExample => 'Station ID (z. B. S01700)';

  @override
  String get providerExample => 'Anbieter (z. B. bari)';

  @override
  String get optionalBaseUrl => 'Basis-URL (optional)';

  @override
  String get test => 'Test';

  @override
  String get testTrains => 'Zug-Test';

  @override
  String get testBuses => 'Bus-Test';

  @override
  String get testFunctions => 'Funktions-Test';

  @override
  String get trainArrivalPreNotice => 'Ankunftsvorankündigung';

  @override
  String get trainArrivalPreNoticeDesc =>
      'Erhalten Sie eine Benachrichtigung N Minuten vor der geschätzten Ankunft an Ihrer Haltestelle (5–20 Minuten).';

  @override
  String get vectorTrainLogosDesc =>
      'Laden Sie offizielle Logos für Zugkategorien herunter (z. B. Frecciarossa, Intercity) anstelle von einfachem Text.';

  @override
  String get updateConfiguration => 'Konfiguration aktualisieren';

  @override
  String get configurationUpdateDesc =>
      'Laden Sie die neueste Busanbieter-Konfiguration vom Server herunter';

  @override
  String get updateProviderConfiguration =>
      'Anbieterkonfiguration aktualisieren';

  @override
  String get offlineSyncDesc =>
      'Routen- und Fahrplandaten werden automatisch heruntergeladen, wenn Sie eine Stadt synchronisieren. Die Daten werden lokal gespeichert und auch ohne Verbindung verfügbar sein.';

  @override
  String get disclaimerTitle =>
      'BC Transporter ersetzt keine offiziellen Kanäle';

  @override
  String get disclaimerText =>
      'Diese Anwendung ist in keiner Weise dazu gedacht, die offiziellen Plattformen der Eisenbahngesellschaften oder deren Vertriebskanäle zu ersetzen. BC Transporter stellt Informationen und Tracking-Daten rein zu Informationszwecken bereit.\n\nFür den Ticketkauf sowie zur Überprüfung von Verfügbarkeit, Tarifen, Reisebedingungen und offiziellen Bestätigungen müssen Sie sich ausschließlich an die offiziellen Kanäle der Eisenbahngesellschaften wenden (Websites, offizielle Apps, autorisierte Agenturen oder zertifizierte Händler).\n\nTickets müssen über offizielle Plattformen erworben werden; BC Transporter verkauft keine Tickets und ersetzt keine offiziellen Vertriebskanäle.\n\nWir übernehmen keine Verantwortung für Käufe über inoffizielle Kanäle oder für veraltete Preis-/Bedingungsinformationen. Eventuelle Links zu Drittanbieterseiten werden aus Gründen der Bequemlichkeit bereitgestellt und implizieren keine Zustimmung oder Partnerschaft.';

  @override
  String get user => 'Benutzer';
}

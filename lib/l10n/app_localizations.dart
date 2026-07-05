import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('it')
  ];

  /// The title of the application
  ///
  /// In it, this message translates to:
  /// **'BC Transporter'**
  String get appTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni'**
  String get settingsTitle;

  /// No description provided for @language.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get language;

  /// No description provided for @languageItalian.
  ///
  /// In it, this message translates to:
  /// **'Italiano'**
  String get languageItalian;

  /// No description provided for @languageEnglish.
  ///
  /// In it, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageGerman.
  ///
  /// In it, this message translates to:
  /// **'Deutsch'**
  String get languageGerman;

  /// No description provided for @theme.
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get theme;

  /// No description provided for @themeLight.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get themeDark;

  /// No description provided for @themeSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get themeSystem;

  /// No description provided for @selectedStop.
  ///
  /// In it, this message translates to:
  /// **'Fermata Selezionata'**
  String get selectedStop;

  /// No description provided for @stop.
  ///
  /// In it, this message translates to:
  /// **'Fermata'**
  String get stop;

  /// No description provided for @close.
  ///
  /// In it, this message translates to:
  /// **'Chiudi'**
  String get close;

  /// No description provided for @quickActions.
  ///
  /// In it, this message translates to:
  /// **'Azioni Rapide'**
  String get quickActions;

  /// No description provided for @mapStyle.
  ///
  /// In it, this message translates to:
  /// **'Stile Mappa'**
  String get mapStyle;

  /// No description provided for @mapStyleDesc.
  ///
  /// In it, this message translates to:
  /// **'Cambia l\'aspetto della cartina'**
  String get mapStyleDesc;

  /// No description provided for @favorites.
  ///
  /// In it, this message translates to:
  /// **'Preferiti'**
  String get favorites;

  /// No description provided for @favoritesDesc.
  ///
  /// In it, this message translates to:
  /// **'I tuoi treni e bus salvati'**
  String get favoritesDesc;

  /// No description provided for @notifications.
  ///
  /// In it, this message translates to:
  /// **'Notifiche'**
  String get notifications;

  /// No description provided for @notificationsDesc.
  ///
  /// In it, this message translates to:
  /// **'Gestisci i monitoraggi'**
  String get notificationsDesc;

  /// No description provided for @settingsDesc.
  ///
  /// In it, this message translates to:
  /// **'Configura l\'applicazione'**
  String get settingsDesc;

  /// No description provided for @searchTrainNumberHint.
  ///
  /// In it, this message translates to:
  /// **'Numero Treno (es: 9610)'**
  String get searchTrainNumberHint;

  /// No description provided for @searchStationHint.
  ///
  /// In it, this message translates to:
  /// **'Stazione (es: Roma Termini)'**
  String get searchStationHint;

  /// No description provided for @searchBusStopHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca fermata bus...'**
  String get searchBusStopHint;

  /// No description provided for @searchAirportHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca volo o aeroporto...'**
  String get searchAirportHint;

  /// No description provided for @searchDestinationHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca destinazione...'**
  String get searchDestinationHint;

  /// No description provided for @autoUpdate.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento Automatico'**
  String get autoUpdate;

  /// No description provided for @trains.
  ///
  /// In it, this message translates to:
  /// **'Treni'**
  String get trains;

  /// No description provided for @buses.
  ///
  /// In it, this message translates to:
  /// **'Autobus'**
  String get buses;

  /// No description provided for @planes.
  ///
  /// In it, this message translates to:
  /// **'Aerei'**
  String get planes;

  /// No description provided for @configuration.
  ///
  /// In it, this message translates to:
  /// **'Configurazione'**
  String get configuration;

  /// No description provided for @testNotifications.
  ///
  /// In it, this message translates to:
  /// **'Test Notifiche'**
  String get testNotifications;

  /// No description provided for @experienceUi.
  ///
  /// In it, this message translates to:
  /// **'Experience UI'**
  String get experienceUi;

  /// No description provided for @vectorTrainLogos.
  ///
  /// In it, this message translates to:
  /// **'Loghi Treni Vettoriali'**
  String get vectorTrainLogos;

  /// No description provided for @map.
  ///
  /// In it, this message translates to:
  /// **'Mappa'**
  String get map;

  /// No description provided for @busClustering.
  ///
  /// In it, this message translates to:
  /// **'Clustering Autobus'**
  String get busClustering;

  /// No description provided for @busClusteringDesc.
  ///
  /// In it, this message translates to:
  /// **'Raggruppa gli autobus vicini in cluster per una visualizzazione più chiara'**
  String get busClusteringDesc;

  /// No description provided for @stopClustering.
  ///
  /// In it, this message translates to:
  /// **'Clustering Fermate'**
  String get stopClustering;

  /// No description provided for @stopClusteringDesc.
  ///
  /// In it, this message translates to:
  /// **'Raggruppa le fermate vicine in cluster per una visualizzazione più chiara'**
  String get stopClusteringDesc;

  /// No description provided for @offlineSync.
  ///
  /// In it, this message translates to:
  /// **'Sincronizzazione Offline'**
  String get offlineSync;

  /// No description provided for @infoDisclaimer.
  ///
  /// In it, this message translates to:
  /// **'Informazioni e Disclaimer'**
  String get infoDisclaimer;

  /// No description provided for @managedByServer.
  ///
  /// In it, this message translates to:
  /// **'Gestito dal server in base al traffico'**
  String get managedByServer;

  /// No description provided for @goToMap.
  ///
  /// In it, this message translates to:
  /// **'Vai alla mappa'**
  String get goToMap;

  /// No description provided for @operator.
  ///
  /// In it, this message translates to:
  /// **'Operatore'**
  String get operator;

  /// No description provided for @reorderProviders.
  ///
  /// In it, this message translates to:
  /// **'Riordina provider'**
  String get reorderProviders;

  /// No description provided for @stops.
  ///
  /// In it, this message translates to:
  /// **'Fermate'**
  String get stops;

  /// No description provided for @lines.
  ///
  /// In it, this message translates to:
  /// **'Linee'**
  String get lines;

  /// No description provided for @solutions.
  ///
  /// In it, this message translates to:
  /// **'Soluzioni'**
  String get solutions;

  /// No description provided for @searchLineHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca linea...'**
  String get searchLineHint;

  /// No description provided for @searchStopHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca fermata...'**
  String get searchStopHint;

  /// No description provided for @nearYou.
  ///
  /// In it, this message translates to:
  /// **'Vicini a te'**
  String get nearYou;

  /// No description provided for @refresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get refresh;

  /// No description provided for @planJourney.
  ///
  /// In it, this message translates to:
  /// **'Pianifica Viaggio'**
  String get planJourney;

  /// No description provided for @departure.
  ///
  /// In it, this message translates to:
  /// **'Partenza'**
  String get departure;

  /// No description provided for @arrival.
  ///
  /// In it, this message translates to:
  /// **'Arrivo'**
  String get arrival;

  /// No description provided for @searchSolutions.
  ///
  /// In it, this message translates to:
  /// **'Cerca Soluzioni'**
  String get searchSolutions;

  /// No description provided for @select.
  ///
  /// In it, this message translates to:
  /// **'Seleziona'**
  String get select;

  /// No description provided for @noLinesLoaded.
  ///
  /// In it, this message translates to:
  /// **'Nessuna linea caricata'**
  String get noLinesLoaded;

  /// No description provided for @noLinesFound.
  ///
  /// In it, this message translates to:
  /// **'Nessuna linea trovata'**
  String get noLinesFound;

  /// No description provided for @loadLines.
  ///
  /// In it, this message translates to:
  /// **'Carica Linee'**
  String get loadLines;

  /// No description provided for @searchTravelSolution.
  ///
  /// In it, this message translates to:
  /// **'Cerca una soluzione di viaggio'**
  String get searchTravelSolution;

  /// No description provided for @noStopsFound.
  ///
  /// In it, this message translates to:
  /// **'Nessuna fermata trovata'**
  String get noStopsFound;

  /// No description provided for @showOnMap.
  ///
  /// In it, this message translates to:
  /// **'Mostra su mappa'**
  String get showOnMap;

  /// No description provided for @noActiveBusFound.
  ///
  /// In it, this message translates to:
  /// **'Nessun autobus attivo trovato\nper {city}'**
  String noActiveBusFound(String city);

  /// No description provided for @inTransit.
  ///
  /// In it, this message translates to:
  /// **'In viaggio'**
  String get inTransit;

  /// No description provided for @routeTowards.
  ///
  /// In it, this message translates to:
  /// **'Percorso verso'**
  String get routeTowards;

  /// No description provided for @cancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get cancel;

  /// No description provided for @searchStation.
  ///
  /// In it, this message translates to:
  /// **'Cerca stazione...'**
  String get searchStation;

  /// No description provided for @searchFlight.
  ///
  /// In it, this message translates to:
  /// **'Cerca volo o aeroporto...'**
  String get searchFlight;

  /// No description provided for @station.
  ///
  /// In it, this message translates to:
  /// **'Stazione'**
  String get station;

  /// No description provided for @train.
  ///
  /// In it, this message translates to:
  /// **'Treno'**
  String get train;

  /// No description provided for @flight.
  ///
  /// In it, this message translates to:
  /// **'Volo'**
  String get flight;

  /// No description provided for @error.
  ///
  /// In it, this message translates to:
  /// **'Errore'**
  String get error;

  /// No description provided for @loading.
  ///
  /// In it, this message translates to:
  /// **'Caricamento...'**
  String get loading;

  /// No description provided for @noResults.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato trovato'**
  String get noResults;

  /// No description provided for @showOnMapTitle.
  ///
  /// In it, this message translates to:
  /// **'Mostra su Mappa'**
  String get showOnMapTitle;

  /// No description provided for @searchByNumber.
  ///
  /// In it, this message translates to:
  /// **'Cerca per numero'**
  String get searchByNumber;

  /// No description provided for @searchByStation.
  ///
  /// In it, this message translates to:
  /// **'Cerca per stazione'**
  String get searchByStation;

  /// No description provided for @globalBeta.
  ///
  /// In it, this message translates to:
  /// **'Globale'**
  String get globalBeta;

  /// No description provided for @trainNumber.
  ///
  /// In it, this message translates to:
  /// **'Numero Treno'**
  String get trainNumber;

  /// No description provided for @allPlatforms.
  ///
  /// In it, this message translates to:
  /// **'Tutti i Binari'**
  String get allPlatforms;

  /// No description provided for @platform.
  ///
  /// In it, this message translates to:
  /// **'Binario'**
  String get platform;

  /// No description provided for @onTime.
  ///
  /// In it, this message translates to:
  /// **'In orario'**
  String get onTime;

  /// No description provided for @youAreOffline.
  ///
  /// In it, this message translates to:
  /// **'Sei offline'**
  String get youAreOffline;

  /// No description provided for @connectToSearchStations.
  ///
  /// In it, this message translates to:
  /// **'Connettiti per cercare nuove stazioni'**
  String get connectToSearchStations;

  /// No description provided for @savedTrains.
  ///
  /// In it, this message translates to:
  /// **'Treni Salvati'**
  String get savedTrains;

  /// No description provided for @accessOfflineData.
  ///
  /// In it, this message translates to:
  /// **'Accedi ai dati scaricati offline'**
  String get accessOfflineData;

  /// No description provided for @savedTrainsOffline.
  ///
  /// In it, this message translates to:
  /// **'Treni Salvati (Offline)'**
  String get savedTrainsOffline;

  /// No description provided for @noOfflineData.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato salvato offline'**
  String get noOfflineData;

  /// No description provided for @arrivals.
  ///
  /// In it, this message translates to:
  /// **'ARRIVI'**
  String get arrivals;

  /// No description provided for @departures.
  ///
  /// In it, this message translates to:
  /// **'PARTENZE'**
  String get departures;

  /// No description provided for @searchStationOrTrain.
  ///
  /// In it, this message translates to:
  /// **'Cerca stazione o treno...'**
  String get searchStationOrTrain;

  /// No description provided for @reorderCountries.
  ///
  /// In it, this message translates to:
  /// **'Riordina nazioni'**
  String get reorderCountries;

  /// No description provided for @allCities.
  ///
  /// In it, this message translates to:
  /// **'Tutte le città'**
  String get allCities;

  /// No description provided for @save.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get save;

  /// No description provided for @flightRadar.
  ///
  /// In it, this message translates to:
  /// **'Radar Voli'**
  String get flightRadar;

  /// No description provided for @airports.
  ///
  /// In it, this message translates to:
  /// **'AEROPORTI'**
  String get airports;

  /// No description provided for @searchAirportIcaoHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca aeroporto (ICAO/IATA)...'**
  String get searchAirportIcaoHint;

  /// No description provided for @noFlightsInRadar.
  ///
  /// In it, this message translates to:
  /// **'Nessun volo nel raggio radar'**
  String get noFlightsInRadar;

  /// No description provided for @searchResult.
  ///
  /// In it, this message translates to:
  /// **'RISULTATO RICERCA'**
  String get searchResult;

  /// No description provided for @nearbyAirports.
  ///
  /// In it, this message translates to:
  /// **'AEROPORTI VICINI'**
  String get nearbyAirports;

  /// No description provided for @airport.
  ///
  /// In it, this message translates to:
  /// **'Aeroporto'**
  String get airport;

  /// No description provided for @departures2.
  ///
  /// In it, this message translates to:
  /// **'Partenze'**
  String get departures2;

  /// No description provided for @arrivals2.
  ///
  /// In it, this message translates to:
  /// **'Arrivi'**
  String get arrivals2;

  /// No description provided for @noFlightsForAirport.
  ///
  /// In it, this message translates to:
  /// **'Nessun volo disponibile per questo aeroporto.'**
  String get noFlightsForAirport;

  /// No description provided for @back.
  ///
  /// In it, this message translates to:
  /// **'Torna indietro'**
  String get back;

  /// No description provided for @login.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get login;

  /// No description provided for @register.
  ///
  /// In it, this message translates to:
  /// **'Registrati'**
  String get register;

  /// No description provided for @welcomeTitle.
  ///
  /// In it, this message translates to:
  /// **'Benvenuto su\nBC Transporter'**
  String get welcomeTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Accedi al tuo account'**
  String get loginSubtitle;

  /// No description provided for @email.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @emailHint.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua email'**
  String get emailHint;

  /// No description provided for @emailRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci l\'email'**
  String get emailRequired;

  /// No description provided for @emailInvalid.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un\'email valida'**
  String get emailInvalid;

  /// No description provided for @password.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordHint.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password'**
  String get passwordHint;

  /// No description provided for @passwordRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password'**
  String get passwordRequired;

  /// No description provided for @passwordMin6.
  ///
  /// In it, this message translates to:
  /// **'La password deve essere di almeno 6 caratteri'**
  String get passwordMin6;

  /// No description provided for @noAccount.
  ///
  /// In it, this message translates to:
  /// **'Non hai un account?'**
  String get noAccount;

  /// No description provided for @createAccountTitle.
  ///
  /// In it, this message translates to:
  /// **'Crea il tuo\nAccount'**
  String get createAccountTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Unisciti alla comunita BC Transporter'**
  String get registerSubtitle;

  /// No description provided for @nickname.
  ///
  /// In it, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @nicknameHint.
  ///
  /// In it, this message translates to:
  /// **'Scegli un nickname'**
  String get nicknameHint;

  /// No description provided for @nicknameRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un nickname'**
  String get nicknameRequired;

  /// No description provided for @nicknameMin3.
  ///
  /// In it, this message translates to:
  /// **'Il nickname deve essere di almeno 3 caratteri'**
  String get nicknameMin3;

  /// No description provided for @createPasswordHint.
  ///
  /// In it, this message translates to:
  /// **'Crea una password sicura'**
  String get createPasswordHint;

  /// No description provided for @confirmPassword.
  ///
  /// In it, this message translates to:
  /// **'Conferma Password'**
  String get confirmPassword;

  /// No description provided for @repeatPassword.
  ///
  /// In it, this message translates to:
  /// **'Ripeti la password'**
  String get repeatPassword;

  /// No description provided for @confirmPasswordRequired.
  ///
  /// In it, this message translates to:
  /// **'Conferma la password'**
  String get confirmPasswordRequired;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non coincidono'**
  String get passwordsDoNotMatch;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In it, this message translates to:
  /// **'Hai gia un account?'**
  String get alreadyHaveAccount;

  /// No description provided for @registrationSuccess.
  ///
  /// In it, this message translates to:
  /// **'Registrazione completata con successo!'**
  String get registrationSuccess;

  /// No description provided for @dashboard.
  ///
  /// In it, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @logout.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get logout;

  /// No description provided for @welcomeUser.
  ///
  /// In it, this message translates to:
  /// **'Benvenuto{nickname}!'**
  String welcomeUser(String nickname);

  /// No description provided for @publicTransportExplore.
  ///
  /// In it, this message translates to:
  /// **'Esplora i trasporti pubblici'**
  String get publicTransportExplore;

  /// No description provided for @findBuses.
  ///
  /// In it, this message translates to:
  /// **'Trova autobus'**
  String get findBuses;

  /// No description provided for @trainTimes.
  ///
  /// In it, this message translates to:
  /// **'Orari treni'**
  String get trainTimes;

  /// No description provided for @flights.
  ///
  /// In it, this message translates to:
  /// **'Voli'**
  String get flights;

  /// No description provided for @flightInfo.
  ///
  /// In it, this message translates to:
  /// **'Informazioni voli'**
  String get flightInfo;

  /// No description provided for @viewRoutes.
  ///
  /// In it, this message translates to:
  /// **'Visualizza percorsi'**
  String get viewRoutes;

  /// No description provided for @yourProfile.
  ///
  /// In it, this message translates to:
  /// **'Il tuo Profilo'**
  String get yourProfile;

  /// No description provided for @memberSince.
  ///
  /// In it, this message translates to:
  /// **'Membro dal'**
  String get memberSince;

  /// No description provided for @notAvailable.
  ///
  /// In it, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// No description provided for @security.
  ///
  /// In it, this message translates to:
  /// **'Sicurezza'**
  String get security;

  /// No description provided for @changePassword.
  ///
  /// In it, this message translates to:
  /// **'Cambia Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In it, this message translates to:
  /// **'Password Attuale'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In it, this message translates to:
  /// **'Nuova Password'**
  String get newPassword;

  /// No description provided for @atLeast8Chars.
  ///
  /// In it, this message translates to:
  /// **'Almeno 8 caratteri'**
  String get atLeast8Chars;

  /// No description provided for @update.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna'**
  String get update;

  /// No description provided for @currentPasswordRequired.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la password attuale'**
  String get currentPasswordRequired;

  /// No description provided for @passwordMin8.
  ///
  /// In it, this message translates to:
  /// **'La password deve avere almeno 8 caratteri'**
  String get passwordMin8;

  /// No description provided for @newPasswordMustDiffer.
  ///
  /// In it, this message translates to:
  /// **'La nuova password deve essere diversa da quella attuale'**
  String get newPasswordMustDiffer;

  /// No description provided for @passwordChanged.
  ///
  /// In it, this message translates to:
  /// **'Password cambiata con successo!'**
  String get passwordChanged;

  /// No description provided for @currentPasswordWrong.
  ///
  /// In it, this message translates to:
  /// **'Password attuale non corretta'**
  String get currentPasswordWrong;

  /// No description provided for @changePasswordSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica la tua password di accesso'**
  String get changePasswordSubtitle;

  /// No description provided for @comingSoon.
  ///
  /// In it, this message translates to:
  /// **'Prossimamente'**
  String get comingSoon;

  /// No description provided for @newFeaturesComing.
  ///
  /// In it, this message translates to:
  /// **'Nuove funzionalita in arrivo!'**
  String get newFeaturesComing;

  /// No description provided for @newFeaturesBody.
  ///
  /// In it, this message translates to:
  /// **'Stiamo lavorando per offrirti un\'esperienza ancora migliore con nuove features esclusive.'**
  String get newFeaturesBody;

  /// No description provided for @statistics.
  ///
  /// In it, this message translates to:
  /// **'Statistiche'**
  String get statistics;

  /// No description provided for @alerts.
  ///
  /// In it, this message translates to:
  /// **'Avvisi'**
  String get alerts;

  /// No description provided for @sharing.
  ///
  /// In it, this message translates to:
  /// **'Condivisione'**
  String get sharing;

  /// No description provided for @backup.
  ///
  /// In it, this message translates to:
  /// **'Backup'**
  String get backup;

  /// No description provided for @notificationsManager.
  ///
  /// In it, this message translates to:
  /// **'Gestore notifiche'**
  String get notificationsManager;

  /// No description provided for @refreshAll.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna tutto'**
  String get refreshAll;

  /// No description provided for @refreshCompleted.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento completato'**
  String get refreshCompleted;

  /// No description provided for @monitorStopsStations.
  ///
  /// In it, this message translates to:
  /// **'Monitora fermate e stazioni'**
  String get monitorStopsStations;

  /// No description provided for @monitoredStops.
  ///
  /// In it, this message translates to:
  /// **'Fermate monitorate'**
  String get monitoredStops;

  /// No description provided for @noMonitoredStops.
  ///
  /// In it, this message translates to:
  /// **'Nessuna fermata monitorata'**
  String get noMonitoredStops;

  /// No description provided for @removeMonitoring.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi monitoraggio'**
  String get removeMonitoring;

  /// No description provided for @removeStopQuestion.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere la fermata {name}?'**
  String removeStopQuestion(String name);

  /// No description provided for @removeTrainQuestion.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere il monitoraggio per il treno {name}?'**
  String removeTrainQuestion(String name);

  /// No description provided for @removeStationQuestion.
  ///
  /// In it, this message translates to:
  /// **'Rimuovere la stazione {name}?'**
  String removeStationQuestion(String name);

  /// No description provided for @remove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get remove;

  /// No description provided for @forceRefresh.
  ///
  /// In it, this message translates to:
  /// **'Aggiornamento forzato'**
  String get forceRefresh;

  /// No description provided for @notificationCancelled.
  ///
  /// In it, this message translates to:
  /// **'Notifica cancellata'**
  String get notificationCancelled;

  /// No description provided for @cancelNotification.
  ///
  /// In it, this message translates to:
  /// **'Cancella notifica'**
  String get cancelNotification;

  /// No description provided for @monitoredStations.
  ///
  /// In it, this message translates to:
  /// **'Stazioni monitorate'**
  String get monitoredStations;

  /// No description provided for @noMonitoredStations.
  ///
  /// In it, this message translates to:
  /// **'Nessuna stazione monitorata'**
  String get noMonitoredStations;

  /// No description provided for @monitoredTrains.
  ///
  /// In it, this message translates to:
  /// **'Treni monitorati'**
  String get monitoredTrains;

  /// No description provided for @noMonitoredTrains.
  ///
  /// In it, this message translates to:
  /// **'Nessun treno monitorato'**
  String get noMonitoredTrains;

  /// No description provided for @noData.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato'**
  String get noData;

  /// No description provided for @updatedAt.
  ///
  /// In it, this message translates to:
  /// **'Aggiornato: {value}'**
  String updatedAt(String value);

  /// No description provided for @stationWithId.
  ///
  /// In it, this message translates to:
  /// **'Stazione {id}'**
  String stationWithId(String id);

  /// No description provided for @customStyleUrl.
  ///
  /// In it, this message translates to:
  /// **'URL stile personalizzato'**
  String get customStyleUrl;

  /// No description provided for @other.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get other;

  /// No description provided for @dark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get dark;

  /// No description provided for @light.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get light;

  /// No description provided for @streets.
  ///
  /// In it, this message translates to:
  /// **'Strade'**
  String get streets;

  /// No description provided for @satellite.
  ///
  /// In it, this message translates to:
  /// **'Satellite'**
  String get satellite;

  /// No description provided for @satelliteStreets.
  ///
  /// In it, this message translates to:
  /// **'Sat+Str'**
  String get satelliteStreets;

  /// No description provided for @auto.
  ///
  /// In it, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @off.
  ///
  /// In it, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @trainNotificationsConfig.
  ///
  /// In it, this message translates to:
  /// **'Configura notifiche treni'**
  String get trainNotificationsConfig;

  /// No description provided for @busNotificationsConfig.
  ///
  /// In it, this message translates to:
  /// **'Configura notifiche autobus'**
  String get busNotificationsConfig;

  /// No description provided for @stationIdExample.
  ///
  /// In it, this message translates to:
  /// **'Station ID (es. S01700)'**
  String get stationIdExample;

  /// No description provided for @providerExample.
  ///
  /// In it, this message translates to:
  /// **'Provider (es. bari)'**
  String get providerExample;

  /// No description provided for @optionalBaseUrl.
  ///
  /// In it, this message translates to:
  /// **'Base URL (opzionale)'**
  String get optionalBaseUrl;

  /// No description provided for @test.
  ///
  /// In it, this message translates to:
  /// **'Test'**
  String get test;

  /// No description provided for @testTrains.
  ///
  /// In it, this message translates to:
  /// **'Test Treni'**
  String get testTrains;

  /// No description provided for @testBuses.
  ///
  /// In it, this message translates to:
  /// **'Test Bus'**
  String get testBuses;

  /// No description provided for @testFunctions.
  ///
  /// In it, this message translates to:
  /// **'Test Funzioni'**
  String get testFunctions;

  /// No description provided for @trainArrivalPreNotice.
  ///
  /// In it, this message translates to:
  /// **'Preavviso arrivo stazione'**
  String get trainArrivalPreNotice;

  /// No description provided for @trainArrivalPreNoticeDesc.
  ///
  /// In it, this message translates to:
  /// **'Ricevi un avviso N minuti prima dell\'arrivo stimato alla tua fermata (5–20 minuti).'**
  String get trainArrivalPreNoticeDesc;

  /// No description provided for @vectorTrainLogosDesc.
  ///
  /// In it, this message translates to:
  /// **'Scarica e visualizza loghi ufficiali per le categorie dei treni (es. Frecciarossa, Intercity) invece del testo semplice.'**
  String get vectorTrainLogosDesc;

  /// No description provided for @updateConfiguration.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna Configurazione'**
  String get updateConfiguration;

  /// No description provided for @configurationUpdateDesc.
  ///
  /// In it, this message translates to:
  /// **'Scarica l\'ultima configurazione dei provider di autobus dal server'**
  String get configurationUpdateDesc;

  /// No description provided for @updateProviderConfiguration.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna configurazione provider'**
  String get updateProviderConfiguration;

  /// No description provided for @offlineSyncDesc.
  ///
  /// In it, this message translates to:
  /// **'Scarica automaticamente i dati di percorsi e orari quando sincronizzi da una città. I dati verranno salvati localmente e disponibili anche senza connessione.'**
  String get offlineSyncDesc;

  /// No description provided for @disclaimerTitle.
  ///
  /// In it, this message translates to:
  /// **'BC Transporter Non Sostituisce i Canali Ufficiali'**
  String get disclaimerTitle;

  /// No description provided for @disclaimerText.
  ///
  /// In it, this message translates to:
  /// **'Questa applicazione non intende in alcun modo sostituire le piattaforme ufficiali delle compagnie ferroviarie o i loro canali di vendita. BC Transporter fornisce informazioni e dati di tracciamento a scopo puramente informativo.\n\nPer l\'acquisto dei biglietti e per verificare disponibilità, tariffe, condizioni di viaggio e conferme ufficiali, è necessario rivolgersi esclusivamente ai canali ufficiali delle compagnie ferroviarie (siti web, app ufficiali, agenzie autorizzate o rivenditori certificati).\n\nI biglietti devono essere acquistati tramite le piattaforme ufficiali; BC Transporter non vende biglietti e non sostituisce i canali ufficiali di vendita.\n\nNon ci assumiamo responsabilità per acquisti effettuati su canali non ufficiali o per informazioni di prezzo/condizioni non aggiornate. Eventuali link a siti di terze parti sono forniti a scopo di comodità e non implicano approvazione o partnership.'**
  String get disclaimerText;

  /// No description provided for @user.
  ///
  /// In it, this message translates to:
  /// **'Utente'**
  String get user;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

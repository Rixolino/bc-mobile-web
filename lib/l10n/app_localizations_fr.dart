// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'BC Transporter';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get language => 'Langue';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get theme => 'Thème';

  @override
  String get themeLight => 'Clair';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeSystem => 'Système';

  @override
  String get selectedStop => 'Arrêt sélectionné';

  @override
  String get stop => 'Arrêt';

  @override
  String get close => 'Fermer';

  @override
  String get quickActions => 'Actions rapides';

  @override
  String get mapStyle => 'Style de carte';

  @override
  String get mapStyleDesc => 'Changer l’apparence de la carte';

  @override
  String get favorites => 'Favoris';

  @override
  String get favoritesDesc => 'Vos trains et bus enregistrés';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDesc => 'Gérer le suivi';

  @override
  String get settingsDesc => 'Configurer l’application';

  @override
  String get searchTrainNumberHint => 'Numéro de train (ex. 9610)';

  @override
  String get searchStationHint => 'Gare (ex. Roma Termini)';

  @override
  String get searchBusStopHint => 'Rechercher un arrêt...';

  @override
  String get searchAirportHint => 'Rechercher un vol ou aéroport...';

  @override
  String get searchDestinationHint => 'Rechercher une destination...';

  @override
  String get autoUpdate => 'Mise à jour auto';

  @override
  String get trains => 'Trains';

  @override
  String get buses => 'Bus';

  @override
  String get planes => 'Avions';

  @override
  String get configuration => 'Configuration';

  @override
  String get testNotifications => 'Test des notifications';

  @override
  String get experienceUi => 'Expérience IU';

  @override
  String get vectorTrainLogos => 'Logos vectoriels des trains';

  @override
  String get map => 'Carte';

  @override
  String get busClustering => 'Regroupement bus';

  @override
  String get busClusteringDesc => 'Raggruppa gli autobus vicini in cluster per una visualizzazione più chiara';

  @override
  String get stopClustering => 'Regroupement arrêts';

  @override
  String get stopClusteringDesc => 'Raggruppa le fermate vicine in cluster per una visualizzazione più chiara';

  @override
  String get offlineSync => 'Synchro hors ligne';

  @override
  String get infoDisclaimer => 'Infos et mentions';

  @override
  String get managedByServer => 'Géré par le serveur selon le trafic';

  @override
  String get goToMap => 'Aller à la carte';

  @override
  String get operator => 'Opérateur';

  @override
  String get reorderProviders => 'Réordonner les fournisseurs';

  @override
  String get stops => 'Arrêts';

  @override
  String get lines => 'Lignes';

  @override
  String get solutions => 'Solutions';

  @override
  String get searchLineHint => 'Rechercher une ligne...';

  @override
  String get searchStopHint => 'Rechercher un arrêt...';

  @override
  String get nearYou => 'Près de vous';

  @override
  String get refresh => 'Actualiser';

  @override
  String get planJourney => 'Planifier un trajet';

  @override
  String get departure => 'Départ';

  @override
  String get arrival => 'Arrivée';

  @override
  String get searchSolutions => 'Rechercher';

  @override
  String get select => 'Choisir';

  @override
  String get noLinesLoaded => 'Aucune ligne chargée';

  @override
  String get noLinesFound => 'Aucune ligne trouvée';

  @override
  String get loadLines => 'Charger les lignes';

  @override
  String get searchTravelSolution => 'Rechercher une solution de voyage';

  @override
  String get noStopsFound => 'Aucun arrêt trouvé';

  @override
  String get showOnMap => 'Voir sur la carte';

  @override
  String noActiveBusFound(String city) {
    return 'Aucun bus actif\npour $city';
  }

  @override
  String get inTransit => 'En transit';

  @override
  String get routeTowards => 'Direction';

  @override
  String get cancel => 'Annuler';

  @override
  String get searchStation => 'Rechercher une gare...';

  @override
  String get searchFlight => 'Rechercher un vol ou aéroport...';

  @override
  String get station => 'Gare';

  @override
  String get train => 'Train';

  @override
  String get flight => 'Vol';

  @override
  String get error => 'Erreur';

  @override
  String get loading => 'Chargement...';

  @override
  String get noResults => 'Aucun résultat';

  @override
  String get showOnMapTitle => 'Voir sur la carte';

  @override
  String get searchByNumber => 'Par numéro';

  @override
  String get searchByStation => 'Par gare';

  @override
  String get globalBeta => 'Global';

  @override
  String get trainNumber => 'Numéro de train';

  @override
  String get allPlatforms => 'Toutes les voies';

  @override
  String get platform => 'Voie';

  @override
  String get onTime => 'À l’heure';

  @override
  String get youAreOffline => 'Vous êtes hors ligne';

  @override
  String get connectToSearchStations => 'Connectez-vous pour chercher de nouvelles gares';

  @override
  String get savedTrains => 'Trains enregistrés';

  @override
  String get accessOfflineData => 'Accéder aux données hors ligne';

  @override
  String get savedTrainsOffline => 'Trains enregistrés (hors ligne)';

  @override
  String get noOfflineData => 'Aucune donnée hors ligne';

  @override
  String get arrivals => 'ARRIVÉES';

  @override
  String get departures => 'DÉPARTS';

  @override
  String get searchStationOrTrain => 'Rechercher gare ou train...';

  @override
  String get reorderCountries => 'Réordonner les pays';

  @override
  String get allCities => 'Toutes les villes';

  @override
  String get save => 'Enregistrer';

  @override
  String get flightRadar => 'Radar de vols';

  @override
  String get airports => 'AÉROPORTS';

  @override
  String get searchAirportIcaoHint => 'Rechercher un aéroport (ICAO/IATA)...';

  @override
  String get noFlightsInRadar => 'Aucun vol dans la zone radar';

  @override
  String get searchResult => 'RÉSULTAT';

  @override
  String get nearbyAirports => 'AÉROPORTS PROCHES';

  @override
  String get airport => 'Aéroport';

  @override
  String get departures2 => 'Départs';

  @override
  String get arrivals2 => 'Arrivées';

  @override
  String get noFlightsForAirport => 'Aucun vol pour cet aéroport.';

  @override
  String get back => 'Retour';

  @override
  String get login => 'Connexion';

  @override
  String get register => 'Inscription';

  @override
  String get welcomeTitle => 'Bienvenue sur\nBC Transporter';

  @override
  String get loginSubtitle => 'Connectez-vous à votre compte';

  @override
  String get email => 'E-mail';

  @override
  String get emailHint => 'Saisissez votre e-mail';

  @override
  String get emailRequired => 'Saisissez votre e-mail';

  @override
  String get emailInvalid => 'Saisissez un e-mail valide';

  @override
  String get password => 'Mot de passe';

  @override
  String get passwordHint => 'Saisissez votre mot de passe';

  @override
  String get passwordRequired => 'Saisissez votre mot de passe';

  @override
  String get passwordMin6 => '6 caractères minimum';

  @override
  String get noAccount => 'Pas encore de compte ?';

  @override
  String get createAccountTitle => 'Créez votre\ncompte';

  @override
  String get registerSubtitle => 'Rejoignez la communauté BC Transporter';

  @override
  String get nickname => 'Pseudo';

  @override
  String get nicknameHint => 'Choisissez un pseudo';

  @override
  String get nicknameRequired => 'Saisissez un pseudo';

  @override
  String get nicknameMin3 => '3 caractères minimum';

  @override
  String get createPasswordHint => 'Créez un mot de passe sûr';

  @override
  String get confirmPassword => 'Confirmer le mot de passe';

  @override
  String get repeatPassword => 'Répétez votre mot de passe';

  @override
  String get confirmPasswordRequired => 'Confirmez votre mot de passe';

  @override
  String get passwordsDoNotMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get alreadyHaveAccount => 'Déjà un compte ?';

  @override
  String get registrationSuccess => 'Inscription réussie !';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get logout => 'Déconnexion';

  @override
  String welcomeUser(String nickname) {
    return 'Bienvenue$nickname !';
  }

  @override
  String get publicTransportExplore => 'Explorer les transports publics';

  @override
  String get findBuses => 'Trouver des bus';

  @override
  String get trainTimes => 'Horaires des trains';

  @override
  String get flights => 'Vols';

  @override
  String get flightInfo => 'Infos de vol';

  @override
  String get viewRoutes => 'Voir les itinéraires';

  @override
  String get yourProfile => 'Votre profil';

  @override
  String get memberSince => 'Membre depuis';

  @override
  String get notAvailable => 'N/D';

  @override
  String get security => 'Sécurité';

  @override
  String get changePassword => 'Changer le mot de passe';

  @override
  String get currentPassword => 'Mot de passe actuel';

  @override
  String get newPassword => 'Nouveau mot de passe';

  @override
  String get atLeast8Chars => '8 caractères minimum';

  @override
  String get update => 'Mettre à jour';

  @override
  String get currentPasswordRequired => 'Saisissez votre mot de passe actuel';

  @override
  String get passwordMin8 => '8 caractères minimum';

  @override
  String get newPasswordMustDiffer => 'Le nouveau mot de passe doit différer de l’actuel';

  @override
  String get passwordChanged => 'Mot de passe modifié !';

  @override
  String get currentPasswordWrong => 'Mot de passe actuel incorrect';

  @override
  String get changePasswordSubtitle => 'Changez votre mot de passe';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get newFeaturesComing => 'De nouvelles fonctions arrivent !';

  @override
  String get newFeaturesBody => 'Nous travaillons pour vous offrir une expérience encore meilleure.';

  @override
  String get statistics => 'Statistiques';

  @override
  String get alerts => 'Alertes';

  @override
  String get sharing => 'Partage';

  @override
  String get backup => 'Sauvegarde';

  @override
  String get notificationsManager => 'Gestionnaire de notifications';

  @override
  String get refreshAll => 'Tout actualiser';

  @override
  String get refreshCompleted => 'Actualisation terminée';

  @override
  String get monitorStopsStations => 'Surveiller arrêts et gares';

  @override
  String get monitoredStops => 'Arrêts surveillés';

  @override
  String get noMonitoredStops => 'Aucun arrêt surveillé';

  @override
  String get removeMonitoring => 'Retirer la surveillance';

  @override
  String removeStopQuestion(String name) {
    return 'Retirer l’arrêt $name ?';
  }

  @override
  String removeTrainQuestion(String name) {
    return 'Retirer le suivi du train $name ?';
  }

  @override
  String removeStationQuestion(String name) {
    return 'Retirer la gare $name ?';
  }

  @override
  String get remove => 'Retirer';

  @override
  String get forceRefresh => 'Actualisation forcée';

  @override
  String get notificationCancelled => 'Notification annulée';

  @override
  String get cancelNotification => 'Annuler la notification';

  @override
  String get monitoredStations => 'Gares surveillées';

  @override
  String get noMonitoredStations => 'Aucune gare surveillée';

  @override
  String get monitoredTrains => 'Trains surveillés';

  @override
  String get noMonitoredTrains => 'Aucun train surveillé';

  @override
  String get noData => 'Aucune donnée';

  @override
  String updatedAt(String value) {
    return 'Mis à jour : $value';
  }

  @override
  String stationWithId(String id) {
    return 'Gare $id';
  }

  @override
  String get customStyleUrl => 'URL de style personnalisé';

  @override
  String get other => 'Autre';

  @override
  String get dark => 'Sombre';

  @override
  String get light => 'Clair';

  @override
  String get streets => 'Rues';

  @override
  String get satellite => 'Satellite';

  @override
  String get satelliteStreets => 'Sat+Rues';

  @override
  String get auto => 'Auto';

  @override
  String get off => 'Off';

  @override
  String get trainNotificationsConfig => 'Configurer les notifications trains';

  @override
  String get busNotificationsConfig => 'Configurer les notifications bus';

  @override
  String get stationIdExample => 'ID gare (ex. S01700)';

  @override
  String get providerExample => 'Fournisseur (ex. bari)';

  @override
  String get optionalBaseUrl => 'URL de base (facultatif)';

  @override
  String get test => 'Test';

  @override
  String get testTrains => 'Tester les trains';

  @override
  String get testBuses => 'Tester les bus';

  @override
  String get testFunctions => 'Tester les fonctions';

  @override
  String get trainArrivalPreNotice => 'Préavis d’arrivée en gare';

  @override
  String get trainArrivalPreNoticeDesc => 'Recevez une notification N minutes avant l’arrivée estimée à votre arrêt (5–20 minutes)';

  @override
  String get vectorTrainLogosDesc => 'Télécharge et affiche les logos officiels des catégories de trains (ex. Frecciarossa, Intercity) au lieu du texte.';

  @override
  String get updateConfiguration => 'Mettre à jour la configuration';

  @override
  String get configurationUpdateDesc => 'Télécharge la dernière configuration du fournisseur de bus depuis le serveur';

  @override
  String get updateProviderConfiguration => 'Mettre à jour la configuration du fournisseur';

  @override
  String get offlineSyncDesc => 'Télécharge automatiquement itinéraires et horaires lors de la synchro depuis une ville.';

  @override
  String get disclaimerTitle => 'BC Transporter ne remplace pas les canaux officiels';

  @override
  String get disclaimerText => 'Cette application ne remplace en rien les plateformes officielles des compagnies.';

  @override
  String get user => 'Utilisateur';
}

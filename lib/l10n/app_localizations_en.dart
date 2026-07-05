// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BC Transporter';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageItalian => 'Italiano';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get theme => 'Theme';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSystem => 'System';

  @override
  String get selectedStop => 'Selected Stop';

  @override
  String get stop => 'Stop';

  @override
  String get close => 'Close';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get mapStyle => 'Map Style';

  @override
  String get mapStyleDesc => 'Change map appearance';

  @override
  String get favorites => 'Favorites';

  @override
  String get favoritesDesc => 'Your saved trains and buses';

  @override
  String get notifications => 'Notifications';

  @override
  String get notificationsDesc => 'Manage tracking';

  @override
  String get settingsDesc => 'Configure application';

  @override
  String get searchTrainNumberHint => 'Train Number (e.g. 9610)';

  @override
  String get searchStationHint => 'Station (e.g. Roma Termini)';

  @override
  String get searchBusStopHint => 'Search bus stop...';

  @override
  String get searchAirportHint => 'Search flight or airport...';

  @override
  String get searchDestinationHint => 'Search destination...';

  @override
  String get autoUpdate => 'Auto Update';

  @override
  String get trains => 'Trains';

  @override
  String get buses => 'Buses';

  @override
  String get planes => 'Planes';

  @override
  String get configuration => 'Configuration';

  @override
  String get testNotifications => 'Notification Test';

  @override
  String get experienceUi => 'UI Experience';

  @override
  String get vectorTrainLogos => 'Vector Train Logos';

  @override
  String get map => 'Map';

  @override
  String get busClustering => 'Bus Clustering';

  @override
  String get busClusteringDesc =>
      'Raggruppa gli autobus vicini in cluster per una visualizzazione più chiara';

  @override
  String get stopClustering => 'Stop Clustering';

  @override
  String get stopClusteringDesc =>
      'Raggruppa le fermate vicine in cluster per una visualizzazione più chiara';

  @override
  String get offlineSync => 'Offline Synchronization';

  @override
  String get infoDisclaimer => 'Info & Disclaimer';

  @override
  String get managedByServer => 'Managed by server based on traffic';

  @override
  String get goToMap => 'Go to map';

  @override
  String get operator => 'Operator';

  @override
  String get reorderProviders => 'Reorder providers';

  @override
  String get stops => 'Stops';

  @override
  String get lines => 'Lines';

  @override
  String get solutions => 'Solutions';

  @override
  String get searchLineHint => 'Search line...';

  @override
  String get searchStopHint => 'Search stop...';

  @override
  String get nearYou => 'Near you';

  @override
  String get refresh => 'Refresh';

  @override
  String get planJourney => 'Plan Journey';

  @override
  String get departure => 'Departure';

  @override
  String get arrival => 'Arrival';

  @override
  String get searchSolutions => 'Search Solutions';

  @override
  String get select => 'Select';

  @override
  String get noLinesLoaded => 'No lines loaded';

  @override
  String get noLinesFound => 'No lines found';

  @override
  String get loadLines => 'Load Lines';

  @override
  String get searchTravelSolution => 'Search for a travel solution';

  @override
  String get noStopsFound => 'No stops found';

  @override
  String get showOnMap => 'Show on map';

  @override
  String noActiveBusFound(String city) {
    return 'No active bus found\nfor $city';
  }

  @override
  String get inTransit => 'In transit';

  @override
  String get routeTowards => 'Route towards';

  @override
  String get cancel => 'Cancel';

  @override
  String get searchStation => 'Search station...';

  @override
  String get searchFlight => 'Search flight or airport...';

  @override
  String get station => 'Station';

  @override
  String get train => 'Train';

  @override
  String get flight => 'Flight';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading...';

  @override
  String get noResults => 'No results found';

  @override
  String get showOnMapTitle => 'Show on Map';

  @override
  String get searchByNumber => 'Search by number';

  @override
  String get searchByStation => 'Search by station';

  @override
  String get globalBeta => 'Global';

  @override
  String get trainNumber => 'Train Number';

  @override
  String get allPlatforms => 'All Platforms';

  @override
  String get platform => 'Platform';

  @override
  String get onTime => 'On time';

  @override
  String get youAreOffline => 'You are offline';

  @override
  String get connectToSearchStations => 'Connect to search for new stations';

  @override
  String get savedTrains => 'Saved Trains';

  @override
  String get accessOfflineData => 'Access downloaded offline data';

  @override
  String get savedTrainsOffline => 'Saved Trains (Offline)';

  @override
  String get noOfflineData => 'No offline data saved';

  @override
  String get arrivals => 'ARRIVALS';

  @override
  String get departures => 'DEPARTURES';

  @override
  String get searchStationOrTrain => 'Search station or train...';

  @override
  String get reorderCountries => 'Reorder countries';

  @override
  String get allCities => 'All cities';

  @override
  String get save => 'Save';

  @override
  String get flightRadar => 'Flight Radar';

  @override
  String get airports => 'AIRPORTS';

  @override
  String get searchAirportIcaoHint => 'Search airport (ICAO/IATA)...';

  @override
  String get noFlightsInRadar => 'No flights in radar range';

  @override
  String get searchResult => 'SEARCH RESULT';

  @override
  String get nearbyAirports => 'NEARBY AIRPORTS';

  @override
  String get airport => 'Airport';

  @override
  String get departures2 => 'Departures';

  @override
  String get arrivals2 => 'Arrivals';

  @override
  String get noFlightsForAirport => 'No flights available for this airport.';

  @override
  String get back => 'Go back';

  @override
  String get login => 'Log in';

  @override
  String get register => 'Sign up';

  @override
  String get welcomeTitle => 'Welcome to\nBC Transporter';

  @override
  String get loginSubtitle => 'Log in to your account';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get emailRequired => 'Enter your email';

  @override
  String get emailInvalid => 'Enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get passwordMin6 => 'Password must be at least 6 characters';

  @override
  String get noAccount => 'Don\'t have an account?';

  @override
  String get createAccountTitle => 'Create your\nAccount';

  @override
  String get registerSubtitle => 'Join the BC Transporter community';

  @override
  String get nickname => 'Nickname';

  @override
  String get nicknameHint => 'Choose a nickname';

  @override
  String get nicknameRequired => 'Enter a nickname';

  @override
  String get nicknameMin3 => 'Nickname must be at least 3 characters';

  @override
  String get createPasswordHint => 'Create a secure password';

  @override
  String get confirmPassword => 'Confirm Password';

  @override
  String get repeatPassword => 'Repeat your password';

  @override
  String get confirmPasswordRequired => 'Confirm your password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get registrationSuccess => 'Registration completed successfully!';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get logout => 'Logout';

  @override
  String welcomeUser(String nickname) {
    return 'Welcome$nickname!';
  }

  @override
  String get publicTransportExplore => 'Explore public transport';

  @override
  String get findBuses => 'Find buses';

  @override
  String get trainTimes => 'Train times';

  @override
  String get flights => 'Flights';

  @override
  String get flightInfo => 'Flight information';

  @override
  String get viewRoutes => 'View routes';

  @override
  String get yourProfile => 'Your Profile';

  @override
  String get memberSince => 'Member since';

  @override
  String get notAvailable => 'N/A';

  @override
  String get security => 'Security';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current Password';

  @override
  String get newPassword => 'New Password';

  @override
  String get atLeast8Chars => 'At least 8 characters';

  @override
  String get update => 'Update';

  @override
  String get currentPasswordRequired => 'Enter your current password';

  @override
  String get passwordMin8 => 'Password must be at least 8 characters';

  @override
  String get newPasswordMustDiffer =>
      'The new password must be different from the current one';

  @override
  String get passwordChanged => 'Password changed successfully!';

  @override
  String get currentPasswordWrong => 'Current password is incorrect';

  @override
  String get changePasswordSubtitle => 'Change your login password';

  @override
  String get comingSoon => 'Coming Soon';

  @override
  String get newFeaturesComing => 'New features are coming!';

  @override
  String get newFeaturesBody =>
      'We are working to give you an even better experience with new exclusive features.';

  @override
  String get statistics => 'Statistics';

  @override
  String get alerts => 'Alerts';

  @override
  String get sharing => 'Sharing';

  @override
  String get backup => 'Backup';

  @override
  String get notificationsManager => 'Notifications Manager';

  @override
  String get refreshAll => 'Refresh all';

  @override
  String get refreshCompleted => 'Refresh completed';

  @override
  String get monitorStopsStations => 'Monitor stops and stations';

  @override
  String get monitoredStops => 'Monitored stops';

  @override
  String get noMonitoredStops => 'No monitored stops';

  @override
  String get removeMonitoring => 'Remove monitoring';

  @override
  String removeStopQuestion(String name) {
    return 'Remove stop $name?';
  }

  @override
  String removeTrainQuestion(String name) {
    return 'Remove monitoring for train $name?';
  }

  @override
  String removeStationQuestion(String name) {
    return 'Remove station $name?';
  }

  @override
  String get remove => 'Remove';

  @override
  String get forceRefresh => 'Forced refresh';

  @override
  String get notificationCancelled => 'Notification cancelled';

  @override
  String get cancelNotification => 'Cancel notification';

  @override
  String get monitoredStations => 'Monitored stations';

  @override
  String get noMonitoredStations => 'No monitored stations';

  @override
  String get monitoredTrains => 'Monitored trains';

  @override
  String get noMonitoredTrains => 'No monitored trains';

  @override
  String get noData => 'No data';

  @override
  String updatedAt(String value) {
    return 'Updated: $value';
  }

  @override
  String stationWithId(String id) {
    return 'Station $id';
  }

  @override
  String get customStyleUrl => 'Custom style URL';

  @override
  String get other => 'Other';

  @override
  String get dark => 'Dark';

  @override
  String get light => 'Light';

  @override
  String get streets => 'Streets';

  @override
  String get satellite => 'Satellite';

  @override
  String get satelliteStreets => 'Sat+Streets';

  @override
  String get auto => 'Auto';

  @override
  String get off => 'Off';

  @override
  String get trainNotificationsConfig => 'Configure train notifications';

  @override
  String get busNotificationsConfig => 'Configure bus notifications';

  @override
  String get stationIdExample => 'Station ID (e.g. S01700)';

  @override
  String get providerExample => 'Provider (e.g. bari)';

  @override
  String get optionalBaseUrl => 'Base URL (optional)';

  @override
  String get test => 'Test';

  @override
  String get testTrains => 'Test Trains';

  @override
  String get testBuses => 'Test Buses';

  @override
  String get testFunctions => 'Test Functions';

  @override
  String get trainArrivalPreNotice => 'Station Arrival Notice';

  @override
  String get trainArrivalPreNoticeDesc =>
      'Receive a notification N minutes before the estimated arrival at your stop (5–20 minutes).';

  @override
  String get vectorTrainLogosDesc =>
      'Download and display official logos for train categories (e.g. Frecciarossa, Intercity) instead of plain text.';

  @override
  String get updateConfiguration => 'Update Configuration';

  @override
  String get configurationUpdateDesc =>
      'Download the latest bus provider configuration from the server';

  @override
  String get updateProviderConfiguration => 'Update provider configuration';

  @override
  String get offlineSyncDesc =>
      'Automatically download route and timetable data when syncing from a city. Data will be saved locally and available even without a connection.';

  @override
  String get disclaimerTitle =>
      'BC Transporter Does Not Replace Official Channels';

  @override
  String get disclaimerText =>
      'This application is in no way intended to replace the official platforms of railway companies or their sales channels. BC Transporter provides information and tracking data for purely informational purposes.\n\nTo purchase tickets and verify availability, fares, travel conditions and official confirmations, you must refer exclusively to the official channels of the railway companies (websites, official apps, authorized agencies or certified retailers).\n\nTickets must be purchased through official platforms; BC Transporter does not sell tickets and does not replace official sales channels.\n\nWe assume no responsibility for purchases made through unofficial channels or for outdated price/condition information. Any links to third-party sites are provided for convenience and do not imply approval or partnership.';

  @override
  String get user => 'User';
}

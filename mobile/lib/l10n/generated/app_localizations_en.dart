// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'beebeebike';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get loginTitle => 'Log in';

  @override
  String get loginSubmit => 'Log in';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginErrorEmptyEmail => 'Enter your email';

  @override
  String get loginErrorEmptyPassword => 'Enter your password';

  @override
  String get loginErrorInvalid => 'Invalid email or password';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubmit => 'Create account';

  @override
  String get registerErrorPasswordTooShort =>
      'Password must be at least 8 characters';

  @override
  String get registerErrorEmailTaken =>
      'An account with this email already exists';

  @override
  String get registerErrorGeneric =>
      'Could not create account. Please try again.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGuest => 'Guest';

  @override
  String get settingsHome => 'Home';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsLogIn => 'Log in';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsSectionCredits => 'Shout outs';

  @override
  String get settingsCreditOsm => 'Map data © OpenStreetMap contributors';

  @override
  String get settingsCreditMaplibre => 'Map rendering by MapLibre';

  @override
  String get settingsCreditGraphhopper => 'Routing by GraphHopper';

  @override
  String get settingsCreditPhoton => 'Geocoding by Photon, hosted by Komoot';

  @override
  String get settingsSectionLegal => 'Legal';

  @override
  String get settingsLegalPrivacy => 'Privacy policy';

  @override
  String get settingsLegalImprint => 'Imprint';

  @override
  String get settingsSectionDanger => 'Danger zone';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Permanently removes your account, ratings and locations.';

  @override
  String get settingsDeleteConfirmTitle => 'Delete account?';

  @override
  String get settingsDeleteConfirmBody =>
      'All of your ratings, locations and your account will be permanently deleted from our server.';

  @override
  String get settingsDeleteCancel => 'Cancel';

  @override
  String get settingsDeleteConfirm => 'Delete forever';

  @override
  String get settingsDeleteSuccess => 'Account deleted';

  @override
  String settingsDeleteError(String error) {
    return 'Delete failed: $error';
  }

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingFinish => 'Let\'s go';

  @override
  String get onboardingLogin => 'Sign in';

  @override
  String get onboardingCreateAccount => 'Create account';

  @override
  String get onboardingSkip => 'Skip for now';

  @override
  String get onboardingPrivacyLink => 'Full privacy policy';

  @override
  String get onboardingPrivacyTitle => 'Privacy';

  @override
  String get onboardingPrivacyOpenBrowser => 'Open in browser';

  @override
  String get onboardingPrivacyLoadError => 'Could not load the privacy policy.';

  @override
  String get onboarding1Headline => 'Paint your favourite routes';

  @override
  String get onboarding1Body =>
      'Paint on the map where you like to ride and where you\'d rather avoid. beebeebike turns that into bike routes that match your taste.';

  @override
  String get onboarding2Headline => 'What we store';

  @override
  String get onboarding2Bullet1 =>
      'Your ratings, saved places and — if you register an account — your email plus a password hash live on a server in Germany.';

  @override
  String get onboarding2Bullet2 =>
      'Place search: your query is forwarded through our server to the Photon geocoder (run by Komoot GmbH, Germany). No account data is sent along.';

  @override
  String get onboarding2Bullet3 =>
      'Without an account you stay anonymous — we only set a random session ID.';

  @override
  String get onboarding2Bullet4 =>
      'You can delete your account anytime in Settings. All server-side data is removed with it.';

  @override
  String get onboarding3Headline =>
      'Paint on the desktop, ride with your phone';

  @override
  String get onboarding3Body =>
      'You can use beebeebike right away anonymously. With a free account you can paint faster on beebeebike.com in the browser — your ratings sync to the phone automatically.';

  @override
  String get searchHint => 'Where to?';

  @override
  String get searchSavedPlaces => 'Saved places';

  @override
  String get searchSectionQuick => 'Quick';

  @override
  String get searchSectionRecent => 'Recent';

  @override
  String get searchSectionResults => 'Results';

  @override
  String get homeGoHome => 'Go home';

  @override
  String get routeStartRide => 'Start ride';

  @override
  String routeEta(String time) {
    return 'ETA $time';
  }

  @override
  String navArrives(String time) {
    return 'arrives $time';
  }

  @override
  String get locationCurrent => 'Current location';

  @override
  String get locationDroppedPin => 'Dropped pin';

  @override
  String locationFetchError(String error) {
    return 'Could not get current location: $error';
  }

  @override
  String mapLoadError(String error) {
    return 'Failed to load map: $error';
  }

  @override
  String get routeLoadError => 'Could not load route';

  @override
  String get routeClearTooltip => 'Clear route';

  @override
  String get routeStart => 'Start';

  @override
  String routeSummary(int minutes, String distance) {
    return '🚲 $minutes min · $distance km';
  }

  @override
  String get navStarting => 'Starting navigation...';

  @override
  String get navError => 'Navigation error';

  @override
  String get navOnRoute => 'On route';

  @override
  String get navMuteVoice => 'Mute voice';

  @override
  String get navEnableVoice => 'Enable voice';

  @override
  String get navEndNavigation => 'End navigation';

  @override
  String get navRerouting => 'Rerouting…';

  @override
  String get navTtsDeparting => 'Let\'s get buzzing';

  @override
  String get navTtsRerouted => 'Wrong turn, route recalculated';

  @override
  String get navTtsArrived => 'You have arrived';

  @override
  String get arrivedTitle => 'Arrived';

  @override
  String get arrivedDone => 'Done';

  @override
  String get mapResetNorth => 'Reset to north';

  @override
  String get paintEnter => 'Paint mode';

  @override
  String get paintExit => 'Exit paint mode';

  @override
  String get paintDisabled => 'Paint mode (coming soon)';

  @override
  String get paintEraser => 'Eraser';

  @override
  String paintRatingLabel(int value) {
    return 'Rating $value';
  }

  @override
  String get paintUndo => 'Undo';

  @override
  String get paintRedo => 'Redo';
}

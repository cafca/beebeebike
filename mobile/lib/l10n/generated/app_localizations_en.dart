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
  String get searchHint => 'Where to?';

  @override
  String get searchSavedPlaces => 'Saved places';

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
  String get arrivedTitle => 'Arrived';

  @override
  String get arrivedDone => 'Done';
}

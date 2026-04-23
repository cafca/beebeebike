// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'beebeebike';

  @override
  String get commonLoading => 'Lädt…';

  @override
  String get loginTitle => 'Anmeldung';

  @override
  String get loginSubmit => 'Einloggen';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginErrorEmptyEmail => 'Email eingeben';

  @override
  String get loginErrorEmptyPassword => 'Passwort eingeben';

  @override
  String get loginErrorInvalid => 'Ungültige Email oder ungültiges Passwort';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGuest => 'Gast';

  @override
  String get settingsHome => 'Zuhause';

  @override
  String get settingsLogOut => 'Ausloggen';

  @override
  String get settingsLogIn => 'Einloggen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsSectionAccount => 'Konto';

  @override
  String get settingsSectionLanguage => 'Sprache';

  @override
  String get settingsSectionCredits => 'Gebaut mit';

  @override
  String get settingsCreditPhoton => 'Photon-Dienst gehostet von Komoot';

  @override
  String get searchHint => 'Wohin?';

  @override
  String get searchSavedPlaces => 'Gespeicherte Orte';

  @override
  String get locationCurrent => 'Aktueller Standort';

  @override
  String get locationDroppedPin => 'Markierung';

  @override
  String locationFetchError(String error) {
    return 'Standort konnte nicht ermittelt werden: $error';
  }

  @override
  String mapLoadError(String error) {
    return 'Karte konnte nicht geladen werden: $error';
  }

  @override
  String get routeLoadError => 'Route konnte nicht geladen werden';

  @override
  String get routeClearTooltip => 'Route löschen';

  @override
  String get routeStart => 'Start';

  @override
  String routeSummary(int minutes, String distance) {
    return '🚲 $minutes Min · $distance km';
  }

  @override
  String get navStarting => 'Navigation wird gestartet…';

  @override
  String get navError => 'Navigationsfehler';

  @override
  String get navOnRoute => 'Auf der Route';

  @override
  String get navMuteVoice => 'Stimme aus';

  @override
  String get navEnableVoice => 'Stimme an';

  @override
  String get navEndNavigation => 'Navigation beenden';

  @override
  String get navRerouting => 'Route wird neu berechnet…';

  @override
  String get arrivedTitle => 'Angekommen';

  @override
  String get arrivedDone => 'Fertig';

  @override
  String get mapResetNorth => 'Nach Norden ausrichten';

  @override
  String get homeCaveatsTitle => 'Einschränkungen';

  @override
  String get homeCaveatsBefore =>
      'Du kannst deine gemalten Flächen noch nicht in der App bearbeiten. Mach das auf ';

  @override
  String get homeCaveatsAfter =>
      ', dann weit raus- und wieder reinzoomen, damit die Änderungen in der App geladen werden lol.';

  @override
  String get homeHowToTitle => 'So geht\'s';

  @override
  String get homeHowToBody =>
      'Tippe auf „Wohin?“, um ein Ziel zu suchen, oder tippe irgendwo auf die Karte. Mit dem Pinsel malst du Flächen grün (gute Strecken) oder rot (vermeiden) — die Navigation passt sich deinen Wünschen an. Wenn du in der Web-App ein Zuhause gespeichert hast kannst du mit einem Tap dorthin navigieren.';
}

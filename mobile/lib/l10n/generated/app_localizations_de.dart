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
  String get settingsSectionCredits => 'Shoutouts';

  @override
  String get settingsCreditOsm => 'Kartendaten © OpenStreetMap-Mitwirkende';

  @override
  String get settingsCreditMaplibre => 'Kartendarstellung mit MapLibre';

  @override
  String get settingsCreditGraphhopper => 'Routing mit GraphHopper';

  @override
  String get settingsCreditPhoton =>
      'Geocoding mit Photon, gehostet von Komoot';

  @override
  String get searchHint => 'Wohin?';

  @override
  String get searchSavedPlaces => 'Gespeicherte Orte';

  @override
  String get searchSectionQuick => 'Schnell';

  @override
  String get searchSectionRecent => 'Zuletzt';

  @override
  String get searchSectionResults => 'Ergebnisse';

  @override
  String get homeGoHome => 'Nach Hause';

  @override
  String get routeStartRide => 'Los geht\'s';

  @override
  String routeEta(String time) {
    return 'Ankunft $time';
  }

  @override
  String navArrives(String time) {
    return 'Ankunft um $time';
  }

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
}

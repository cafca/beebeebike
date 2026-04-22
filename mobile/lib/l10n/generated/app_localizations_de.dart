// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'BeeBeeBike';

  @override
  String get commonLoading => 'Lädt…';

  @override
  String get loginTitle => 'Anmelden';

  @override
  String get loginEmail => 'E-Mail';

  @override
  String get loginPassword => 'Passwort';

  @override
  String get loginErrorEmptyEmail => 'E-Mail eingeben';

  @override
  String get loginErrorEmptyPassword => 'Passwort eingeben';

  @override
  String get loginErrorInvalid => 'Ungültige E-Mail oder ungültiges Passwort';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGuest => 'Gast';

  @override
  String get settingsHome => 'Zuhause';

  @override
  String get settingsLogOut => 'Abmelden';

  @override
  String get settingsLogIn => 'Anmelden';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Systemstandard';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get searchHint => 'Hier suchen…';

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
}

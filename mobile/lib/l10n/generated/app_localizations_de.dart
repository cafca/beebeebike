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
  String get settingsSectionLegal => 'Rechtliches';

  @override
  String get settingsLegalPrivacy => 'Datenschutz';

  @override
  String get settingsLegalImprint => 'Impressum';

  @override
  String get settingsSectionDanger => 'Gefahrenzone';

  @override
  String get settingsDeleteAccount => 'Konto löschen';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Entfernt Konto, Bewertungen und Standorte unwiderruflich.';

  @override
  String get settingsDeleteConfirmTitle => 'Konto wirklich löschen?';

  @override
  String get settingsDeleteConfirmBody =>
      'Alle deine Bewertungen, Standorte und dein Konto werden unwiderruflich von unserem Server gelöscht.';

  @override
  String get settingsDeleteCancel => 'Abbrechen';

  @override
  String get settingsDeleteConfirm => 'Endgültig löschen';

  @override
  String get settingsDeleteSuccess => 'Konto gelöscht';

  @override
  String settingsDeleteError(String error) {
    return 'Löschen fehlgeschlagen: $error';
  }

  @override
  String get onboardingBack => 'Zurück';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingFinish => 'Los geht\'s';

  @override
  String get onboardingLogin => 'Jetzt einloggen';

  @override
  String get onboardingPrivacyLink => 'Vollständige Datenschutzerklärung';

  @override
  String get onboardingPrivacyTitle => 'Datenschutz';

  @override
  String get onboardingPrivacyOpenBrowser => 'Im Browser öffnen';

  @override
  String get onboardingPrivacyLoadError =>
      'Datenschutzerklärung konnte nicht geladen werden.';

  @override
  String get onboarding1Headline => 'Male deine Lieblingsstrecken';

  @override
  String get onboarding1Body =>
      'Male mit dem Pinsel auf der Karte wo du gerne Rad fährst und wo du lieber fernbleiben möchtest. beebeebike plant daraus Radrouten nach deinen Wünschen.';

  @override
  String get onboarding2Headline => 'Was wir speichern';

  @override
  String get onboarding2Bullet1 =>
      'Deine Bewertungen, gespeicherten Standorte, E-Mail und Passwort-Hash liegen auf einem Hetzner-Server in Deutschland.';

  @override
  String get onboarding2Bullet2 =>
      'Ortssuche: Deine Eingabe wird über unseren Server an den Geocoding-Dienst Photon (betrieben von der Komoot GmbH, Deutschland) weitergeleitet. Deine Konto-Daten werden dabei nicht übertragen.';

  @override
  String get onboarding2Bullet4 =>
      'Du kannst dein Konto jederzeit in den Einstellungen löschen. Damit werden alle serverseitig gespeicherten Daten entfernt.';

  @override
  String get onboarding3Headline => 'Am Rechner malen, am Rad fahren';

  @override
  String get onboarding3Body =>
      'Male deine Bewertungen am Rechner auf beebeebike.com — sie landen automatisch auf dem Handy. Zum Loslegen einloggen.';

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

  @override
  String get paintEnter => 'Malmodus';

  @override
  String get paintExit => 'Malmodus beenden';

  @override
  String get paintDisabled => 'Malmodus (bald verfügbar)';

  @override
  String get paintEraser => 'Radierer';

  @override
  String paintRatingLabel(int value) {
    return 'Bewertung $value';
  }

  @override
  String get paintUndo => 'Rückgängig';

  @override
  String get paintRedo => 'Wiederherstellen';
}

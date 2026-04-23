import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
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
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'beebeebike'**
  String get appTitle;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get commonLoading;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginTitle;

  /// No description provided for @loginSubmit.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get loginSubmit;

  /// No description provided for @loginEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get loginEmail;

  /// No description provided for @loginPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPassword;

  /// No description provided for @loginErrorEmptyEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get loginErrorEmptyEmail;

  /// No description provided for @loginErrorEmptyPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get loginErrorEmptyPassword;

  /// No description provided for @loginErrorInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get loginErrorInvalid;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsGuest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get settingsGuest;

  /// No description provided for @settingsHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get settingsHome;

  /// No description provided for @settingsLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// No description provided for @settingsLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get settingsLogIn;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsSectionLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsSectionLanguage;

  /// No description provided for @settingsSectionCredits.
  ///
  /// In en, this message translates to:
  /// **'Built with'**
  String get settingsSectionCredits;

  /// No description provided for @settingsCreditPhoton.
  ///
  /// In en, this message translates to:
  /// **'Photon service hosted by Komoot'**
  String get settingsCreditPhoton;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Where to?'**
  String get searchHint;

  /// No description provided for @searchSavedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved places'**
  String get searchSavedPlaces;

  /// No description provided for @locationCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get locationCurrent;

  /// No description provided for @locationDroppedPin.
  ///
  /// In en, this message translates to:
  /// **'Dropped pin'**
  String get locationDroppedPin;

  /// No description provided for @locationFetchError.
  ///
  /// In en, this message translates to:
  /// **'Could not get current location: {error}'**
  String locationFetchError(String error);

  /// No description provided for @mapLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load map: {error}'**
  String mapLoadError(String error);

  /// No description provided for @routeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load route'**
  String get routeLoadError;

  /// No description provided for @routeClearTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear route'**
  String get routeClearTooltip;

  /// No description provided for @routeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get routeStart;

  /// No description provided for @routeSummary.
  ///
  /// In en, this message translates to:
  /// **'🚲 {minutes} min · {distance} km'**
  String routeSummary(int minutes, String distance);

  /// No description provided for @navStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting navigation...'**
  String get navStarting;

  /// No description provided for @navError.
  ///
  /// In en, this message translates to:
  /// **'Navigation error'**
  String get navError;

  /// No description provided for @navOnRoute.
  ///
  /// In en, this message translates to:
  /// **'On route'**
  String get navOnRoute;

  /// No description provided for @navMuteVoice.
  ///
  /// In en, this message translates to:
  /// **'Mute voice'**
  String get navMuteVoice;

  /// No description provided for @navEnableVoice.
  ///
  /// In en, this message translates to:
  /// **'Enable voice'**
  String get navEnableVoice;

  /// No description provided for @navEndNavigation.
  ///
  /// In en, this message translates to:
  /// **'End navigation'**
  String get navEndNavigation;

  /// No description provided for @navRerouting.
  ///
  /// In en, this message translates to:
  /// **'Rerouting…'**
  String get navRerouting;

  /// No description provided for @arrivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Arrived'**
  String get arrivedTitle;

  /// No description provided for @arrivedDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get arrivedDone;

  /// No description provided for @mapResetNorth.
  ///
  /// In en, this message translates to:
  /// **'Reset to north'**
  String get mapResetNorth;

  /// No description provided for @homeCaveatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Caveats'**
  String get homeCaveatsTitle;

  /// No description provided for @homeCaveatsBefore.
  ///
  /// In en, this message translates to:
  /// **'You can\'t edit your painted areas yet in the mobile app. Do that on '**
  String get homeCaveatsBefore;

  /// No description provided for @homeCaveatsAfter.
  ///
  /// In en, this message translates to:
  /// **', then zoom out a lot and back in to load updates in the app.'**
  String get homeCaveatsAfter;

  /// No description provided for @homeHowToTitle.
  ///
  /// In en, this message translates to:
  /// **'How to use'**
  String get homeHowToTitle;

  /// No description provided for @homeHowToBody.
  ///
  /// In en, this message translates to:
  /// **'Tap \"Where to?\" to search for a destination, or tap anywhere on the map. Use the brush tool to paint areas green (good cycling) or red (avoid) — your ratings shape future routes. Set a home address in the web app to get one-tap navigation.'**
  String get homeHowToBody;
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
      <String>['de', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

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
    Locale('en'),
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

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// No description provided for @registerSubmit.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerSubmit;

  /// No description provided for @registerErrorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get registerErrorPasswordTooShort;

  /// No description provided for @registerErrorEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get registerErrorEmailTaken;

  /// No description provided for @registerErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Could not create account. Please try again.'**
  String get registerErrorGeneric;

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
  /// **'Shout outs'**
  String get settingsSectionCredits;

  /// No description provided for @settingsCreditOsm.
  ///
  /// In en, this message translates to:
  /// **'Map data © OpenStreetMap contributors'**
  String get settingsCreditOsm;

  /// No description provided for @settingsCreditMaplibre.
  ///
  /// In en, this message translates to:
  /// **'Map rendering by MapLibre'**
  String get settingsCreditMaplibre;

  /// No description provided for @settingsCreditGraphhopper.
  ///
  /// In en, this message translates to:
  /// **'Routing by GraphHopper'**
  String get settingsCreditGraphhopper;

  /// No description provided for @settingsCreditPhoton.
  ///
  /// In en, this message translates to:
  /// **'Geocoding by Photon, hosted by Komoot'**
  String get settingsCreditPhoton;

  /// No description provided for @settingsSectionLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsSectionLegal;

  /// No description provided for @settingsLegalPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsLegalPrivacy;

  /// No description provided for @settingsLegalImprint.
  ///
  /// In en, this message translates to:
  /// **'Imprint'**
  String get settingsLegalImprint;

  /// No description provided for @settingsSectionDanger.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsSectionDanger;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// No description provided for @settingsDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently removes your account, ratings and locations.'**
  String get settingsDeleteAccountSubtitle;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All of your ratings, locations and your account will be permanently deleted from our server.'**
  String get settingsDeleteConfirmBody;

  /// No description provided for @settingsDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsDeleteCancel;

  /// No description provided for @settingsDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get settingsDeleteConfirm;

  /// No description provided for @settingsDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get settingsDeleteSuccess;

  /// No description provided for @settingsDeleteError.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String settingsDeleteError(String error);

  /// No description provided for @onboardingBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingFinish.
  ///
  /// In en, this message translates to:
  /// **'Let\'s go'**
  String get onboardingFinish;

  /// No description provided for @onboardingLogin.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get onboardingLogin;

  /// No description provided for @onboardingCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get onboardingCreateAccount;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get onboardingSkip;

  /// No description provided for @onboardingPrivacyLink.
  ///
  /// In en, this message translates to:
  /// **'Full privacy policy'**
  String get onboardingPrivacyLink;

  /// No description provided for @onboardingPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get onboardingPrivacyTitle;

  /// No description provided for @onboardingPrivacyOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get onboardingPrivacyOpenBrowser;

  /// No description provided for @onboardingPrivacyLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the privacy policy.'**
  String get onboardingPrivacyLoadError;

  /// No description provided for @onboarding1Headline.
  ///
  /// In en, this message translates to:
  /// **'Paint your favourite routes'**
  String get onboarding1Headline;

  /// No description provided for @onboarding1Body.
  ///
  /// In en, this message translates to:
  /// **'Paint on the map where you like to ride and where you\'d rather avoid. beebeebike turns that into bike routes that match your taste.'**
  String get onboarding1Body;

  /// No description provided for @onboarding2Headline.
  ///
  /// In en, this message translates to:
  /// **'What we store'**
  String get onboarding2Headline;

  /// No description provided for @onboarding2Bullet1.
  ///
  /// In en, this message translates to:
  /// **'Your ratings, saved places and — if you register an account — your email plus a password hash live on a server in Germany.'**
  String get onboarding2Bullet1;

  /// No description provided for @onboarding2Bullet2.
  ///
  /// In en, this message translates to:
  /// **'Place search: your query is forwarded through our server to the Photon geocoder (run by Komoot GmbH, Germany). No account data is sent along.'**
  String get onboarding2Bullet2;

  /// No description provided for @onboarding2Bullet3.
  ///
  /// In en, this message translates to:
  /// **'Without an account you stay anonymous — we only set a random session ID.'**
  String get onboarding2Bullet3;

  /// No description provided for @onboarding2Bullet4.
  ///
  /// In en, this message translates to:
  /// **'You can delete your account anytime in Settings. All server-side data is removed with it.'**
  String get onboarding2Bullet4;

  /// No description provided for @onboarding3Headline.
  ///
  /// In en, this message translates to:
  /// **'Paint on the desktop, ride with your phone'**
  String get onboarding3Headline;

  /// No description provided for @onboarding3Body.
  ///
  /// In en, this message translates to:
  /// **'You can use beebeebike right away anonymously. With a free account you can paint faster on beebeebike.com in the browser — your ratings sync to the phone automatically.'**
  String get onboarding3Body;

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

  /// No description provided for @searchSectionQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick'**
  String get searchSectionQuick;

  /// No description provided for @searchSectionRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get searchSectionRecent;

  /// No description provided for @searchSectionResults.
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get searchSectionResults;

  /// No description provided for @homeGoHome.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get homeGoHome;

  /// No description provided for @routeStartRide.
  ///
  /// In en, this message translates to:
  /// **'Start ride'**
  String get routeStartRide;

  /// No description provided for @routeEta.
  ///
  /// In en, this message translates to:
  /// **'ETA {time}'**
  String routeEta(String time);

  /// No description provided for @navArrives.
  ///
  /// In en, this message translates to:
  /// **'arrives {time}'**
  String navArrives(String time);

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

  /// No description provided for @navTtsDeparting.
  ///
  /// In en, this message translates to:
  /// **'Let\'s get buzzing'**
  String get navTtsDeparting;

  /// No description provided for @navTtsRerouted.
  ///
  /// In en, this message translates to:
  /// **'Wrong turn, route recalculated'**
  String get navTtsRerouted;

  /// No description provided for @navTtsArrived.
  ///
  /// In en, this message translates to:
  /// **'You have arrived'**
  String get navTtsArrived;

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

  /// No description provided for @paintEnter.
  ///
  /// In en, this message translates to:
  /// **'Paint mode'**
  String get paintEnter;

  /// No description provided for @paintExit.
  ///
  /// In en, this message translates to:
  /// **'Exit paint mode'**
  String get paintExit;

  /// No description provided for @paintDisabled.
  ///
  /// In en, this message translates to:
  /// **'Paint mode (coming soon)'**
  String get paintDisabled;

  /// No description provided for @paintEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get paintEraser;

  /// No description provided for @paintRatingLabel.
  ///
  /// In en, this message translates to:
  /// **'Rating {value}'**
  String paintRatingLabel(int value);

  /// No description provided for @paintUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get paintUndo;

  /// No description provided for @paintRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get paintRedo;
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
    'that was used.',
  );
}

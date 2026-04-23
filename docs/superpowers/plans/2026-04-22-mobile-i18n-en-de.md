# Mobile i18n (en + de) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add English + German localization to the Flutter mobile app using `flutter_localizations` + `gen_l10n` + ARB files; default to the device locale with a togglable override in Settings; propagate the chosen locale to TTS and to the backend via `Accept-Language` so GraphHopper returns turn instructions in the right language.

**Architecture:**

- Flutter standard toolchain: `flutter_localizations` delegates + `gen_l10n` codegen + `app_en.arb` / `app_de.arb`.
- Riverpod `localeProvider` exposes `LocalePref` (`system` / `en` / `de`), persists to `shared_preferences`, drives `MaterialApp.locale`.
- Dio interceptor reads the provider, sets `Accept-Language` on every request.
- `flutterTtsProvider` watches the provider and reconfigures `setLanguage`.
- Backend `routing.rs` parses `Accept-Language` header and maps `en|de` → GraphHopper `locale` field (fallback `en`).

**Tech Stack:** Flutter 3.19+, Dart 3.3+, `flutter_localizations`, `intl`, Riverpod 2, `shared_preferences`, `dio`, `flutter_tts`; Axum/Rust backend.

**Spec:** `docs/superpowers/specs/2026-04-22-mobile-i18n-en-de-design.md`

---

## File structure

Created:
- `mobile/l10n.yaml`
- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_de.arb`
- `mobile/lib/providers/locale_provider.dart`
- `mobile/lib/widgets/language_picker.dart`
- `mobile/test/providers/locale_provider_test.dart`
- `mobile/test/widgets/language_picker_test.dart`

Modified:
- `mobile/pubspec.yaml`
- `mobile/lib/app.dart`
- `mobile/lib/api/client.dart`
- `mobile/lib/providers/navigation_provider.dart`
- `mobile/lib/screens/login_screen.dart`
- `mobile/lib/screens/map_screen.dart`
- `mobile/lib/screens/search_screen.dart`
- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/widgets/arrived_sheet.dart`
- `mobile/lib/widgets/eta_sheet.dart`
- `mobile/lib/widgets/rerouting_toast.dart`
- `mobile/lib/widgets/route_summary.dart`
- `mobile/lib/widgets/search_bar.dart`
- `mobile/test/providers/navigation_provider_test.dart`
- `mobile/test/screens/*.dart` (wrap `pumpWidget` roots with localization delegates)
- `mobile/test/widgets/*.dart` (same)
- `backend/src/routing.rs`
- `backend/tests/integration.rs`

---

## Task 1: Wire flutter_localizations + gen_l10n skeleton

Goal: add the Flutter i18n toolchain and produce an empty `AppLocalizations` class. No UI behaviour yet.

**Files:**
- Modify: `mobile/pubspec.yaml`
- Create: `mobile/l10n.yaml`
- Create: `mobile/lib/l10n/app_en.arb`
- Create: `mobile/lib/l10n/app_de.arb`

- [ ] **Step 1: Add `flutter_localizations` + `intl` + `generate: true` to pubspec**

Edit `mobile/pubspec.yaml`. In `dependencies:` add `flutter_localizations` and `intl`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
  cupertino_icons: ^1.0.8
  # ... rest unchanged
```

Add `generate: true` under the `flutter:` key:

```yaml
flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/styles/
```

- [ ] **Step 2: Create `mobile/l10n.yaml`**

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
synthetic-package: false
output-dir: lib/l10n/generated
```

`synthetic-package: false` + explicit `output-dir` keeps the generated file inside the project so imports resolve normally and IDEs jump to definition.

- [ ] **Step 3: Create seed ARB files**

`mobile/lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "BeeBeeBike",
  "@appTitle": { "description": "App name in app switcher / task list." }
}
```

`mobile/lib/l10n/app_de.arb`:

```json
{
  "@@locale": "de",
  "appTitle": "BeeBeeBike"
}
```

- [ ] **Step 4: Trigger generation**

```bash
cd mobile && flutter pub get
```

Expected: finishes cleanly. `mobile/lib/l10n/generated/app_localizations.dart` exists with `class AppLocalizations` and `supportedLocales = [Locale('en'), Locale('de')]`.

Verify: `ls mobile/lib/l10n/generated/` shows `app_localizations.dart`, `app_localizations_en.dart`, `app_localizations_de.dart`.

- [ ] **Step 5: Run mobile tests to confirm no regression**

```bash
just test-mobile
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/pubspec.yaml mobile/pubspec.lock mobile/l10n.yaml mobile/lib/l10n/
git commit -m "mobile: scaffold flutter_localizations with en+de ARB"
```

---

## Task 2: `LocalePref` provider with persistence (TDD)

Goal: a Riverpod notifier storing user choice (`system` / `en` / `de`), reading and writing `shared_preferences`, plus an `effectiveLanguageTag` helper.

**Files:**
- Create: `mobile/lib/providers/locale_provider.dart`
- Create: `mobile/test/providers/locale_provider_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/providers/locale_provider_test.dart`:

```dart
import 'package:beebeebike/providers/locale_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(SharedPreferences prefs) {
  final c = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults to LocalePref.system with no stored value', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    expect(c.read(localeProvider), LocalePref.system);
    expect(c.read(localeProvider.notifier).materialLocale, isNull);
  });

  test('reads stored de on construction', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'de'});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    expect(c.read(localeProvider), LocalePref.de);
    expect(c.read(localeProvider.notifier).materialLocale, const Locale('de'));
  });

  test('setPref persists and updates state', () async {
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    await c.read(localeProvider.notifier).setPref(LocalePref.en);
    expect(c.read(localeProvider), LocalePref.en);
    expect(prefs.getString('locale_pref'), 'en');
    expect(c.read(localeProvider.notifier).materialLocale, const Locale('en'));
  });

  test('setPref(system) stores "system", materialLocale is null', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'de'});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    await c.read(localeProvider.notifier).setPref(LocalePref.system);
    expect(c.read(localeProvider), LocalePref.system);
    expect(prefs.getString('locale_pref'), 'system');
    expect(c.read(localeProvider.notifier).materialLocale, isNull);
  });

  test('unknown stored value falls back to system', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'fr'});
    final prefs = await SharedPreferences.getInstance();
    final c = _container(prefs);
    expect(c.read(localeProvider), LocalePref.system);
  });

  test('effectiveLanguageTag maps pref/device to en|de', () {
    expect(effectiveLanguageTag(LocalePref.en, const Locale('de')), 'en');
    expect(effectiveLanguageTag(LocalePref.de, const Locale('en')), 'de');
    expect(effectiveLanguageTag(LocalePref.system, const Locale('de')), 'de');
    expect(effectiveLanguageTag(LocalePref.system, const Locale('en')), 'en');
    expect(effectiveLanguageTag(LocalePref.system, const Locale('fr')), 'en');
  });
}
```

- [ ] **Step 2: Run test, confirm it fails**

```bash
cd mobile && flutter test test/providers/locale_provider_test.dart
```

Expected: FAIL — `package:beebeebike/providers/locale_provider.dart` does not exist.

- [ ] **Step 3: Implement the provider**

Create `mobile/lib/providers/locale_provider.dart`:

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'search_history_provider.dart';

/// User language preference. `system` defers to the device locale; `en` and
/// `de` pin the app.
enum LocalePref { system, en, de }

const _storageKey = 'locale_pref';

final localeProvider =
    NotifierProvider<LocaleController, LocalePref>(LocaleController.new);

class LocaleController extends Notifier<LocalePref> {
  @override
  LocalePref build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _decode(prefs.getString(_storageKey));
  }

  Locale? get materialLocale {
    switch (state) {
      case LocalePref.system:
        return null;
      case LocalePref.en:
        return const Locale('en');
      case LocalePref.de:
        return const Locale('de');
    }
  }

  Future<void> setPref(LocalePref next) async {
    state = next;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_storageKey, _encode(next));
  }

  static LocalePref _decode(String? raw) {
    switch (raw) {
      case 'en':
        return LocalePref.en;
      case 'de':
        return LocalePref.de;
      case 'system':
      default:
        return LocalePref.system;
    }
  }

  static String _encode(LocalePref v) {
    switch (v) {
      case LocalePref.system:
        return 'system';
      case LocalePref.en:
        return 'en';
      case LocalePref.de:
        return 'de';
    }
  }
}

/// Resolve the effective BCP-47 language tag (two letters) for the app.
/// Device locales outside the supported set fall back to `en`.
String effectiveLanguageTag(LocalePref pref, Locale deviceLocale) {
  switch (pref) {
    case LocalePref.en:
      return 'en';
    case LocalePref.de:
      return 'de';
    case LocalePref.system:
      return deviceLocale.languageCode == 'de' ? 'de' : 'en';
  }
}
```

- [ ] **Step 4: Run test, confirm it passes**

```bash
cd mobile && flutter test test/providers/locale_provider_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/locale_provider.dart mobile/test/providers/locale_provider_test.dart
git commit -m "mobile: add locale_provider with shared_preferences persistence"
```

---

## Task 3: Wire `AppLocalizations` + `localeProvider` into `MaterialApp`

Goal: register the localization delegates, use the user pref for `MaterialApp.locale`, show the app title from ARB.

**Files:**
- Modify: `mobile/lib/app.dart`

- [ ] **Step 1: Replace `mobile/lib/app.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'l10n/generated/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'screens/map_screen.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

class BeeBeeBikeApp extends ConsumerWidget {
  const BeeBeeBikeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Start auth eagerly on the first frame. The anonymous session completes
    // in the background; all user-triggered API calls (route, geocode) happen
    // after human interaction, giving the session time to settle.
    ref.watch(authControllerProvider);

    ref.watch(localeProvider);
    final controller = ref.watch(localeProvider.notifier);

    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.appTitle,
      locale: controller.materialLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E6F66),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F3EC),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}
```

- [ ] **Step 2: Run mobile test suite**

```bash
just test-mobile
```

Expected: PASS. `mobile/test/app_smoke_test.dart` already overrides `sharedPreferencesProvider` (it drives `search_history_provider`), so `localeProvider` resolves without extra overrides. If any test fails because it constructs `BeeBeeBikeApp` without that override, add `sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())` to the `ProviderScope`.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/app.dart
git commit -m "mobile: wire AppLocalizations + localeProvider into MaterialApp"
```

---

## Task 4: Dio `Accept-Language` interceptor

Goal: every backend request carries `Accept-Language: en` or `de` based on the current `LocalePref` + device locale.

**Files:**
- Modify: `mobile/lib/api/client.dart`

- [ ] **Step 1: Replace `mobile/lib/api/client.dart`**

```dart
import 'dart:ui' as ui;

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';
import '../providers/locale_provider.dart';

/// Override this in main() with getApplicationSupportDirectory().path.
final cookieStoragePathProvider = Provider<String>(
  (_) => throw UnimplementedError('cookieStoragePathProvider not overridden'),
);

final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);
  final cookiePath = ref.watch(cookieStoragePathProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(
    CookieManager(PersistCookieJar(storage: FileStorage('$cookiePath/.cookies/'))),
  );
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    final pref = ref.read(localeProvider);
    // PlatformDispatcher.locale mirrors the current device locale and is
    // kept up to date by the Flutter engine, so reading it per-request
    // picks up OS-level changes without tearing down the Dio instance.
    final deviceLocale = ui.PlatformDispatcher.instance.locale;
    options.headers['Accept-Language'] =
        effectiveLanguageTag(pref, deviceLocale);
    handler.next(options);
  }));
  return dio;
});
```

- [ ] **Step 2: Run mobile tests**

```bash
just test-mobile
```

Expected: PASS. All existing tests that read `dioProvider` already override `sharedPreferencesProvider` (required for the in-memory container to construct the downstream `searchHistoryProvider`), so `localeProvider` resolves cleanly.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/api/client.dart
git commit -m "mobile: add Accept-Language header via dio interceptor"
```

---

## Task 5: TTS language follows `LocalePref` (TDD)

Goal: replace the hardcoded `de-DE` with a derivation from the effective locale. Introduce a factory provider so tests can inject a mock `FlutterTts`.

**Files:**
- Modify: `mobile/lib/providers/navigation_provider.dart`
- Modify: `mobile/test/providers/navigation_provider_test.dart`

- [ ] **Step 1: Add failing tests**

Replace `mobile/test/providers/navigation_provider_test.dart` with:

```dart
import 'package:beebeebike/api/client.dart';
import 'package:beebeebike/app.dart';
import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/providers/locale_provider.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockFlutterTts extends Mock implements FlutterTts {}

const _cfg = AppConfig(
  apiBaseUrl: 'http://localhost',
  tileServerBaseUrl: 'http://localhost',
  tileStyleUrl: 'http://localhost/tiles',
  ratingsSseEnabled: false,
);

ProviderContainer _container({
  required SharedPreferences prefs,
  required FlutterTts tts,
}) {
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(_cfg),
    cookieStoragePathProvider.overrideWithValue('/tmp'),
    sharedPreferencesProvider.overrideWithValue(prefs),
    ttsFactoryProvider.overrideWithValue(() => tts),
  ]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('speakInstruction calls FlutterTts.speak with the given text', () async {
    final tts = MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.speak(any())).thenAnswer((_) async => 1);
    final prefs = await SharedPreferences.getInstance();
    final container = _container(prefs: prefs, tts: tts);

    final service = container.read(navigationServiceProvider);
    await service.speakInstruction('Turn left');

    verify(() => tts.speak('Turn left')).called(1);
  });

  test('flutterTtsProvider sets de-DE when LocalePref is de', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'de'});
    final prefs = await SharedPreferences.getInstance();
    final tts = MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    final container = _container(prefs: prefs, tts: tts);

    container.read(flutterTtsProvider);

    verify(() => tts.setLanguage('de-DE')).called(1);
  });

  test('flutterTtsProvider sets en-US when LocalePref is en', () async {
    SharedPreferences.setMockInitialValues({'locale_pref': 'en'});
    final prefs = await SharedPreferences.getInstance();
    final tts = MockFlutterTts();
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    final container = _container(prefs: prefs, tts: tts);

    container.read(flutterTtsProvider);

    verify(() => tts.setLanguage('en-US')).called(1);
  });
}
```

- [ ] **Step 2: Run test, confirm it fails**

```bash
cd mobile && flutter test test/providers/navigation_provider_test.dart
```

Expected: FAIL — `ttsFactoryProvider` undefined and the hardcoded `de-DE` does not depend on `LocalePref`.

- [ ] **Step 3: Update `navigation_provider.dart`**

In `mobile/lib/providers/navigation_provider.dart`, add these imports near the top (keep existing imports):

```dart
import 'dart:ui' as ui;
import 'locale_provider.dart';
```

Replace the existing block:

```dart
final flutterTtsProvider = Provider<FlutterTts>((ref) {
  final tts = FlutterTts();
  // Berlin-only v0.1: instruction text is German.
  tts.setLanguage('de-DE');
  return tts;
});
```

with:

```dart
/// Factory override so tests can inject a mock FlutterTts.
final ttsFactoryProvider = Provider<FlutterTts Function()>((_) => FlutterTts.new);

final flutterTtsProvider = Provider<FlutterTts>((ref) {
  final tts = ref.watch(ttsFactoryProvider)();
  final pref = ref.watch(localeProvider);
  final deviceLocale = ui.PlatformDispatcher.instance.locale;
  final tag = effectiveLanguageTag(pref, deviceLocale);
  // Map BCP-47 language → region-qualified TTS voice tag. Voice availability
  // is handled by the TTS engine; it falls back when the exact region is
  // not installed.
  final ttsTag = tag == 'de' ? 'de-DE' : 'en-US';
  tts.setLanguage(ttsTag);
  return tts;
});
```

- [ ] **Step 4: Run tests**

```bash
cd mobile && flutter test test/providers/navigation_provider_test.dart
just test-mobile
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/providers/navigation_provider.dart mobile/test/providers/navigation_provider_test.dart
git commit -m "mobile: TTS language follows LocalePref"
```

---

## Task 6: Populate full ARB key set

Goal: every user-facing string from the inventoried files has an entry in both ARBs.

**Files:**
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/lib/l10n/app_de.arb`

- [ ] **Step 1: Replace `mobile/lib/l10n/app_en.arb`**

```json
{
  "@@locale": "en",

  "appTitle": "BeeBeeBike",

  "commonLoading": "Loading...",

  "loginTitle": "Log in",
  "loginEmail": "Email",
  "loginPassword": "Password",
  "loginErrorEmptyEmail": "Enter your email",
  "loginErrorEmptyPassword": "Enter your password",
  "loginErrorInvalid": "Invalid email or password",

  "settingsTitle": "Settings",
  "settingsGuest": "Guest",
  "settingsHome": "Home",
  "settingsLogOut": "Log out",
  "settingsLogIn": "Log in",
  "settingsLanguage": "Language",
  "settingsLanguageSystem": "System default",
  "settingsLanguageEnglish": "English",
  "settingsLanguageGerman": "Deutsch",

  "searchHint": "Search here...",
  "searchSavedPlaces": "Saved places",

  "locationCurrent": "Current location",
  "locationDroppedPin": "Dropped pin",
  "locationFetchError": "Could not get current location: {error}",
  "@locationFetchError": {
    "placeholders": { "error": { "type": "String" } }
  },

  "mapLoadError": "Failed to load map: {error}",
  "@mapLoadError": {
    "placeholders": { "error": { "type": "String" } }
  },

  "routeLoadError": "Could not load route",
  "routeClearTooltip": "Clear route",
  "routeStart": "Start",
  "routeSummary": "🚲 {minutes} min · {distance} km",
  "@routeSummary": {
    "placeholders": {
      "minutes": { "type": "int" },
      "distance": { "type": "String" }
    }
  },

  "navStarting": "Starting navigation...",
  "navError": "Navigation error",
  "navOnRoute": "On route",
  "navMuteVoice": "Mute voice",
  "navEnableVoice": "Enable voice",
  "navEndNavigation": "End navigation",
  "navRerouting": "Rerouting…",

  "arrivedTitle": "Arrived",
  "arrivedDone": "Done"
}
```

- [ ] **Step 2: Replace `mobile/lib/l10n/app_de.arb`**

```json
{
  "@@locale": "de",

  "appTitle": "BeeBeeBike",

  "commonLoading": "Lädt…",

  "loginTitle": "Anmelden",
  "loginEmail": "E-Mail",
  "loginPassword": "Passwort",
  "loginErrorEmptyEmail": "E-Mail eingeben",
  "loginErrorEmptyPassword": "Passwort eingeben",
  "loginErrorInvalid": "Ungültige E-Mail oder ungültiges Passwort",

  "settingsTitle": "Einstellungen",
  "settingsGuest": "Gast",
  "settingsHome": "Zuhause",
  "settingsLogOut": "Abmelden",
  "settingsLogIn": "Anmelden",
  "settingsLanguage": "Sprache",
  "settingsLanguageSystem": "Systemstandard",
  "settingsLanguageEnglish": "English",
  "settingsLanguageGerman": "Deutsch",

  "searchHint": "Hier suchen…",
  "searchSavedPlaces": "Gespeicherte Orte",

  "locationCurrent": "Aktueller Standort",
  "locationDroppedPin": "Markierung",
  "locationFetchError": "Standort konnte nicht ermittelt werden: {error}",

  "mapLoadError": "Karte konnte nicht geladen werden: {error}",

  "routeLoadError": "Route konnte nicht geladen werden",
  "routeClearTooltip": "Route löschen",
  "routeStart": "Start",
  "routeSummary": "🚲 {minutes} Min · {distance} km",

  "navStarting": "Navigation wird gestartet…",
  "navError": "Navigationsfehler",
  "navOnRoute": "Auf der Route",
  "navMuteVoice": "Stimme aus",
  "navEnableVoice": "Stimme an",
  "navEndNavigation": "Navigation beenden",
  "navRerouting": "Route wird neu berechnet…",

  "arrivedTitle": "Angekommen",
  "arrivedDone": "Fertig"
}
```

- [ ] **Step 3: Regenerate**

```bash
cd mobile && flutter pub get
```

Expected: no errors; `AppLocalizations` now exposes getters for every key.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/l10n/
git commit -m "mobile: add full en+de ARB key set"
```

---

## Task 7: Localize leaf widgets

Goal: convert hardcoded strings in simple widgets (not screens) and update their widget tests to wrap roots with the localization delegates.

**Files:**
- Modify: `mobile/lib/widgets/arrived_sheet.dart`
- Modify: `mobile/lib/widgets/eta_sheet.dart`
- Modify: `mobile/lib/widgets/rerouting_toast.dart`
- Modify: `mobile/lib/widgets/route_summary.dart`
- Modify: `mobile/lib/widgets/search_bar.dart`
- Modify: `mobile/test/widgets/arrived_sheet_test.dart`
- Modify: `mobile/test/widgets/eta_sheet_test.dart`
- Modify: `mobile/test/widgets/rerouting_toast_test.dart`
- Modify: `mobile/test/widgets/route_summary_test.dart`

(`turn_banner.dart` has no strings; leave unchanged.)

- [ ] **Step 1: Rewrite `arrived_sheet.dart`**

```dart
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class ArrivedSheet extends StatelessWidget {
  const ArrivedSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.arrivedTitle, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: Text(l10n.arrivedDone)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update `eta_sheet.dart`**

Add `import '../l10n/generated/app_localizations.dart';`. Inside `build`, after the `Padding(` opening, add `final l10n = AppLocalizations.of(context)!;`. Replace:

- `const Text('Loading...')` → `Text(l10n.commonLoading)` (drop `const`)
- `const Text('—')` stays as-is (non-translatable em-dash)
- `tooltip: ttsEnabled ? 'Mute voice' : 'Enable voice'` → `tooltip: ttsEnabled ? l10n.navMuteVoice : l10n.navEnableVoice`
- `tooltip: 'End navigation'` → `tooltip: l10n.navEndNavigation`

- [ ] **Step 3: Update `rerouting_toast.dart`**

Full replacement:

```dart
import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

class ReroutingToast extends StatelessWidget {
  const ReroutingToast({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.navRerouting,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Update `route_summary.dart`**

Add `import '../l10n/generated/app_localizations.dart';`. Rewrite `build`:

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              l10n.routeSummary(durationMinutes, distanceKm.toStringAsFixed(1)),
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: l10n.routeClearTooltip,
              icon: const Icon(Icons.close),
              onPressed: onClose,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: onStart,
        child: Text(l10n.routeStart),
      ),
    ],
  );
}
```

- [ ] **Step 5: Update `search_bar.dart`**

Add the ARB import. Inside `build`, add `final l10n = AppLocalizations.of(context)!;`. Replace:

```dart
child: const Padding(
  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  child: Text('Search here...'),
),
```

with:

```dart
child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  child: Text(l10n.searchHint),
),
```

- [ ] **Step 6: Wrap widget tests with localization delegates**

For each of `arrived_sheet_test.dart`, `eta_sheet_test.dart`, `rerouting_toast_test.dart`, `route_summary_test.dart`: add

```dart
import 'package:beebeebike/l10n/generated/app_localizations.dart';
```

and make sure the `pumpWidget` root is:

```dart
await tester.pumpWidget(MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: <widget under test>),
));
```

Keep string assertions on English literals (`'Start'`, `'Done'`, etc.) — identical to the ARB `en` values. This makes tests break loudly if a key is renamed without updating the ARB.

- [ ] **Step 7: Run widget tests**

```bash
cd mobile && flutter test test/widgets/
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/widgets/ mobile/test/widgets/
git commit -m "mobile: localize leaf widgets (arrived/eta/rerouting/summary/search bar)"
```

---

## Task 8: Localize login, search, and map screens

Goal: convert strings in the three large screens.

**Files:**
- Modify: `mobile/lib/screens/login_screen.dart`
- Modify: `mobile/lib/screens/search_screen.dart`
- Modify: `mobile/lib/screens/map_screen.dart`
- Modify: `mobile/test/screens/map_screen_test.dart`
- Modify: `mobile/test/screens/map_screen_navigation_test.dart`
- Modify: `mobile/test/screens/search_screen_test.dart`

- [ ] **Step 1: Rewrite `login_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';

enum _LoginErrorKind { invalidCredentials }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  _LoginErrorKind? _errorKind;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorKind = null;
    });

    await ref.read(authControllerProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text,
        );

    if (!mounted) return;

    final result = ref.read(authControllerProvider);
    if (result is AsyncError) {
      setState(() {
        _errorKind = _LoginErrorKind.invalidCredentials;
        _loading = false;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const Key('login_email'),
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.loginEmail),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.loginErrorEmptyEmail
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('login_password'),
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: l10n.loginPassword),
                validator: (v) => (v == null || v.isEmpty)
                    ? l10n.loginErrorEmptyPassword
                    : null,
              ),
              const SizedBox(height: 8),
              if (_errorKind != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    l10n.loginErrorInvalid,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.loginTitle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Update `search_screen.dart`**

Add `import '../l10n/generated/app_localizations.dart';`. In `build`, add `final l10n = AppLocalizations.of(context)!;` and replace:

```dart
decoration: const InputDecoration(
  hintText: 'Search here...',
  border: InputBorder.none,
),
```

with:

```dart
decoration: InputDecoration(
  hintText: l10n.searchHint,
  border: InputBorder.none,
),
```

- [ ] **Step 3: Update `map_screen.dart`**

Add `import '../l10n/generated/app_localizations.dart';`.

In each `build` method that constructs user-visible text — `_MapScreenState.build`, `_BrowseOverlay.build`, `_NavigationOverlay.build` — add `final l10n = AppLocalizations.of(context)!;` at the top.

Then replace these literals:

Inside `_MapScreenState`:
- `_handleMapTap`: `name: 'Current location'` / `label: 'Current location'` → use `l10n.locationCurrent` (read `l10n` at the top of the method via `AppLocalizations.of(context)!`). `label: 'Dropped pin'` → `l10n.locationDroppedPin`.
- `_flyToCurrentLocation`: `'Could not get current location: $e'` → `l10n.locationFetchError(e.toString())` (read `l10n` inside the method from `this.context`).

Inside `_MapScreenState.build`:
- `Center(child: Text('Failed to load map: $e'))` → `Center(child: Text(l10n.mapLoadError(e.toString())))`

Inside `_BrowseOverlay.build`:
- `onTap` handler — creates `Location` with `name: 'Current location'` and `label: 'Current location'` → `l10n.locationCurrent`.
- `'Could not load route'` → `l10n.routeLoadError`.
- `'Home'` inside the saved-places stub → `l10n.settingsHome`.
- `'Saved places'` → `l10n.searchSavedPlaces`.
- Remove `const` on the surrounding `Column` / `Text` since they now reference non-const `l10n`.

Inside `_NavigationOverlay.build`:
- `primaryText: 'Starting navigation...'` → `l10n.navStarting`
- `primaryText: 'Navigation error'` → `l10n.navError`
- `state.currentVisual?.primaryText ?? 'On route'` → `state.currentVisual?.primaryText ?? l10n.navOnRoute`

- [ ] **Step 4: Wrap screen tests with localization delegates**

For `map_screen_test.dart`, `map_screen_navigation_test.dart`, `search_screen_test.dart`: import `AppLocalizations` and wrap `pumpWidget` roots with `MaterialApp` carrying `localizationsDelegates`, `supportedLocales`, and `locale: const Locale('en')`. Any string assertions stay on the English literal.

- [ ] **Step 5: Run mobile tests**

```bash
just test-mobile
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/login_screen.dart mobile/lib/screens/search_screen.dart mobile/lib/screens/map_screen.dart mobile/test/screens/
git commit -m "mobile: localize login, search, and map screens"
```

---

## Task 9: Language picker widget (TDD)

Goal: a reusable Settings row with three radio options (System / English / Deutsch) that writes to `localeProvider`.

**Files:**
- Create: `mobile/lib/widgets/language_picker.dart`
- Create: `mobile/test/widgets/language_picker_test.dart`

- [ ] **Step 1: Write failing test**

Create `mobile/test/widgets/language_picker_test.dart`:

```dart
import 'package:beebeebike/l10n/generated/app_localizations.dart';
import 'package:beebeebike/providers/locale_provider.dart';
import 'package:beebeebike/providers/search_history_provider.dart';
import 'package:beebeebike/widgets/language_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows all three options in English', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: _wrap(const LanguagePicker()),
    ));
    expect(find.text('System default'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });

  testWidgets('tapping Deutsch persists LocalePref.de', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _wrap(const LanguagePicker()),
    ));

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();

    expect(container.read(localeProvider), LocalePref.de);
    expect(prefs.getString('locale_pref'), 'de');
  });
}
```

- [ ] **Step 2: Run test, confirm it fails**

```bash
cd mobile && flutter test test/widgets/language_picker_test.dart
```

Expected: FAIL — file missing.

- [ ] **Step 3: Implement the widget**

Create `mobile/lib/widgets/language_picker.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/locale_provider.dart';

class LanguagePicker extends ConsumerWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(localeProvider);
    final controller = ref.read(localeProvider.notifier);

    Widget tile(LocalePref value, String label) {
      return RadioListTile<LocalePref>(
        title: Text(label),
        value: value,
        groupValue: current,
        onChanged: (v) {
          if (v != null) controller.setPref(v);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            l10n.settingsLanguage,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        tile(LocalePref.system, l10n.settingsLanguageSystem),
        tile(LocalePref.en, l10n.settingsLanguageEnglish),
        tile(LocalePref.de, l10n.settingsLanguageGerman),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test, confirm it passes**

```bash
cd mobile && flutter test test/widgets/language_picker_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/widgets/language_picker.dart mobile/test/widgets/language_picker_test.dart
git commit -m "mobile: add language picker widget"
```

---

## Task 10: Localize settings screen + mount picker

Goal: translate the settings list and add the language picker at the bottom.

**Files:**
- Modify: `mobile/lib/screens/settings_screen.dart`
- Modify: `mobile/test/screens/settings_login_test.dart`

- [ ] **Step 1: Replace `settings_screen.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/generated/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/language_picker.dart';
import 'login_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.watch(authControllerProvider).valueOrNull;
    final home = ref.watch(homeLocationProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(user?.email ?? l10n.settingsGuest),
            subtitle: Text(user?.accountType ?? l10n.commonLoading),
          ),
          if (home != null)
            ListTile(
              title: Text(l10n.settingsHome),
              subtitle: Text(home.label),
            ),
          if (user?.email != null)
            ListTile(
              title: Text(l10n.settingsLogOut),
              onTap: () =>
                  ref.read(authControllerProvider.notifier).logout(),
            )
          else
            ListTile(
              title: Text(l10n.settingsLogIn),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            ),
          const Divider(),
          const LanguagePicker(),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Update `settings_login_test.dart`**

Wrap `pumpWidget` root with `MaterialApp` supplying `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales`, `locale: const Locale('en')`. Keep assertions on English literals.

- [ ] **Step 3: Run tests**

```bash
just test-mobile
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add mobile/lib/screens/settings_screen.dart mobile/test/screens/settings_login_test.dart
git commit -m "mobile: localize settings screen and mount language picker"
```

---

## Task 11: Backend `Accept-Language` → GraphHopper `locale` (TDD)

Goal: `routing.rs` reads the `Accept-Language` header and maps `en|de` (fallback `en`) into the GraphHopper request body.

**Files:**
- Modify: `backend/src/routing.rs`
- Modify: `backend/tests/integration.rs`

- [ ] **Step 1: Add a failing test — `Accept-Language: en` routes with `"locale": "en"`**

In `backend/tests/integration.rs`, find the existing `/api/navigate` integration test (around line 970) that asserts `"locale": "de"`. Add a new test immediately after it (copy the existing setup, change the header + asserted locale):

```rust
#[tokio::test]
async fn navigate_uses_english_locale_when_accept_language_is_en() {
    let graphhopper = MockServer::start().await;

    let navigate_json = json!({
        "routes": [{ "legs": [] }],
        "waypoints": []
    });

    Mock::given(method("POST"))
        .and(path("/navigate"))
        .and(body_partial_json(json!({
            "profile": "bike",
            "locale": "en",
            "type": "mapbox"
        })))
        .respond_with(ResponseTemplate::new(200).set_body_json(navigate_json.clone()))
        .expect(1)
        .mount(&graphhopper)
        .await;

    let Some(server) = setup_with_graphhopper_url(graphhopper.uri()).await else {
        return;
    };
    let session = create_anonymous(&server).await;
    let (hname, hval) = with_session(&session);

    let resp = server
        .post("/api/navigate")
        .add_header(hname, hval)
        .add_header(
            axum::http::header::ACCEPT_LANGUAGE,
            axum::http::HeaderValue::from_static("en"),
        )
        .json(&json!({
            "origin": [13.405, 52.52],
            "destination": [13.45, 52.51],
            "rating_weight": 1.0,
            "distance_influence": 42.0
        }))
        .await;

    resp.assert_status_ok();
    graphhopper.verify().await;
}
```

Also update the existing `/api/navigate` test that currently expects `"locale": "de"` without sending a header: add the header explicitly

```rust
.add_header(
    axum::http::header::ACCEPT_LANGUAGE,
    axum::http::HeaderValue::from_static("de"),
)
```

so the test pins behaviour to the header rather than the default. Do the same (update or add) for the existing `/api/route` test if it asserts `"locale": "de"`: either change its expectation to `"locale": "en"` (no header) OR keep `"de"` and add the explicit `Accept-Language: de` header — prefer the latter for symmetry with the navigate case.

- [ ] **Step 2: Run backend tests, confirm they fail**

```bash
just test-backend
```

Expected: FAIL. The new test asserts `locale: en` but the current implementation hardcodes `locale: de`.

- [ ] **Step 3: Implement the header parser + wire it through**

Edit `backend/src/routing.rs`. Add a new helper near the top (below the existing `resolve_distance_influence`):

```rust
/// Resolve GraphHopper `locale` from an HTTP `Accept-Language` header. Only
/// `en` and `de` are supported; anything else (including a missing header)
/// falls back to `en`.
fn resolve_gh_locale(headers: &axum::http::HeaderMap) -> &'static str {
    let raw = headers
        .get(axum::http::header::ACCEPT_LANGUAGE)
        .and_then(|v| v.to_str().ok())
        .unwrap_or("");
    // Accept-Language can look like "de-DE,en;q=0.8". Take the primary tag.
    let primary = raw
        .split(|c: char| c == ',' || c == ';')
        .next()
        .unwrap_or("");
    let lang = primary
        .split('-')
        .next()
        .unwrap_or("")
        .trim()
        .to_ascii_lowercase();
    match lang.as_str() {
        "de" => "de",
        _ => "en",
    }
}
```

Change `build_graphhopper_request` to accept the locale:

```rust
fn build_graphhopper_request(
    state: &AppState,
    body: &RouteRequest,
    rows: &[RatedAreaRow],
    mode: GraphhopperMode,
    locale: &str,
) -> Result<Value, AppError> {
    // ... existing setup unchanged ...

    let mut gh_request = json!({
        "points": [body.origin, body.destination],
        "profile": "bike",
        "locale": locale,
        "ch.disable": true,
    });

    // ... rest unchanged
}
```

Update both handlers:

```rust
pub async fn get_route(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<RouteRequest>,
) -> Result<Json<RouteResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let locale = resolve_gh_locale(&headers);
    let rows = load_rated_areas(&state, user_id, body.origin, body.destination).await?;
    let gh_request =
        build_graphhopper_request(&state, &body, &rows, GraphhopperMode::Preview, locale)?;
    // ... unchanged
}

pub async fn get_navigation_route(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<RouteRequest>,
) -> Result<Json<Value>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let locale = resolve_gh_locale(&headers);
    let rows = load_rated_areas(&state, user_id, body.origin, body.destination).await?;
    let gh_request =
        build_graphhopper_request(&state, &body, &rows, GraphhopperMode::Navigate, locale)?;
    // ... unchanged
}
```

Add unit tests inside the existing `#[cfg(test)] mod tests` block at the bottom of `routing.rs`:

```rust
#[test]
fn resolve_locale_defaults_to_en_when_missing() {
    let h = axum::http::HeaderMap::new();
    assert_eq!(resolve_gh_locale(&h), "en");
}

#[test]
fn resolve_locale_recognises_de() {
    let mut h = axum::http::HeaderMap::new();
    h.insert(
        axum::http::header::ACCEPT_LANGUAGE,
        axum::http::HeaderValue::from_static("de"),
    );
    assert_eq!(resolve_gh_locale(&h), "de");
}

#[test]
fn resolve_locale_parses_weighted_tag() {
    let mut h = axum::http::HeaderMap::new();
    h.insert(
        axum::http::header::ACCEPT_LANGUAGE,
        axum::http::HeaderValue::from_static("de-DE,en;q=0.8"),
    );
    assert_eq!(resolve_gh_locale(&h), "de");
}

#[test]
fn resolve_locale_unknown_tag_falls_back_to_en() {
    let mut h = axum::http::HeaderMap::new();
    h.insert(
        axum::http::header::ACCEPT_LANGUAGE,
        axum::http::HeaderValue::from_static("fr"),
    );
    assert_eq!(resolve_gh_locale(&h), "en");
}
```

- [ ] **Step 4: Run backend tests + lint**

```bash
just test-backend
just lint-backend
```

Expected: PASS, no clippy warnings.

- [ ] **Step 5: Commit**

```bash
git add backend/src/routing.rs backend/tests/integration.rs
git commit -m "backend: derive GraphHopper locale from Accept-Language"
```

---

## Task 12: End-to-end verification

Goal: run the full lint + test matrix and sanity-check on the iOS simulator.

- [ ] **Step 1: Full test matrix**

```bash
just lint-backend
just test-backend
just test-mobile
```

Expected: all PASS.

- [ ] **Step 2: Boot the dev stack**

In one terminal:

```bash
just dev
```

In another:

```bash
just dev-ios-sim
```

- [ ] **Step 3: Manual smoke — simulator in English**

1. App UI is in English.
2. Settings → Language → tap `Deutsch`.
3. UI flips to German immediately (Settings title becomes "Einstellungen", Search bar placeholder becomes "Hier suchen…").
4. Compute a route: "Start" / "Route löschen" appear.
5. Start navigation: TTS speaks German. First voice instruction includes a German direction word.
6. Inspect backend logs (`docker logs $(docker ps -q -f name=backend)`) — the `/api/navigate` request carries `accept-language: de`.
7. Switch back to `System default`. UI returns to English (simulator locale is en).

- [ ] **Step 4: Manual smoke — simulator in German**

Switch the iOS simulator system language (Settings app → General → Language & Region → iPhone Language → Deutsch), reopen the app with `System default` selected:

1. UI renders in German without manual toggle.
2. TTS speaks German.
3. Backend receives `accept-language: de`.

- [ ] **Step 5: Commit any follow-up fixes**

If the smoke test surfaces regressions, add fixes in separate commits, re-run `just test-mobile` + `just test-backend`, then either push the branch or open a PR.

---

## Self-review checklist

- Every section of the spec (Goal, Supported locales, LocalePref model, Flutter wiring, TTS, Backend Accept-Language, Settings UI, Data flow, Error handling, Testing) is implemented by at least one task above.
- No placeholders, TBDs, or "similar to above" blocks — every code block is concrete.
- Type names are consistent across tasks: `LocalePref`, `LocaleController`, `localeProvider`, `effectiveLanguageTag`, `ttsFactoryProvider`, `resolve_gh_locale`.
- Every task ends with a commit.
- Test commands are exact and runnable from the repo root.

# Mobile app i18n — English + German

**Date:** 2026-04-22
**Scope:** Flutter mobile app (`mobile/`) and backend routing endpoint.

## Goal

Add first-class English + German localization to the BeeBeeBike mobile app using the standard Flutter toolchain (`flutter_localizations` + `gen_l10n` + ARB files). Locale defaults to the device setting and can be overridden via a picker in the settings screen.

## Non-goals

- Map label language (OSM `name:en` fallback in the MapLibre style). Out of scope for this iteration; map style stays on the default `name` field.
- Third-party packages (`easy_localization`, `slang`). Standard Flutter only.
- Additional languages beyond `en` and `de`.

## Background

Current state (2026-04-22):

- ~48 hardcoded English-ish UI strings across 10 screens/widgets in `mobile/lib/`.
- TTS hardcoded to `de-DE` in `mobile/lib/providers/navigation_provider.dart:33`.
- Backend `POST /api/route` hardcodes `"locale": "de"` when calling GraphHopper (`backend/src/routing.rs:163`), so turn-by-turn instructions come back in German regardless of client.
- No `flutter_localizations` dependency, no ARB files, no `l10n.yaml`.

## Architecture

### Supported locales

- `en` (English) — fallback.
- `de` (German).

### Locale preference model

A single source of truth exposed via a Riverpod provider:

```dart
enum LocalePref { system, en, de }
```

Persisted in `shared_preferences` under key `locale_pref` as `"system" | "en" | "de"`. Default on first launch: `system`.

The provider exposes:

- `LocalePref pref` — user choice (for UI selection state).
- `Locale? materialLocale` — value for `MaterialApp.locale`: `null` when `system`, otherwise `Locale('en')` or `Locale('de')`.
- `Locale effectiveLocale(BuildContext)` — resolved locale after Flutter's `supportedLocales` negotiation (used by TTS and HTTP header).
- `setPref(LocalePref)` — writes prefs and updates state.

### Flutter wiring

- `pubspec.yaml`: add `flutter_localizations: { sdk: flutter }`, `intl` (version pinned by Flutter SDK), `generate: true` under `flutter:`.
- `l10n.yaml` at `mobile/l10n.yaml`:
  ```yaml
  arb-dir: lib/l10n
  template-arb-file: app_en.arb
  output-localization-file: app_localizations.dart
  output-class: AppLocalizations
  ```
- `mobile/lib/l10n/app_en.arb` + `app_de.arb` with one key per user-facing string (see Translation Inventory below).
- `MaterialApp` in `mobile/lib/app.dart`:
  - `localizationsDelegates: AppLocalizations.localizationsDelegates`
  - `supportedLocales: AppLocalizations.supportedLocales`
  - `locale: ref.watch(localeProvider).materialLocale`

### TTS

In `mobile/lib/providers/navigation_provider.dart`, replace the hardcoded `setLanguage('de-DE')` with a derivation from the effective locale:

- `en` → `en-US`
- `de` → `de-DE`

The `flutterTtsProvider` watches `localeProvider` so a change at runtime reconfigures TTS before the next spoken instruction.

### Backend `Accept-Language`

Mobile `dio` client gets an interceptor that adds `Accept-Language: <lang>` (just `en` or `de`) to every request, based on `localeProvider.effectiveLocale`.

Backend `POST /api/route` handler:

- Reads `Accept-Language` header.
- Parses it: if value starts with `de` → `"de"`; if starts with `en` → `"en"`; otherwise → `"en"`.
- Passes to GraphHopper request body `locale` field.
- No change to request/response schema; purely header-driven.

Other endpoints (`/api/geocode`, `/api/ratings/*`, auth) do not currently return localizable content, so no backend change required beyond routing.

### Settings UI

Add a new section to `mobile/lib/screens/settings_screen.dart`:

- Section title (localized): "Language" / "Sprache".
- Three-way selector (Cupertino segmented control or list tiles with radio) with options:
  - System default
  - English
  - Deutsch
- Label for each option is written in that option's own language (Deutsch is always "Deutsch"), except "System default" which is localized.

## Data flow

1. App launch.
2. `localeProvider` reads `locale_pref` from `shared_preferences` → initial state (default `system`).
3. `MaterialApp.locale` = `null` when system, else explicit. Flutter resolves against `supportedLocales`; unknown device locales fall back to `en`.
4. Widgets read strings via `AppLocalizations.of(context)!`.
5. Dio interceptor reads `effectiveLocale` on each request → `Accept-Language` header.
6. TTS reconfigures on locale change.
7. User changes picker → provider persists + rebuilds → MaterialApp rebuilds → dio interceptor and TTS see the new value.

## Translation inventory

Enumerated by scanning the 10 files identified at design time. During implementation, one ARB key is created per unique string. Keys use lowerCamelCase, grouped by screen (e.g., `settingsLanguage`, `loginSignIn`, `searchHintWhereTo`). Plurals use ICU plural syntax in ARB.

Files to re-scan during implementation for coverage:
- `mobile/lib/screens/login_screen.dart`
- `mobile/lib/screens/map_screen.dart`
- `mobile/lib/screens/search_screen.dart`
- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/widgets/arrived_sheet.dart`
- `mobile/lib/widgets/eta_sheet.dart`
- `mobile/lib/widgets/rerouting_toast.dart`
- `mobile/lib/widgets/route_summary.dart`
- `mobile/lib/widgets/search_bar.dart`
- `mobile/lib/widgets/turn_banner.dart`

Implementation translates all strings into both English and German; user reviews translations post-implementation.

## Error handling

- Missing ARB key in `app_de.arb`: `gen_l10n` fails the build — caught by `just test-mobile` / CI.
- Unknown device locale: Flutter's `localeResolutionCallback` falls back to first supported (`en`).
- `shared_preferences` read failure: state defaults to `system`.
- Backend `Accept-Language` missing or unparseable: defaults to `"en"`.

## Testing

- **Widget tests** (`mobile/test/`):
  - Pump a scaffold with `localizationsDelegates` in both locales; assert a representative string in each (e.g., settings title in `de` vs `en`).
  - Language picker: tapping an option updates provider and rebuilds visible strings.
- **Unit tests**:
  - `localeProvider` persistence roundtrip (system → en → de → system) using `SharedPreferences.setMockInitialValues`.
- **Backend tests** (`backend/tests/integration.rs`):
  - `Accept-Language: de` → GraphHopper request `"locale": "de"`.
  - `Accept-Language: en` → `"locale": "en"`.
  - Missing header → `"locale": "en"`.
- **Commands**: `just test-mobile`, `just test-backend`, `just lint-backend`.

## Out of scope / follow-ups

- Map label language: requires `name:en` fallback in `web/src/lib/bicycle-style.js` and style regeneration (`just build-mobile-style`). Track separately once English coverage in Berlin is verified.
- Web app localization: same approach applies but is not part of this spec.
- Additional locales (fr, es, ...): add ARB + extend `LocalePref` enum; no structural change.

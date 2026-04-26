# Mobile: set home location

## Goal

Let mobile users set / change their home location. Backend (`PUT /api/locations/home`), API client (`LocationsApi.setHome`), and provider (`homeLocationProvider`) already exist. Mobile reads home in several places but exposes no setter UI.

## Non-goals

- Map long-press to set home
- "Use current location" shortcut
- Editable label after geocode
- Multiple saved places (work, etc.)
- Backend changes

## Entry points

Three triggers, all push the same picker:

1. **Settings screen** ([mobile/lib/screens/settings_screen.dart](../../../mobile/lib/screens/settings_screen.dart))
   - No home set: list row labelled `settingsSetHome` ("Set home")
   - Home set: existing home display becomes tappable as a whole row, with `settingsChangeHome` ("Change home") shown as a trailing label or icon-button hint
   - Both push `SearchScreen(mode: SearchMode.pickHome)`

2. **Home sheet — empty state** ([mobile/lib/widgets/home_sheet.dart](../../../mobile/lib/widgets/home_sheet.dart))
   - When `auth.isLoggedIn && homeLocation == null`: render a single primary CTA ("Set home", `homeSheetSetHome`) in place of the existing `Go Home` button
   - Tap pushes `SearchScreen(mode: SearchMode.pickHome)`
   - Login/register cards still shown when logged out (existing behaviour preserved)

3. **Home sheet — long-press existing Go Home button**
   - When home is set: long-press `_GoHomeButton` triggers `HapticFeedback.mediumImpact()` and pushes the same picker
   - Short-press behaviour (start nav home) unchanged

## Picker: SearchScreen pickHome mode

Add `enum SearchMode { route, pickHome }` to [mobile/lib/screens/search_screen.dart](../../../mobile/lib/screens/search_screen.dart). Default `route` keeps current behaviour.

In `pickHome` mode:
- App-bar title uses `searchPickHomeTitle` ("Pick home location")
- "Saved home" / recent / current-location shortcuts that exist for routing pickup are **not** rendered
- Search field + geocode results behave identically to route mode
- Tapping a result:
  1. Calls `await ref.read(homeLocationProvider.notifier).set(location)`
  2. On success: `Navigator.of(context).pop()`, then `ScaffoldMessenger.of(context).showSnackBar(...)` with `homeSetSuccess` ("Home set to {label}")
  3. On failure: stay on screen, snackbar with `homeSetError` ("Couldn't set home"). No state mutation on failure (provider's `set` already guards via `AsyncValue.guard`)

The snackbar must fire on the screen the user *returns to*, not on `SearchScreen` (which has popped). Capture `final messenger = ScaffoldMessenger.of(context)` in the trigger callback **before** the `Navigator.push`, then call `messenger.showSnackBar(...)` after the push resolves with the saved `Location`. Picker returns the saved `Location?` from `Navigator.pop(context, savedLocation)` so the caller knows whether to show success or stay silent.

## Provider

`HomeLocationController.set(Location)` already exists at [mobile/lib/providers/location_provider.dart:25](../../../mobile/lib/providers/location_provider.dart). No changes.

The `Location` passed in: built from the tapped `GeocodeResult` — `Location(label: result.label, lng: result.lng, lat: result.lat)`. Existing route mode already does this conversion; reuse the same helper if one exists, otherwise inline.

## Localization

Add to `mobile/lib/l10n/app_en.arb` and `mobile/lib/l10n/app_de.arb`:

| Key | en | de |
|---|---|---|
| `settingsSetHome` | "Set home" | "Zuhause festlegen" |
| `settingsChangeHome` | "Change home" | "Zuhause ändern" |
| `homeSheetSetHome` | "Set home" | "Zuhause festlegen" |
| `searchPickHomeTitle` | "Pick home location" | "Zuhause auswählen" |
| `homeSetSuccess` | "Home set to {label}" | "Zuhause auf {label} gesetzt" |
| `homeSetError` | "Couldn't set home" | "Zuhause konnte nicht gespeichert werden" |

`homeSetSuccess` uses ARB placeholder syntax with `{label}` (string).

Regenerate `mobile/lib/l10n/generated/*` as part of the change.

## Tests

- **`mobile/test/widgets/home_sheet_test.dart`** (new or extended)
  - Logged-in + no home → "Set home" CTA renders, "Go Home" button absent
  - Logged-in + home set → long-press on `_GoHomeButton` calls `HapticFeedback.mediumImpact` (verify via test channel) and pushes route to picker (use a `MaterialApp` with `onGenerateRoute` mock)
  - Logged-out → existing login/register cards still render

- **`mobile/test/screens/search_screen_test.dart`** (new or extended)
  - `pickHome` mode: title is `searchPickHomeTitle`
  - Tap on a fake geocode result calls `homeLocationProvider.set` with the right `Location`
  - On success: route popped + snackbar visible with success text
  - On `setHome` throwing: route not popped + snackbar with error text

- **`mobile/test/screens/settings_screen_test.dart`** (new or extended)
  - No home → row labelled `settingsSetHome`
  - Home set → existing home block + `settingsChangeHome` affordance

Override `locationsApiProvider` with a fake in tests to control success/failure without hitting Dio.

## Files touched

- `mobile/lib/screens/settings_screen.dart`
- `mobile/lib/screens/search_screen.dart`
- `mobile/lib/widgets/home_sheet.dart`
- `mobile/lib/l10n/app_en.arb`
- `mobile/lib/l10n/app_de.arb`
- `mobile/lib/l10n/generated/*` (regenerated)
- `mobile/test/widgets/home_sheet_test.dart`
- `mobile/test/screens/search_screen_test.dart`
- `mobile/test/screens/settings_screen_test.dart`

## Edge cases

- **Logged-out user opens settings via deep link**: settings already gates home block on auth. New "Set home" row only renders when logged in.
- **Network failure mid-set**: `AsyncValue.guard` keeps prior state; UI stays on picker; user can retry.
- **Backend returns different label than typed query**: snackbar uses the saved `Location.label` returned from the provider, not the geocode result's raw label.
- **User pops picker before tapping**: no-op. No partial state.
- **Rapid double-tap on a result**: protect with a local "saving" flag in the picker tile or disable the list during the in-flight `set` call.

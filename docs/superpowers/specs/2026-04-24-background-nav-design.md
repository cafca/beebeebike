# Background navigation + wake lock (iOS)

## Goal

While navigation is active, the app must:

1. Continue receiving GPS updates and rerouting when backgrounded or the screen is locked.
2. Keep the screen awake (no auto-dim) while the app is foregrounded.
3. Continue speaking turn-by-turn voice cues when the screen is locked.

"Navigation is active" = from `NavigationService.start()` returning to `NavigationService.dispose()`.

## Current state

- `UIBackgroundModes` already contains `location` ([mobile/ios/Runner/Info.plist:68-71](../../../mobile/ios/Runner/Info.plist)).
- `NSLocationAlwaysAndWhenInUseUsageDescription` + `NSLocationWhenInUseUsageDescription` set.
- Geolocator stream uses generic `LocationSettings` — no iOS-specific background flags ([mobile/lib/providers/navigation_provider.dart:26-31](../../../mobile/lib/providers/navigation_provider.dart)).
- Only `LocationPermission.whenInUse` requested.
- No wakelock dependency.
- `flutter_tts` initialized without iOS audio-session config — playback stops when screen locks.

## Design

### 1. Wake lock

- Add `wakelock_plus` dependency.
- Inject an on/off pair into `NavigationService` (typedef `SetWakelock`) so tests can mock.
- Enable at the end of `start()`; disable at the start of `dispose()` (in a try/finally so a failed start still disables).

Rationale for injection: keeps `NavigationService` pure Dart, avoids pulling a plugin into unit-test paths.

### 2. Background GPS

Replace `LocationSettings` in `_buildLocationStream` with platform-specific `AppleSettings`:

```dart
AppleSettings(
  accuracy: LocationAccuracy.bestForNavigation,
  activityType: ActivityType.otherNavigation,
  distanceFilter: 0,
  pauseLocationUpdatesAutomatically: false,
  allowBackgroundLocationUpdates: true,
  showBackgroundLocationIndicator: true,
)
```

Permission escalation: after the current `whenInUse` grant, call `Geolocator.requestPermission()` again — on iOS this promotes to `always`. Accept `whileInUse` silently (foreground nav still works); log if denied.

`activityType: otherNavigation` is appropriate for bicycle navigation (not `automotiveNavigation`, which biases CoreLocation heuristics toward cars).

### 3. TTS while locked

- Add `audio` to `UIBackgroundModes` array.
- In `flutterTtsProvider`, call:
  ```dart
  await tts.setSharedInstance(true);
  await tts.setIosAudioCategory(
    IosTextToSpeechAudioCategory.playback,
    [
      IosTextToSpeechAudioCategoryOptions.duckOthers,
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
    ],
    IosTextToSpeechAudioMode.voicePrompt,
  );
  ```

`playback` category (vs. current default `ambient`/`soloAmbient`) is the only category that plays when the screen is locked. `duckOthers` lowers background music during a prompt instead of stopping it.

## Testing

- **Unit:** extend `navigation_service_test.dart` — verify the injected wake-lock fn is called with `true` after `start`, `false` after `dispose`.
- **Manual on device** (release mode, `just release-ios-device`):
  - Start navigation → lock phone → confirm voice cue fires on next turn.
  - Start navigation → lock phone → walk/drive 30 s → unlock → confirm route progressed (not stuck at start).
  - Start navigation → foreground screen for 60 s without touching → confirm no auto-dim.
  - End navigation → confirm phone dims normally afterward.

## Out of scope

- Android (iOS-only per `CLAUDE.md`).
- Lock-screen widget / CarPlay / dynamic island.
- Distinction between "backgrounded with screen on" vs. "locked" — both handled identically.
- Battery-saver heuristics (pausing GPS when stationary).

## App Store review note

Adding `audio` to `UIBackgroundModes` may trigger review questions. Justification: turn-by-turn bicycle navigation voice prompts while the rider's phone is in a handlebar mount and locked.

# Mobile UX Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix six mobile UX gaps: persistent login across restarts, live ETA + remaining distance during navigation, wider arrival detection radius, auto-center on first GPS fix in browse mode, and re-fetch route with painted areas after login.

**Architecture:** All changes are in the Flutter mobile app (`mobile/`) and the local `ferrostar_flutter` plugin (`packages/ferrostar_flutter/`). No backend changes required. Each task is self-contained and independently testable.

**Tech Stack:** Flutter/Dart, Riverpod, Ferrostar (custom local plugin), MapLibre GL, Geolocator, `cookie_jar`/`dio_cookie_manager`/`path_provider`

---

## Task 1: Persist auth session across app restarts

**Problem:** `client.dart:16` uses `CookieJar()` (in-memory). Sessions are lost on every restart or reinstall.

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/api/client.dart`

- [ ] **Step 1: Add `cookieStoragePathProvider` to `client.dart`**

Add a provider that holds the cookie storage path. It must be overridden at startup (same pattern as `sharedPreferencesProvider`).

```dart
// mobile/lib/api/client.dart
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app.dart';

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
  return dio;
});
```

- [ ] **Step 2: Initialize path in `main.dart`**

```dart
// mobile/lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'api/client.dart';
import 'config/app_config.dart';
import 'providers/search_history_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final supportDir = await getApplicationSupportDirectory();
  runApp(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.fromEnvironment()),
        sharedPreferencesProvider.overrideWithValue(prefs),
        cookieStoragePathProvider.overrideWithValue(supportDir.path),
      ],
      child: const BeeBeeBikeApp(),
    ),
  );
}
```

- [ ] **Step 3: Run the app on simulator and verify login persists**

```bash
just dev-ios-sim
```

Log in, kill the app from the simulator (swipe up in app switcher), relaunch. Settings screen should still show the logged-in email without requiring re-login.

- [ ] **Step 4: Verify existing auth test still passes**

```bash
cd mobile && flutter test test/providers/auth_provider_test.dart
```

Expected: PASS (test overrides `dioProvider` directly, so the new `cookieStoragePathProvider` dependency is never exercised).

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/api/client.dart mobile/lib/main.dart
git commit -m "fix(mobile): persist auth cookies to disk across app restarts"
```

---

## Task 2: Show total remaining distance + live ETA in navigation UI

**Problem:** `EtaSheet` shows ETA time but not total remaining distance. `TripProgress.distanceRemainingM` exists but is never displayed. `TurnBanner` shows `distanceToNextManeuverM` (to next turn only). Both values update live from the Ferrostar state stream — they just aren't surfaced.

**Files:**
- Modify: `mobile/lib/navigation/maneuver_icons.dart`
- Modify: `mobile/lib/widgets/eta_sheet.dart`
- Modify: `mobile/test/widgets/eta_sheet_test.dart`

- [ ] **Step 1: Add `formatTotalRemaining` helper to `maneuver_icons.dart`**

```dart
// mobile/lib/navigation/maneuver_icons.dart

// ... existing functions unchanged ...

/// Formats total remaining distance + ETA: "1.4 km · 14:32".
String formatTotalRemaining(double distanceRemainingM, int durationRemainingMs) {
  final dist = formatDistance(distanceRemainingM);
  final eta = DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  return '$dist · $h:$m';
}
```

- [ ] **Step 2: Update `EtaSheet` to show total remaining distance + arrival time**

Replace the single `Text(formatEta(...))` with two lines: distance remaining on top, arrival time + minutes remaining below.

```dart
// mobile/lib/widgets/eta_sheet.dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/maneuver_icons.dart';

class EtaSheet extends StatelessWidget {
  const EtaSheet({
    super.key,
    required this.navState,
    required this.ttsEnabled,
    required this.onToggleTts,
    required this.onClose,
  });

  final AsyncValue<NavigationState> navState;
  final bool ttsEnabled;
  final VoidCallback onToggleTts;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          navState.when(
            loading: () => const Text('Loading...'),
            error: (_, __) => const Text('—'),
            data: (state) {
              final p = state.progress;
              if (p == null) return const Text('—');
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatDistance(p.distanceRemainingM),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    formatEta(p.durationRemainingMs),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              IconButton(
                tooltip: ttsEnabled ? 'Mute voice' : 'Enable voice',
                icon: Icon(ttsEnabled ? Icons.volume_up : Icons.volume_off),
                onPressed: onToggleTts,
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'End navigation',
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Write failing test for remaining distance display**

Add to `mobile/test/widgets/eta_sheet_test.dart`:

```dart
  testWidgets('shows remaining distance from distanceRemainingM', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EtaSheet(
          navState: AsyncValue.data(_state()),
          ttsEnabled: true,
          onToggleTts: () {},
          onClose: () {},
        ),
      ),
    ));
    // _state() has distanceRemainingM: 1500, so expect "1.5 km"
    expect(find.text('1.5 km'), findsOneWidget);
  });
```

- [ ] **Step 4: Run failing test**

```bash
cd mobile && flutter test test/widgets/eta_sheet_test.dart
```

Expected: FAIL with "Expected: exactly one matching node in the widget tree / Actual: _TextFinder: zero widgets"

- [ ] **Step 5: Apply changes from Steps 1 and 2, then run tests**

```bash
cd mobile && flutter test test/widgets/eta_sheet_test.dart
```

Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/navigation/maneuver_icons.dart mobile/lib/widgets/eta_sheet.dart mobile/test/widgets/eta_sheet_test.dart
git commit -m "feat(mobile): show remaining distance and live ETA in navigation sheet"
```

---

## Task 3: Widen arrival detection threshold

**Problem:** In `Serialization.swift:183`, `waypointWithinRange(20.0)` triggers trip completion only when the user is within 20m of the destination. Urban GPS accuracy is typically 20–40m, so the user often stands at the destination but their reported position is still 25–35m away. The trip never completes. 35m is the chosen threshold.

**Files:**
- Modify: `packages/ferrostar_flutter/ios/ferrostar_flutter/Sources/ferrostar_flutter/Serialization.swift`

- [ ] **Step 1: Change `waypointWithinRange` from 20m to 35m**

In `Serialization.swift`, inside `decodeConfig`:

```swift
// packages/ferrostar_flutter/ios/ferrostar_flutter/Sources/ferrostar_flutter/Serialization.swift
  static func decodeConfig(_ dict: [String: Any]) throws -> NavigationControllerConfig {
    let devM = (dict["deviation_threshold_m"] as? Double) ?? 50.0
    let snap = (dict["snap_user_location_to_route"] as? Bool) ?? true
    return NavigationControllerConfig(
      waypointAdvance: .waypointWithinRange(35.0),
      stepAdvanceCondition: stepAdvanceDistanceToEndOfStep(distance: 10, minimumHorizontalAccuracy: 32),
      arrivalStepAdvanceCondition: stepAdvanceManual(),
      routeDeviationTracking: .staticThreshold(minimumHorizontalAccuracy: 25, maxAcceptableDeviation: devM),
      snappedLocationCourseFiltering: snap ? .snapToRoute : .raw
    )
  }
```

- [ ] **Step 2: Build and test on simulator**

```bash
just dev-ios-sim
```

Navigate to a destination. Walk (or simulate GPS) to within 50m of the destination and confirm the `ArrivedSheet` appears.

- [ ] **Step 3: Run ferrostar plugin tests**

```bash
cd packages/ferrostar_flutter && flutter test
```

Expected: all PASS.

- [ ] **Step 4: Commit**

```bash
git add packages/ferrostar_flutter/ios/ferrostar_flutter/Sources/ferrostar_flutter/Serialization.swift
git commit -m "fix(ferrostar): increase arrival detection radius from 20m to 35m"
```

---

## Task 4: Auto-center on first GPS fix in browse mode

**Problem:** In `map_screen.dart`, `_handleFirstFix` only fires when `navigationSessionProvider == true`. In browse mode, the map always starts centered on Berlin (52.5200, 13.4050) regardless of the user's actual location — even if GPS is already available. The user must manually tap the "My Location" FAB.

**Files:**
- Modify: `mobile/lib/screens/map_screen.dart`

- [ ] **Step 1: Add a `_browseAutocentered` flag and auto-center logic**

Add a flag `_browseAutocentered` to `_MapScreenState` that is set to `true` after the first auto-center in browse mode. Then, after `onMapCreated`, trigger `_autocentreOnFirstBrowseFix()` which calls `_flyToCurrentLocation()` if GPS permission is already granted, silently skipping if not.

```dart
// mobile/lib/screens/map_screen.dart
// Inside _MapScreenState, add the flag:
bool _browseAutocentered = false;

// Add this method:
Future<void> _autocentreOnFirstBrowseFix() async {
  if (_browseAutocentered) return;
  if (ref.read(navigationSessionProvider)) return;
  final permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) return;
  _browseAutocentered = true;
  await _flyToCurrentLocation();
}
```

- [ ] **Step 2: Call `_autocentreOnFirstBrowseFix` from `onMapCreated`**

In the `MapLibreMap` widget's `onMapCreated` callback, add the call after setting `_mapController`:

```dart
onMapCreated: (controller) {
  _mapController = controller;
  _autocentreOnFirstBrowseFix();
},
```

- [ ] **Step 3: Reset flag when nav session ends**

In `_endNavigationSession`, reset `_browseAutocentered = false` so the user is re-centered when they exit navigation and return to browse mode:

```dart
Future<void> _endNavigationSession({bool clearRoute = false}) async {
  debugPrint('nav: end (clearRoute=$clearRoute)');
  final service = ref.read(navigationServiceProvider);
  await service.dispose();
  final controller = _mapController;
  if (controller != null) {
    await controller.updateMyLocationTrackingMode(MyLocationTrackingMode.none);
  }
  if (!mounted) return;
  setState(() {
    _rerouting = false;
    _browseAutocentered = false;
  });
  ref.read(navigationSessionProvider.notifier).state = false;
  if (clearRoute) {
    ref.read(routeControllerProvider.notifier).clear();
  }
}
```

- [ ] **Step 4: Test on simulator**

```bash
just dev-ios-sim
```

Launch a fresh app. The map should animate to the simulator's current location (default: Apple Park, Cupertino, or whatever the simulator has) within a few seconds of map load, without tapping any button.

If the simulator has no GPS fix, the map stays on Berlin — that's correct behavior.

- [ ] **Step 5: Run full mobile test suite**

```bash
cd mobile && flutter test
```

Expected: all PASS (no widget tests cover `_MapScreenState` directly).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/screens/map_screen.dart
git commit -m "feat(mobile): auto-center map on first GPS fix when opening in browse mode"
```

---

## Task 5: Re-fetch route with painted areas after login

**Problem:** When a user calculates a route while anonymous and then logs in, the existing route remains — calculated without their painted area preferences. The backend uses auth cookies to include rated areas in routing; after login the cookie is updated, but `RouteController` never re-requests the route.

`RouteController` in `route_provider.dart` is a `Notifier` with `ref` access. It can `listen` to `authControllerProvider` and re-trigger preview loading when auth transitions from anonymous to a named user.

**Files:**
- Modify: `mobile/lib/providers/route_provider.dart`
- Modify: `mobile/test/providers/route_provider_test.dart`

- [ ] **Step 1: Write a failing test for re-fetch on login**

Add to `mobile/test/providers/route_provider_test.dart`:

```dart
import 'package:beebeebike/models/user.dart';
import 'package:beebeebike/providers/auth_provider.dart';

// (Keep the existing test, add below)

test('re-fetches route preview when user logs in', () async {
  var callCount = 0;
  final container = ProviderContainer(overrides: [
    routePreviewLoaderProvider.overrideWithValue(
      ({required origin, required destination}) async {
        callCount++;
        return RoutePreview(
          geometry: const {'type': 'LineString', 'coordinates': []},
          distance: 1000 * callCount,
          time: 300000,
        );
      },
    ),
    authControllerProvider.overrideWith(() => _FakeAuthController()),
  ]);
  addTearDown(container.dispose);

  // Set up a route while anonymous.
  await container.read(routeControllerProvider.notifier).setOrigin(
        const Location(id: 'o', name: 'origin', label: 'Origin', lng: 13.4, lat: 52.5),
      );
  await container.read(routeControllerProvider.notifier).setDestination(
        const Location(id: 'd', name: 'dest', label: 'Dest', lng: 13.45, lat: 52.51),
      );
  expect(callCount, 1);

  // Simulate login.
  container.read(authControllerProvider.notifier).simulateLogin();
  await container.pump();

  expect(callCount, 2);
  expect(container.read(routeControllerProvider).preview?.distance, 2000);
});

// Fake auth controller for test
class _FakeAuthController extends AuthController {
  @override
  Future<User?> build() async =>
      const User(id: 'anon', accountType: 'anonymous');

  void simulateLogin() {
    state = const AsyncData(User(id: 'u1', email: 'a@b.com', accountType: 'user'));
  }
}
```

- [ ] **Step 2: Run the failing test**

```bash
cd mobile && flutter test test/providers/route_provider_test.dart
```

Expected: FAIL — `callCount` is 1, not 2.

- [ ] **Step 3: Implement re-fetch in `RouteController`**

In `route_provider.dart`, add a `ref.listen` call in `build()` that watches `authControllerProvider` and calls `_maybeLoadPreview()` when the user transitions to a non-anonymous account:

```dart
// mobile/lib/providers/route_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/routing_api.dart';
import '../models/location.dart';
import '../models/route_preview.dart';
import '../models/route_state.dart';
import '../providers/auth_provider.dart';

typedef RoutePreviewLoader = Future<RoutePreview> Function({
  required Location origin,
  required Location destination,
});

final routePreviewLoaderProvider = Provider<RoutePreviewLoader>((ref) {
  final api = RoutingApi(ref.watch(dioProvider));
  return ({required origin, required destination}) {
    return api.computeRoute(
      [origin.lng, origin.lat],
      [destination.lng, destination.lat],
      ratingWeight: 0.5,
      distanceInfluence: 70,
    );
  };
});

final routeControllerProvider =
    NotifierProvider<RouteController, RouteState>(RouteController.new);

class RouteController extends Notifier<RouteState> {
  @override
  RouteState build() {
    ref.listen<AsyncValue>(authControllerProvider, (prev, next) {
      final prevUser = prev?.valueOrNull;
      final nextUser = next.valueOrNull;
      // Re-fetch if a non-anonymous login just completed.
      if (prevUser?.accountType == 'anonymous' &&
          nextUser != null &&
          nextUser.accountType != 'anonymous') {
        _maybeLoadPreview();
      }
    });
    return const RouteState();
  }

  Future<void> setOrigin(Location origin) async {
    state = state.copyWith(origin: origin, error: null);
    await _maybeLoadPreview();
  }

  Future<void> setDestination(Location destination) async {
    state = state.copyWith(destination: destination, error: null);
    await _maybeLoadPreview();
  }

  int _loadGeneration = 0;

  Future<void> _maybeLoadPreview() async {
    final origin = state.origin;
    final destination = state.destination;
    if (origin == null || destination == null) return;

    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null, preview: null);
    try {
      final preview = await ref.read(routePreviewLoaderProvider)(
        origin: origin,
        destination: destination,
      );
      if (generation != _loadGeneration) return;
      state = state.copyWith(preview: preview, isLoading: false);
    } catch (error) {
      if (generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  void clear() {
    state = const RouteState();
  }
}
```

- [ ] **Step 4: Run all route provider tests**

```bash
cd mobile && flutter test test/providers/route_provider_test.dart
```

Expected: all PASS.

- [ ] **Step 5: Test manually**

```bash
just dev-ios-sim
```

1. Tap the map to set a destination — route preview appears.
2. Open Settings → log in with a test account.
3. Go back to map. The route preview should briefly show a loading spinner and then update (same route, now weighted with painted areas if any exist).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/providers/route_provider.dart mobile/test/providers/route_provider_test.dart
git commit -m "feat(mobile): re-fetch route with painted areas after user logs in"
```

---

## Self-review

### Spec coverage

| Feature | Task | Covered? |
|---------|------|----------|
| Login persists across restarts/reinstalls | Task 1 | ✅ PersistCookieJar |
| Update ETA as we progress | Task 2 | ✅ EtaSheet reads live durationRemainingMs |
| Arrival not recognized — GPS accuracy | Task 3 | ✅ 35m threshold |
| Remaining distance + ETA during navigation | Task 2 | ✅ distanceRemainingM + formatEta |
| Center on first GPS fix on app open | Task 4 | ✅ _autocentreOnFirstBrowseFix |
| Reroute after login using painted areas | Task 5 | ✅ authControllerProvider listener |

### Placeholder scan

No TBD, TODO, or "similar to Task N" references found.

### Type consistency

- `TripProgress.distanceRemainingM` (Double) used in Task 2 — matches `trip_progress.dart:9` (`distanceRemainingM: required double`)
- `formatDistance(double)` takes `double` — matches usage in `EtaSheet`
- `User.accountType` (String) used in Task 5 — matches `user.dart:13`
- `AuthController` subclass in test uses same `build()` signature as `AsyncNotifier<User?>`
- `_browseAutocentered` flag is `bool` — consistent with `setState` usage in Task 4

### Notes

- Task 5's test uses `container.pump()` (Riverpod 2 API) — verify the installed version supports it; if not, replace with a short `await Future.delayed(Duration.zero)`.
- `PersistCookieJar` creates the `.cookies/` directory automatically; no manual `mkdir` needed.
- The `arrivalStepAdvanceCondition: stepAdvanceManual()` in `Serialization.swift` means the last step never auto-advances (the `arrive` instruction stays on screen until `TripStatus.complete` is emitted by `waypointWithinRange`). This is intentional — do not change it.

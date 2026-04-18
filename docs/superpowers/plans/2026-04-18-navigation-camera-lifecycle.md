# Navigation Camera Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the navigation map fly to the rider on Start, follow with heading-up camera, yield to user pan/zoom, offer a recenter button, and react to reroute/arrival per [the spec](../specs/2026-04-18-navigation-camera-lifecycle-design.md).

**Architecture:** A `NavigationCameraController` (ChangeNotifier) holds the 4-state machine (`awaitingFirstFix`, `following`, `free`, `arrived`) and persists `followZoom`. It is injected into `NavigationScreen` via a Riverpod provider so tests can drive it directly. `NavigationScreen` wires maplibre callbacks and `navigationStateProvider` transitions to the controller, and swaps three small widgets (`RecenterFab`, `ReroutingToast`, `ArrivedSheet`) based on controller state and nav state.

**Tech Stack:** Flutter 3.19+, Riverpod 2.x, maplibre_gl 0.20.0 (has `onCameraTrackingDismissed`, `updateMyLocationTrackingMode`), ferrostar_flutter (exposes `NavigationState` with `snappedLocation`, `isOffRoute`, `status`).

---

## File Structure

| File | Responsibility | Change |
|---|---|---|
| `mobile/lib/navigation/camera_controller.dart` | State machine (ChangeNotifier); no Flutter widget imports | **rewrite** (stub → real) |
| `mobile/lib/providers/navigation_camera_provider.dart` | `navigationCameraControllerProvider` | **create** |
| `mobile/lib/widgets/recenter_fab.dart` | Small FAB with `Icons.my_location`, tap callback | **create** |
| `mobile/lib/widgets/rerouting_toast.dart` | Pill with spinner + "Rerouting…" text | **create** |
| `mobile/lib/widgets/arrived_sheet.dart` | Bottom-sheet content for arrival: headline + Done button | **create** |
| `mobile/lib/services/route_drawing.dart` | Existing route overlay; add `fitCamera` opt-out | **modify** |
| `mobile/lib/screens/navigation_screen.dart` | Wire everything: initial camera, state listener, FAB, toast, sheet | **rewrite** |
| `mobile/test/navigation/camera_controller_test.dart` | Existing 1-test file — replace with full state-machine coverage | **rewrite** |
| `mobile/test/widgets/recenter_fab_test.dart` | New | **create** |
| `mobile/test/widgets/rerouting_toast_test.dart` | New | **create** |
| `mobile/test/widgets/arrived_sheet_test.dart` | New | **create** |
| `mobile/test/screens/navigation_screen_test.dart` | Existing — keep passing after rewrite | **verify unchanged behavior** |
| `mobile/test/screens/navigation_screen_lifecycle_test.dart` | New lifecycle assertions | **create** |

---

## Tasks

### Task 1: Replace `NavigationCameraController` stub with state machine

**Files:**
- Modify: `mobile/lib/navigation/camera_controller.dart`
- Modify: `mobile/test/navigation/camera_controller_test.dart`

- [ ] **Step 1: Replace the existing test file with full state-machine coverage**

Overwrite `mobile/test/navigation/camera_controller_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:beebeebike/navigation/camera_controller.dart';

void main() {
  group('NavigationCameraController', () {
    test('starts in awaitingFirstFix with default zoom 17', () {
      final c = NavigationCameraController();
      expect(c.mode, CameraMode.awaitingFirstFix);
      expect(c.followZoom, 17.0);
    });

    test('onFirstFix transitions awaitingFirstFix -> following', () {
      final c = NavigationCameraController();
      c.onFirstFix();
      expect(c.mode, CameraMode.following);
    });

    test('onFirstFix is a no-op if already following', () {
      final c = NavigationCameraController()..onFirstFix();
      c.onFirstFix();
      expect(c.mode, CameraMode.following);
    });

    test('onTrackingDismissed transitions following -> free', () {
      final c = NavigationCameraController()..onFirstFix();
      c.onTrackingDismissed();
      expect(c.mode, CameraMode.free);
    });

    test('onTrackingDismissed is a no-op in awaitingFirstFix', () {
      final c = NavigationCameraController();
      c.onTrackingDismissed();
      expect(c.mode, CameraMode.awaitingFirstFix);
    });

    test('onTrackingDismissed is a no-op in arrived', () {
      final c = NavigationCameraController()..onArrived();
      c.onTrackingDismissed();
      expect(c.mode, CameraMode.arrived);
    });

    test('onZoomChanged mutates followZoom iff mode == free', () {
      final c = NavigationCameraController();
      c.onZoomChanged(14.0);
      expect(c.followZoom, 17.0); // awaitingFirstFix: ignored
      c.onFirstFix();
      c.onZoomChanged(15.5);
      expect(c.followZoom, 17.0); // following: ignored
      c.onTrackingDismissed();
      c.onZoomChanged(13.2);
      expect(c.followZoom, 13.2); // free: captured
    });

    test('onRecenterTapped transitions free -> following', () {
      final c = NavigationCameraController()
        ..onFirstFix()
        ..onTrackingDismissed();
      c.onRecenterTapped();
      expect(c.mode, CameraMode.following);
    });

    test('onRecenterTapped is a no-op in following', () {
      final c = NavigationCameraController()..onFirstFix();
      c.onRecenterTapped();
      expect(c.mode, CameraMode.following);
    });

    test('onArrived transitions any state to arrived', () {
      for (final setup in [
        () => NavigationCameraController(),
        () => NavigationCameraController()..onFirstFix(),
        () => NavigationCameraController()
          ..onFirstFix()
          ..onTrackingDismissed(),
      ]) {
        final c = setup();
        c.onArrived();
        expect(c.mode, CameraMode.arrived);
      }
    });

    test('notifies listeners on every successful transition', () {
      final c = NavigationCameraController();
      var notifications = 0;
      c.addListener(() => notifications++);
      c.onFirstFix();
      c.onTrackingDismissed();
      c.onZoomChanged(14.0);
      c.onRecenterTapped();
      c.onArrived();
      expect(notifications, 5);
    });

    test('does not notify on no-op transitions', () {
      final c = NavigationCameraController();
      var notifications = 0;
      c.addListener(() => notifications++);
      c.onTrackingDismissed(); // no-op from awaitingFirstFix
      c.onRecenterTapped();    // no-op from awaitingFirstFix
      expect(notifications, 0);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd mobile && flutter test test/navigation/camera_controller_test.dart`
Expected: FAIL — old `NavigationCameraController` has `followMode` bool, not `mode` enum.

- [ ] **Step 3: Rewrite `mobile/lib/navigation/camera_controller.dart`**

```dart
import 'package:flutter/foundation.dart';

enum CameraMode { awaitingFirstFix, following, free, arrived }

class NavigationCameraController extends ChangeNotifier {
  CameraMode _mode = CameraMode.awaitingFirstFix;
  double _followZoom = 17.0;

  CameraMode get mode => _mode;
  double get followZoom => _followZoom;

  void onFirstFix() {
    if (_mode != CameraMode.awaitingFirstFix) return;
    _mode = CameraMode.following;
    notifyListeners();
  }

  void onTrackingDismissed() {
    if (_mode != CameraMode.following) return;
    _mode = CameraMode.free;
    notifyListeners();
  }

  void onZoomChanged(double zoom) {
    if (_mode != CameraMode.free) return;
    _followZoom = zoom;
    notifyListeners();
  }

  void onRecenterTapped() {
    if (_mode != CameraMode.free) return;
    _mode = CameraMode.following;
    notifyListeners();
  }

  void onArrived() {
    if (_mode == CameraMode.arrived) return;
    _mode = CameraMode.arrived;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd mobile && flutter test test/navigation/camera_controller_test.dart`
Expected: PASS, all 11 tests.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/navigation/camera_controller.dart mobile/test/navigation/camera_controller_test.dart
git commit -m "feat(mobile): navigation camera state machine"
```

---

### Task 2: Add `fitCamera` opt-out to `RouteOverlay.draw`

Context: `RouteOverlay.draw` currently calls `animateCamera(newLatLngBounds(...))` to fit the route. `NavigationScreen` needs to set its own camera (origin at zoom 17), so we must make bounds-fit opt-out while keeping current `MapScreen` behavior default.

**Files:**
- Modify: `mobile/lib/services/route_drawing.dart:40-75`

- [ ] **Step 1: Modify `RouteOverlay.draw` signature**

Change [mobile/lib/services/route_drawing.dart:40-75](../../../mobile/lib/services/route_drawing.dart#L40-L75) to accept a `fitCamera` bool and gate the `animateCamera` call on it:

```dart
  static Future<RouteOverlay> draw(
    MapLibreMapController controller,
    RoutePreview preview, {
    bool fitCamera = true,
  }) async {
    final coords = _decodeLineString(preview.geometry);
    final line = await controller.addLine(LineOptions(
      geometry: coords,
      lineColor: _routeLineColor,
      lineWidth: 5.0,
      lineOpacity: 0.9,
    ));
    final origin = await controller.addCircle(CircleOptions(
      geometry: coords.first,
      circleRadius: 8.0,
      circleColor: _markerFillColor,
      circleStrokeColor: _markerStrokeColor,
      circleStrokeWidth: 2.0,
    ));
    final destination = await controller.addCircle(CircleOptions(
      geometry: coords.last,
      circleRadius: 8.0,
      circleColor: _markerFillColor,
      circleStrokeColor: _markerStrokeColor,
      circleStrokeWidth: 2.0,
    ));
    if (fitCamera) {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          _boundsFor(coords),
          left: 40,
          top: 100,
          right: 40,
          bottom: 240,
        ),
      );
    }
    return RouteOverlay._(line, origin, destination);
  }
```

- [ ] **Step 2: Run all tests to verify nothing broke**

Run: `cd mobile && flutter test`
Expected: PASS (existing tests do not assert `animateCamera` was called; they just render the screen).

- [ ] **Step 3: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/services/route_drawing.dart
git commit -m "feat(mobile): RouteOverlay.draw fitCamera opt-out"
```

---

### Task 3: Create `RecenterFab` widget

**Files:**
- Create: `mobile/lib/widgets/recenter_fab.dart`
- Create: `mobile/test/widgets/recenter_fab_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/recenter_fab_test.dart`:

```dart
import 'package:beebeebike/widgets/recenter_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders my_location icon and fires onTap when tapped',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RecenterFab(onTap: () => tapped++)),
    ));

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    await tester.tap(find.byType(RecenterFab));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/recenter_fab_test.dart`
Expected: FAIL — `RecenterFab` not found.

- [ ] **Step 3: Create the widget**

Create `mobile/lib/widgets/recenter_fab.dart`:

```dart
import 'package:flutter/material.dart';

class RecenterFab extends StatelessWidget {
  const RecenterFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'nav-recenter-fab',
      onPressed: onTap,
      child: const Icon(Icons.my_location),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/recenter_fab_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/widgets/recenter_fab.dart mobile/test/widgets/recenter_fab_test.dart
git commit -m "feat(mobile): RecenterFab widget"
```

---

### Task 4: Create `ReroutingToast` widget

**Files:**
- Create: `mobile/lib/widgets/rerouting_toast.dart`
- Create: `mobile/test/widgets/rerouting_toast_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/rerouting_toast_test.dart`:

```dart
import 'package:beebeebike/widgets/rerouting_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders text and spinner', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: ReroutingToast()),
    ));
    expect(find.text('Rerouting…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/rerouting_toast_test.dart`
Expected: FAIL — `ReroutingToast` not found.

- [ ] **Step 3: Create the widget**

Create `mobile/lib/widgets/rerouting_toast.dart`:

```dart
import 'package:flutter/material.dart';

class ReroutingToast extends StatelessWidget {
  const ReroutingToast({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 12),
          Text('Rerouting…',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/rerouting_toast_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/widgets/rerouting_toast.dart mobile/test/widgets/rerouting_toast_test.dart
git commit -m "feat(mobile): ReroutingToast widget"
```

---

### Task 5: Create `ArrivedSheet` widget

**Files:**
- Create: `mobile/lib/widgets/arrived_sheet.dart`
- Create: `mobile/test/widgets/arrived_sheet_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/widgets/arrived_sheet_test.dart`:

```dart
import 'package:beebeebike/widgets/arrived_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders Arrived headline and fires onDone when Done tapped',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ArrivedSheet(onDone: () => tapped++)),
    ));

    expect(find.text('Arrived'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/arrived_sheet_test.dart`
Expected: FAIL — `ArrivedSheet` not found.

- [ ] **Step 3: Create the widget**

Create `mobile/lib/widgets/arrived_sheet.dart`:

```dart
import 'package:flutter/material.dart';

class ArrivedSheet extends StatelessWidget {
  const ArrivedSheet({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arrived', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          FilledButton(onPressed: onDone, child: const Text('Done')),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/arrived_sheet_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/widgets/arrived_sheet.dart mobile/test/widgets/arrived_sheet_test.dart
git commit -m "feat(mobile): ArrivedSheet widget"
```

---

### Task 6: Add `navigationCameraControllerProvider`

Provider wrapping `NavigationCameraController`. Needed so lifecycle tests can read/drive the controller from outside the screen.

**Files:**
- Create: `mobile/lib/providers/navigation_camera_provider.dart`

- [ ] **Step 1: Create the provider file**

Create `mobile/lib/providers/navigation_camera_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../navigation/camera_controller.dart';

final navigationCameraControllerProvider =
    Provider.autoDispose<NavigationCameraController>((ref) {
  final controller = NavigationCameraController();
  ref.onDispose(controller.dispose);
  return controller;
});
```

- [ ] **Step 2: Verify compile**

Run: `cd mobile && flutter analyze lib/providers/navigation_camera_provider.dart`
Expected: no issues.

- [ ] **Step 3: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/providers/navigation_camera_provider.dart
git commit -m "feat(mobile): navigationCameraControllerProvider"
```

---

### Task 7: Wire `NavigationScreen` to the new camera lifecycle

This is the biggest task. We rewrite `navigation_screen.dart` to:
- Use the origin from `routeControllerProvider` as `initialCameraPosition` (zoom 17), falling back to Berlin centroid if origin is null (keeps the existing screen test valid).
- Read `navigationCameraControllerProvider` and rebuild on its changes via `AnimatedBuilder` wrapping the affected UI regions.
- `ref.listen(navigationStateProvider, ...)` handles three transitions:
  - `prev.snappedLocation == null && next.snappedLocation != null` → `cam.onFirstFix()`, animate to location at `cam.followZoom`, set `trackingCompass`.
  - `prev.isOffRoute == false && next.isOffRoute == true` → `setState(_rerouting = true)`.
  - `prev.isOffRoute == true && next.isOffRoute == false` → `setState(_rerouting = false)`.
  - `prev.status != complete && next.status == complete` → disable tracking, animate to destination at zoom 17, `cam.onArrived()`.
- Maplibre callbacks: `onCameraTrackingDismissed` → `cam.onTrackingDismissed()`; `onCameraIdle` → `cam.onZoomChanged(pos.zoom)`.
- Recenter FAB tap → animate to user at `cam.followZoom`, set `trackingCompass`, `cam.onRecenterTapped()`.
- `RouteOverlay.draw` called with `fitCamera: false`.
- Bottom sheet swaps to `ArrivedSheet` when `cam.mode == arrived`.
- `ReroutingToast` shown under `TurnBanner` when `_rerouting == true`.
- `RecenterFab` shown bottom-right above bottom sheet when `cam.mode == free`.

**Files:**
- Modify: `mobile/lib/screens/navigation_screen.dart` (full rewrite)

- [ ] **Step 1: Rewrite `mobile/lib/screens/navigation_screen.dart`**

```dart
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../navigation/camera_controller.dart';
import '../navigation/navigation_service.dart';
import '../providers/navigation_camera_provider.dart';
import '../providers/navigation_provider.dart';
import '../providers/route_provider.dart';
import '../services/map_style_loader.dart';
import '../services/route_drawing.dart';
import '../widgets/arrived_sheet.dart';
import '../widgets/recenter_fab.dart';
import '../widgets/rerouting_toast.dart';
import '../widgets/turn_banner.dart';

const _defaultCenter = LatLng(52.5200, 13.4050);
const _followZoomOnStart = 17.0;

class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({super.key});

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  late final NavigationService _navigationService;
  MapLibreMapController? _mapController;
  RouteOverlay? _routeOverlay;
  bool _ttsEnabled = true;
  bool _rerouting = false;

  @override
  void initState() {
    super.initState();
    _navigationService = ref.read(navigationServiceProvider);
    _startNavigation();
  }

  @override
  void dispose() {
    _navigationService.dispose();
    super.dispose();
  }

  Future<void> _startNavigation() async {
    final routeState = ref.read(routeControllerProvider);
    final origin = routeState.origin;
    final destination = routeState.destination;
    if (origin == null || destination == null) return;
    try {
      await _navigationService.start(
        origin: WaypointInput(lat: origin.lat, lng: origin.lng),
        destination:
            WaypointInput(lat: destination.lat, lng: destination.lng),
      );
    } catch (e, st) {
      debugPrint('NavigationScreen: failed to start navigation: $e\n$st');
    }
  }

  Future<void> _drawRouteIfReady() async {
    final controller = _mapController;
    if (controller == null) return;
    if (_routeOverlay != null) return;
    final preview = ref.read(routeControllerProvider).preview;
    if (preview == null) return;
    _routeOverlay =
        await RouteOverlay.draw(controller, preview, fitCamera: false);
  }

  Future<void> _handleFirstFix(UserLocation loc) async {
    final controller = _mapController;
    if (controller == null) return;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onFirstFix();
    await controller
        .animateCamera(CameraUpdate.newLatLngZoom(
            LatLng(loc.lat, loc.lng), cam.followZoom));
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
  }

  Future<void> _handleArrival() async {
    final controller = _mapController;
    if (controller == null) return;
    final destination = ref.read(routeControllerProvider).destination;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onArrived();
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.none);
    if (destination != null) {
      await controller.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(destination.lat, destination.lng), 17));
    }
  }

  Future<void> _handleRecenterTap() async {
    final controller = _mapController;
    if (controller == null) return;
    final snapped = ref.read(navigationStateProvider).value?.snappedLocation;
    if (snapped == null) return;
    final cam = ref.read(navigationCameraControllerProvider);
    cam.onRecenterTapped();
    await controller.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(snapped.lat, snapped.lng), cam.followZoom));
    await controller
        .updateMyLocationTrackingMode(MyLocationTrackingMode.trackingCompass);
  }

  void _onNavStateChange(
      AsyncValue<NavigationState>? prev, AsyncValue<NavigationState> next) {
    final prevState = prev?.value;
    final nextState = next.value;
    if (nextState == null) return;

    if (prevState?.snappedLocation == null &&
        nextState.snappedLocation != null) {
      _handleFirstFix(nextState.snappedLocation!);
    }

    if ((prevState?.isOffRoute ?? false) != nextState.isOffRoute) {
      setState(() => _rerouting = nextState.isOffRoute);
    }

    if (prevState?.status != TripStatus.complete &&
        nextState.status == TripStatus.complete) {
      _handleArrival();
    }
  }

  @override
  Widget build(BuildContext context) {
    final navState = ref.watch(navigationStateProvider);
    final styleAsync = ref.watch(mapStyleProvider);
    final cam = ref.watch(navigationCameraControllerProvider);
    final origin = ref.watch(routeControllerProvider).origin;

    ref.listen<AsyncValue<NavigationState>>(
        navigationStateProvider, _onNavStateChange);

    final initialTarget =
        origin != null ? LatLng(origin.lat, origin.lng) : _defaultCenter;

    return Scaffold(
      body: Stack(
        children: [
          styleAsync.when(
            loading: () => const ColoredBox(color: Color(0xFFCFE3D3)),
            error: (e, _) => Center(child: Text('Map error: $e')),
            data: (style) => MapLibreMap(
              styleString: style,
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: _followZoomOnStart,
              ),
              myLocationEnabled: true,
              myLocationTrackingMode: MyLocationTrackingMode.none,
              trackCameraPosition: true,
              onMapCreated: (controller) async {
                _mapController = controller;
                await _drawRouteIfReady();
              },
              onCameraTrackingDismissed: () {
                ref
                    .read(navigationCameraControllerProvider)
                    .onTrackingDismissed();
              },
              onCameraIdle: () {
                final c = _mapController;
                if (c == null) return;
                final zoom = c.cameraPosition?.zoom;
                if (zoom != null) {
                  ref
                      .read(navigationCameraControllerProvider)
                      .onZoomChanged(zoom);
                }
              },
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  navState.when(
                    loading: () => const TurnBanner(
                      primaryText: 'Starting navigation...',
                      distanceText: '',
                    ),
                    error: (e, _) => const TurnBanner(
                      primaryText: 'Navigation error',
                      distanceText: '',
                      icon: Icons.error_outline,
                    ),
                    data: (state) => TurnBanner(
                      primaryText:
                          state.currentVisual?.primaryText ?? 'On route',
                      distanceText: state.progress != null
                          ? _formatDistance(
                              state.progress!.distanceToNextManeuverM)
                          : '',
                      icon: state.currentVisual != null
                          ? _iconForManeuver(
                              state.currentVisual!.maneuverType,
                              state.currentVisual!.maneuverModifier,
                            )
                          : Icons.straight,
                    ),
                  ),
                  if (_rerouting) const ReroutingToast(),
                ],
              ),
            ),
          ),
          if (cam.mode == CameraMode.free)
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 140),
                  child: RecenterFab(onTap: _handleRecenterTap),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: cam.mode == CameraMode.arrived
                    ? ArrivedSheet(onDone: () => Navigator.of(context).pop())
                    : _EtaSheet(
                        navState: navState,
                        ttsEnabled: _ttsEnabled,
                        onToggleTts: () =>
                            setState(() => _ttsEnabled = !_ttsEnabled),
                        onClose: () => Navigator.of(context).pop(),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EtaSheet extends StatelessWidget {
  const _EtaSheet({
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
              return Text(_formatEta(p.durationRemainingMs));
            },
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                    ttsEnabled ? Icons.volume_up : Icons.volume_off),
                onPressed: onToggleTts,
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onClose,
                child: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

IconData _iconForManeuver(String type, String? modifier) {
  final mod = modifier?.replaceAll('_', ' ');
  if (type == 'turn') {
    if (mod == 'left') return Icons.turn_left;
    if (mod == 'right') return Icons.turn_right;
    if (mod == 'sharp left') return Icons.turn_sharp_left;
    if (mod == 'sharp right') return Icons.turn_sharp_right;
    if (mod == 'slight left') return Icons.turn_slight_left;
    if (mod == 'slight right') return Icons.turn_slight_right;
  }
  if (type == 'arrive') return Icons.flag;
  return Icons.straight;
}

String _formatDistance(double meters) {
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km';
  return '${meters.round()} m';
}

String _formatEta(int durationRemainingMs) {
  final eta =
      DateTime.now().add(Duration(milliseconds: durationRemainingMs));
  final h = eta.hour.toString().padLeft(2, '0');
  final m = eta.minute.toString().padLeft(2, '0');
  final minRemaining = (durationRemainingMs / 60000).round();
  return '$h:$m arrival · $minRemaining min';
}
```

- [ ] **Step 2: Run all existing tests; confirm `navigation_screen_test.dart` still passes**

Run: `cd mobile && flutter test test/screens/navigation_screen_test.dart`
Expected: PASS (existing test asserts `TurnBanner` content; our rewrite still renders it).

- [ ] **Step 3: Run the full suite to confirm no regressions**

Run: `cd mobile && flutter test`
Expected: PASS (existing ~30 tests all green; new widget tests from Tasks 3-5 all green).

- [ ] **Step 4: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/lib/screens/navigation_screen.dart
git commit -m "feat(mobile): wire NavigationScreen to camera lifecycle"
```

---

### Task 8: Lifecycle widget test

Assert the screen-level visibility rules: recenter FAB, rerouting toast, arrived sheet.

**Files:**
- Create: `mobile/test/screens/navigation_screen_lifecycle_test.dart`

- [ ] **Step 1: Write the failing test**

Create `mobile/test/screens/navigation_screen_lifecycle_test.dart`:

```dart
import 'dart:async';

import 'package:beebeebike/config/app_config.dart';
import 'package:beebeebike/models/location.dart';
import 'package:beebeebike/navigation/camera_controller.dart';
import 'package:beebeebike/navigation/navigation_service.dart';
import 'package:beebeebike/providers/navigation_camera_provider.dart';
import 'package:beebeebike/providers/navigation_provider.dart';
import 'package:beebeebike/providers/route_provider.dart';
import 'package:beebeebike/screens/navigation_screen.dart';
import 'package:beebeebike/services/map_style_loader.dart';
import 'package:beebeebike/widgets/arrived_sheet.dart';
import 'package:beebeebike/widgets/recenter_fab.dart';
import 'package:beebeebike/widgets/rerouting_toast.dart';
import 'package:ferrostar_flutter/ferrostar_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

NavigationState _baseState({
  TripStatus status = TripStatus.navigating,
  bool isOffRoute = false,
  UserLocation? snapped,
}) {
  return NavigationState(
    status: status,
    isOffRoute: isOffRoute,
    snappedLocation: snapped,
    progress: const TripProgress(
      distanceToNextManeuverM: 150,
      distanceRemainingM: 3200,
      durationRemainingMs: 720000,
    ),
  );
}

Future<(WidgetTester, StreamController<NavigationState>,
        NavigationCameraController)>
    _pump(WidgetTester tester) async {
  final navStream = StreamController<NavigationState>.broadcast();
  final cam = NavigationCameraController();

  final fakeService = NavigationService(
    createController: (_, __) => throw UnimplementedError(),
    loadNavigationRoute: ({required origin, required destination}) =>
        throw UnimplementedError(),
    locationStream: const Stream.empty(),
    speakInstruction: (_) async {},
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'http://localhost',
            tileServerBaseUrl: 'http://localhost',
            tileStyleUrl: 'http://localhost/tiles',
          ),
        ),
        mapStyleProvider.overrideWith((ref) => Future.value('{}')),
        navigationStateProvider
            .overrideWith((ref) => navStream.stream),
        navigationServiceProvider.overrideWithValue(fakeService),
        navigationCameraControllerProvider.overrideWith((ref) {
          ref.onDispose(cam.dispose);
          return cam;
        }),
        routeControllerProvider.overrideWith(() {
          return _SeededRouteController(
            origin: const Location(
                id: 'o', name: 'o', label: 'o', lng: 13.4, lat: 52.5),
            destination: const Location(
                id: 'd', name: 'd', label: 'd', lng: 13.5, lat: 52.55),
          );
        }),
      ],
      child: const MaterialApp(home: NavigationScreen()),
    ),
  );
  await tester.pump();
  addTearDown(navStream.close);
  return (tester, navStream, cam);
}

void main() {
  testWidgets('recenter FAB hidden initially', (tester) async {
    await _pump(tester);
    expect(find.byType(RecenterFab), findsNothing);
  });

  testWidgets('recenter FAB visible when camera enters free mode',
      (tester) async {
    final (_, __, cam) = await _pump(tester);
    cam.onFirstFix();
    cam.onTrackingDismissed();
    await tester.pumpAndSettle();
    expect(find.byType(RecenterFab), findsOneWidget);
  });

  testWidgets('rerouting toast appears when isOffRoute flips true',
      (tester) async {
    final (_, stream, __) = await _pump(tester);
    stream.add(_baseState(isOffRoute: true));
    await tester.pumpAndSettle();
    expect(find.byType(ReroutingToast), findsOneWidget);

    stream.add(_baseState(isOffRoute: false));
    await tester.pumpAndSettle();
    expect(find.byType(ReroutingToast), findsNothing);
  });

  testWidgets('arrived sheet replaces ETA sheet on TripStatus.complete',
      (tester) async {
    final (_, stream, __) = await _pump(tester);
    stream.add(_baseState(status: TripStatus.complete));
    await tester.pumpAndSettle();
    expect(find.byType(ArrivedSheet), findsOneWidget);
  });
}

class _SeededRouteController extends RouteController {
  _SeededRouteController({required this.origin, required this.destination});
  final Location origin;
  final Location destination;
  @override
  build() => super.build().copyWith(origin: origin, destination: destination);
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/screens/navigation_screen_lifecycle_test.dart`
Expected: fails on import / missing route controller override (we need to confirm the `RouteController` constructor pattern matches).

- [ ] **Step 3: If `RouteController` has no default constructor signature matching `overrideWith(() => _SeededRouteController(...))`, switch to seeding via a post-pump `setOrigin` / `setDestination` call**

If Step 2 fails due to `overrideWith` signature, replace the `routeControllerProvider.overrideWith(...)` block with:

```dart
// (no override — seed via notifier after pump)
```

and after the `pumpWidget`:

```dart
final container = ProviderScope.containerOf(
    tester.element(find.byType(NavigationScreen)));
container.read(routeControllerProvider.notifier).setOrigin(
      const Location(id: 'o', name: 'o', label: 'o', lng: 13.4, lat: 52.5),
    );
container.read(routeControllerProvider.notifier).setDestination(
      const Location(id: 'd', name: 'd', label: 'd', lng: 13.5, lat: 52.55),
    );
```

Note: `setOrigin`/`setDestination` call `_maybeLoadPreview` which hits the API. Since `dioProvider` is not overridden here, this may fail. In that case, also override the loader with a stub that throws (the screen tolerates a null preview):

```dart
routePreviewLoaderProvider.overrideWithValue(
  ({required Location origin, required Location destination}) async {
    throw Exception('test: loader disabled');
  },
),
```

Prefer the direct `overrideWith` approach; use this fallback only if needed.

- [ ] **Step 4: Run the test; iterate until it passes**

Run: `cd mobile && flutter test test/screens/navigation_screen_lifecycle_test.dart`
Expected: PASS, all 4 tests.

- [ ] **Step 5: Run the full suite**

Run: `cd mobile && flutter test`
Expected: all tests green.

- [ ] **Step 6: Commit**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
git add mobile/test/screens/navigation_screen_lifecycle_test.dart
git commit -m "test(mobile): NavigationScreen lifecycle — FAB, toast, arrived sheet"
```

---

### Task 9: End-to-end verification on iOS simulator

**Files:** none (manual).

- [ ] **Step 1: Start docker dev stack (pick a free port)**

```bash
cd /Users/pv/code/beebeebike
cp -R data .claude/worktrees/silly-roentgen-26bbf9/data
cd .claude/worktrees/silly-roentgen-26bbf9
VITE_DEV_PORT=5273 docker compose -f compose.yml -f compose.dev.yml up -d
```

Expected: backend, db, graphhopper, tiles all healthy (`docker ps` shows 4 containers up).

- [ ] **Step 2: Run the mobile app on iPhone 17 Pro simulator**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9/mobile
flutter run -d 8BFDF915-79EA-43B2-B5D6-E2E81976A84B
```

Expected: app launches, map shows Berlin.

- [ ] **Step 3: Set simulator location to Berlin**

In Simulator menu: Features → Location → Custom Location → `52.5200, 13.4050`.

- [ ] **Step 4: Walk through the full flow and check each assertion**

| Action | Expected |
|---|---|
| Tap a destination on map | Route polyline appears, bottom card shows minutes/km |
| Tap Start | Navigation screen opens; map initially at origin, zoom 17, north-up |
| Wait 1–2s | Map snaps to user location, heading-up tracking engaged, `trackingCompass` puck visible |
| Pinch zoom out to ~14 | Recenter FAB appears bottom-right |
| Pan map | FAB still visible |
| Tap FAB | Camera animates to user at zoom 14 (your pinched zoom preserved); FAB disappears |
| Simulator → Features → Location → City Run | User puck moves, map heading rotates |
| Simulator → Features → Location → Custom Location → set far from route (e.g. `52.6, 13.5`) | "Rerouting…" toast appears; after ~1–2s new polyline replaces old; toast disappears |
| Set Custom Location near the destination to trigger arrival | Arrived sheet replaces ETA sheet; map zooms to destination at zoom 17, north-up |
| Tap Done | Returns to map screen |

- [ ] **Step 5: Stop the stack**

```bash
cd /Users/pv/code/beebeebike/.claude/worktrees/silly-roentgen-26bbf9
docker compose -f compose.yml -f compose.dev.yml down
```

- [ ] **Step 6: Final test run**

```bash
cd mobile && flutter test
```

Expected: all tests green.

---

## Out of Scope (from spec)

- 3D tilt / pitched perspective
- Speed-adaptive zoom
- Auto-recenter timeout
- Cancel-confirmation dialog
- Trip-summary screen post-arrival
- GPS-course-based heading (vs device compass)
- TTS mute wiring to ferrostar
- Off-route visual beyond the toast

# Navigation Camera Lifecycle — Design

## Goal

Make the map on `NavigationScreen` behave like a real turn-by-turn navigation view: fly to the rider on Start, follow heading while moving, yield to user pan/pinch/rotate without fighting them, offer a recenter button to re-engage follow, and react sensibly to off-route, reroute, and arrival.

## Problem

Current `NavigationScreen` ([mobile/lib/screens/navigation_screen.dart](../../../mobile/lib/screens/navigation_screen.dart)):

- Sets `myLocationTrackingMode: MyLocationTrackingMode.trackingCompass` once and never re-engages it.
- Loads with `initialCameraPosition: LatLng(52.5200, 13.4050), zoom: 15` — Berlin centroid, not the route.
- Never reacts to `onCameraTrackingDismissed` (the maplibre callback that fires when the user pans).
- No recenter UI.
- No special handling of `NavigationState.status == complete` (arrival) or `isOffRoute` (reroute).
- The existing `NavigationCameraController` ([mobile/lib/navigation/camera_controller.dart](../../../mobile/lib/navigation/camera_controller.dart)) is a 3-method stub with a `followMode` bool, not wired to anything.

Effect: on Start the map sits over Berlin centroid until first GPS fix triggers tracking; user pan permanently breaks tracking with no way to recover; on arrival nothing visually changes.

## Design Decisions (from brainstorming)

| Q | Choice | Rationale |
|---|---|---|
| Q1 — follow style | **2D heading-up** (`MyLocationTrackingMode.trackingCompass`) | Matches platform default; no per-tick `animateCamera` cost; standard cyclist-nav view |
| Q2 — zoom | **Fixed default 17, preserved across recenter** | If user pinches to 14 then pans, recenter restores 14 |
| Q3 — recenter button | **Hidden when following, shown when broken; no auto-timeout** | No surprise auto-jumps mid-glance |
| Q4 — arrival | **Stop following, zoom to destination at z17, show Arrived sheet** | Destination is what matters at moment of arrival |
| Q5 — reroute | **"Rerouting…" toast during fetch, silent polyline swap, camera unchanged** | Feedback without yanking camera |
| Q6 — cancel (X) | **No confirm, just `Navigator.pop`** | Current behavior; user accepts accidental-tap risk for v1 |
| Q7 — pre-first-fix | **Static at origin pin, zoom 17, north-up; snap to follow on first fix** | Predictable starting view |

## State Machine

Five states for the navigation map camera. Implemented in `NavigationCameraController`.

| State | Entry trigger | Camera behavior | Recenter FAB |
|---|---|---|---|
| `awaitingFirstFix` | Screen `initState` | Static at origin, zoom 17, bearing 0, pitch 0 | hidden |
| `following` | First non-null `navState.snappedLocation` OR recenter tapped | `MyLocationTrackingMode.trackingCompass` at `_followZoom` | hidden |
| `free` | maplibre fires `onCameraTrackingDismissed` | User-controlled (no tracking) | **shown** |
| `arrived` | `NavigationState.status == complete` | Static at destination, zoom 17, bearing 0 | hidden |

`rerouting` is **not** a state — it's a cross-cutting overlay (`navState.isOffRoute == true`) that shows a toast without changing camera state.

### Transitions

```
awaitingFirstFix --first snappedLocation--> following
following --user pan/pinch--> free
free --tap recenter--> following
any --status==complete--> arrived
arrived --(no exit; user taps Done → pop screen)
```

**Idempotency:**
- `onFirstFix` called twice: only first triggers transition; second is a no-op.
- `onArrived` from `arrived`: no-op.
- `onTrackingDismissed` while in `awaitingFirstFix` or `arrived`: no-op (no tracking was active).
- `onRecenterTapped` while in `following`: no-op.

## Zoom Preservation

`NavigationCameraController.followZoom` defaults to **17.0**. Updated in `free` state via `onZoomChanged(double z)`, which `NavigationScreen` calls from the `MapLibreMap.onCameraIdle` callback (passing `cameraPosition.zoom`). On recenter, `NavigationScreen` calls `mapController.animateCamera(CameraUpdate.newLatLngZoom(user, cam.followZoom))` then `updateMyLocationTrackingMode(trackingCompass)`.

`onZoomChanged` is gated to only mutate `followZoom` when `mode == free`. This avoids capturing the bearing/zoom drift that maplibre may report during `trackingCompass`-mode location updates.

## Event Handler Table

| Event | Source | What `NavigationScreen` does |
|---|---|---|
| First fix (`navState.snappedLocation` first non-null) | `navigationStateProvider` (`ref.listen`) | If `cam.mode == awaitingFirstFix`: `cam.onFirstFix()`; `mapController.animateCamera(CameraUpdate.newLatLngZoom(snapped, cam.followZoom))`; `mapController.updateMyLocationTrackingMode(trackingCompass)` |
| `onCameraTrackingDismissed` | maplibre callback | `cam.onTrackingDismissed()`; `setState` (FAB visibility) |
| `onCameraIdle` | maplibre callback | `cam.onZoomChanged(_mapController.cameraPosition?.zoom)` |
| Recenter FAB tap | UI | If user location known: `cam.onRecenterTapped()`; `animateCamera(...)`; `updateMyLocationTrackingMode(trackingCompass)`; `setState` |
| `navState.isOffRoute → true` | `navigationStateProvider` (`ref.listen`) | `setState(_rerouting = true)` (toast visible). Camera untouched. |
| `navState.isOffRoute → false` | provider | `setState(_rerouting = false)` (toast gone). Polyline already swapped by `RouteOverlay.replace`. |
| `navState.status → complete` | provider | `cam.onArrived()`; `mapController.updateMyLocationTrackingMode(none)`; `animateCamera(destination, 17)`; `setState` (arrived sheet replaces ETA sheet) |
| Cancel (X) tap | UI | `Navigator.pop(context)` (no confirm; v1) |
| Route polyline replaced | `replaceRoute` from `NavigationService.deviationStream` handler | `RouteOverlay.replace(newPreview)` redraws line; camera untouched |

## Component Breakdown

### Modified: `mobile/lib/navigation/camera_controller.dart`

Replace stub with state machine. Pure Dart, no Flutter import → fast unit tests.

```dart
enum CameraMode { awaitingFirstFix, following, free, arrived }

class NavigationCameraController {
  CameraMode _mode = CameraMode.awaitingFirstFix;
  double _followZoom = 17.0;

  CameraMode get mode => _mode;
  double get followZoom => _followZoom;

  void onFirstFix() {
    if (_mode == CameraMode.awaitingFirstFix) _mode = CameraMode.following;
  }

  void onTrackingDismissed() {
    if (_mode == CameraMode.following) _mode = CameraMode.free;
  }

  void onZoomChanged(double z) {
    if (_mode == CameraMode.free) _followZoom = z;
  }

  void onRecenterTapped() {
    if (_mode == CameraMode.free) _mode = CameraMode.following;
  }

  void onArrived() {
    if (_mode != CameraMode.arrived) _mode = CameraMode.arrived;
  }
}
```

### Modified: `mobile/lib/screens/navigation_screen.dart`

Owns `MapLibreMapController`, `NavigationCameraController`, navigation-state listener for first-fix / reroute / arrival. Wires:

- `MapLibreMap.initialCameraPosition`: origin from `routeControllerProvider.origin`, zoom 17, bearing 0
- `MapLibreMap.myLocationTrackingMode`: starts as `none`; flipped to `trackingCompass` after first fix
- `onMapCreated`: store controller, draw route via `RouteOverlay.draw`
- `onCameraTrackingDismissed`: `_cam.onTrackingDismissed(); setState(() {})`
- `onCameraIdle`: `_cam.onZoomChanged(_mapController!.cameraPosition?.zoom ?? _cam.followZoom)`
- `ref.listen(navigationStateProvider, (prev, next) {...})` handles first-fix (`prev.snappedLocation == null && next.snappedLocation != null`), `isOffRoute` toggle, and `status == complete`
- Recenter FAB shown iff `_cam.mode == CameraMode.free`, positioned bottom-right above bottom sheet

### New: `mobile/lib/widgets/recenter_fab.dart`

Small stateless widget: circular icon button with `Icons.my_location`, calls `onTap`. Positioned by parent.

### New: `mobile/lib/widgets/rerouting_toast.dart`

Small stateless widget: pill shown below `TurnBanner`, semi-transparent background, "Rerouting…" text + small spinner. Positioned by parent.

### New: `mobile/lib/widgets/arrived_sheet.dart`

Replaces ETA bottom sheet content when `_cam.mode == arrived`. Layout: "Arrived" headline, optional address (skip in v1), `Done` button → `Navigator.pop(context)`.

## Tests

### Unit (`mobile/test/navigation/camera_controller_test.dart`)

Pure Dart, no maplibre. Covers:
- `onFirstFix` flips `awaitingFirstFix → following`; second call is a no-op (stays `following`)
- `onTrackingDismissed` only flips `following → free`; from `awaitingFirstFix` or `arrived`: no-op
- `onZoomChanged` mutates `followZoom` iff `mode == free`; in `following`/`awaitingFirstFix`/`arrived`: ignored
- `onRecenterTapped` flips `free → following`; from any other state: no-op
- `onArrived` flips any state → `arrived`; second call: no-op
- Default `followZoom == 17.0`

### Widget (`mobile/test/screens/navigation_screen_lifecycle_test.dart`)

Riverpod overrides: fake `navigationServiceProvider` exposing a controllable `StreamController<NavigationState>`; `mapStyleProvider` returns `'{}'`. `MapLibreMap` is a no-op platform view in widget tests, so we cannot assert real camera moves. Asserts:

- Recenter FAB hidden initially (`awaitingFirstFix`)
- After firing the camera controller's `onTrackingDismissed` directly via a test seam (an `@visibleForTesting` getter on the screen state that exposes the controller), FAB visible
- Tap FAB → FAB hidden
- Pump fake `NavigationState(status: complete, ...)` into the stream → Arrived sheet visible, ETA hidden
- Tap Done → `Navigator.pop` invoked (verify with a route observer)
- Pump fake `NavigationState(isOffRoute: true, ...)` → "Rerouting…" toast visible
- Pump fake `NavigationState(isOffRoute: false, ...)` → toast gone

### Integration (manual, on iOS sim)

End-to-end walkthrough below, executed against the docker dev stack.

## Verification

After implementation:

1. Start docker stack: `cd /Users/pv/code/beebeebike && cp -R data .claude/worktrees/silly-roentgen-26bbf9/data && cd .claude/worktrees/silly-roentgen-26bbf9 && VITE_DEV_PORT=5273 docker compose -f compose.yml -f compose.dev.yml up -d`
2. `cd mobile && flutter run -d 8BFDF915-79EA-43B2-B5D6-E2E81976A84B` (iPhone 17 Pro sim)
3. iOS Simulator → Features → Location → Custom Location → set to Berlin (e.g. 52.52, 13.405)
4. In-app:
   - Tap a destination on map → preview appears → tap Start
   - Navigation screen opens; map shows origin at zoom 17 briefly, then snaps to user location with heading-up tracking once ferrostar emits first `snappedLocation` (within ~1s on sim)
   - Pinch to zoom out → recenter FAB appears
   - Drag map → still in `free`, FAB still visible
   - Tap FAB → camera animates back to user, follow re-engaged at the zoom you pinched to (e.g. if pinched to 14, recenter restores 14)
   - In Simulator → Features → Location → Freeway Drive (or City Run) → user puck moves and map heading rotates
   - Take user off-route (Custom Location away from route) → "Rerouting…" toast appears; after ~1-2s new polyline replaces old; toast disappears
   - Use a short route and let user reach destination → Arrived sheet replaces ETA sheet; map zooms to destination at z17; tap Done → pops back to map screen
5. `cd mobile && flutter test` → all green (existing 29 + new unit + new widget tests)

## Out of Scope (Followups)

- 3D tilt / pitched perspective camera
- Speed-adaptive zoom
- Auto-recenter timeout
- Cancel-confirmation dialog
- Trip-summary screen post-arrival (full-route fit)
- GPS course (`UserLocation.courseDeg`) as bearing source instead of device compass — handlebar-mount problem; revisit on real bike
- TTS mute wiring to ferrostar (still TODO from prior plan)
- Off-route visual treatment beyond the toast (e.g. dim old route)
- Pre-fetch reroute (current code reroutes on `deviationStream` event from ferrostar; latency = network)

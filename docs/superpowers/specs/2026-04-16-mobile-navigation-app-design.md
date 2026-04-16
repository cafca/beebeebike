# Mobile Navigation App Design

**Date:** 2026-04-16
**Status:** Approved
**Stack:** Flutter + MapLibre GL + Riverpod + Dio

## Context

BeeBeeBike is a Berlin bicycle routing web app (Svelte + Rust/Axum + GraphHopper + PostGIS). Users "paint" rated areas onto a map to influence bicycle route computation. This spec covers a mobile app (iOS first, Android later) that replicates routing and overlay features, adds turn-by-turn navigation, and defers the brush/paint tool to the web.

### Constraints

- **Target audience:** Small group of testers (TestFlight-level)
- **Backend:** Use the existing Rust/Axum API at maps.001.land, with one new endpoint that proxies GraphHopper's navigate API for Ferrostar consumption
- **No Mapbox:** MapLibre only, due to Mapbox pricing
- **No painting on mobile:** Users paint rated areas on the web; mobile renders them read-only.
- **Navigation:** Full turn-by-turn with voice guidance, automatic rerouting, and correct distance-based banner updates — all provided by Ferrostar via a minimal Flutter plugin we build ourselves.
- **Ferrostar Flutter plugin is a separate deliverable.** Ferrostar has no Dart bindings as of 2026 (upstream issue open since 2023). We build a minimal `ferrostar_flutter` plugin as an independent artifact (separate package directory, independently testable and publishable) that wraps Ferrostar's production-ready iOS Swift SDK and Android Kotlin SDK via method channels. Upstream contribution to the Ferrostar project is a non-goal for v1 but the plugin is structured to make it possible later.

## Architecture

The mobile app is a thin client. All business logic (routing, rating priority, polygon clipping, auth) stays in the existing Rust backend.

```
┌──────────────────────────────────────────────┐
│                Flutter App                   │
│                                              │
│   ┌───────────┐    ┌────────────────────┐   │
│   │ MapLibre  │    │ Riverpod providers │   │
│   └─────┬─────┘    └─────────┬──────────┘   │
│         │                    │               │
│         │          ┌─────────┴──────────┐   │
│         │          │ ferrostar_flutter  │   │  ← Our plugin
│         │          │   (Dart facade)    │   │    (separate artifact)
│         │          └─────────┬──────────┘   │
│         │                    │               │
│  ┌──────┴────────────────────┴──────────┐   │
│  │   Platform channels (method + event) │   │
│  └──────┬────────────────────┬──────────┘   │
└─────────┼────────────────────┼──────────────┘
          │                    │
    ┌─────▼─────┐        ┌─────▼──────┐
    │ MapLibre  │        │ Ferrostar  │
    │  Native   │        │ Swift/     │
    │ (iOS/And) │        │ Kotlin SDK │
    └───────────┘        └────────────┘

                 Dart API Client (Dio)
                          │ HTTPS
                 ┌────────┴────────┐
                 │  maps.001.land  │
                 │  (Rust/Axum)    │
                 └─────────────────┘
```

**Two deliverables:**

1. **`packages/ferrostar_flutter/`** — Standalone Flutter plugin. Wraps Ferrostar's native SDKs (Swift iOS, Kotlin Android) via method + event channels. Exposes a minimal Dart API covering only what our app needs in v1. Has its own tests and example app. Structured so it could eventually be published to pub.dev or upstreamed to the Ferrostar project.
2. **`mobile/`** — The Ortschaft mobile app. Consumes `ferrostar_flutter` via a path dependency. Focuses purely on app UX (map, routing, navigation UI).

### Key packages

**App (`mobile/`):**
- **`maplibre_gl`** — Map rendering, camera, markers, GeoJSON layers
- **`ferrostar_flutter`** — Our own plugin (path dependency), wraps Ferrostar's native SDKs
- **`riverpod`** — State management
- **`dio`** + **`dio_cookie_manager`** — HTTP client with cookie-based session handling
- **`geolocator`** + **`flutter_compass`** — GPS tracking and heading (fed into `ferrostar_flutter`)
- **`freezed`** + **`json_serializable`** — Immutable data models with JSON parsing
- **`flutter_tts`** — Text-to-speech for voice guidance (wired to `ferrostar_flutter` spoken instruction stream)

**Plugin (`packages/ferrostar_flutter/`):**
- **iOS**: Ferrostar Swift SDK via Swift Package Manager (`FerrostarCore` ≥ 0.49.0)
- **Android**: Ferrostar Kotlin SDK via Maven Central (`com.stadiamaps.ferrostar:core` ≥ 0.49.0)
- **Dart**: `plugin_platform_interface`, `json_annotation`, `freezed_annotation`

### Project structure

Two top-level directories added to the repository, each with its own Flutter tooling:

```
packages/
└── ferrostar_flutter/              # Standalone plugin
    ├── lib/
    │   ├── ferrostar_flutter.dart  # Public API (Facade)
    │   ├── src/
    │   │   ├── controller.dart     # FerrostarController (Dart side of native controller)
    │   │   ├── models.dart         # Data models (Route, TripState, UserLocation, ...)
    │   │   ├── observer.dart       # NavigationObserver interface
    │   │   └── platform_interface.dart
    │   └── src/method_channel/
    │       └── method_channel_ferrostar.dart
    ├── ios/
    │   ├── ferrostar_flutter.podspec
    │   └── Classes/
    │       ├── FerrostarPlugin.swift         # Plugin entry
    │       ├── ControllerBridge.swift        # Wraps FerrostarCore.NavigationController
    │       ├── Serialization.swift           # Swift <-> JSON
    │       └── ObserverBridge.swift          # Native -> Dart callbacks
    ├── android/
    │   ├── build.gradle
    │   └── src/main/kotlin/land/_001/ferrostar_flutter/
    │       ├── FerrostarPlugin.kt
    │       ├── ControllerBridge.kt
    │       ├── Serialization.kt
    │       └── ObserverBridge.kt
    ├── example/                    # Example app the plugin ships with
    ├── test/                       # Dart unit tests (mocked channels)
    └── pubspec.yaml

mobile/                             # Ortschaft iOS/Android app
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── api/
│   │   ├── client.dart
│   │   ├── auth_api.dart
│   │   ├── routing_api.dart
│   │   ├── ratings_api.dart
│   │   ├── geocode_api.dart
│   │   └── locations_api.dart
│   ├── models/
│   │   ├── user.dart
│   │   ├── route.dart
│   │   ├── location.dart
│   │   └── geocode_result.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── route_provider.dart
│   │   ├── location_provider.dart
│   │   └── navigation_provider.dart
│   ├── screens/
│   │   ├── map_screen.dart
│   │   ├── search_screen.dart
│   │   ├── navigation_screen.dart
│   │   └── settings_screen.dart
│   ├── widgets/
│   │   ├── search_bar.dart
│   │   ├── route_summary.dart
│   │   ├── turn_banner.dart
│   │   └── rating_overlay.dart
│   └── navigation/
│       ├── navigation_service.dart  # Uses ferrostar_flutter; exposes Riverpod stream
│       └── camera_controller.dart   # Follow-mode map camera
├── test/
├── ios/
├── android/
└── pubspec.yaml
```

## Screens & User Flow

### Map Screen (default)

Full-screen map. Bottom sheet is the primary UI surface.

```
┌──────────────────────────────┐
│  ┌────────────────────┐ (●)  │  ← Search bar + profile avatar
│  │ Search here...     │      │
│  └────────────────────┘      │
│                              │
│         MapLibre Map         │
│                              │
│                        [◎]   │  ← My location FAB
│                              │
│ ┌────────────────────────────┤
│ │ ━━━ (drag handle)          │  ← Bottom sheet (collapsed)
│ │ 🏠 Home    ⭐ Saved        │
│ └────────────────────────────┘
```

- Bottom sheet collapsed: quick shortcuts (Home, Saved places)
- Tapping **Home** shortcut: sets current GPS as origin, saved home as destination, computes route, transitions to Route Preview
- No zoom buttons — pinch-to-zoom only
- My location FAB centers map on GPS
- Rated area polygons rendered as colored overlay (read-only), refetched on map `onCameraIdle` with current viewport bbox

### Search (full-screen overlay)

Tapping search bar opens full-screen search:

```
┌──────────────────────────────┐
│  [←] [Search here...      ] │  ← Back arrow + auto-focused input
│──────────────────────────────│
│  🏠 Home · Torstraße 12     │  ← Saved home
│──────────────────────────────│
│  🕐 Recent searches          │  ← Locally cached
│──────────────────────────────│
│  (autocomplete results)      │  ← From Photon geocoder
└──────────────────────────────┘
```

Selecting a result drops a pin on map, bottom sheet slides up with route option.

### Route Preview (bottom sheet expanded)

```
┌──────────────────────────────┐
│  [←] [Your location    ]    │  ← Origin (editable, defaults to GPS)
│       [Tempelhofer Feld ]    │  ← Destination
│──────────────────────────────│
│                              │
│         MapLibre Map         │  ← Route line, markers, fitted bounds
│                              │
│ ┌────────────────────────────┤
│ │ 🚲 12 min · 3.2 km        │
│ │ via Gitschiner Str.        │
│ │ ┌────────────────────────┐ │
│ │ │       Start  ▸        │ │  ← Start navigation
│ │ └────────────────────────┘ │
│ └────────────────────────────┘
```

- Origin defaults to GPS, editable via search
- Route auto-computes when both points set — uses lightweight `POST /api/route` for preview (GeoJSON line + distance + time)
- Drag markers to adjust, recompute on drop
- Tapping **Start** triggers `POST /api/navigate` (heavier response with voice + banner instructions), hands to Ferrostar, transitions to Navigation Screen

### Navigation Screen

```
┌──────────────────────────────┐
│ ┌────────────────────────────┐
│ │ ↰  Turn left         200m ││  ← Green turn banner
│ │    Kastanienallee          ││
│ └────────────────────────────┘
│                              │
│         MapLibre Map         │  ← Heading-up, tilted, follows GPS
│            ▲                 │  ← Blue chevron
│                              │
│                       [◎]    │  ← Re-center (only when panned away)
│──────────────────────────────│
│  12:34 arrival · 10 min     │  ← Bottom bar: ETA + remaining
│  2.8 km remaining  [🔊] [×] │     Mute toggle + stop button
└──────────────────────────────┘
```

- Green banner: maneuver icon + instruction + distance to next turn (Ferrostar times these correctly, e.g., "In 200m" appears at 200m, not earlier)
- Blue chevron for user position with heading (Ferrostar-snapped)
- Camera: heading-up, ~45 tilt, zoom ~16, follows GPS at 1Hz
- Re-center FAB appears only when user manually pans
- **Voice guidance**: Ferrostar emits spoken instruction events (e.g., 500m ahead, 200m ahead, at the maneuver). Wired to `flutter_tts`. Mute toggle in the bottom bar.
- **Automatic rerouting**: If Ferrostar's deviation handler detects >50m off-route for >10s, it calls our route API with current GPS as the new origin. UI shows a brief "Rerouting..." banner; new route replaces the old one.
- Arrival: "You have arrived" banner, auto-returns to map screen after 5s

### Settings Screen

Opened by tapping the profile avatar in the search bar. Minimal content:

- Current account (Guest / email)
- Login / Register buttons (if guest)
- Logout button (if logged in)
- Save current origin as Home (if origin set and no home saved)
- Reset Home (if home saved)
- App version

### Auth

Invisible. Anonymous session created silently on first launch via `POST /api/auth/anonymous`. Cookie stored in Dio's cookie jar. Login/register available in the Settings Screen for users who want to sync with their web account.

## Backend Changes

One new endpoint: **`POST /api/navigate`** — proxies GraphHopper's `/navigate/directions` endpoint to produce a response Ferrostar consumes directly via its built-in OSRM adapter.

### Why a separate endpoint

Ferrostar's natively-supported route formats are OSRM and Valhalla. GraphHopper's `/navigate/directions` endpoint returns **Mapbox Directions API v5-compatible JSON**, which is a superset of OSRM with two crucial additions:

- `voice_instructions` — distance-keyed spoken prompts ("In 500m, turn left...")
- `banner_instructions` — distance-keyed visual instructions for the UI

These are what let Ferrostar emit correctly-timed voice and banner events without the client synthesizing them. Writing a custom adapter for GraphHopper's regular `/route` format would require us to generate these arrays ourselves — more code, worse localization, worse timing.

The existing `POST /api/route` endpoint stays unchanged for the web app.

### `POST /api/navigate` — request

Same shape as `/api/route`:

```json
{
  "origin": [lng, lat],
  "destination": [lng, lat],
  "rating_weight": 0.5,
  "distance_influence": 70
}
```

### `POST /api/navigate` — behavior

1. Load user's rated areas intersecting the route corridor (same as `/api/route`)
2. Build a GraphHopper request targeting the `/navigate/directions` endpoint (not `/route`)
3. Apply the same Custom Model with rating-weighted priority multipliers
4. Set `voice_instructions=true`, `banner_instructions=true`, `roundabout_exits=true` in the request
5. Return GraphHopper's response verbatim — do not re-shape. Ferrostar parses Mapbox Directions format directly.

### Prerequisite: GraphHopper navigate endpoint availability

Self-hosted GraphHopper requires a navigation profile configured in `infra/graphhopper/config.yml`. The `/navigate/directions` endpoint is part of the open-source distribution but may need `profiles_navigation` configuration. This is verified during the first implementation task.

**Fallback if navigate is unavailable:** Write a custom Dart Ferrostar adapter that transforms the regular `/route` response into Ferrostar's `Route` model, synthesizing `spoken_instructions` client-side from the plain text + interval data. This is more work but keeps the option open. Flag this as a decision point early in the plan.

### No other backend changes

Auth, ratings, geocoding, home location, and `POST /api/route` all work as-is.

## Navigation Engine

We use [**Ferrostar**](https://github.com/stadiamaps/ferrostar) (Stadia Maps) as the navigation engine. Ferrostar is a Rust-core SDK with production-ready Swift (iOS) and Kotlin (Android) bindings via UniFFI. It handles route matching, instruction tracking, ETA, and off-route detection.

Ferrostar has no Dart bindings, so we build a minimal Flutter plugin (`packages/ferrostar_flutter/`) that wraps the native SDKs.

### Plugin scope (`ferrostar_flutter` v0.1)

The plugin exposes the subset of Ferrostar needed for v1. Anything not listed is explicitly out of scope for the plugin.

**In scope:**
- Construct a Ferrostar `NavigationController` from an OSRM-format JSON route (one method: `createFromOsrmJson`)
- Feed GPS location updates (one method: `updateLocation`)
- Expose state as a Dart `Stream<NavigationState>` where `NavigationState` contains the UI-relevant derived data (current step visual + spoken instructions, trip progress, route deviation, ETA). The full `Route` and `TripState` are kept as opaque native handles; we only ship the fields the UI renders.
- Emit spoken instruction events as they fire (a Dart `Stream<SpokenInstruction>`)
- Emit route deviation events (a Dart `Stream<RouteDeviation>`)
- Replace the active route (for rerouting) without tearing down the controller
- Dispose method

**Out of scope for plugin v0.1:**
- Recording/replay (`NavigationRecorder`)
- `NavigationCache`
- Custom `RouteRequestGenerator` / `RouteResponseParser` — we use Ferrostar's built-in OSRM parser with JSON we pass in
- Simulated location provider (not needed — we drive updates from Dart)
- Background navigation (platform service work)
- Alternative route processing

### Plugin Dart API shape

```dart
class FerrostarFlutter {
  /// Creates a controller from Mapbox Directions / OSRM-compatible JSON.
  /// Returns a handle used for subsequent calls.
  Future<FerrostarController> createController({
    required Map<String, dynamic> osrmJson,
    required List<WaypointInput> waypoints,
    NavigationConfig config,
  });
}

class FerrostarController {
  /// Derived state stream — the main subscription for UI.
  Stream<NavigationState> get stateStream;

  /// Spoken instruction events — subscribe to drive TTS.
  Stream<SpokenInstruction> get spokenInstructionStream;

  /// Route deviation events — subscribe to drive rerouting.
  Stream<RouteDeviation> get deviationStream;

  /// Push a new GPS location. State update arrives via stateStream.
  Future<void> updateLocation(UserLocation location);

  /// Replace the active route (for rerouting) without recreating the controller.
  Future<void> replaceRoute({required Map<String, dynamic> osrmJson});

  /// Destroy native resources.
  Future<void> dispose();
}

class NavigationState {
  final TripStatus status;                 // idle, navigating, complete
  final UserLocation? snappedLocation;
  final TripProgress? progress;            // distance/duration remaining + ETA
  final VisualInstruction? currentVisual;  // For banner UI
  final StepRef? currentStep;              // index + road name
  final bool isOffRoute;
}
```

### How the app uses it (`mobile/lib/navigation/navigation_service.dart`)

Thin orchestration layer:

- Calls `POST /api/navigate` on our backend → receives OSRM JSON
- Calls `FerrostarFlutter.createController(osrmJson: …)` → gets a controller
- Feeds `geolocator` GPS updates into `controller.updateLocation`
- Exposes `controller.stateStream` as a Riverpod `StreamProvider<NavigationState>`
- Subscribes to `spokenInstructionStream` → forwards to `flutter_tts`
- Subscribes to `deviationStream` → when triggered, calls `/api/navigate` with current GPS as new origin, calls `controller.replaceRoute(…)` with the response
- Manages lifecycle (dispose on navigation exit)

### GraphHopper → OSRM JSON

The backend's new `POST /api/navigate` endpoint proxies GraphHopper's `/navigate/directions`, which returns Mapbox Directions v5-compatible JSON. That format is OSRM-compatible and Ferrostar's native OSRM adapter ingests it directly. **No client-side transformation.**

### Camera Controller

Separate module in the app (not in the plugin). Reads `NavigationState.snappedLocation` from the state stream and drives the MapLibre camera.

- Smoothly interpolates camera between updates
- Heading from snapped location's course (falls back to `flutter_compass` when stationary)
- Tilt ~45°, zoom ~16 in follow mode
- Follow mode breaks on user pan gesture; re-center FAB restores it

### App-level state machine (driven by plugin state stream)

```
         ┌──────────┐
         │   Idle   │
         └────┬─────┘
              │ user taps "Start"
         ┌────▼─────┐
         │Navigating│◄────────────────┐
         └────┬─────┘                 │
              │                       │
    ┌─────────┼──────────┐            │
    │         │          │            │
┌───▼──┐ ┌───▼───┐ ┌────▼────┐       │
│On-   │ │Off-   │ │Arrived  │       │
│Route │ │Route  │ │         │       │
└───┬──┘ └───┬───┘ └────┬────┘       │
    │         │          │            │
    │  (snap back)       │(auto-exit) │
    │         │          │            │
    └─────────┘     ┌────▼─────┐      │
                    │   Idle   │      │
                    └────┬─────┘      │
                         └────────────┘
```

### Extensibility seams (post-v1)

- **Background navigation:** Ferrostar's core runs independently of the UI layer, but platform-specific work is needed — foreground service (Android) / background location + audio session (iOS) to keep voice and rerouting working when the screen is off or the app is backgrounded.
- **Lane guidance:** Ferrostar supports lane objects on banner instructions. Requires GraphHopper to include lane info in its navigate response, which depends on OSM data richness for the road. Evaluate once we have real rides.
- **Painting rated areas on mobile:** Add back the brush tool from the web app as a mobile mode. Requires: touch gesture handler for stroke capture, local polygon buffering, `PUT /api/ratings/paint` integration, undo/redo stack, and color palette UI. The overlay rendering is already in place for v1 (read-only), so this is incremental work on top.
- **CarPlay / Android Auto:** Ferrostar has a roadmap for these; not a near-term priority for bicycle use anyway.

## Map & Tiles

### Tile source

VersaTiles server via existing backend at maps.001.land. Same tile spec as web app.

### Style

Same custom bicycle-optimized MapLibre style as web. Fetched from backend or bundled as asset. Minor mobile overrides: larger labels, thicker road lines at navigation zoom levels.

### Map layers

| Layer | Source | Purpose |
|-------|--------|---------|
| `route` | GeoJSON | Route line (white casing + blue line) |
| `ratings` | GeoJSON | Rated area polygons (color-coded fills, read-only) |
| `user-location` | Native | Blue chevron with heading |

### Offline (not now, door kept open)

- `maplibre_gl` supports `offlineManager` for tile region downloads
- No auth-gated tile access that would block this later
- Route instructions are small JSON, trivially cacheable

## Data Models

Dart data classes using `freezed` + `json_serializable`:

- **User:** `{ id, email?, displayName?, accountType }`
- **RouteResponse:** `{ geometry, distance, time, instructions }`
- **Instruction:** `{ text, distance, time, interval, sign, streetName }`
- **GeocodeResult:** GeoJSON FeatureCollection from Photon
- **Location:** `{ id, label, longitude, latitude }`
- **RatedArea:** GeoJSON Feature with `{ value: int }` property

## API Client

Single Dio instance. Cookie jar handles session cookie transparently (same as browser).

```dart
class ApiClient {
  // Auth
  Future<User> createAnonymousSession();
  Future<User> login(String email, String password);
  Future<User> register(String email, String password, String? displayName);
  Future<void> logout();
  Future<User> getMe();

  // Routing — preview (GeoJSON line for route preview screen)
  Future<RouteResponse> computeRoute(
    LatLng origin,
    LatLng destination, {
    double? ratingWeight,        // 0.0-1.0, default 1.0
    double? distanceInfluence,   // 0-100, default 70
  });

  // Routing — navigation (Mapbox Directions-compatible JSON for Ferrostar)
  // Returns raw JSON; passed verbatim to Ferrostar's OSRM adapter.
  Future<Map<String, dynamic>> computeNavigationRoute(
    LatLng origin,
    LatLng destination, {
    double? ratingWeight,
    double? distanceInfluence,
  });

  // Geocoding
  Future<List<GeocodeResult>> geocode(String query, {int limit = 5});

  // Ratings (read-only)
  Future<FeatureCollection> getRatings(LatLngBounds bbox);

  // Home location
  Future<Location?> getHome();
  Future<Location> setHome(String label, double lng, double lat);
  Future<void> deleteHome();
}
```

### Error handling

API errors surface as typed exceptions (`AuthError`, `NetworkError`, `ServerError`). UI shows snackbar. No retry logic for v1.

## Out of scope (v1)

All of these have extensibility seams noted in the relevant sections — they are deferred, not architecturally precluded.

- Brush/paint tool on mobile (use web for v1; see Extensibility seams)
- Lane guidance (depends on OSM/GraphHopper data quality; evaluate post-v1)
- Background navigation (platform-specific work — foreground service / background location)
- Offline routing or tile download UI
- App Store submission / public release
- Rating weight preference slider (use web default of 1.0)
- Distance influence preference slider (use backend default of 70)
- Recent search persistence on server (local only)
- CarPlay / Android Auto
- Publishing `ferrostar_flutter` to pub.dev or upstreaming to the Ferrostar project (structured to allow it later)

## Implementation plans

This spec decomposes into three implementation plans, each producing independently testable software:

1. **Plan A — `ferrostar_flutter` plugin v0.1**: The plugin package, with example app and tests. Standalone deliverable. Largest and riskiest piece; done first.
2. **Plan B — Backend `/api/navigate` endpoint**: Small, ~1-2 day change to the Rust backend. Can be done in parallel with Plan A once the OSRM response shape is confirmed.
3. **Plan C — Ortschaft mobile app**: Consumes the plugin (Plan A) and new endpoint (Plan B). Implements map, search, routing, navigation UI, auth, settings.

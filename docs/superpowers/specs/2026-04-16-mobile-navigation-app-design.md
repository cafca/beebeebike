# Mobile Navigation App Design

**Date:** 2026-04-16
**Status:** Approved
**Stack:** Flutter + MapLibre GL + Riverpod + Dio

## Context

Ortschaft is a Berlin bicycle routing web app (Svelte + Rust/Axum + GraphHopper + PostGIS). Users "paint" rated areas onto a map to influence bicycle route computation. This spec covers a mobile app (iOS first, Android later) that replicates routing and overlay features, adds turn-by-turn navigation, and defers the brush/paint tool to the web.

### Constraints

- **Target audience:** Small group of testers (TestFlight-level)
- **Backend:** Use the existing Rust/Axum API at maps.001.land as-is, with one small extension (pass through GraphHopper instructions)
- **No Mapbox:** MapLibre only, due to Mapbox pricing
- **No painting on mobile:** Users paint rated areas on the web; mobile renders them read-only
- **Navigation:** Basic turn-by-turn guidance now, designed for extension to full navigation later

## Architecture

The mobile app is a thin client. All business logic (routing, rating priority, polygon clipping, auth) stays in the existing Rust backend.

```
┌─────────────────────────────────┐
│         Flutter App             │
│                                 │
│  ┌───────────┐  ┌────────────┐  │
│  │ MapLibre  │  │ Navigation │  │
│  │ GL Native │  │ Controller │  │
│  └─────┬─────┘  └─────┬──────┘  │
│        │              │         │
│  ┌─────┴──────────────┴──────┐  │
│  │      State (Riverpod)     │  │
│  └─────────────┬─────────────┘  │
│                │                │
│  ┌─────────────┴─────────────┐  │
│  │     API Client (Dio)      │  │
│  └─────────────┬─────────────┘  │
│                │                │
└────────────────┼────────────────┘
                 │ HTTPS
        ┌────────┴────────┐
        │  maps.001.land  │
        │  (Rust/Axum)    │
        └─────────────────┘
```

### Key packages

- **`maplibre_gl`** — Map rendering, camera, markers, GeoJSON layers
- **`riverpod`** — State management
- **`dio`** + **`dio_cookie_manager`** — HTTP client with cookie-based session handling
- **`geolocator`** + **`flutter_compass`** — GPS tracking and heading
- **`freezed`** + **`json_serializable`** — Immutable data models with JSON parsing
- **`flutter_tts`** — Text-to-speech for voice guidance (later)

### Project structure

```
mobile/
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
│       ├── route_matcher.dart
│       ├── instruction_tracker.dart
│       └── camera_controller.dart
├── test/
├── ios/
├── android/
└── pubspec.yaml
```

## Screens & User Flow (Google Maps-style)

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
- Route auto-computes when both points set
- Drag markers to adjust, recompute on drop

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
│  2.8 km remaining    [×]    │
└──────────────────────────────┘
```

- Green banner: maneuver icon + instruction + distance to next turn
- Blue chevron for user position with heading
- Camera: heading-up, ~45 tilt, zoom ~16, follows GPS at 1Hz
- Re-center FAB appears only when user manually pans
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

One change required: pass through GraphHopper turn instructions in the route response.

### Extended `POST /api/route` response

Currently returns `{ geometry, distance, time }`. Extended to include:

```json
{
  "geometry": { ... },
  "distance": 3200,
  "time": 720000,
  "instructions": [
    {
      "text": "Turn left onto Kastanienallee",
      "distance": 200,
      "time": 45000,
      "interval": [0, 12],
      "sign": -2,
      "street_name": "Kastanienallee"
    }
  ]
}
```

GraphHopper `sign` values: -3 sharp left, -2 left, -1 slight left, 0 straight, 1 slight right, 2 right, 3 sharp right, 4 finish, 5 via reached, 6 roundabout.

The `interval` field indexes into the route geometry coordinate array — this is how the mobile app maps instructions to positions on the route.

No other backend changes needed. Auth, ratings, geocoding, and home location endpoints work as-is.

## Navigation Engine

Self-contained module with three components. Designed for extensibility — basic guidance now, full navigation later.

### Route Matcher

Snaps GPS position to nearest point on route geometry.

- Projects GPS coordinate onto each route segment, finds closest point
- Reports: snapped position, distance along route, current segment index
- Detects off-route when snapped distance exceeds 50m threshold
- Off-route shows visual indicator for now; rerouting hooks in later

### Instruction Tracker

Determines active instruction based on position along route.

- Uses `interval` field from GraphHopper to map position to current instruction
- Tracks distance remaining to next maneuver
- Emits proximity states: `upcoming` (>200m), `approaching` (<=200m), `now` (<=30m), `passed`
- Voice guidance hooks into proximity state changes (later)

### Camera Controller

Manages map camera in follow mode.

- Smoothly interpolates between GPS updates
- Heading from GPS bearing (moving) or compass (stopped)
- Tilt and zoom adjust based on speed
- Follow mode breaks on user pan; re-center FAB restores it

### State machine

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

### Navigation state

```dart
class NavigationState {
  final NavigationStatus status;       // idle, navigating, arrived
  final bool onRoute;
  final SnappedPosition? position;
  final Instruction? current;
  final Instruction? next;
  final InstructionProximity proximity; // upcoming, approaching, now, passed
  final double remainingDistance;
  final Duration remainingTime;
  final DateTime? estimatedArrival;
  final bool followMode;
}
```

### Extensibility seams (not built now)

- **Voice guidance:** subscribe to proximity changes, trigger TTS at `approaching` and `now`
- **Rerouting:** subscribe to onRoute, when false >10s call route API with current GPS as origin
- **Background navigation:** engine runs on GPS stream, decoupled from UI
- **Off-route threshold:** configurable parameter, not hardcoded

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

  // Routing
  Future<RouteResponse> computeRoute(LatLng origin, LatLng destination, {double? ratingWeight});

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

- Brush/paint tool (use web)
- Voice guidance / TTS
- Automatic rerouting on off-route
- Offline routing or tile download UI
- App Store submission / public release
- Rating weight preference slider (use web default of 1.0)
- Recent search persistence on server (local only)

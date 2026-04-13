# Ortschaft — MVP Plan

A bicycle routing application for Berlin, targeting macOS and iOS. This document covers phase 1 only: the MVP. Phase 2 (on-device routing, navigation) is out of scope here.

---

## What the MVP Does

A user opens the app and sees a map of Berlin. A sidebar contains filters for routing preferences. The user types a location name into a search box to set the route start, repeats for the route end, and the route appears on the map. Adjusting any filter recalculates the route. Tapping or clicking two points on the map is an alternative way to set start and end.

Nothing else. No navigation, no GPS following, no turn instructions, no voice, no offline routing.

---

## Fixed Decisions

- **Targets:** macOS and iOS, sharing a Rust core via UniFFI. Android is a far-future possibility; no Apple-specific types cross the FFI boundary.
- **Map rendering:** MapLibre Native with vector tiles.
- **Tile delivery:** Berlin OSM extract processed into a PMTiles bundle, served over HTTPS from a self-hosted server.
- **Routing engine:** GraphHopper, accessed by the apps over HTTP. Runs in Docker locally during development and on a public server for any non-local use. The server is part of this project.
- **Geocoding:** Photon's public instance at `photon.komoot.io`, an OSM-based geocoder built specifically for autocomplete. Per Photon's usage policy, the implementation must set a descriptive `User-Agent` identifying this project and respect their fair-use guidance (consider self-hosting if usage grows). The geocoding interface treats the backend as swappable, but Photon is the only implementation in the MVP.
- **Shared core language:** Rust, exposed to Swift via UniFFI.
- **Persistence:** SQLite, owned and operated by the Rust core. The platform passes a file path (or an in-memory sentinel) at startup; everything else is core-side.
- **Development scope:** Berlin only.

Phase 2 will replace GraphHopper with an on-device routing engine written in Rust, eliminating the routing server. The MVP must keep that swap mechanical, but no phase 2 code is written now.

---

## Components

### Server (this project, deployable)

A single deployable bundle running on a public host. Contains:

- **GraphHopper** in Docker, configured for Berlin bicycle routing with a custom model that exposes the four MVP preference weights.
- **A tile server** (Caddy or nginx) serving the Berlin PMTiles file over HTTPS with range request support.
- **A reverse proxy** terminating TLS and routing to the two services.

Geocoding is not part of the server stack — the apps call Photon's public instance directly. The server hosts only what the project itself produces (routing graph, tiles). If MVP usage ever outgrows Photon's public instance, self-hosting Photon on this same server is the escape hatch; Photon is much lighter than Nominatim and fits comfortably alongside GraphHopper.

The same compose file runs on a developer laptop and on the production host. Hostnames and TLS differ; nothing else does. The repository contains the compose file, the configuration, and a deployment script.

### OSM Data Pipeline

A small set of scripts that take a Berlin `.osm.pbf` and produce the artifacts the server needs: the GraphHopper graph cache and the PMTiles bundle. Runs on demand, not continuously. One command from raw extract to deployable artifacts.

The Rust preprocessor is **not** part of the MVP. It will be the entry point for phase 2. Don't build it now.

### Shared Core (Rust + UniFFI)

The application logic shared between iOS and macOS. Owns:

- The preference model (four weights, versioned, extensible).
- The routing engine interface and its one implementation, the GraphHopper HTTP client.
- The geocoding interface and its one implementation.
- The route model.
- Persistence: SQLite database opened by the core at a path supplied by the platform. Stores recent searches and the current preference profile.

Does not own: rendering, network reachability detection, file paths, anything UI.

### iOS and macOS Apps

Thin SwiftUI apps over the shared core. Same Swift package consumed by both. UI differs in interaction model (tap vs. click, sheet vs. sidebar) but not in behavior. Each app passes a platform-appropriate database path to the core at startup; the core handles everything else.

---

## Interfaces

Three seams in the MVP. Each exists for a concrete reason; if a seam can't justify itself, it doesn't exist yet.

### Routing Engine Interface

The most important seam. Exists so phase 2 can replace GraphHopper with an embedded engine by writing one new implementation.

The interface accepts a route request (origin, destination, preference weights) and returns a list of routes. The list is length 1 in the MVP but the shape exists from day one so adding alternatives later doesn't change the contract. Each route carries its coordinate sequence, total distance, and estimated time.

The contract is designed with the maneuver list in mind — phase 2 will add it — but the MVP does not include it in running code. Keep the route model in a shape where adding a maneuver list later is a field addition, not a redesign.

The interface must also tolerate a synchronous, in-process implementation. Don't bake HTTP assumptions into method signatures, timeouts, or error types.

### Geocoding Interface

Exists because the geocoding backend will likely change at least once (Photon public → self-hosted Photon → on-device index in phase 2) and because tests need a fake. The MVP implementation calls Photon's public instance.

The interface exposes two methods, distinguished because they have different semantics:

- A **suggest** method for autocomplete: takes a partial query string and returns a small list of likely completions, each with a display label and coordinates. Called as the user types, debounced on the UI side. Photon is designed for this and the public instance permits it within fair use.
- A **resolve** method for explicit submission: takes a full query string and returns full result objects. Called when the user picks a suggestion or presses Enter without picking one.

Both methods return the same result type. The split exists so that future implementations (a local on-device index, a hybrid client) can optimize the two paths independently — suggest needs to be fast and approximate, resolve needs to be precise.

The Rust implementation sets a descriptive `User-Agent` header identifying this project, configured once when the geocoding client is constructed and impossible to omit per-call.

### Persistence

SQLite, owned and operated entirely by the Rust core. The Swift side's only responsibility is to pass a path string at startup: either a platform-appropriate file path (iOS sandbox, macOS application support directory) or a sentinel meaning "in-memory" for tests. The Rust core opens or creates the database, runs migrations, and owns the schema. There is no callback interface and no Swift-side database code.

Stores recent searches and the current preference profile. Nothing else in the MVP.

### Tile Source

Not a shared-core interface. MapLibre handles tile fetching directly, configured on the Swift side with the URL of the tile server. The MVP has no second tile source implementation and no shared-core involvement in tile delivery, so there is nothing to abstract.

---

## Preference Model

A versioned set of named weights. Each weight has a stable identifier, a value in [0.0, 1.0], and metadata (label, description, default) used by the UI to render a generic control. The UI does not name specific weights in layout code; it iterates over whatever the model provides.

The MVP weights:

| Identifier | Meaning |
|---|---|
| `traffic_light_penalty` | Penalize routes with many traffic light stops |
| `unpaved_surface_penalty` | Penalize unpaved or rough surfaces |
| `main_road_avoidance` | Avoid high-traffic roads |
| `cycling_infra_preference` | Prefer dedicated cycling infrastructure |

Mapping these to GraphHopper's Custom Model lives entirely in the GraphHopper adapter. The mapping will be approximate — GraphHopper's Custom Model operates on pre-derived attributes, not arbitrary OSM tag queries. Verify the four weights are expressible in milestone 2 and document gaps explicitly.

The model is versioned. When weights are added in the future, missing fields in saved profiles fall back to defaults.

---

## Data Flow

A single flow for the MVP: request a route.

1. User sets origin and destination, either by typing into the search box (geocoding interface returns coordinates) or by tapping the map.
2. UI calls the shared core with origin, destination, and the current preference weights.
3. Shared core builds a route request and calls the routing engine interface.
4. The GraphHopper adapter serializes the request to GraphHopper's Custom Model JSON, sends it over HTTP, deserializes the response into the route model.
5. Shared core returns the route to the UI.
6. UI converts the coordinate sequence to a GeoJSON LineString and adds it to MapLibre.

Changing a preference weight repeats steps 2–6. There is no shared state between requests; each request carries its full parameter set.

---

## Build Order

Six milestones. Each produces something runnable.

### Milestone 0 — Toolchain

Both apps build and launch to a blank screen. The Rust core compiles and a trivial UniFFI call works from both iOS and macOS. The compose file exists with stub services. A Berlin OSM extract download script is committed.

The reason this is a milestone: Rust + UniFFI cross-compilation for Apple targets has real setup cost. Prove it works before writing logic. Test one async call too, not just a synchronous hello world — async across UniFFI is where the rough edges live, and every interesting MVP call is async.

### Milestone 1 — Map Renders Berlin

Both apps show a MapLibre map of Berlin, fetching tiles from the local compose stack. Pan and zoom work. No routing.

This validates the tile pipeline (PBF → PMTiles → tile server → MapLibre) and surfaces any MapLibre Native macOS issues before the UI is built on top.

### Milestone 2 — GraphHopper Answers

The GraphHopper container loads the Berlin bicycle graph and responds to a hand-crafted `curl` request with a valid route. The four MVP preference weights are tested against GraphHopper's Custom Model and confirmed expressible. A sample response JSON is committed to the repository as a test fixture.

No app integration in this milestone. The point is to validate the engine and capture a fixture before any code consumes it.

### Milestone 3 — First Route on Map

The app makes a hardcoded routing call through the routing engine interface to the GraphHopper adapter, gets back a route, and renders it on the map. Origin and destination are constants in code.

This is the moment the routing engine interface stops being a sketch and becomes load-bearing. Build it, use it, then trust it.

### Milestone 4 — Search and Click to Set Endpoints

A search box accepts a place name. As the user types, the geocoding interface's suggest method is called (debounced) and a dropdown of completions appears. Selecting a completion sets the origin or destination. Pressing Enter without picking a suggestion calls the resolve method and uses the top result. Tapping or clicking the map sets endpoints as an alternative. The route updates whenever either endpoint changes.

Debouncing the suggest calls (e.g. 150ms after the last keystroke) keeps request rates reasonable on Photon's public instance and is good UX regardless. The debounce lives in the UI layer — the geocoding interface itself is stateless.

The preference model exists with default values but is not yet exposed in the UI.

### Milestone 5 — Preference Sidebar

A sidebar (macOS) or sheet (iOS) shows a generic control for each weight in the preference model. Adjusting any weight triggers a new routing request and updates the route on screen. The preference profile and recent searches persist across app launches via SQLite.

This milestone completes the MVP scope.

### Milestone 6 — Production Deployment

The compose stack runs on the public server with TLS. The apps point at the production URL by configuration. A deployment script in the repository takes the artifacts from the data pipeline and pushes them to the server.

Not strictly user-facing, but it's the difference between "works on my laptop" and "I can use it on a phone away from my desk." Worth a dedicated milestone because deployment work expands to fill whatever time it's given.

---

## Testing and Experimentation

Two practices matter for the MVP, both in service of iterating on routing behavior.

**Request logging.** The GraphHopper adapter logs every request (full preference set, origin, destination) and every response (geometry, total cost) to a structured local file. Any prior request can be replayed against modified weights and the results compared. Cheap to build, immediately useful.

**A regression set.** A small committed list of (origin, destination) pairs with the routes they currently produce. After changing the preference-to-GraphHopper translation or adjusting weight defaults, re-run the set and eyeball the diffs. Not automated pass/fail — just a way to notice when a change moves routes you weren't expecting it to move.

Unit tests cover the preference-to-GraphHopper translation (using the committed sample response fixture) and the preference model's version migration logic. UI is not unit-tested.

A route comparison tool — submit one request with N parameter sets in parallel, render all routes on one map — is valuable but not MVP-critical. It can come after milestone 5 if the MVP work is moving and the team wants to tune weights faster.

---

## What's Deferred to Phase 2

For clarity, the following are explicitly out of scope for the MVP. The MVP architecture must not preclude them, but no code is written for them now.

- On-device routing engine (the Rust preprocessor, the Cap'n Proto graph format, the embedded routing implementation).
- On-device geocoding, built from the same Berlin OSM extract as the routing graph. With the preprocessor in place for routing, producing a small local search index (street names, POIs, addresses) is a natural extension and would eliminate the geocoding network dependency entirely. The geocoding interface is already shaped for this swap.
- Maneuver lists, turn instructions, the navigation state machine, location streaming, off-route detection, rerouting.
- Voice guidance.
- Offline tile bundles or any on-device tile cache management beyond what MapLibre provides for free.
- Multi-city support.
- Saved routes, route history beyond recent searches, route export.
- Elevation data and gradient-aware routing.

---

## Risks

**UniFFI async maturity.** Async across the FFI boundary is the single thing most likely to cause real friction. Verify at milestone 0 with a real async call.

**GraphHopper Custom Model expressiveness.** GraphHopper's Custom Model operates on a fixed set of pre-derived attributes. If the four MVP weights cannot be cleanly expressed, the adapter needs workarounds or the weights need rethinking. Verify at milestone 2 before any UI consumes them.

**MapLibre Native macOS maturity.** Less exercised than iOS. Verify at milestone 1.

**Photon usage and fair use.** Photon's public instance is generous but expects callers to be reasonable: descriptive `User-Agent`, debounced suggest calls, and self-hosting if usage grows beyond casual. The User-Agent and debounce are enforced by the geocoding implementation and the search box UI respectively. If MVP usage ever outgrows the public instance, self-hosting Photon on the project's existing server is the escape hatch — the geocoding interface already permits this swap. Verify Photon's current terms at `photon.komoot.io` before milestone 4 in case anything has changed.

**Server operational burden.** Running a public GraphHopper + tile + geocoding stack means caring about uptime, certificate renewal, and OSM data refresh. The MVP keeps this minimal but it is real work. Phase 2 eliminates it; the discomfort is temporary and bounded.

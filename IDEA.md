# Ortschaft — Architecture and Build Plan

A cross-platform bicycle routing application for Berlin, targeting macOS and iOS.

---

## Fixed Decisions

These decisions are treated as constraints throughout this document.

- **Targets:** macOS and iOS. Android possible in the far future.
- **Map rendering:** MapLibre Native with vector tiles.
- **Tile delivery:** Berlin OSM extract processed into a PMTiles bundle, served from a self-hosted Hetzner VPS.
- **Routing engine, phase 1:** GraphHopper running locally (containerized), accessed over HTTP.
- **Routing engine, phase 2+:** A custom engine built later. Phase 1 hides the engine behind an interface so the swap is mechanical.
- **Preprocessor language:** Rust. Will later produce the graph file for the custom engine.
- **Graph serialization format (future):** Cap'n Proto.
- **Shared core language:** Rust, exposed to Swift via UniFFI. The same UniFFI definitions generate Kotlin bindings for a future Android port.
- **Offline-first:** Required mid-term. Phase 1 relies on network.
- **Development scope:** Berlin only.

---

## 1. Component Inventory

### OSM Preprocessor (Rust)

Purpose: Transform the raw Berlin OSM extract into the artifacts the rest of the system consumes. In phase 1 this primarily means preparing input for GraphHopper. In phase 2+ it produces the custom routing graph in Cap'n Proto format and enriched per-way metadata — surface quality index, cycling infrastructure classification, signal presence — that the cost model needs.

Owns the pipeline from `.osm.pbf` → structured artifacts. All OSM tag interpretation logic lives here. When you need to decide what `surface=compacted` means for a cyclist, the answer lives in this component.

Depends on: raw OSM data, Cap'n Proto schema (phase 2+).

Does not: serve HTTP, render tiles, or run on the user's device.

### Tile Generator (dev tooling)

Purpose: Produce the vector tile bundle the map layer consumes. A one-off invocation of a tile generation tool against the Berlin extract, followed by deployment to the Hetzner VPS.

Owns: the `.pmtiles` bundle and the map style schema (which OSM layers are included, at which zoom levels).

Depends on: OSM extract.

Does not: route, share code with the app, or run at app build time.

### GraphHopper Service (phase 1, containerized)

Purpose: Answer routing requests over HTTP for Berlin bicycle routes. Acts as a stand-in for the future custom engine.

Owns: the routing graph it builds from OSM data, the HTTP endpoint.

Depends on: OSM data (or a pre-built graph file), Docker runtime.

Does not: serve tiles, store user data, or run on the user's device.

### Routing Adapter (part of shared core)

Purpose: Translate between the app's preference model and a concrete routing engine's request/response format. In phase 1 this adapter speaks GraphHopper's Custom Model HTTP API. In phase 2+ a different adapter speaks to the custom engine while the rest of the system is unchanged.

Owns: serialization and deserialization for one specific engine, the mapping from preference weights to engine parameters.

Depends on: the routing engine interface (abstract), the preference model.

Does not: contain routing logic, make UI decisions, or persist anything.

### Shared Core Library (Rust + UniFFI)

Purpose: All application logic that is not rendering or OS integration. This is the largest and most important component. Written in Rust, exposed to the Apple apps through a UniFFI-generated Swift binding layer, and portable to Android via UniFFI-generated Kotlin bindings without a rewrite.

Owns: route planning orchestration, the preference model, the navigation state machine (idle → planning → navigating → off-route → rerouting), off-route detection geometry, the route model, persistence of recent routes and preferences, the location pipeline (filtering, snapping to route).

Depends on: the routing engine interface (abstract), the location provider interface (abstract), the persistence interface (abstract). All are injected; the library never names a concrete implementation.

Does not: render anything, make network requests directly (it calls through interfaces), contain engine-specific code.

### iOS Application

Purpose: The iOS user interface.

Owns: MapLibre map view, tap-to-pick origin and destination, preference controls, turn card UI, voice triggering hooks (phase 2+).

Depends on: shared core library, MapLibre Native iOS.

Does not: contain routing logic or navigation state.

### macOS Application

Purpose: The macOS user interface. Shares all non-UI code with iOS; the UI differs in interaction model (click vs. tap, larger map canvas, menu-driven preferences) but not in behavior.

Owns: same responsibilities as the iOS app, adapted for macOS HIG.

Depends on: shared core library, MapLibre Native macOS.

### Development Support Tooling

Purpose: Route comparison, parameter inspection, and trace replay. Not shipped to users.

Owns: a lightweight interface (macOS app or web page) that sends multiple routing requests with different parameter sets and renders all resulting routes simultaneously.

Depends on: the GraphHopper HTTP interface directly. Deliberately bypasses the shared core so it can be rewritten freely.

Does not: share production UI code.

---

## 2. Interface Boundaries

The seams below are the places where one component depends on an abstraction rather than a concrete implementation. Each one exists for a specific reason; if that reason is not clear, the seam should not exist.

### Routing Engine Interface

The most important seam in the system. It exists so that replacing GraphHopper with the custom engine in phase 2 requires changing one adapter file, not the shared core or either app.

The abstraction must express:
- A route request: origin, destination, preference weight vector, optional intermediate waypoints.
- A route response: ordered coordinate sequence, maneuver list (turn type, street name, distance to turn), per-segment metadata (surface type, infrastructure type, way ID), total distance and estimated time.
- An async error: no route found, engine unavailable.

The maneuver list must be in the contract from day one. If it is added later, both the interface and every existing adapter must change. The UI can ignore it in phase 1, but the data must flow.

### Location Provider Interface

Exists for testability and future sensor extensibility. The navigation state machine needs a location stream; it should not care whether that stream comes from CoreLocation, a recorded trace file, or a synthetic generator.

The abstraction must express: a stream of updates carrying position, bearing, speed, and accuracy; start and stop control. Nothing platform-specific should cross this boundary.

### Tile Source Interface

Exists because the current CDN-backed implementation and a future offline-cache implementation have the same contract from MapLibre's perspective. The interface also prevents MapLibre configuration from leaking into the shared core.

The abstraction must express: a tile URL template (for remote sources) or a data provider handle (for embedded sources), and a bounding region for prefetch hints.

### Persistence Interface

Exists so that unit tests run without filesystem side effects and so the storage backend can change. The abstraction must express: save and load for the preference model, save/load/list for saved routes, save and load for navigation session state (so the app survives backgrounding mid-navigation).

### Navigation Event Interface

Exists between the navigation state machine (in the shared core) and all consumers of navigation state — the UI and, eventually, voice guidance.

The state machine emits discrete events rather than exposing mutable state: approaching turn, execute turn, arrived, off route, reroute started, reroute complete. The UI subscribes. Voice guidance (phase 2+) is another subscriber to the same stream. Nothing about voice guidance should touch the UI layer; everything it needs is in the event stream.

---

## 3. Data Flow

### Planning a Route

```
User input (tap origin + destination)
  → Shared Core: build RouteRequest from coordinates + current preference weights
    → Routing Engine Interface
      → GraphHopper Adapter: serialize to Custom Model HTTP request
        → GraphHopper over HTTP
        ← JSON response
      ← Adapter: deserialize to Route model (coordinates, maneuvers, metadata)
    ← Route model returned across interface
  → Shared Core: store route, emit RouteReady event
    → UI layer: receive event, extract coordinate polyline
      → MapLibre: add polyline as GeoJSON source, render
```

The preference weights are part of the request, not a separate configuration call. Every route request is fully self-contained; changing a weight and re-requesting produces a different route with no shared state between requests.

### Displaying a Route

Once the UI layer holds a route model, it converts the coordinate sequence to a GeoJSON LineString and registers it as a MapLibre source. Per-segment properties (surface type, infrastructure classification) drive MapLibre layer expressions that control stroke color and width. The shared core is not involved in display after delivery.

### Following a Route

```
Location update arrives (GPS or simulated trace)
  → Location Provider Interface
    → Shared Core navigation state machine:
        - Project position onto route polyline
        - Compute distance to next maneuver
        - Determine on-route / off-route status
        - Emit NavigationProgress event
    → UI: update camera position, update turn card distance
    → (future) Voice: evaluate "approaching turn" trigger
```

The state machine is the single source of truth for navigation progress. The UI reads from events; it does not compute distances or headings independently.

### Recovering from Off-Route

```
State machine: sustained off-route condition detected
  → Transition to OffRoute state
  → Construct new RouteRequest (current position as origin, original destination, same preferences)
    → Routing Engine Interface (identical path to initial planning)
      → GraphHopper Adapter → GraphHopper → new Route model
    ← New Route model
  → State machine: transition to Navigating on new route
  → Emit RerouteComplete event
    → UI: replace polyline on map
```

Rerouting is not a special case. It goes through the same routing engine interface as initial planning. The state machine owns the decision of when to reroute; the UI only learns about it through events.

---

## 4. Phase 1 Build Order

### Milestone 0 — Scaffolding

Goal: The project structure exists. Both apps build and launch to a blank screen. The shared core Rust library compiles and is a declared dependency of both apps. A trivial UniFFI "hello world" call completes successfully from both iOS and macOS. Data pipeline scripts are present (as stubs if necessary).

Out of scope: any visible functionality.

Why first: the Rust + UniFFI toolchain (cross-compilation for `aarch64-apple-ios`, `aarch64-apple-darwin`, `x86_64-apple-ios` simulator, XCFramework packaging) has real setup cost. Proving it works before writing logic prevents a situation where a large amount of Rust code exists but cannot be called from Swift.

### Milestone 1 — Map Renders Berlin

Goal: Both apps show a MapLibre map centered on Berlin, fetching vector tiles from the Hetzner VPS. Panning and zooming work. No routing, no location.

Out of scope: routing, location, any UI beyond the map canvas.

Why this matters: validates the tile generation pipeline, the Hetzner serving setup, MapLibre Native configuration on both platforms, and the tile source interface. MapLibre Native macOS is the less-tested path; surface integration issues now rather than after the UI is built.

### Milestone 2 — GraphHopper Answers

Goal: A containerized GraphHopper instance loads the Berlin bicycle graph and responds to a hardcoded `curl` request with a valid route. The routing adapter in the shared core compiles and can deserialize a sample response. No app integration yet.

Out of scope: app UI, real preferences, any Swift call to the adapter.

Why this matters: confirms the routing data pipeline end to end and, critically, that GraphHopper's Custom Model feature can express the full initial preference set (traffic light penalty, surface quality, main road avoidance, cycling infrastructure preference). Test all four weights now. Discovering a limitation at milestone 5 is much more expensive.

### Milestone 3 — First Route on Map

Goal: The app constructs a routing request with hardcoded origin and destination, calls through the routing engine interface to the GraphHopper adapter, and renders the resulting polyline on the map.

Out of scope: user-selectable points, preferences UI, location.

Why this matters: the routing engine interface is the most important seam in the system. Making it real — with actual data flowing end to end — is more valuable than designing it in the abstract. Build it, stress it, then trust it.

### Milestone 4 — User Selects Points, Route Updates

Goal: The user can tap (iOS) or click (macOS) to set origin and destination. The route updates each time a point changes. The preference model exists with default values but is not yet exposed in the UI.

Out of scope: preference controls, location tracking.

### Milestone 5 — Preference Controls

Goal: The user can adjust the four initial preference weights via UI controls (sliders or equivalent). Changing any weight triggers a new routing request and the route updates on screen.

Out of scope: navigation, saving preferences between sessions.

Why this matters: validates the preference model abstraction and the adapter's translation layer. The custom engine in phase 2 will consume these same weights; their structure must be correct before it becomes hard to change.

### Milestone 6 — Route Comparison Tooling

Goal: The development support tool exists and is usable. Given an origin and destination, it submits the same request with N different parameter sets in parallel and renders all N routes on a single map with distinct visual treatments.

Out of scope: per-segment cost breakdown, trace replay.

Why this matters: this is the tool that makes experimenting with cost functions productive. It should exist before extensive preference tuning begins.

---

## 5. Forward Compatibility

### Custom Routing Engine

Phase 1 must get right: the routing engine interface must be designed for the richer contract the custom engine will provide, not trimmed to what GraphHopper returns easily. Specifically: per-segment metadata (surface, infrastructure type, way ID) must flow through the interface even if GraphHopper's support is partial. If the interface is narrowed to GraphHopper's output, the custom engine will be forced to fit into that mold.

Can defer: the Cap'n Proto schema, the Rust preprocessor's graph output format, any engine-specific performance optimizations.

### Turn-by-Turn Navigation

Phase 1 must get right: the route model carries a maneuver list (turn type, street name, distance) from the first milestone that exercises routing. The navigation event vocabulary — approaching turn, execute turn, arrived — must be established even if no UI component consumes it yet. Adding these after the fact requires changing the interface and both adapters.

Can defer: the turn card UI, sound effects, distance thresholds for "approaching", complex intersection geometry.

### Voice Guidance

Phase 1 must get right: voice guidance is a subscriber to the navigation event stream, not a side-channel from the UI. If the UI calls a voice function directly ("play this audio cue now"), adding voice to the macOS app requires duplicating that logic. The event stream must carry enough information for an independent subscriber to produce correct voice output — turn type, street name, distance, localized instruction text.

Can defer: everything else. Voice is purely additive once the event stream is correct.

### Dynamic Rerouting

Phase 1 must get right: rerouting goes through the same routing engine interface as initial planning, with no special code path. The navigation state machine owns the reroute decision; the UI only receives events. Off-route thresholds and minimum reroute intervals must be configurable parameters (not hardcoded) from the start.

Can defer: predictive rerouting (anticipate a wrong turn before it happens), traffic-aware rerouting.

### Offline Mode

Phase 1 relies on network for both tiles and routing. The architecture must not assume availability: the routing engine interface returns a structured "unavailable" error, and the tile source interface is structured so a local cache implementation can be substituted without changing anything above it. MapLibre's built-in tile cache provides a partial offline experience for recently viewed areas at no extra cost.

Can defer: fully offline routing (requires the custom engine on-device), explicit area download, background tile refresh.

### Additional Cities

Phase 1 must get right: the data pipeline must be parameterized by region from the start. Scripts that hardcode Berlin bounding boxes or filenames will require surgery to extend to a second city. Region should be an input, not an assumption.

Can defer: multi-city UI, routing across city boundaries, city selection in the app.

### Android

The shared core is written in Rust and exposed via UniFFI. UniFFI generates Swift bindings for the Apple apps and Kotlin bindings for Android from the same interface definition file. When the Android port begins, the shared core compiles to an Android target with no code changes; only the UI layer and Android OS integration are new.

Phase 1 must ensure that no Apple-specific types leak through the UniFFI boundary. The interface definitions must use primitive types, structs, and enums that UniFFI can represent in both Swift and Kotlin.

---

## 6. Preference and Cost Model

The preference model is a named, versioned set of weights. Each weight has a stable identifier, a normalized value (0.0 to 1.0), and metadata for display (human-readable label, description, default value). The initial set:

| Identifier | Meaning |
|---|---|
| `traffic_light_penalty` | How much to penalize routes with many traffic light stops |
| `unpaved_surface_penalty` | How much to penalize unpaved or rough surfaces |
| `main_road_avoidance` | How much to avoid high-traffic roads |
| `cycling_infra_preference` | How strongly to prefer dedicated cycling infrastructure |

New weights can be added to the schema without changing the UI layer. The UI renders a generic control for each weight it finds in the model, using the weight's metadata to configure the label and range. The UI does not name specific weights in its layout code.

### Mapping to GraphHopper (phase 1)

The routing adapter translates the weight vector into a GraphHopper Custom Model JSON block. GraphHopper's Custom Model operates on a predefined set of road attributes it derives from OSM during graph build. The mapping is approximate: `cycling_infra_preference` at maximum might set priority to 1.5 for `highway=cycleway` and 0.6 for `highway=primary`. The translation function lives entirely in the adapter.

This mapping will be imperfect. GraphHopper's Custom Model does not support arbitrary tag queries, only the attributes it pre-processes. The constraint should be verified at milestone 2, and the adapter's translation documented explicitly so that gaps are visible rather than hidden.

### Mapping to the Custom Engine (phase 2+)

The weight vector maps directly to cost function coefficients. The edge cost for the custom engine is a linear combination:

```
cost(edge) = base_travel_time(edge)
           + w_traffic_light   * signal_count(edge)
           + w_unpaved_surface * surface_penalty(edge)
           + w_main_road       * road_class_penalty(edge)
           - w_cycling_infra   * infra_bonus(edge)
```

The numeric properties (`signal_count`, `surface_penalty`, `road_class_penalty`, `infra_bonus`) are computed by the Rust preprocessor from OSM tags and stored as edge attributes. The cost function evaluates those attributes; it does not re-parse tags. Adding a new cost factor means: add a tag-to-attribute rule in the preprocessor, add a new edge attribute, add a weight to the model, add a term to the cost function. Nothing in the UI changes.

### Versioning

The model is versioned. When new weights are added, saved preference profiles from older versions are migrated by filling new weights with their defaults. The migration logic is part of the shared core's persistence layer and is tested.

---

## 7. Data Pipeline

```
berlin-latest.osm.pbf  (downloaded from Geofabrik, ~80 MB)
         │
         ├──► Tile Generator  (dev tooling, runs on OSM data refresh)
         │         └──► berlin.pmtiles
         │                   └──► deploy to Hetzner VPS
         │                         nginx/Caddy serves range requests
         │                         MapLibre fetches tiles over HTTPS
         │
         ├──► GraphHopper graph prep  (runs in container on first start, or pre-built)
         │         └──► graphhopper-cache/  (Docker volume, persists)
         │                   └──► GraphHopper answers HTTP routing requests
         │
         └──► Rust Preprocessor  (phase 1: stub; phase 2+: full pipeline)
                   └──► berlin.graph.capnp  (phase 2+)
                             └──► bundled with or fetched by custom engine
```

### Tile Serving

Tiles are served from a self-hosted PMTiles file on the Hetzner VPS. PMTiles is a single-file archive that any HTTP server with range request support can serve — no dedicated tile server process is required. The app constructs a tile URL template pointing at the VPS and provides it to MapLibre through the tile source interface. MapLibre handles HTTP fetching and its built-in LRU cache.

Self-hosted is recommended over a public CDN (MapTiler, Stadia, Protomaps CDN) because it eliminates API key management, imposes no usage limits, and gives full control over the tile schema. The VPS likely hosts GraphHopper anyway. Revisit only if VPS maintenance becomes burdensome.

### GraphHopper Graph Preparation

Graph preparation runs the first time the container starts against fresh OSM data, or against a pre-built graph file if one is provided. Pre-building is strongly recommended for the development loop — Berlin graph preparation takes several minutes, and rebuilding on every container restart is disruptive. The pre-built graph is a Docker volume snapshot or a committed artifact.

### Rust Preprocessor

Present in phase 1 as a stub. The pipeline script invokes it even if it does nothing substantive, so the pipeline remains a single-command operation throughout the project. In phase 2+ it grows to produce enriched edge attributes and eventually the Cap'n Proto graph.

### Pipeline Repeatability

When Berlin OSM data is refreshed (monthly or on demand), the full pipeline reruns: new `.pbf` → new tiles deployed to VPS → new GraphHopper graph built → new preprocessor output. This is a deliberate, infrequent operation, not a continuous build. A single script in the repository documents and automates each step.

Nothing in this pipeline runs on the user's device in phase 1.

---

## 8. Testing and Experimentation Strategy

The primary goal is fast iteration on cost functions and OSM tag logic. The strategy should serve that goal first, and classical correctness testing second.

### Route Comparison Tool (phase 1, milestone 6)

The single most valuable experimentation tool. Given an origin and destination, it submits the same request with N different parameter sets in parallel and renders all N resulting routes on a single map with distinct colors. This reveals immediately how changing a weight affects routing decisions.

Implementation: a minimal macOS app or a web page with MapLibre GL JS. It talks directly to the GraphHopper HTTP endpoint. It is expendable — rewrite it freely as needs evolve.

### Request Logging (phase 1)

The routing adapter logs every request (full parameter set, origin, destination, timestamp) and every response (route geometry, total cost, per-segment data) to a structured local file. Any prior request can be replayed against a modified parameter set and the results diffed. This is the minimum viable debugging capability.

### Simulated Location Traces (phase 1)

The location provider interface accepts a recorded trace (timestamped coordinate sequence) as an alternative to live GPS. A small set of representative Berlin traces is committed to the repository:
- Following a known cycle route cleanly
- Deliberately going off-route and recovering
- Navigating through a complex intersection

These traces make navigation state machine behavior deterministic and testable without physical rides. They work in the iOS simulator and on macOS.

### Segment Inspection (phase 1, stretch goal)

If GraphHopper returns per-edge data (OSM way IDs, speeds, priorities), the map can display this data for tapped segments — at minimum, the OSM way ID linking to osm.org. This dramatically accelerates tag logic iteration: when a route makes a surprising choice, tapping the offending segment reveals the underlying OSM way and allows direct inspection of its tags.

### Unit Testing

The navigation state machine and off-route detection geometry are deterministic pure functions and must be unit-tested with synthetic inputs in the Rust test suite. The routing adapter's translation logic (preference weights → GraphHopper Custom Model JSON) is testable with no running engine. Preference model version migration logic must be tested. UI layers are not unit-tested.

### Full Cost Debugger (phase 2+)

Per-segment cost breakdown showing each preference weight's contribution to each edge's cost. Visual diff between two routes showing exactly where they diverge and the cost difference at that point. This requires the custom engine to expose per-edge cost data — a requirement to capture in the routing engine interface design when the custom engine is planned.

### Trace Replay with Modified Parameters (phase 2+)

Re-run a recorded GPS trace through the navigation state machine with a different underlying route and compare the resulting off-route event timings. Useful for calibrating reroute thresholds without physical testing.

---

## 9. Risks and Open Questions

### Rust + UniFFI Toolchain Setup (mitigate at milestone 0)

Rust + UniFFI introduces real toolchain complexity: cross-compilation for multiple Apple targets, XCFramework packaging, Swift package integration, build script maintenance. UniFFI's async support is maturing but not seamless — complex async patterns across the FFI boundary require careful handling.

Mitigation: milestone 0 is explicitly scoped to prove the toolchain before any logic is written. Start with a trivial function call and confirm it works on iOS simulator, iOS device, and macOS before proceeding. Defer async-heavy patterns until the synchronous baseline is solid.

### GraphHopper Custom Model Expressiveness (verify at milestone 2)

GraphHopper's Custom Model operates on a fixed set of pre-derived attributes, not arbitrary OSM tag queries. If the preference model requires tag logic that GraphHopper cannot express — conditional rules, tag combinations, attributes it does not pre-process — the phase 1 routing will be less faithful than intended, or the adapter will need workarounds.

Resolution: test the full four-weight translation at milestone 2, document gaps explicitly, and decide whether to live with approximations or invest in workarounds before milestone 3.

### MapLibre Native macOS Maturity (verify at milestone 1)

MapLibre Native's macOS support has historically been less exercised than its iOS counterpart. Gesture handling, Metal renderer behavior, and some APIs may differ. This is a low-probability but high-disruption risk if discovered late.

Resolution: milestone 1 is specifically scoped to render a map on both platforms. Any macOS-specific issues surface before the UI is built on top of them.

### Tile Server Availability (acceptable risk, low priority)

In phase 1 the app requires network access to the Hetzner VPS for tile rendering. If the VPS is unreachable, the map does not display. This is acceptable during development. When moving toward a more production-quality experience, MapLibre's tile cache provides resilience for recently visited areas without any additional work.

Resolution: size the MapLibre tile cache generously (the Berlin cycling area is not large). Add a fallback CDN URL as a second option behind the tile source interface only if VPS reliability becomes a real problem.

### Cap'n Proto Schema Stability (defer until phase 2 begins)

Defining the routing graph schema in phase 1 is premature — the custom engine's data requirements are not yet fully understood. Locking a schema early risks either over-constraining the engine or requiring a breaking schema change later.

What phase 1 must do: ensure the Rust preprocessor's build pipeline can produce different output formats based on a flag. The GraphHopper path and the future Cap'n Proto path should be parallel output modes of the same input processing, not separate codepaths.

### Off-Route Detection Thresholds (calibrate when navigation is built)

The distance and time thresholds for declaring a user off-route have a large impact on perceived quality — too sensitive and the app reroutes constantly, too loose and the user is lost. Berlin's street density and urban canyon GPS accuracy will inform the right values. These thresholds must be configurable parameters in the navigation state machine from the start, not constants.

Resolution: expose them as a tuning configuration (distinct from user-facing preferences), establish initial values through testing with the Berlin trace set, and iterate during development.

### Rerouting Latency (evaluate at milestone 6)

Rerouting through GraphHopper over HTTP introduces measurable latency. If the navigation state machine triggers reroutes frequently (GPS noise, slow streets), the resulting request rate may degrade the experience or overload the local GraphHopper instance.

Mitigation: implement a minimum reroute interval and an off-route debounce (sustained deviation for N seconds, not momentary). Both are configurable parameters. The custom engine in phase 2 will be lower-latency; the GraphHopper constraint is temporary.

### Elevation Data (decide before phase 2 preprocessor work)

Berlin is flat but not entirely level. If gradient becomes a preference weight (common feature requests: avoid hills, maximize training load), SRTM or similar DEM data must be incorporated into the preprocessor pipeline. The OSM data alone has incomplete elevation coverage.

Resolution: the preprocessor pipeline structure should not make elevation data hard to add. Design the edge attribute schema with a nullable gradient field from the start. Whether to populate it in phase 1 is a scope decision, not an architectural one.

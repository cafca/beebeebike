# beebeebike — Web App MVP

A personal bicycle routing app for Berlin. Each user builds their own map of road segment ratings — streets they love, streets they avoid. When they request a route, the routing engine incorporates those personal ratings to find the best path *for them*.

---

## What the MVP Does

A user opens the web app and sees a map of Berlin. They sign up, and start painting their personal preference map: click any road segment and rate it on a 7-point scale (-7, -3, -1, 0, +1, +3, +7). Rate an entire computed route at once. Over time, the map fills with color — green for streets they enjoy, red for streets they want to avoid.

When the user requests a route, the backend folds their personal ratings into the routing cost function. A segment rated -7 becomes expensive to traverse; a segment rated +7 becomes cheap. The route bends around the user's dislikes and toward their favorites. Unrated segments use GraphHopper's default bicycle cost.

The developer controls a set of tuning parameters that govern how strongly personal ratings influence routing relative to GraphHopper's base cost factors (distance, elevation, road class, cycling infrastructure). These parameters are server-side configuration, not exposed to end users.

---

## Fixed Decisions

- **Platform:** Web only. No native apps, no FFI, no UniFFI.
- **Backend:** Rust (Axum), serving both the API and the frontend static assets.
- **Frontend:** Lightweight SPA. Vanilla JS or a minimal framework (Svelte preferred for ergonomics). MapLibre GL JS for the map.
- **Database:** PostgreSQL with PostGIS. Multi-user from day one.
- **Authentication:** Email + password to start.
- **Map rendering:** MapLibre GL JS with vector tiles.
- **Tile delivery:** Berlin OSM extract processed into PMTiles, served by the backend or a static file server in the compose stack.
- **Routing engine:** GraphHopper, running in the existing Docker Compose setup. Accessed server-side by the Rust backend — the browser never talks to GraphHopper directly.
- **Geocoding:** Photon (public instance at `photon.komoot.io`), called server-side by the Rust backend.
- **Development:** Everything runs via `docker-compose up`. The Rust backend, PostgreSQL, and GraphHopper all live in the compose file. Hot-reload for the frontend during development.
- **Scope:** Berlin only.

---

## Data Model

### Users

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | PK |
| `email` | text | unique, indexed |
| `password_hash` | text | argon2 |
| `display_name` | text | |
| `created_at` | timestamptz | |

### Segments

Road segments derived from OSM ways. Each segment is a contiguous piece of road between two intersections.

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | PK, derived from OSM way ID + segment index |
| `osm_way_id` | bigint | indexed |
| `geometry` | geometry(LineString, 4326) | PostGIS |
| `name` | text | street name if available |
| `road_class` | text | e.g. `cycleway`, `residential`, `primary` |

Segments are imported from the same Berlin OSM extract that feeds GraphHopper. A one-time import script populates this table.

### Ratings

| Column | Type | Notes |
|---|---|---|
| `id` | bigint | PK |
| `user_id` | uuid | FK users, indexed |
| `segment_id` | bigint | FK segments, indexed |
| `value` | smallint | one of: -7, -3, -1, 0, 1, 3, 7 |
| `created_at` | timestamptz | |
| `updated_at` | timestamptz | |

Unique constraint on `(user_id, segment_id)` — one active rating per user per segment. Updating replaces.

### Routing Config (server-side, not a DB table)

Developer-tunable parameters that control how personal ratings blend into routing cost. Stored as a config file or environment variables, not in the database. Examples:

| Parameter | Meaning |
|---|---|
| `rating_weight` | Overall influence of personal ratings vs. GraphHopper base cost (0.0 = ratings ignored, 1.0 = ratings dominate) |
| `unrated_penalty` | Cost bias for segments the user hasn't rated (0.0 = neutral, positive = mildly discourage unknown roads) |
| `distance_weight` | How much raw distance matters relative to other factors |
| `elevation_weight` | How much elevation gain matters |
| `infra_weight` | How much cycling infrastructure (bike lanes, cycleways) matters |

These are knobs for the developer to tune the routing heuristic. They are **not** exposed to users. The exact set will evolve as routing behavior is tested on real Berlin road networks.

---

## Components

### Rust Backend (Axum)

The single server process. Responsibilities:

- **Auth:** Registration, login, session management (cookie-based sessions stored in PostgreSQL).
- **Personalized routing:** Accepts route requests from the frontend, loads the user's segment ratings, translates them into GraphHopper Custom Model cost adjustments, calls GraphHopper, and returns GeoJSON. The frontend never talks to GraphHopper directly.
- **Geocoding proxy:** Accepts search queries, calls Photon, returns results. Sets the project `User-Agent`.
- **Ratings API:** CRUD for user ratings on segments. Validates the rating value is in the allowed set. Supports single-segment upsert, bulk upsert (for route rating), and paint upsert (brush stroke geometry, returns all affected segments).
- **Segment lookup:** Given a click location (lat/lng), find the nearest segment using PostGIS `ST_DWithin` / `ST_Distance`.
- **Personal overlay:** Serves the logged-in user's segment ratings as GeoJSON for the map overlay. Each user sees their own map, not an aggregate.
- **Routing config:** Reads developer-tunable parameters that control how ratings blend into routing cost. Not exposed to end users.
- **Static file serving:** Serves the built frontend assets.

### Frontend (SPA)

A single-page application. Key interactions:

- **Map:** MapLibre GL JS. Pan, zoom, click. The user's personal rating overlay rendered as a colored layer — their map, nobody else's.
- **Search:** Autocomplete search box. Debounced calls to the backend geocoding proxy.
- **Routing:** Click or search to set origin and destination. Route is computed using the user's personal ratings and renders on the map. The route visibly prefers green segments and avoids red ones.
- **Segment rating:** Click a road segment on the map. A compact popup appears showing the segment name and the user's current rating (if any). Seven buttons in a row: -7 -3 -1 0 +1 +3 +7. No labels, only color coding- dark red, intense red, light red, blue, light green, intense green, emerald green. No margin between color buttons. One tap to rate. The popup closes or updates immediately.
- **Paint Brush Rating** Switch from segment rating to paint brush with a toggle switch. Paint large areas with a single color / rating. Defaults to light green (+1). Brush size adjustable roughly 5px - 80px equivalent.
- **Route rating:** After computing a route, a "Rate this route" button appears. Clicking it applies the chosen rating to every segment in the route. A confirmation shows how many segments will be rated.
- **Rating history:** A simple list view of the user's past ratings with links back to the map location.

### Database (PostgreSQL + PostGIS)

Runs in Docker Compose. Schema managed by migrations in the Rust backend (using `sqlx` or `refinery`).

### GraphHopper

Existing setup, unchanged. Berlin bicycle routing. The Rust backend calls it over the Docker network.

### Tile Server

Existing setup. Serves Berlin vector tiles to MapLibre in the browser.

---

## UX: Rating Flow

The rating interaction must be fast and low-friction. The user is building a personal map over time — it should feel like painting, not filling out forms.

### Two Rating Modes

The user switches between modes via a toggle in the toolbar.

**Segment click mode (default).** Click a segment on the map. A compact popup appears anchored to the click point, showing the segment name and the user's current rating (if any). Seven color buttons in a tight row — no labels, no margins between them: dark red, intense red, light red, blue (neutral), light green, intense green, emerald green. One tap to rate. The popup closes immediately. Two interactions total: click to identify, click to rate.

**Paint brush mode.** The cursor becomes a brush. The user selects a rating value from the same 7-color strip (defaults to +1, light green). Then they click-drag across the map, and every segment the brush touches gets that rating. Brush size is adjustable, roughly 5px to 80px equivalent on screen. This is for covering large areas fast — "I know this whole neighborhood is fine" or "avoid everything along this corridor."

### Design Goals

1. **Immediate feedback.** After rating (click or paint), the segment color on the map updates within the same frame. No spinner, no "saving..." state. Optimistic update, reconcile in background.
2. **No modals, no forms.** The click popup is a small floating panel. The paint brush has no popup at all — just drag and color appears.
3. **Undo by re-rating.** Rating neutral (blue, 0) effectively removes a rating. Clicking or painting a different value replaces the previous one. No separate delete action.
4. **Route bulk-rating.** When a route is displayed, the user can rate the entire route at once. This is a convenience — each segment still gets its own rating row. A toast confirms "Rated 23 segments +3" and the map updates.
5. **Color is the language.** No numeric labels on the buttons. The scale communicates through color intensity alone:

| Value | Color | Meaning |
|---|---|---|
| -7 | Dark red | Dangerous / never ride here |
| -3 | Intense red | Unpleasant / avoid if possible |
| -1 | Light red | Slightly below average |
| 0 | Blue | Neutral / no opinion |
| +1 | Light green | Slightly above average |
| +3 | Intense green | Pleasant / prefer this street |
| +7 | Emerald green | Excellent / go out of my way for this |

6. **Auth required.** You must be logged in to see the map overlay and to rate. The map without login shows a plain Berlin map — there is nothing to show anonymously since ratings are personal.

### Building the Personal Map

The core experience loop:

- A new user's map is blank — all segments are unstyled.
- They ride their usual routes, then come home and paint the segments they know. Switch to paint brush, pick green, drag over familiar streets. Switch to click mode for individual segments they feel strongly about. The map fills with color fast.
- When they request a route, they see it bending toward their green segments and away from red ones. This reinforces the value of rating: the more you paint, the better your routes get.
- Over time, their map becomes a complete picture of their Berlin cycling preferences — a personal infrastructure opinion they can act on every day.

---

## Map Overlay

Each logged-in user sees their own personal overlay. Segments are colored by the user's rating on a continuous red-to-green gradient. Unrated segments are unstyled (transparent). The overlay is a MapLibre layer sourced from a GeoJSON endpoint on the backend that filters by the authenticated user.

The overlay is fetched per-viewport on map move. Since it's per-user data (not a shared aggregate), pre-rendering tiles doesn't help — the data is different for every user. The query is fast: a spatial join between the viewport bounding box and the user's ratings, indexed on `(user_id, segment_id)` with a spatial index on segment geometry.

For users with many ratings (thousands of segments), the response may grow. Mitigation: simplify geometries at low zoom levels, paginate or cluster at city-wide zoom.

---

## Data Flow

### Rating a segment (click mode)

1. User clicks the map.
2. Frontend sends click coordinates to `GET /api/segments/nearest?lat=X&lng=Y`.
3. Backend queries PostGIS for the nearest segment within a threshold. Returns segment info and the user's existing rating (if any).
4. Frontend shows the rating popup with segment info and the 7-color strip, highlighting the current rating.
5. User clicks a color button.
6. Frontend sends `PUT /api/ratings` with `{ segment_id, value }`.
7. Backend upserts the rating.
8. Frontend optimistically updates the segment color on the map and closes the popup.

### Painting segments (brush mode)

1. User switches to paint brush mode and selects a rating value (default: +1).
2. User clicks and drags across the map.
3. Frontend continuously converts the brush stroke into a buffered geometry (a corridor around the drag path, width determined by brush size).
4. On mouse-up (or periodically during a long drag), frontend sends `PUT /api/ratings/paint` with `{ geometry: <GeoJSON polygon of the brush stroke>, value }`.
5. Backend queries PostGIS for all segments that intersect the brush geometry (`ST_Intersects`).
6. Backend upserts ratings for all matched segments.
7. Backend returns the list of affected segment IDs.
8. Frontend optimistically colors segments during the drag (using client-side spatial approximation) and reconciles with the server response.

The brush stroke geometry is computed client-side as a buffered LineString along the drag path. The buffer radius maps from the brush size in screen pixels to meters at the current zoom level. At low zoom (city-wide), a small brush covers many segments; at high zoom (street-level), it covers few. This feels natural.

### Rating a route

1. User has a route displayed (computed via search or map clicks).
2. User clicks "Rate this route" and selects a value from the 7-color strip.
3. Frontend sends `PUT /api/ratings/bulk` with `{ segment_ids: [...], value }`.
4. Backend upserts ratings for all segments.
5. Frontend updates all affected segment colors.

### Requesting a personalized route

1. User sets origin and destination via search or map click.
2. Frontend sends `POST /api/route` with `{ origin, destination }`.
3. Backend loads the user's segment ratings that are geographically relevant (within a bounding box around origin/destination, with margin).
4. Backend builds a GraphHopper Custom Model request that encodes the user's ratings as cost adjustments — rated segments get speed or priority overrides proportional to their rating value, scaled by the developer-tuned `rating_weight` parameter.
5. Backend calls GraphHopper with the custom model, gets the route geometry.
6. Backend matches the route geometry to segments in the database (for the "rate this route" feature).
7. Backend returns `{ geometry, segments: [...], distance, duration }`.
8. Frontend renders the route and enables the bulk-rating button.

### How ratings influence routing

GraphHopper's Custom Model allows per-request cost adjustments via `priority` statements that match road attributes. The backend translates user ratings into these statements:

- A segment rated +7 gets a high priority multiplier (cheaper to traverse).
- A segment rated -7 gets a near-zero priority multiplier (very expensive to traverse).
- Unrated segments keep GraphHopper's default bicycle cost.

The exact mapping from rating values to priority multipliers is controlled by the developer-tuned routing config. The non-linear rating scale (-7, -3, -1, 0, +1, +3, +7) maps to non-linear cost adjustments — a -7 rating should make a segment nearly impassable, not just slightly more expensive.

**Limitation:** GraphHopper's Custom Model matches on road attributes (road class, surface type, etc.), not on individual OSM way IDs directly. To target specific user-rated segments, the backend may need to use waypoint avoidance/preference hints, or encode ratings into a per-request cost matrix. The exact mechanism needs validation against GraphHopper's API during milestone 2. If Custom Model alone can't express per-segment costs, alternatives include:

- Using GraphHopper's flexible routing mode with a custom weighting
- A thin routing post-processor that re-ranks alternative routes by user rating overlap
- Contributing a per-edge cost override feature upstream

This is the hardest technical risk in the MVP and must be spiked early.

---

## Build Order

### Milestone 0 — Dev Environment + Routing Spike

Docker Compose runs PostgreSQL (with PostGIS), GraphHopper, and the tile server. The Rust backend compiles, starts, connects to PostgreSQL, runs migrations, and serves a health check endpoint. A "hello world" HTML page is served as a static asset.

**Critical spike:** Validate that GraphHopper can express per-segment cost overrides driven by user ratings. Test the Custom Model API with hand-crafted requests that penalize or reward specific road segments. Document what works and what doesn't. If Custom Model can't do it, identify the alternative approach before proceeding. This spike gates the entire project — don't build the rating UI until the routing integration is proven.

### Milestone 1 — Map + Segments + Rating

The frontend shows a MapLibre map of Berlin with vector tiles from the compose stack. The segment import script loads Berlin road segments into PostgreSQL. Auth works (registration + login). Both rating modes work: click a segment to see the popup and pick a color, or switch to paint brush and drag across streets. The personal color overlay updates in real time. This is the painting loop — click or drag, see the map fill with color.

### Milestone 2 — Personalized Routing

Search box with autocomplete (Photon via backend proxy). Route computation through the backend, with the user's personal ratings folded into GraphHopper's cost model. The route visibly responds to the user's ratings — a heavily downvoted street gets routed around. Bulk route rating works. This is the payoff — the personal map becomes actionable.

### Milestone 3 — Polish + Deploy

Rating history view. Mobile-responsive layout. Error handling. Rate limiting. Developer routing config is tunable without redeployment (env vars or config file reload). The compose stack runs on a public server with TLS. Deployment script committed.

---

## Docker Compose (Development)

Extends the existing compose file with:

```yaml
services:
  db:
    image: postgis/postgis:16-3.4
    environment:
      POSTGRES_DB: beebeebike
      POSTGRES_USER: beebeebike
      POSTGRES_PASSWORD: beebeebike
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  backend:
    build: ./backend
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://beebeebike:beebeebike@db:5432/beebeebike
      GRAPHHOPPER_URL: http://graphhopper:8989
      PHOTON_URL: https://photon.komoot.io
    depends_on:
      - db
      - graphhopper

  # graphhopper and tiles services unchanged from existing compose

volumes:
  pgdata:
```

---

## Testing

- **Backend integration tests:** Use a test PostgreSQL database (separate container or testcontainers). Test the rating flow end-to-end: create user, rate segment, verify personal overlay returns only that user's data.
- **Personalized routing tests:** Create a user with known segment ratings, request a route, verify the route avoids heavily downvoted segments. Compare against the same route with no ratings.
- **Segment lookup tests:** Verify PostGIS nearest-segment queries return correct results for known coordinates.
- **API tests:** HTTP-level tests for all endpoints, including auth guards and user isolation (user A cannot see user B's ratings).
- **Frontend:** Manual testing against the dev compose stack. No frontend unit tests in the MVP.
- **Routing config tests:** Verify that changing developer-tunable parameters (rating_weight, etc.) produces measurably different routes for the same user ratings.
- **Regression routes:** A committed list of (origin, destination, user_ratings) tuples. After changing the rating-to-cost translation or tuning parameters, re-run and compare. Not automated pass/fail — just a way to notice when routes shift unexpectedly.

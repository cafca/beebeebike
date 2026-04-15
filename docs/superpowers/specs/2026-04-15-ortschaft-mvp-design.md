# Ortschaft MVP Design

Personal bicycle routing app for Berlin. Users rate road segments, routing engine uses ratings to find personalized routes.

## Decisions

| Choice | Decision |
|---|---|
| Frontend | Svelte + Vite, MapLibre GL JS |
| Backend | Rust (Axum), single `backend/` crate |
| Database | PostgreSQL 16 + PostGIS via sqlx (compile-time checked queries, migrations) |
| Tiles | VersaTiles (`versatiles/versatiles:latest`), Berlin extract from download.versatiles.org |
| Routing | GraphHopper (existing Docker setup), Custom Model API for per-segment cost |
| Geocoding | Photon (photon.komoot.io), proxied server-side |
| Auth | Email + password, argon2, cookie sessions in PostgreSQL |
| Dev env | docker-compose: PostgreSQL, GraphHopper, VersaTiles, Rust backend |

## Architecture

```
Browser (Svelte SPA + MapLibre)
  |
  v
Rust Backend (Axum, port 3000)
  |--- serves frontend static assets
  |--- /api/auth/*         (register, login, logout)
  |--- /api/segments/nearest  (PostGIS nearest-segment lookup)
  |--- /api/ratings/*      (CRUD, bulk, paint)
  |--- /api/ratings/overlay (GeoJSON per-user overlay, viewport-filtered)
  |--- /api/route           (personalized routing via GraphHopper)
  |--- /api/geocode          (Photon proxy)
  |
  +---> PostgreSQL + PostGIS (segments, users, ratings, sessions)
  +---> GraphHopper (route computation)

VersaTiles (port 8080) -- serves vector tiles directly to browser
```

The browser talks to two services: the Axum backend (API + static assets) and VersaTiles (map tiles). Everything else is server-side.

## Data Model

Exactly as specified in IDEA.md:

- **users**: id (uuid), email, password_hash (argon2), display_name, created_at
- **segments**: id (bigint), osm_way_id, geometry (LineString 4326), name, road_class
- **ratings**: id, user_id (FK), segment_id (FK), value (-7/-3/-1/0/+1/+3/+7), created_at, updated_at
- **sessions**: sid, user_id (FK), data, expires_at

Unique constraint on (user_id, segment_id) for ratings.

## Segment Import

One-time script that reads the Berlin OSM PBF and inserts road segments into PostgreSQL. Segments are road pieces between intersections. Uses the same extract that feeds GraphHopper.

Implementation: Rust binary or script using the `osmpbf` crate to parse the PBF, extract ways tagged as roads/cycleways, split at intersections, and insert via sqlx.

## Routing Integration

GraphHopper Custom Model API allows per-request cost adjustments via `priority` statements. The backend:

1. Loads user's ratings in the geographic area around origin/destination
2. Maps ratings to GraphHopper priority multipliers (non-linear: -7 -> near-zero priority, +7 -> high priority)
3. Sends Custom Model request to GraphHopper
4. Returns route geometry + matched segment IDs

**Known risk:** Custom Model matches on road attributes, not individual way IDs. The spike must validate whether `area` conditions with per-segment geometries work, or if an alternative approach is needed.

## Frontend Components

- **Map**: MapLibre GL JS, full-screen, Berlin-centered
- **Rating overlay**: GeoJSON layer from `/api/ratings/overlay`, colored red-to-green per rating value, fetched per-viewport
- **Segment click mode** (default): Click segment -> popup with 7-color strip -> one tap to rate
- **Paint brush mode**: Toggle switch, select rating, click-drag to paint segments. Brush sends buffered geometry to `/api/ratings/paint`
- **Search**: Autocomplete search box, debounced Photon queries via backend
- **Routing**: Click/search to set origin+destination, route rendered on map, "Rate this route" bulk action
- **Auth**: Login/register forms, minimal UI
- **Rating history**: Simple list view with map links

## Tile Setup

VersaTiles serves Berlin vector tiles:
- One-time download: `versatiles convert --bbox "13.0,52.3,13.8,52.7" https://download.versatiles.org/osm.versatiles berlin.versatiles`
- Docker service serves the file on port 8080
- MapLibre configured to use VersaTiles style + tile endpoints

## Developer Routing Config

Server-side config file (not in DB, not user-facing):
- `rating_weight`: influence of ratings vs base cost (0.0-1.0)
- `unrated_penalty`: cost bias for unrated segments
- `distance_weight`, `elevation_weight`, `infra_weight`

Read from config file or env vars, hot-reloadable.

## Testing Strategy

- Backend integration tests with test PostgreSQL (sqlx test fixtures)
- API tests for all endpoints including auth guards and user isolation
- PostGIS spatial query tests with known coordinates
- Routing tests: known ratings -> verify route avoidance/preference
- Frontend: manual testing against dev compose stack

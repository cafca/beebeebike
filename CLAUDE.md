# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

### Full stack (Docker Compose)

```bash
# Development: all services + hot-reload frontend
docker compose -f compose.yml -f compose.dev.yml up

# Production (memory-constrained):
docker compose -f compose.prod.yml up -d --build
```

### Previewing changes when working in a worktree

Always do this when you have completed a unit of work.

To preview your changes for the user: Assume other docker instances of this app are running and start the stack with a custom port. Pick a random port, save time and don't check for other running stacks.

First, copy the data/ directory from the main repo location to current worktree. Then:

VITE_DEV_PORT=<random port> docker compose -f compose.yml -f compose.dev.yml up

Frontend has HMR, don't restart the stack following changes, it will auto-reload.

### Backend only (local Rust dev)

```bash
cd backend
cargo build
cargo run          # needs DATABASE_URL, GRAPHHOPPER_URL etc. (see config.rs defaults)
cargo test
cargo fmt --check
cargo clippy -- -D warnings
```

Backend uses `SQLX_OFFLINE=true` for Docker builds (no live DB needed at compile time). Locally, sqlx connects to Postgres at build time for query checking.

### Frontend only

```bash
cd web
npm ci
npm run dev        # Vite dev server on :5173, proxies /api → localhost:3000
npm run build      # production build → web/dist/
```

### Static data (not in repo)

OSM extract and vector tiles must be downloaded before first run:

```bash
scripts/download_berlin_osm.sh   # → data/osm/berlin/berlin.osm.pbf
scripts/download_berlin_tiles.sh  # → data/tiles/berlin.versatiles
```

## Architecture

**Svelte 5 frontend** (MapLibre GL + Turf.js) → **Rust/Axum backend** → **PostGIS** + **GraphHopper**

### How routing works

Users "paint" rated polygons onto the map (brush tool). When requesting a route:

1. Backend loads the user's rated areas intersecting the route corridor from PostGIS
2. Converts ratings to GraphHopper priority multipliers via `rating_to_priority()` (ratings.rs)
3. Builds a GraphHopper Custom Model request with area-based priority rules
4. Returns route geometry, distance, and time

Rating values are discrete: -7, -3, -1, 0 (eraser), 1, 3, 7. The paint endpoint (`PUT /api/ratings/paint`) handles polygon clipping — new polygons clip existing overlapping ones via PostGIS `ST_Difference`.

### Backend modules

- `routing.rs` — Route calculation via GraphHopper Custom Model API
- `ratings.rs` — Paint/erase rated areas, get overlay as GeoJSON FeatureCollection
- `auth.rs` — Session-based auth (argon2 passwords, UUID sessions)
- `geocode.rs` — Proxies to Photon (Komoot) geocoding API
- `config.rs` — All config via env vars with sensible defaults

### Frontend structure

- `Map.svelte` — MapLibre GL map instance
- `lib/brush.svelte.js` — Brush tool for painting rated areas
- `lib/overlay.js` — Renders rated area polygons on map
- `lib/routing.svelte.js` — Route request/display state
- `lib/auth.svelte.js` — Auth state (Svelte 5 runes)
- `lib/api.js` — Backend API client

### Compose services

| Service | Port | Purpose |
|---------|------|---------|
| backend | 3000 | Axum API + serves frontend dist as static files |
| db | 5432 | PostGIS (spatial queries for rated areas) |
| graphhopper | 8989 | Bicycle routing with custom model support |
| tiles | 8080 | VersaTiles vector tile server |
| web (dev only) | 5173 (default) | Vite dev server with API proxy |

### Migrations

SQL migrations in `backend/migrations/`, auto-run on backend startup via `sqlx::migrate!`.

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`): lint → test-backend → test-frontend → publish Docker image to GHCR → deploy via SSH (on push to main).

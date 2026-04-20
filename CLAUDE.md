# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

All day-to-day commands run through `just`. Install once with `brew install just`, then `just` (no args) lists everything.

### Full stack (Docker Compose)

- Dev: `just dev` — full stack with hot-reload frontend (`compose.yml` + `compose.dev.yml`)
- Prod: `just release` — `compose.prod.yml`, detached, with rebuild

### Previewing changes when working in a worktree

Always do this when you have completed a unit of work.

`just preview` — copies `data/` from the main repo checkout if missing, picks a random port in 20000–30000, echoes the URL, and starts the dev stack with `VITE_DEV_PORT` set. Frontend has HMR — don't restart the stack after changes.

### Backend

- `just test-backend` — cargo test
- `just lint-backend` — fmt check + clippy with `-D warnings`
- `just fmt` — mutating `cargo fmt`

Backend uses `SQLX_OFFLINE=true` for Docker builds. Locally, sqlx connects to Postgres at build time for query checking.

### Web app (Svelte)

- `just setup-web` — `npm ci`
- `just build-web` — production build to `web/dist/`
- `just test-web` — vitest unit tests + mobile-style parity (run `just build-web` first if build matters)
- `just test-e2e` — Playwright chromium smoke (webServer builds + serves vite preview). Requires one-time `npx playwright install chromium` from inside `web/`.

### Mobile app (iOS only)

- `just setup-mobile` — `flutter pub get` for plugin and app
- `just dev-ios-sim` — run on iOS simulator against local docker stack (defaults to 127.0.0.1)
- `just dev-ios-device <DEVICE>` — run on physical device against dev stack over LAN (auto-detects host IP via `ipconfig getifaddr en0`)
- `just release-ios-device <DEVICE>` — release-mode run against production URLs (`https://beebeebike.com`)
- `just test-mobile` — analyze + test for the app
- `just test-ferrostar-flutter-plugin` — analyze + test for the plugin at `packages/ferrostar_flutter/`
- `just test-ios [UDID=""]` — iOS sim integration smoke test; auto-picks an available iPhone 17 if `UDID` is empty

Platform scope: iOS only in v0.1. `ferrostar_flutter` at `packages/ferrostar_flutter/` is a path dependency and must be present.

### Map style (web + mobile)

The bicycle-planning visual style lives in [web/src/lib/bicycle-style.js](web/src/lib/bicycle-style.js) as `buildBicycleStyle`. Mobile bundles a pre-baked artifact at `mobile/assets/styles/beebeebike-style.json` whose URLs use `{{TILE_BASE}}`, swapped at runtime. After editing the shared builder, regenerate with `just build-mobile-style`. CI (`just test-web`) fails if the committed artifact diverges.

### Static data (not in repo)

OSM extract and vector tiles must be downloaded before first run: `just setup-data` (runs both `scripts/download_berlin_*.sh`).

### Clean

- `just clean` — clean everything (cargo, web, flutter, docker volumes)
- Subcommands: `clean-backend`, `clean-web`, `clean-mobile`, `clean-docker`

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

GitHub Actions (`.github/workflows/ci.yml`): lint → backend → frontend → frontend-e2e → publish Docker image to GHCR → deploy via SSH (on push to main). All jobs call `just` recipes.

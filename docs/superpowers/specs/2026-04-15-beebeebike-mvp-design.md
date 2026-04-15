# beebeebike MVP Design

Personal bicycle routing app for Berlin. Users paint rated areas on the map — streets they love in green, streets they avoid in red. The routing engine uses these painted areas to find personalized routes.

## Decisions

| Choice | Decision |
|---|---|
| Frontend | Svelte + Vite, MapLibre GL JS |
| Backend | Rust (Axum), single `backend/` crate |
| Database | PostgreSQL 16 + PostGIS via sqlx (compile-time checked queries, migrations) |
| Tiles | VersaTiles (`versatiles/versatiles:latest`), Berlin extract from download.versatiles.org |
| Routing | GraphHopper (existing Docker setup), Custom Model API with polygon areas |
| Geocoding | Photon (photon.komoot.io), proxied server-side |
| Auth | Email + password, argon2, cookie sessions in PostgreSQL |
| Dev env | docker-compose: PostgreSQL, GraphHopper, VersaTiles, Rust backend |
| Rating model | Polygon-based (not segment-based). Paint brush only, no click-to-rate segments. |
| Overlap | Paint overwrites — new polygons clip existing ones. Non-overlapping coverage. |
| Undo/redo | Session-based. Undo stack resets on browser close. |

## Architecture

```
Browser (Svelte SPA + MapLibre)
  |
  v
Rust Backend (Axum, port 3000)
  |--- serves frontend static assets
  |--- /api/auth/*           (register, login, logout)
  |--- /api/ratings          (GET: user's rated polygons, viewport-filtered)
  |--- /api/ratings/paint    (PUT: upsert painted polygon, clips overlaps)
  |--- /api/ratings/undo     (POST: revert last paint stroke server-side)
  |--- /api/route            (personalized routing via GraphHopper)
  |--- /api/geocode          (Photon proxy)
  |
  +---> PostgreSQL + PostGIS (users, rated_areas, sessions)
  +---> GraphHopper (route computation)

VersaTiles (port 8080) -- serves vector tiles directly to browser
```

## Data Model

### users
| Column | Type | Notes |
|---|---|---|
| id | uuid | PK |
| email | text | unique, indexed |
| password_hash | text | argon2 |
| display_name | text | |
| created_at | timestamptz | |

### rated_areas
| Column | Type | Notes |
|---|---|---|
| id | bigserial | PK |
| user_id | uuid | FK users, indexed |
| geometry | geometry(Polygon, 4326) | PostGIS, spatial index |
| value | smallint | -7, -3, -1, +1, +3, +7 (no 0 — neutral erases) |
| created_at | timestamptz | |
| updated_at | timestamptz | |

No overlaps within a single user's data. When a new polygon is painted:
1. Find all existing polygons that intersect the new one
2. Clip them: `ST_Difference(existing.geometry, new.geometry)`
3. Delete any that become empty after clipping
4. Insert the new polygon (unless value is 0, in which case just clip — erase mode)

### sessions
| Column | Type | Notes |
|---|---|---|
| id | text | PK, random token |
| user_id | uuid | FK users |
| expires_at | timestamptz | |

## Paint Interaction

One mode only: paint brush. The user selects a rating value from a 7-color strip (defaults to +1), then click-drags to paint. Brush size adjustable (~5px to ~80px screen equivalent).

The brush stroke is a buffered LineString — the frontend computes a polygon corridor around the drag path, width based on brush size and zoom level. On mouse-up, the polygon is sent to the backend.

**Color strip**: dark red (-7), intense red (-3), light red (-1), light green (+1), intense green (+3), emerald green (+7). Plus an eraser tool that paints 0 (clips existing polygons without creating a new one).

**Undo/redo**: Session-based stack in the frontend. Each paint stroke records the before/after state of affected polygons. Undo restores the previous state via the same paint API. Stack resets on page close. Ctrl+Z / Ctrl+Shift+Z keybindings.

**Immediate feedback**: Optimistic update — the polygon appears on the map immediately during/after the drag. Server reconciliation happens in the background.

## Routing Integration

GraphHopper Custom Model supports `areas` — GeoJSON polygon features that become conditions in priority statements. This maps perfectly to rated_areas.

The backend:
1. Receives route request with origin + destination
2. Loads user's rated_areas in a bounding box around the route corridor (with margin)
3. Converts each rated_area into a GeoJSON Feature with a unique `id`
4. Builds priority statements: `{ "if": "in_<area_id>", "multiply_by": <factor> }`
5. Rating-to-priority mapping (non-linear):
   - -7 → multiply_by 0.05 (nearly impassable)
   - -3 → multiply_by 0.3
   - -1 → multiply_by 0.7
   - +1 → multiply_by 1.3
   - +3 → multiply_by 2.0
   - +7 → multiply_by 3.0
6. Sends Custom Model request with `ch.disable: true`
7. Returns route GeoJSON to frontend

Request structure:
```json
{
  "points": [[13.38, 52.52], [13.41, 52.50]],
  "profile": "bike",
  "ch.disable": true,
  "custom_model": {
    "priority": [
      { "if": "in_area_1", "multiply_by": "0.05" },
      { "if": "in_area_42", "multiply_by": "2.0" }
    ],
    "distance_influence": 70,
    "areas": {
      "type": "FeatureCollection",
      "features": [
        { "type": "Feature", "id": "area_1", "properties": {}, "geometry": { "type": "Polygon", "coordinates": [...] } },
        { "type": "Feature", "id": "area_42", "properties": {}, "geometry": { "type": "Polygon", "coordinates": [...] } }
      ]
    }
  }
}
```

**Limits**: GraphHopper has practical limits on custom model size. For users with many rated areas, the backend should simplify geometries and potentially merge adjacent same-rated polygons before sending.

## Developer Routing Config

Server-side config (env vars or config file):
- `rating_weight`: overall influence scaling (0.0-1.0), applied as exponent to priority multipliers
- `distance_influence`: passed to GraphHopper, controls preference for shorter routes (default 70)
- `max_areas_per_request`: cap on number of areas sent to GraphHopper (default 200)

## Tile Setup

VersaTiles serves Berlin vector tiles:
- One-time download: `versatiles convert --bbox "13.0,52.3,13.8,52.7" https://download.versatiles.org/osm.versatiles berlin.versatiles`
- Docker service serves the file on port 8080
- MapLibre configured to use VersaTiles style + tile endpoints

## Removed from MVP

- Segment-based ratings (replaced by polygon ratings)
- Click-to-rate individual segments
- Route bulk-rating ("rate this route")
- Rating history view
- Persistent undo (undo is session-only)

## Testing Strategy

- Backend integration tests with test PostgreSQL (sqlx test fixtures)
- API tests: auth guards, user isolation, polygon clipping correctness
- PostGIS spatial tests: overlap clipping produces correct geometries
- Routing tests: rated areas produce different routes vs. unrated
- Frontend: manual testing against dev compose stack

# Ortschaft MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal bicycle routing web app for Berlin where users paint rated areas on a map and get personalized routes.

**Architecture:** Svelte+Vite SPA talks to an Axum backend. Ratings are stored as PostGIS polygons. Routing goes through GraphHopper Custom Model with user polygons as area overrides. VersaTiles serves map tiles.

**Tech Stack:** Rust/Axum, Svelte/Vite, PostgreSQL+PostGIS, sqlx, MapLibre GL JS, GraphHopper, VersaTiles, Docker Compose

---

## File Structure

```
ortschaft/
├── backend/
│   ├── Cargo.toml
│   ├── Dockerfile
│   ├── sqlx-data.json              (offline query data)
│   ├── migrations/
│   │   ├── 001_create_users.sql
│   │   ├── 002_create_sessions.sql
│   │   └── 003_create_rated_areas.sql
│   └── src/
│       ├── main.rs                  (server startup, router assembly)
│       ├── config.rs                (env/file config: DB URL, GH URL, routing params)
│       ├── db.rs                    (connection pool setup)
│       ├── auth.rs                  (register, login, logout, session middleware)
│       ├── ratings.rs               (GET overlay, PUT paint with clipping, undo support)
│       ├── routing.rs               (build GH custom model from user areas, proxy request)
│       ├── geocode.rs               (Photon proxy)
│       └── errors.rs                (unified error type -> HTTP responses)
├── frontend/
│   ├── package.json
│   ├── vite.config.js
│   ├── index.html
│   └── src/
│       ├── main.js                  (mount Svelte app)
│       ├── App.svelte               (top-level layout, auth state, map container)
│       ├── lib/
│       │   ├── api.js               (fetch wrappers for all backend endpoints)
│       │   ├── auth.js              (auth store, login/register/logout calls)
│       │   ├── map.js               (MapLibre instance, tile config, layer management)
│       │   ├── overlay.js           (rating overlay layer — loads/renders user polygons)
│       │   ├── brush.js             (paint brush: drag tracking, polygon buffering, undo stack)
│       │   └── routing.js           (origin/dest state, route request, route layer)
│       └── components/
│           ├── Map.svelte           (map container, initializes MapLibre)
│           ├── Toolbar.svelte       (color strip, brush size slider, undo/redo buttons)
│           ├── SearchBar.svelte     (geocoding autocomplete)
│           ├── AuthModal.svelte     (login/register form)
│           └── RoutePanel.svelte    (origin/dest display, route info)
├── server/
│   └── docker-compose.yml          (updated: add db + versatiles, keep graphhopper)
├── scripts/
│   ├── download_berlin_osm.sh      (existing)
│   └── download_berlin_tiles.sh    (new: download VersaTiles Berlin extract)
└── data/
    ├── osm/berlin/                  (existing)
    └── tiles/berlin.versatiles      (new: VersaTiles tile file)
```

---

### Task 1: Clean Up Old Code and Scaffold Backend

Remove `or-cli/` and `or-domain/` (if present). Create the Axum backend crate with a health check endpoint.

**Files:**
- Delete: `or-cli/` directory
- Create: `backend/Cargo.toml`
- Create: `backend/src/main.rs`
- Create: `backend/src/config.rs`
- Create: `backend/src/errors.rs`
- Create: `backend/Dockerfile`

- [ ] **Step 1: Remove old code**

```bash
rm -rf or-cli/
# Also remove or-domain/ if it exists
rm -rf or-domain/
```

- [ ] **Step 2: Create backend Cargo.toml**

Create `backend/Cargo.toml`:
```toml
[package]
name = "ortschaft-backend"
version = "0.1.0"
edition = "2021"

[dependencies]
axum = "0.8"
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
sqlx = { version = "0.8", features = ["runtime-tokio", "tls-rustls", "postgres", "uuid", "chrono"] }
uuid = { version = "1", features = ["v4", "serde"] }
chrono = { version = "0.4", features = ["serde"] }
tower-http = { version = "0.6", features = ["cors", "fs"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
argon2 = "0.5"
rand = "0.8"
reqwest = { version = "0.12", features = ["json"] }
geojson = "0.24"
geo = "0.29"
dotenvy = "0.15"
```

- [ ] **Step 3: Create config.rs**

Create `backend/src/config.rs`:
```rust
use std::env;

pub struct Config {
    pub database_url: String,
    pub graphhopper_url: String,
    pub photon_url: String,
    pub listen_addr: String,
    pub rating_weight: f64,
    pub distance_influence: f64,
    pub max_areas_per_request: usize,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL")
                .unwrap_or_else(|_| "postgres://ortschaft:ortschaft@localhost:5432/ortschaft".into()),
            graphhopper_url: env::var("GRAPHHOPPER_URL")
                .unwrap_or_else(|_| "http://localhost:8989".into()),
            photon_url: env::var("PHOTON_URL")
                .unwrap_or_else(|_| "https://photon.komoot.io".into()),
            listen_addr: env::var("LISTEN_ADDR")
                .unwrap_or_else(|_| "0.0.0.0:3000".into()),
            rating_weight: env::var("RATING_WEIGHT")
                .ok().and_then(|v| v.parse().ok()).unwrap_or(1.0),
            distance_influence: env::var("DISTANCE_INFLUENCE")
                .ok().and_then(|v| v.parse().ok()).unwrap_or(70.0),
            max_areas_per_request: env::var("MAX_AREAS_PER_REQUEST")
                .ok().and_then(|v| v.parse().ok()).unwrap_or(200),
        }
    }
}
```

- [ ] **Step 4: Create errors.rs**

Create `backend/src/errors.rs`:
```rust
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};

pub enum AppError {
    Internal(String),
    BadRequest(String),
    Unauthorized,
    NotFound,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, message) = match self {
            AppError::Internal(msg) => {
                tracing::error!("Internal error: {msg}");
                (StatusCode::INTERNAL_SERVER_ERROR, "internal error".to_string())
            }
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, msg),
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized".to_string()),
            AppError::NotFound => (StatusCode::NOT_FOUND, "not found".to_string()),
        };
        (status, serde_json::json!({ "error": message }).to_string()).into_response()
    }
}

impl From<sqlx::Error> for AppError {
    fn from(e: sqlx::Error) -> Self {
        AppError::Internal(e.to_string())
    }
}
```

- [ ] **Step 5: Create main.rs with health check**

Create `backend/src/main.rs`:
```rust
mod config;
mod errors;

use axum::{routing::get, Router};
use config::Config;
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;

pub struct AppState {
    pub db: sqlx::PgPool,
    pub config: Config,
    pub http_client: reqwest::Client,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "ortschaft_backend=debug,tower_http=debug".into()),
        )
        .init();

    dotenvy::dotenv().ok();
    let config = Config::from_env();

    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&config.database_url)
        .await
        .expect("Failed to connect to database");

    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .expect("Failed to run migrations");

    let state = Arc::new(AppState {
        db,
        config,
        http_client: reqwest::Client::new(),
    });

    let app = Router::new()
        .route("/api/health", get(|| async { "ok" }))
        .with_state(state);

    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000")
        .await
        .expect("Failed to bind");

    tracing::info!("Listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}
```

- [ ] **Step 6: Create empty migrations directory**

```bash
mkdir -p backend/migrations
touch backend/migrations/.keep
```

- [ ] **Step 7: Create Dockerfile**

Create `backend/Dockerfile`:
```dockerfile
FROM rust:1.82-bookworm AS builder
WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
COPY src ./src
COPY migrations ./migrations
ENV SQLX_OFFLINE=true
RUN cargo build --release

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /app/target/release/ortschaft-backend /usr/local/bin/
CMD ["ortschaft-backend"]
```

- [ ] **Step 8: Verify it compiles**

```bash
cd backend && cargo check
```

- [ ] **Step 9: Commit**

```bash
git add backend/ && git rm -rf or-cli/
git commit -m "Scaffold Axum backend with health check, remove old or-cli"
```

---

### Task 2: Docker Compose — PostgreSQL + VersaTiles

Update docker-compose.yml to add PostgreSQL with PostGIS and replace the tile stub with VersaTiles. Create the tile download script.

**Files:**
- Modify: `server/docker-compose.yml`
- Create: `scripts/download_berlin_tiles.sh`
- Delete: `server/tiles/` directory (stub no longer needed)

- [ ] **Step 1: Create tile download script**

Create `scripts/download_berlin_tiles.sh`:
```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="download_berlin_tiles"
LOG_PREFIX="[${SCRIPT_NAME}]"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${ROOT_DIR}/data/tiles"
OUTPUT_PATH="${OUTPUT_DIR}/berlin.versatiles"
FORCE=0

log() { echo "${LOG_PREFIX} $*"; }
error() { echo "${LOG_PREFIX} ERROR: $*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    --help|-h)
      echo "Usage: ./scripts/download_berlin_tiles.sh [--force]"
      echo "Downloads Berlin vector tiles in VersaTiles format."
      exit 0 ;;
    *) error "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

if [[ -s "${OUTPUT_PATH}" && "${FORCE}" -ne 1 ]]; then
  log "Tiles already exist at ${OUTPUT_PATH}; skipping. Use --force to re-download."
  exit 0
fi

mkdir -p "${OUTPUT_DIR}"

if ! command -v versatiles >/dev/null 2>&1; then
  log "versatiles CLI not found. Using Docker to extract Berlin tiles..."
  docker run --rm -v "${OUTPUT_DIR}:/output" versatiles/versatiles:latest \
    versatiles convert \
    --bbox "13.0,52.3,13.8,52.7" \
    "https://download.versatiles.org/osm.versatiles" \
    "/output/berlin.versatiles"
else
  versatiles convert \
    --bbox "13.0,52.3,13.8,52.7" \
    "https://download.versatiles.org/osm.versatiles" \
    "${OUTPUT_PATH}"
fi

log "Berlin tiles ready at ${OUTPUT_PATH}"
```

```bash
chmod +x scripts/download_berlin_tiles.sh
```

- [ ] **Step 2: Update docker-compose.yml**

Replace `server/docker-compose.yml` entirely:
```yaml
services:
  db:
    image: postgis/postgis:16-3.4
    container_name: ortschaft-db
    environment:
      POSTGRES_DB: ortschaft
      POSTGRES_USER: ortschaft
      POSTGRES_PASSWORD: ortschaft
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data
    restart: unless-stopped

  graphhopper:
    image: israelhikingmap/graphhopper:latest
    container_name: ortschaft-graphhopper
    entrypoint:
      - "./graphhopper.sh"
      - "-c"
      - "/config/config.yml"
      - "-o"
      - "/data/graphhopper-cache"
    ports:
      - "8989:8989"
    volumes:
      - ./graphhopper/config.yml:/config/config.yml:ro
      - ../data/osm/berlin/berlin.osm.pbf:/data/berlin.osm.pbf:ro
      - ../data/osm/berlin/graphhopper:/data/graphhopper-cache
    environment:
      JAVA_OPTS: "-Xmx2g -Xms512m"
    restart: unless-stopped

  tiles:
    image: versatiles/versatiles:latest
    container_name: ortschaft-tiles
    ports:
      - "8080:8080"
    volumes:
      - ../data/tiles/berlin.versatiles:/data/berlin.versatiles:ro
    command: ["versatiles", "serve", "--port", "8080", "--host", "0.0.0.0", "/data/berlin.versatiles"]
    restart: unless-stopped

  backend:
    build: ../backend
    container_name: ortschaft-backend
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://ortschaft:ortschaft@db:5432/ortschaft
      GRAPHHOPPER_URL: http://graphhopper:8989
      PHOTON_URL: https://photon.komoot.io
    depends_on:
      - db
      - graphhopper
    restart: unless-stopped

volumes:
  pgdata:
```

- [ ] **Step 3: Remove old tile stub**

```bash
rm -rf server/tiles/
```

- [ ] **Step 4: Verify compose file parses**

```bash
cd server && docker compose config --quiet
```

- [ ] **Step 5: Commit**

```bash
git add server/docker-compose.yml scripts/download_berlin_tiles.sh
git rm -rf server/tiles/
git commit -m "Add PostgreSQL and VersaTiles to docker-compose, remove tile stub"
```

---

### Task 3: Database Migrations

Create the PostgreSQL schema: users, sessions, rated_areas.

**Files:**
- Create: `backend/migrations/001_create_users.sql`
- Create: `backend/migrations/002_create_sessions.sql`
- Create: `backend/migrations/003_create_rated_areas.sql`

- [ ] **Step 1: Create users migration**

Create `backend/migrations/001_create_users.sql`:
```sql
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_users_email ON users (email);
```

- [ ] **Step 2: Create sessions migration**

Create `backend/migrations/002_create_sessions.sql`:
```sql
CREATE TABLE sessions (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expires_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX idx_sessions_user_id ON sessions (user_id);
CREATE INDEX idx_sessions_expires_at ON sessions (expires_at);
```

- [ ] **Step 3: Create rated_areas migration**

Create `backend/migrations/003_create_rated_areas.sql`:
```sql
CREATE EXTENSION IF NOT EXISTS "postgis";

CREATE TABLE rated_areas (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    geometry GEOMETRY(Polygon, 4326) NOT NULL,
    value SMALLINT NOT NULL CHECK (value IN (-7, -3, -1, 1, 3, 7)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rated_areas_user_id ON rated_areas (user_id);
CREATE INDEX idx_rated_areas_geometry ON rated_areas USING GIST (geometry);
```

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/
git commit -m "Add database migrations: users, sessions, rated_areas"
```

---

### Task 4: Auth — Registration, Login, Logout

Implement cookie-based session auth.

**Files:**
- Create: `backend/src/auth.rs`
- Modify: `backend/src/main.rs` (add auth routes)

- [ ] **Step 1: Create auth.rs**

Create `backend/src/auth.rs`:
```rust
use crate::errors::AppError;
use crate::AppState;
use argon2::{password_hash::SaltString, Argon2, PasswordHash, PasswordHasher, PasswordVerifier};
use axum::{
    extract::State,
    http::{header::SET_COOKIE, HeaderMap, StatusCode},
    response::IntoResponse,
    Json,
};
use rand::rngs::OsRng;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use uuid::Uuid;

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub display_name: Option<String>,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: String,
    pub display_name: String,
}

pub async fn register(
    State(state): State<Arc<AppState>>,
    Json(req): Json<RegisterRequest>,
) -> Result<impl IntoResponse, AppError> {
    if req.email.is_empty() || req.password.len() < 8 {
        return Err(AppError::BadRequest("Email required, password min 8 chars".into()));
    }

    let salt = SaltString::generate(&mut OsRng);
    let hash = Argon2::default()
        .hash_password(req.password.as_bytes(), &salt)
        .map_err(|e| AppError::Internal(e.to_string()))?
        .to_string();

    let display_name = req.display_name.unwrap_or_default();

    let user = sqlx::query_as!(
        UserRow,
        "INSERT INTO users (email, password_hash, display_name) VALUES ($1, $2, $3) RETURNING id, email, display_name",
        req.email,
        hash,
        display_name,
    )
    .fetch_one(&state.db)
    .await
    .map_err(|e| match e {
        sqlx::Error::Database(ref db_err) if db_err.is_unique_violation() => {
            AppError::BadRequest("Email already registered".into())
        }
        _ => AppError::from(e),
    })?;

    let session_id = create_session(&state.db, user.id).await?;
    let mut headers = HeaderMap::new();
    headers.insert(SET_COOKIE, session_cookie(&session_id).parse().unwrap());

    Ok((StatusCode::CREATED, headers, Json(UserResponse {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
    })))
}

pub async fn login(
    State(state): State<Arc<AppState>>,
    Json(req): Json<LoginRequest>,
) -> Result<impl IntoResponse, AppError> {
    let user = sqlx::query_as!(
        UserRowWithPassword,
        "SELECT id, email, display_name, password_hash FROM users WHERE email = $1",
        req.email,
    )
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::Unauthorized)?;

    let parsed_hash = PasswordHash::new(&user.password_hash)
        .map_err(|e| AppError::Internal(e.to_string()))?;
    Argon2::default()
        .verify_password(req.password.as_bytes(), &parsed_hash)
        .map_err(|_| AppError::Unauthorized)?;

    let session_id = create_session(&state.db, user.id).await?;
    let mut headers = HeaderMap::new();
    headers.insert(SET_COOKIE, session_cookie(&session_id).parse().unwrap());

    Ok((headers, Json(UserResponse {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
    })))
}

pub async fn logout(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<impl IntoResponse, AppError> {
    if let Some(session_id) = extract_session_id(&headers) {
        sqlx::query!("DELETE FROM sessions WHERE id = $1", session_id)
            .execute(&state.db)
            .await?;
    }
    let mut resp_headers = HeaderMap::new();
    resp_headers.insert(
        SET_COOKIE,
        "session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0".parse().unwrap(),
    );
    Ok((resp_headers, StatusCode::OK))
}

pub async fn me(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<UserResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let user = sqlx::query_as!(
        UserRow,
        "SELECT id, email, display_name FROM users WHERE id = $1",
        user_id,
    )
    .fetch_one(&state.db)
    .await?;
    Ok(Json(UserResponse {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
    }))
}

// --- helpers ---

struct UserRow {
    id: Uuid,
    email: String,
    display_name: String,
}

struct UserRowWithPassword {
    id: Uuid,
    email: String,
    display_name: String,
    password_hash: String,
}

async fn create_session(db: &sqlx::PgPool, user_id: Uuid) -> Result<String, AppError> {
    let session_id = Uuid::new_v4().to_string();
    sqlx::query!(
        "INSERT INTO sessions (id, user_id, expires_at) VALUES ($1, $2, now() + interval '30 days')",
        session_id,
        user_id,
    )
    .execute(db)
    .await?;
    Ok(session_id)
}

fn session_cookie(session_id: &str) -> String {
    format!("session={session_id}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000")
}

fn extract_session_id(headers: &HeaderMap) -> Option<String> {
    let cookie = headers.get("cookie")?.to_str().ok()?;
    cookie
        .split(';')
        .find_map(|c| {
            let c = c.trim();
            c.strip_prefix("session=").map(|v| v.to_string())
        })
}

pub async fn require_auth(db: &sqlx::PgPool, headers: &HeaderMap) -> Result<Uuid, AppError> {
    let session_id = extract_session_id(headers).ok_or(AppError::Unauthorized)?;
    let row = sqlx::query!(
        "SELECT user_id FROM sessions WHERE id = $1 AND expires_at > now()",
        session_id,
    )
    .fetch_optional(db)
    .await?
    .ok_or(AppError::Unauthorized)?;
    Ok(row.user_id)
}
```

- [ ] **Step 2: Wire auth routes into main.rs**

Add to `backend/src/main.rs`:
```rust
mod auth;
// ... existing mods ...

// In the router:
let app = Router::new()
    .route("/api/health", get(|| async { "ok" }))
    .route("/api/auth/register", post(auth::register))
    .route("/api/auth/login", post(auth::login))
    .route("/api/auth/logout", post(auth::logout))
    .route("/api/auth/me", get(auth::me))
    .with_state(state);
```

Add `use axum::routing::post;` to imports.

- [ ] **Step 3: Verify it compiles**

```bash
cd backend && cargo check
```

- [ ] **Step 4: Commit**

```bash
git add backend/src/
git commit -m "Add auth: registration, login, logout, session middleware"
```

---

### Task 5: Ratings API — Paint with Polygon Clipping

The core feature: accept painted polygons, clip overlapping existing polygons, return overlay GeoJSON.

**Files:**
- Create: `backend/src/ratings.rs`
- Modify: `backend/src/main.rs` (add ratings routes)

- [ ] **Step 1: Create ratings.rs**

Create `backend/src/ratings.rs`:
```rust
use crate::auth::require_auth;
use crate::errors::AppError;
use crate::AppState;
use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Deserialize)]
pub struct PaintRequest {
    pub geometry: serde_json::Value, // GeoJSON Polygon
    pub value: i16,
}

#[derive(Deserialize)]
pub struct OverlayQuery {
    pub bbox: String, // "west,south,east,north"
}

#[derive(Serialize)]
pub struct PaintResponse {
    pub created_id: Option<i64>,
    pub clipped_count: i64,
    pub deleted_count: i64,
}

pub async fn paint(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<PaintRequest>,
) -> Result<Json<PaintResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;

    let allowed = [-7i16, -3, -1, 0, 1, 3, 7];
    if !allowed.contains(&req.value) {
        return Err(AppError::BadRequest("Invalid rating value".into()));
    }

    let geojson_str = serde_json::to_string(&req.geometry)
        .map_err(|e| AppError::BadRequest(e.to_string()))?;

    // Use a transaction for atomicity
    let mut tx = state.db.begin().await?;

    // 1. Delete existing polygons fully contained by the new one
    let deleted = sqlx::query_scalar!(
        r#"
        WITH deleted AS (
            DELETE FROM rated_areas
            WHERE user_id = $1
              AND ST_Contains(ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), geometry)
            RETURNING id
        )
        SELECT count(*) as "count!" FROM deleted
        "#,
        user_id,
        geojson_str,
    )
    .fetch_one(&mut *tx)
    .await?;

    // 2. Clip partially overlapping polygons
    let clipped = sqlx::query_scalar!(
        r#"
        WITH updated AS (
            UPDATE rated_areas
            SET geometry = ST_Multi(ST_Difference(geometry, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326)))::geometry(Polygon, 4326),
                updated_at = now()
            WHERE user_id = $1
              AND ST_Intersects(geometry, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326))
              AND NOT ST_Contains(ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), geometry)
              AND NOT ST_IsEmpty(ST_Difference(geometry, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326)))
            RETURNING id
        )
        SELECT count(*) as "count!" FROM updated
        "#,
        user_id,
        geojson_str,
    )
    .fetch_one(&mut *tx)
    .await?;

    // 3. Clean up any polygons that became empty after clipping
    sqlx::query!(
        "DELETE FROM rated_areas WHERE user_id = $1 AND ST_IsEmpty(geometry)",
        user_id,
    )
    .execute(&mut *tx)
    .await?;

    // 4. Insert the new polygon (unless value is 0 = eraser)
    let created_id = if req.value != 0 {
        let row = sqlx::query_scalar!(
            r#"
            INSERT INTO rated_areas (user_id, geometry, value)
            VALUES ($1, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), $3)
            RETURNING id
            "#,
            user_id,
            geojson_str,
            req.value,
        )
        .fetch_one(&mut *tx)
        .await?;
        Some(row)
    } else {
        None
    };

    tx.commit().await?;

    Ok(Json(PaintResponse {
        created_id,
        clipped_count: clipped,
        deleted_count: deleted,
    }))
}

pub async fn get_overlay(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Query(query): Query<OverlayQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;

    let parts: Vec<f64> = query.bbox.split(',')
        .map(|s| s.parse::<f64>().map_err(|_| AppError::BadRequest("Invalid bbox".into())))
        .collect::<Result<Vec<_>, _>>()?;
    if parts.len() != 4 {
        return Err(AppError::BadRequest("bbox must be west,south,east,north".into()));
    }
    let (west, south, east, north) = (parts[0], parts[1], parts[2], parts[3]);

    let rows = sqlx::query!(
        r#"
        SELECT id, ST_AsGeoJSON(geometry) as "geometry!", value
        FROM rated_areas
        WHERE user_id = $1
          AND ST_Intersects(geometry, ST_MakeEnvelope($2, $3, $4, $5, 4326))
        "#,
        user_id,
        west, south, east, north,
    )
    .fetch_all(&state.db)
    .await?;

    let features: Vec<serde_json::Value> = rows.iter().map(|r| {
        serde_json::json!({
            "type": "Feature",
            "id": r.id,
            "properties": { "value": r.value },
            "geometry": serde_json::from_str::<serde_json::Value>(&r.geometry).unwrap()
        })
    }).collect();

    Ok(Json(serde_json::json!({
        "type": "FeatureCollection",
        "features": features
    })))
}
```

- [ ] **Step 2: Wire ratings routes into main.rs**

Add to router in `backend/src/main.rs`:
```rust
mod ratings;

// In the router:
.route("/api/ratings", get(ratings::get_overlay))
.route("/api/ratings/paint", put(ratings::paint))
```

Add `use axum::routing::put;` to imports.

- [ ] **Step 3: Verify it compiles**

```bash
cd backend && cargo check
```

Note: The ST_Multi/Polygon cast in the clipping query may need adjustment — ST_Difference can produce MultiPolygon results. We may need to handle this by splitting MultiPolygons into individual rows or changing the column type. This will be validated during integration testing.

- [ ] **Step 4: Commit**

```bash
git add backend/src/
git commit -m "Add ratings API: paint with polygon clipping, overlay endpoint"
```

---

### Task 6: Routing — GraphHopper Custom Model with User Areas

Accept origin/destination, load user's rated areas, build Custom Model request, proxy to GraphHopper.

**Files:**
- Create: `backend/src/routing.rs`
- Modify: `backend/src/main.rs` (add route endpoint)

- [ ] **Step 1: Create routing.rs**

Create `backend/src/routing.rs`:
```rust
use crate::auth::require_auth;
use crate::errors::AppError;
use crate::AppState;
use axum::{extract::State, http::HeaderMap, Json};
use serde::{Deserialize, Serialize};
use std::sync::Arc;

#[derive(Deserialize)]
pub struct RouteRequest {
    pub origin: [f64; 2],      // [lng, lat]
    pub destination: [f64; 2], // [lng, lat]
}

#[derive(Serialize)]
pub struct RouteResponse {
    pub geometry: serde_json::Value,
    pub distance: f64,
    pub time: f64,
}

pub async fn get_route(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(req): Json<RouteRequest>,
) -> Result<Json<RouteResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;

    // Build bounding box around origin and destination with margin
    let margin = 0.02; // ~2km
    let west = req.origin[0].min(req.destination[0]) - margin;
    let south = req.origin[1].min(req.destination[1]) - margin;
    let east = req.origin[0].max(req.destination[0]) + margin;
    let north = req.origin[1].max(req.destination[1]) + margin;

    // Load user's rated areas in the corridor
    let areas = sqlx::query!(
        r#"
        SELECT id, ST_AsGeoJSON(geometry) as "geometry!", value
        FROM rated_areas
        WHERE user_id = $1
          AND ST_Intersects(geometry, ST_MakeEnvelope($2, $3, $4, $5, 4326))
        ORDER BY id
        LIMIT $6
        "#,
        user_id,
        west, south, east, north,
        state.config.max_areas_per_request as i64,
    )
    .fetch_all(&state.db)
    .await?;

    // Build Custom Model
    let mut features = Vec::new();
    let mut priority_statements = Vec::new();

    for area in &areas {
        let area_id = format!("area_{}", area.id);
        let geom: serde_json::Value = serde_json::from_str(&area.geometry)
            .map_err(|e| AppError::Internal(e.to_string()))?;

        features.push(serde_json::json!({
            "type": "Feature",
            "id": area_id,
            "properties": {},
            "geometry": geom,
        }));

        let multiplier = rating_to_priority(area.value, state.config.rating_weight);
        priority_statements.push(serde_json::json!({
            "if": format!("in_{area_id}"),
            "multiply_by": format!("{multiplier:.2}"),
        }));
    }

    let mut gh_request = serde_json::json!({
        "points": [
            [req.origin[0], req.origin[1]],
            [req.destination[0], req.destination[1]],
        ],
        "profile": "bike",
        "locale": "de",
        "points_encoded": false,
    });

    // Only add custom_model if user has rated areas in the corridor
    if !features.is_empty() {
        gh_request["ch.disable"] = serde_json::json!(true);
        gh_request["custom_model"] = serde_json::json!({
            "priority": priority_statements,
            "distance_influence": state.config.distance_influence,
            "areas": {
                "type": "FeatureCollection",
                "features": features,
            },
        });
    }

    // Call GraphHopper
    let gh_url = format!("{}/route", state.config.graphhopper_url);
    let gh_resp = state
        .http_client
        .post(&gh_url)
        .json(&gh_request)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("GraphHopper request failed: {e}")))?;

    if !gh_resp.status().is_success() {
        let body = gh_resp.text().await.unwrap_or_default();
        return Err(AppError::Internal(format!("GraphHopper error: {body}")));
    }

    let gh_body: serde_json::Value = gh_resp
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("GraphHopper parse error: {e}")))?;

    let path = gh_body["paths"]
        .get(0)
        .ok_or_else(|| AppError::Internal("No path in GraphHopper response".into()))?;

    Ok(Json(RouteResponse {
        geometry: path["points"].clone(),
        distance: path["distance"].as_f64().unwrap_or(0.0),
        time: path["time"].as_f64().unwrap_or(0.0),
    }))
}

fn rating_to_priority(value: i16, weight: f64) -> f64 {
    let base = match value {
        -7 => 0.05,
        -3 => 0.3,
        -1 => 0.7,
        1 => 1.3,
        3 => 2.0,
        7 => 3.0,
        _ => 1.0,
    };
    // Apply weight: lerp between 1.0 (no effect) and base (full effect)
    1.0 + (base - 1.0) * weight
}
```

- [ ] **Step 2: Wire routing into main.rs**

Add to router:
```rust
mod routing;

.route("/api/route", post(routing::get_route))
```

- [ ] **Step 3: Verify it compiles**

```bash
cd backend && cargo check
```

- [ ] **Step 4: Commit**

```bash
git add backend/src/
git commit -m "Add personalized routing via GraphHopper Custom Model with user areas"
```

---

### Task 7: Geocoding Proxy

Proxy Photon geocoding requests to avoid CORS and control User-Agent.

**Files:**
- Create: `backend/src/geocode.rs`
- Modify: `backend/src/main.rs`

- [ ] **Step 1: Create geocode.rs**

Create `backend/src/geocode.rs`:
```rust
use crate::errors::AppError;
use crate::AppState;
use axum::{extract::{Query, State}, Json};
use serde::Deserialize;
use std::sync::Arc;

#[derive(Deserialize)]
pub struct GeocodeQuery {
    pub q: String,
    pub limit: Option<u32>,
}

pub async fn geocode(
    State(state): State<Arc<AppState>>,
    Query(query): Query<GeocodeQuery>,
) -> Result<Json<serde_json::Value>, AppError> {
    let limit = query.limit.unwrap_or(5).min(10);
    let url = format!(
        "{}/api?q={}&limit={}&lat=52.52&lon=13.405&bbox=13.0,52.3,13.8,52.7",
        state.config.photon_url,
        urlencoding::encode(&query.q),
        limit,
    );

    let resp = state
        .http_client
        .get(&url)
        .header("User-Agent", "Ortschaft/0.1 (bicycle routing app)")
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Photon request failed: {e}")))?;

    let body: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("Photon parse error: {e}")))?;

    Ok(Json(body))
}
```

- [ ] **Step 2: Add urlencoding dependency**

Add to `backend/Cargo.toml` under `[dependencies]`:
```toml
urlencoding = "2"
```

- [ ] **Step 3: Wire geocode into main.rs**

```rust
mod geocode;

.route("/api/geocode", get(geocode::geocode))
```

- [ ] **Step 4: Verify and commit**

```bash
cd backend && cargo check
git add backend/
git commit -m "Add geocoding proxy for Photon"
```

---

### Task 8: Static File Serving

Serve the built frontend assets from the backend.

**Files:**
- Modify: `backend/src/main.rs`

- [ ] **Step 1: Add static file serving to main.rs**

Add after the API routes:
```rust
use tower_http::services::ServeDir;

let app = Router::new()
    // ... API routes ...
    .fallback_service(ServeDir::new("../frontend/dist").append_index_html_on_directories(true))
    .with_state(state);
```

- [ ] **Step 2: Commit**

```bash
git add backend/src/main.rs
git commit -m "Serve frontend static assets from backend"
```

---

### Task 9: Scaffold Frontend — Svelte + Vite + MapLibre

Create the frontend project with a map that loads VersaTiles.

**Files:**
- Create: `frontend/package.json`
- Create: `frontend/vite.config.js`
- Create: `frontend/index.html`
- Create: `frontend/src/main.js`
- Create: `frontend/src/App.svelte`
- Create: `frontend/src/lib/map.js`
- Create: `frontend/src/components/Map.svelte`

- [ ] **Step 1: Initialize frontend**

```bash
cd frontend
npm create vite@latest . -- --template svelte
npm install
npm install maplibre-gl
```

If Vite scaffolding prompts to overwrite, accept. Then clean out the generated boilerplate (default App.svelte, assets, etc.).

- [ ] **Step 2: Create vite.config.js**

Replace `frontend/vite.config.js`:
```js
import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:3000',
    },
  },
});
```

- [ ] **Step 3: Create index.html**

Replace `frontend/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Ortschaft</title>
  <link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4/dist/maplibre-gl.css" />
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body, #app { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
```

- [ ] **Step 4: Create main.js**

Create `frontend/src/main.js`:
```js
import App from './App.svelte';

const app = new App({ target: document.getElementById('app') });

export default app;
```

- [ ] **Step 5: Create lib/api.js**

Create `frontend/src/lib/api.js`:
```js
async function request(method, path, body) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
    credentials: 'same-origin',
  };
  if (body) opts.body = JSON.stringify(body);
  const resp = await fetch(path, opts);
  if (!resp.ok) {
    const err = await resp.json().catch(() => ({ error: resp.statusText }));
    throw new Error(err.error || resp.statusText);
  }
  return resp.json();
}

export const api = {
  register: (email, password, display_name) =>
    request('POST', '/api/auth/register', { email, password, display_name }),
  login: (email, password) =>
    request('POST', '/api/auth/login', { email, password }),
  logout: () => request('POST', '/api/auth/logout'),
  me: () => request('GET', '/api/auth/me'),
  getOverlay: (bbox) => request('GET', `/api/ratings?bbox=${bbox}`),
  paint: (geometry, value) => request('PUT', '/api/ratings/paint', { geometry, value }),
  route: (origin, destination) =>
    request('POST', '/api/route', { origin, destination }),
  geocode: (q) => request('GET', `/api/geocode?q=${encodeURIComponent(q)}`),
};
```

- [ ] **Step 6: Create lib/map.js**

Create `frontend/src/lib/map.js`:
```js
import maplibregl from 'maplibre-gl';

const TILES_URL = 'http://localhost:8080';

export function createMap(container) {
  const map = new maplibregl.Map({
    container,
    // VersaTiles serves a style.json at the root
    style: `${TILES_URL}/tiles/osm/style.json`,
    center: [13.405, 52.52], // Berlin center
    zoom: 12,
    maxBounds: [[12.9, 52.2], [13.9, 52.8]], // Berlin bounds
  });

  map.addControl(new maplibregl.NavigationControl(), 'top-right');

  return map;
}
```

- [ ] **Step 7: Create Map.svelte component**

Create `frontend/src/components/Map.svelte`:
```svelte
<script>
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import { createMap } from '../lib/map.js';

  const dispatch = createEventDispatcher();
  let container;
  let map;

  export function getMap() {
    return map;
  }

  onMount(() => {
    map = createMap(container);
    map.on('load', () => dispatch('load', map));
  });

  onDestroy(() => {
    if (map) map.remove();
  });
</script>

<div bind:this={container} class="map-container"></div>

<style>
  .map-container {
    width: 100%;
    height: 100%;
    position: absolute;
    top: 0;
    left: 0;
  }
</style>
```

- [ ] **Step 8: Create App.svelte**

Create `frontend/src/App.svelte`:
```svelte
<script>
  import Map from './components/Map.svelte';
  import { api } from './lib/api.js';

  let map;
  let user = null;

  // Check if already logged in
  api.me().then(u => user = u).catch(() => {});

  function handleMapLoad(e) {
    map = e.detail;
  }
</script>

<Map on:load={handleMapLoad} />

{#if !user}
  <div class="auth-prompt">
    <p>Log in to start painting your map</p>
  </div>
{/if}

<style>
  .auth-prompt {
    position: absolute;
    top: 16px;
    left: 50%;
    transform: translateX(-50%);
    background: white;
    padding: 12px 24px;
    border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    z-index: 10;
  }
</style>
```

- [ ] **Step 9: Test dev server starts**

```bash
cd frontend && npm run dev
```

Verify the map loads at `http://localhost:5173` (tiles service must be running).

- [ ] **Step 10: Commit**

```bash
git add frontend/
git commit -m "Scaffold Svelte frontend with MapLibre + VersaTiles"
```

---

### Task 10: Auth UI

Login and register modal.

**Files:**
- Create: `frontend/src/components/AuthModal.svelte`
- Create: `frontend/src/lib/auth.js`
- Modify: `frontend/src/App.svelte`

- [ ] **Step 1: Create auth store**

Create `frontend/src/lib/auth.js`:
```js
import { writable } from 'svelte/store';
import { api } from './api.js';

export const user = writable(null);

export async function checkSession() {
  try {
    const u = await api.me();
    user.set(u);
  } catch {
    user.set(null);
  }
}

export async function login(email, password) {
  const u = await api.login(email, password);
  user.set(u);
}

export async function register(email, password, displayName) {
  const u = await api.register(email, password, displayName);
  user.set(u);
}

export async function logout() {
  await api.logout();
  user.set(null);
}
```

- [ ] **Step 2: Create AuthModal.svelte**

Create `frontend/src/components/AuthModal.svelte`:
```svelte
<script>
  import { login, register } from '../lib/auth.js';

  let mode = 'login'; // 'login' | 'register'
  let email = '';
  let password = '';
  let displayName = '';
  let error = '';
  let loading = false;

  async function handleSubmit() {
    error = '';
    loading = true;
    try {
      if (mode === 'login') {
        await login(email, password);
      } else {
        await register(email, password, displayName);
      }
    } catch (e) {
      error = e.message;
    } finally {
      loading = false;
    }
  }
</script>

<div class="overlay">
  <div class="modal">
    <h2>{mode === 'login' ? 'Log In' : 'Sign Up'}</h2>

    <form on:submit|preventDefault={handleSubmit}>
      {#if mode === 'register'}
        <input type="text" placeholder="Display name" bind:value={displayName} />
      {/if}
      <input type="email" placeholder="Email" bind:value={email} required />
      <input type="password" placeholder="Password (min 8 chars)" bind:value={password} required minlength="8" />

      {#if error}<p class="error">{error}</p>{/if}

      <button type="submit" disabled={loading}>
        {loading ? '...' : (mode === 'login' ? 'Log In' : 'Sign Up')}
      </button>
    </form>

    <p class="switch">
      {#if mode === 'login'}
        No account? <button class="link" on:click={() => mode = 'register'}>Sign up</button>
      {:else}
        Have an account? <button class="link" on:click={() => mode = 'login'}>Log in</button>
      {/if}
    </p>
  </div>
</div>

<style>
  .overlay {
    position: fixed; top: 0; left: 0; right: 0; bottom: 0;
    background: rgba(0,0,0,0.4); display: flex; align-items: center; justify-content: center;
    z-index: 100;
  }
  .modal {
    background: white; padding: 32px; border-radius: 12px; min-width: 320px;
    box-shadow: 0 4px 24px rgba(0,0,0,0.2);
  }
  h2 { margin-bottom: 16px; }
  form { display: flex; flex-direction: column; gap: 12px; }
  input {
    padding: 10px 12px; border: 1px solid #ccc; border-radius: 6px; font-size: 14px;
  }
  button[type="submit"] {
    padding: 10px; background: #2563eb; color: white; border: none;
    border-radius: 6px; cursor: pointer; font-size: 14px;
  }
  button[type="submit"]:disabled { opacity: 0.5; }
  .error { color: #dc2626; font-size: 13px; margin: 0; }
  .switch { margin-top: 12px; font-size: 13px; text-align: center; }
  .link { background: none; border: none; color: #2563eb; cursor: pointer; text-decoration: underline; }
</style>
```

- [ ] **Step 3: Update App.svelte to use auth store and modal**

Replace `frontend/src/App.svelte`:
```svelte
<script>
  import { onMount } from 'svelte';
  import Map from './components/Map.svelte';
  import AuthModal from './components/AuthModal.svelte';
  import { user, checkSession, logout } from './lib/auth.js';

  let map;

  onMount(() => checkSession());

  function handleMapLoad(e) {
    map = e.detail;
  }
</script>

<Map on:load={handleMapLoad} />

{#if $user}
  <div class="user-bar">
    <span>{$user.display_name || $user.email}</span>
    <button on:click={logout}>Log out</button>
  </div>
{:else}
  <AuthModal />
{/if}

<style>
  .user-bar {
    position: absolute; top: 12px; right: 60px;
    background: white; padding: 8px 16px; border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 10;
    display: flex; gap: 12px; align-items: center; font-size: 14px;
  }
  .user-bar button {
    background: none; border: none; color: #2563eb; cursor: pointer;
  }
</style>
```

- [ ] **Step 4: Commit**

```bash
git add frontend/src/
git commit -m "Add auth UI: login/register modal, user session store"
```

---

### Task 11: Rating Overlay Layer

Display the user's rated polygons on the map, colored by value.

**Files:**
- Create: `frontend/src/lib/overlay.js`
- Modify: `frontend/src/App.svelte`

- [ ] **Step 1: Create overlay.js**

Create `frontend/src/lib/overlay.js`:
```js
import { api } from './api.js';

const COLORS = {
  '-7': '#991b1b', // dark red
  '-3': '#dc2626', // intense red
  '-1': '#fca5a5', // light red
  '1':  '#86efac', // light green
  '3':  '#22c55e', // intense green
  '7':  '#059669', // emerald green
};

let loaded = false;

export function initOverlay(map) {
  map.addSource('ratings', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  });

  map.addLayer({
    id: 'ratings-fill',
    type: 'fill',
    source: 'ratings',
    paint: {
      'fill-color': [
        'match', ['get', 'value'],
        -7, COLORS['-7'],
        -3, COLORS['-3'],
        -1, COLORS['-1'],
        1,  COLORS['1'],
        3,  COLORS['3'],
        7,  COLORS['7'],
        '#6b7280', // fallback gray
      ],
      'fill-opacity': 0.4,
    },
  });

  map.addLayer({
    id: 'ratings-outline',
    type: 'line',
    source: 'ratings',
    paint: {
      'line-color': [
        'match', ['get', 'value'],
        -7, COLORS['-7'],
        -3, COLORS['-3'],
        -1, COLORS['-1'],
        1,  COLORS['1'],
        3,  COLORS['3'],
        7,  COLORS['7'],
        '#6b7280',
      ],
      'line-width': 1,
      'line-opacity': 0.7,
    },
  });

  loaded = true;

  // Refresh on viewport change
  map.on('moveend', () => refreshOverlay(map));
  refreshOverlay(map);
}

export async function refreshOverlay(map) {
  if (!loaded) return;
  const bounds = map.getBounds();
  const bbox = `${bounds.getWest()},${bounds.getSouth()},${bounds.getEast()},${bounds.getNorth()}`;
  try {
    const data = await api.getOverlay(bbox);
    map.getSource('ratings').setData(data);
  } catch (e) {
    console.error('Failed to load overlay:', e);
  }
}

export function updateOverlayLocal(map, geojson) {
  // Optimistic local update — merge new feature into existing source
  if (!loaded) return;
  const source = map.getSource('ratings');
  const current = source._data || { type: 'FeatureCollection', features: [] };
  current.features.push(...(geojson.features || []));
  source.setData(current);
}
```

- [ ] **Step 2: Wire overlay into App.svelte**

Update the `handleMapLoad` function in `App.svelte`:
```js
import { initOverlay } from './lib/overlay.js';

function handleMapLoad(e) {
  map = e.detail;
  if ($user) initOverlay(map);
}

// Also reinitialize when user logs in
$: if (map && $user) initOverlay(map);
```

- [ ] **Step 3: Commit**

```bash
git add frontend/src/
git commit -m "Add rating overlay: colored polygons on map per user ratings"
```

---

### Task 12: Paint Brush with Undo/Redo

The main interaction: drag to paint polygons, with undo/redo support.

**Files:**
- Create: `frontend/src/lib/brush.js`
- Create: `frontend/src/components/Toolbar.svelte`
- Modify: `frontend/src/App.svelte`

- [ ] **Step 1: Install Turf.js for geometry operations**

```bash
cd frontend && npm install @turf/buffer @turf/helpers
```

- [ ] **Step 2: Create brush.js**

Create `frontend/src/lib/brush.js`:
```js
import { writable } from 'svelte/store';
import buffer from '@turf/buffer';
import { lineString } from '@turf/helpers';
import { api } from './api.js';
import { refreshOverlay } from './overlay.js';

export const brushValue = writable(1);
export const brushSize = writable(30); // pixels
export const canUndo = writable(false);
export const canRedo = writable(false);

const undoStack = [];
const redoStack = [];
let painting = false;
let points = [];
let currentMap = null;
let previewSourceAdded = false;

export function initBrush(map) {
  currentMap = map;

  // Preview layer for active brush stroke
  map.addSource('brush-preview', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  });
  map.addLayer({
    id: 'brush-preview-fill',
    type: 'fill',
    source: 'brush-preview',
    paint: { 'fill-color': '#60a5fa', 'fill-opacity': 0.3 },
  });
  previewSourceAdded = true;

  map.getCanvas().addEventListener('mousedown', onMouseDown);
  map.getCanvas().addEventListener('mousemove', onMouseMove);
  map.getCanvas().addEventListener('mouseup', onMouseUp);

  // Keyboard shortcuts
  document.addEventListener('keydown', onKeyDown);
}

export function destroyBrush() {
  if (currentMap) {
    currentMap.getCanvas().removeEventListener('mousedown', onMouseDown);
    currentMap.getCanvas().removeEventListener('mousemove', onMouseMove);
    currentMap.getCanvas().removeEventListener('mouseup', onMouseUp);
  }
  document.removeEventListener('keydown', onKeyDown);
}

function onMouseDown(e) {
  if (e.button !== 0) return; // left click only
  painting = true;
  points = [currentMap.unproject([e.offsetX, e.offsetY])];
  currentMap.dragPan.disable();
}

function onMouseMove(e) {
  if (!painting) return;
  const pt = currentMap.unproject([e.offsetX, e.offsetY]);
  points.push(pt);
  updatePreview();
}

function onMouseUp() {
  if (!painting) return;
  painting = false;
  currentMap.dragPan.enable();

  if (points.length < 2) {
    clearPreview();
    return;
  }

  const polygon = buildPolygon();
  if (!polygon) {
    clearPreview();
    return;
  }

  clearPreview();

  let currentValue;
  brushValue.subscribe(v => currentValue = v)();

  // Send to backend
  submitPaint(polygon, currentValue);
}

function buildPolygon() {
  let currentSize;
  brushSize.subscribe(v => currentSize = v)();

  const coords = points.map(p => [p.lng, p.lat]);
  if (coords.length < 2) return null;

  const line = lineString(coords);
  // Convert pixel brush size to meters based on zoom
  const zoom = currentMap.getZoom();
  const metersPerPixel = 40075016.686 * Math.cos(52.52 * Math.PI / 180) / Math.pow(2, zoom + 8);
  const radiusKm = (currentSize * metersPerPixel) / 1000;

  const buffered = buffer(line, Math.max(radiusKm, 0.005), { units: 'kilometers' });
  return buffered?.geometry || null;
}

function updatePreview() {
  const polygon = buildPolygon();
  if (!polygon || !previewSourceAdded) return;
  currentMap.getSource('brush-preview').setData({
    type: 'FeatureCollection',
    features: [{ type: 'Feature', properties: {}, geometry: polygon }],
  });
}

function clearPreview() {
  if (previewSourceAdded && currentMap) {
    currentMap.getSource('brush-preview').setData({
      type: 'FeatureCollection', features: [],
    });
  }
}

async function submitPaint(geometry, value) {
  try {
    const result = await api.paint(geometry, value);
    // Record for undo
    undoStack.push({ geometry, value, result });
    redoStack.length = 0;
    canUndo.set(undoStack.length > 0);
    canRedo.set(false);

    // Refresh the overlay from server
    refreshOverlay(currentMap);
  } catch (e) {
    console.error('Paint failed:', e);
  }
}

export async function undo() {
  if (undoStack.length === 0) return;
  const entry = undoStack.pop();
  redoStack.push(entry);
  canUndo.set(undoStack.length > 0);
  canRedo.set(true);

  // Erase the polygon we just painted by painting value=0 over it
  try {
    await api.paint(entry.geometry, 0);
    refreshOverlay(currentMap);
  } catch (e) {
    console.error('Undo failed:', e);
  }
}

export async function redo() {
  if (redoStack.length === 0) return;
  const entry = redoStack.pop();
  undoStack.push(entry);
  canUndo.set(true);
  canRedo.set(redoStack.length > 0);

  try {
    await api.paint(entry.geometry, entry.value);
    refreshOverlay(currentMap);
  } catch (e) {
    console.error('Redo failed:', e);
  }
}

function onKeyDown(e) {
  if (e.key === 'z' && (e.metaKey || e.ctrlKey) && e.shiftKey) {
    e.preventDefault();
    redo();
  } else if (e.key === 'z' && (e.metaKey || e.ctrlKey)) {
    e.preventDefault();
    undo();
  }
}
```

- [ ] **Step 3: Create Toolbar.svelte**

Create `frontend/src/components/Toolbar.svelte`:
```svelte
<script>
  import { brushValue, brushSize, canUndo, canRedo, undo, redo } from '../lib/brush.js';

  const ratings = [
    { value: -7, color: '#991b1b', label: 'Avoid' },
    { value: -3, color: '#dc2626', label: 'Bad' },
    { value: -1, color: '#fca5a5', label: 'Meh' },
    { value: 0,  color: '#6b7280', label: 'Erase' },
    { value: 1,  color: '#86efac', label: 'OK' },
    { value: 3,  color: '#22c55e', label: 'Good' },
    { value: 7,  color: '#059669', label: 'Great' },
  ];
</script>

<div class="toolbar">
  <div class="color-strip">
    {#each ratings as r}
      <button
        class="color-btn"
        class:active={$brushValue === r.value}
        style="background: {r.color}"
        on:click={() => brushValue.set(r.value)}
        title={r.label}
      />
    {/each}
  </div>

  <div class="brush-controls">
    <input
      type="range"
      min="5"
      max="80"
      bind:value={$brushSize}
      title="Brush size"
    />
  </div>

  <div class="undo-redo">
    <button disabled={!$canUndo} on:click={undo} title="Undo (Ctrl+Z)">↩</button>
    <button disabled={!$canRedo} on:click={redo} title="Redo (Ctrl+Shift+Z)">↪</button>
  </div>
</div>

<style>
  .toolbar {
    position: absolute;
    bottom: 24px;
    left: 50%;
    transform: translateX(-50%);
    background: white;
    padding: 8px 12px;
    border-radius: 12px;
    box-shadow: 0 2px 12px rgba(0,0,0,0.2);
    z-index: 10;
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .color-strip {
    display: flex;
    gap: 0;
  }
  .color-btn {
    width: 32px;
    height: 32px;
    border: 2px solid transparent;
    cursor: pointer;
    transition: transform 0.1s;
  }
  .color-btn:first-child { border-radius: 6px 0 0 6px; }
  .color-btn:last-child { border-radius: 0 6px 6px 0; }
  .color-btn.active {
    transform: scale(1.15);
    border-color: white;
    box-shadow: 0 0 0 2px #333;
    z-index: 1;
  }
  .brush-controls input {
    width: 80px;
  }
  .undo-redo {
    display: flex;
    gap: 4px;
  }
  .undo-redo button {
    width: 32px;
    height: 32px;
    border: 1px solid #ddd;
    border-radius: 6px;
    background: white;
    cursor: pointer;
    font-size: 16px;
  }
  .undo-redo button:disabled {
    opacity: 0.3;
    cursor: default;
  }
</style>
```

- [ ] **Step 4: Wire toolbar and brush into App.svelte**

Update `App.svelte`:
```svelte
<script>
  import { onMount, onDestroy } from 'svelte';
  import Map from './components/Map.svelte';
  import AuthModal from './components/AuthModal.svelte';
  import Toolbar from './components/Toolbar.svelte';
  import { user, checkSession, logout } from './lib/auth.js';
  import { initOverlay } from './lib/overlay.js';
  import { initBrush, destroyBrush } from './lib/brush.js';

  let map;

  onMount(() => checkSession());
  onDestroy(() => destroyBrush());

  function handleMapLoad(e) {
    map = e.detail;
    if ($user) {
      initOverlay(map);
      initBrush(map);
    }
  }

  $: if (map && $user) {
    initOverlay(map);
    initBrush(map);
  }
</script>

<Map on:load={handleMapLoad} />

{#if $user}
  <div class="user-bar">
    <span>{$user.display_name || $user.email}</span>
    <button on:click={logout}>Log out</button>
  </div>
  <Toolbar />
{:else}
  <AuthModal />
{/if}

<style>
  .user-bar {
    position: absolute; top: 12px; right: 60px;
    background: white; padding: 8px 16px; border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 10;
    display: flex; gap: 12px; align-items: center; font-size: 14px;
  }
  .user-bar button {
    background: none; border: none; color: #2563eb; cursor: pointer;
  }
</style>
```

- [ ] **Step 5: Commit**

```bash
git add frontend/
git commit -m "Add paint brush with undo/redo, color toolbar"
```

---

### Task 13: Search and Routing UI

Geocoding search bar, origin/destination, route display.

**Files:**
- Create: `frontend/src/components/SearchBar.svelte`
- Create: `frontend/src/components/RoutePanel.svelte`
- Create: `frontend/src/lib/routing.js`
- Modify: `frontend/src/App.svelte`

- [ ] **Step 1: Create routing.js**

Create `frontend/src/lib/routing.js`:
```js
import { writable } from 'svelte/store';
import { api } from './api.js';

export const origin = writable(null);      // { lng, lat, name }
export const destination = writable(null); // { lng, lat, name }
export const routeData = writable(null);   // { geometry, distance, time }
export const routeLoading = writable(false);

let currentMap = null;

export function initRouting(map) {
  currentMap = map;

  map.addSource('route', {
    type: 'geojson',
    data: { type: 'FeatureCollection', features: [] },
  });

  map.addLayer({
    id: 'route-line',
    type: 'line',
    source: 'route',
    paint: {
      'line-color': '#2563eb',
      'line-width': 5,
      'line-opacity': 0.8,
    },
  });
}

export async function computeRoute() {
  let o, d;
  origin.subscribe(v => o = v)();
  destination.subscribe(v => d = v)();

  if (!o || !d) return;

  routeLoading.set(true);
  try {
    const data = await api.route([o.lng, o.lat], [d.lng, d.lat]);
    routeData.set(data);

    if (currentMap) {
      currentMap.getSource('route').setData({
        type: 'Feature',
        properties: {},
        geometry: data.geometry,
      });
    }
  } catch (e) {
    console.error('Routing failed:', e);
    routeData.set(null);
  } finally {
    routeLoading.set(false);
  }
}

export function clearRoute() {
  routeData.set(null);
  origin.set(null);
  destination.set(null);
  if (currentMap) {
    currentMap.getSource('route').setData({
      type: 'FeatureCollection', features: [],
    });
  }
}
```

- [ ] **Step 2: Create SearchBar.svelte**

Create `frontend/src/components/SearchBar.svelte`:
```svelte
<script>
  import { api } from '../lib/api.js';
  import { origin, destination, computeRoute, clearRoute } from '../lib/routing.js';

  let query = '';
  let results = [];
  let debounceTimer;
  let settingField = 'origin'; // 'origin' | 'destination'

  function onInput() {
    clearTimeout(debounceTimer);
    if (query.length < 2) { results = []; return; }
    debounceTimer = setTimeout(async () => {
      try {
        const data = await api.geocode(query);
        results = (data.features || []).map(f => ({
          name: formatName(f.properties),
          lng: f.geometry.coordinates[0],
          lat: f.geometry.coordinates[1],
        }));
      } catch { results = []; }
    }, 300);
  }

  function formatName(props) {
    const parts = [props.name, props.street, props.city].filter(Boolean);
    return parts.join(', ') || 'Unknown';
  }

  function select(result) {
    if (settingField === 'origin') {
      origin.set(result);
      settingField = 'destination';
    } else {
      destination.set(result);
      computeRoute();
    }
    query = '';
    results = [];
  }

  function handleClear() {
    clearRoute();
    settingField = 'origin';
  }
</script>

<div class="search-container">
  <div class="search-bar">
    {#if $origin}
      <div class="waypoint">
        <span class="dot origin-dot"></span>
        <span>{$origin.name}</span>
      </div>
    {/if}
    {#if $destination}
      <div class="waypoint">
        <span class="dot dest-dot"></span>
        <span>{$destination.name}</span>
      </div>
    {/if}

    {#if !$destination}
      <input
        type="text"
        placeholder={settingField === 'origin' ? 'Search origin...' : 'Search destination...'}
        bind:value={query}
        on:input={onInput}
      />
    {/if}

    {#if $origin}
      <button class="clear-btn" on:click={handleClear}>×</button>
    {/if}
  </div>

  {#if results.length > 0}
    <ul class="results">
      {#each results as result}
        <li on:click={() => select(result)} on:keydown={() => {}}>{result.name}</li>
      {/each}
    </ul>
  {/if}
</div>

<style>
  .search-container {
    position: absolute; top: 12px; left: 12px; z-index: 10;
    width: 340px;
  }
  .search-bar {
    background: white; border-radius: 8px; padding: 8px 12px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    display: flex; flex-direction: column; gap: 4px;
  }
  input {
    border: none; outline: none; font-size: 14px; padding: 6px 0;
    width: 100%;
  }
  .waypoint {
    display: flex; align-items: center; gap: 8px; font-size: 13px;
    padding: 4px 0;
  }
  .dot { width: 10px; height: 10px; border-radius: 50%; flex-shrink: 0; }
  .origin-dot { background: #22c55e; }
  .dest-dot { background: #ef4444; }
  .clear-btn {
    position: absolute; right: 8px; top: 8px;
    background: none; border: none; font-size: 18px; cursor: pointer; color: #666;
  }
  .results {
    list-style: none; margin: 4px 0 0; background: white;
    border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.15);
    max-height: 200px; overflow-y: auto;
  }
  .results li {
    padding: 10px 12px; cursor: pointer; font-size: 13px;
    border-bottom: 1px solid #f0f0f0;
  }
  .results li:hover { background: #f0f4ff; }
</style>
```

- [ ] **Step 3: Create RoutePanel.svelte**

Create `frontend/src/components/RoutePanel.svelte`:
```svelte
<script>
  import { routeData, routeLoading } from '../lib/routing.js';

  function formatDist(meters) {
    return meters >= 1000
      ? `${(meters / 1000).toFixed(1)} km`
      : `${Math.round(meters)} m`;
  }

  function formatTime(ms) {
    const minutes = Math.round(ms / 60000);
    return minutes >= 60
      ? `${Math.floor(minutes / 60)}h ${minutes % 60}m`
      : `${minutes} min`;
  }
</script>

{#if $routeLoading}
  <div class="route-panel">Computing route...</div>
{:else if $routeData}
  <div class="route-panel">
    <span>{formatDist($routeData.distance)}</span>
    <span class="sep">·</span>
    <span>{formatTime($routeData.time)}</span>
  </div>
{/if}

<style>
  .route-panel {
    position: absolute; top: 12px; left: 360px;
    background: white; padding: 10px 16px; border-radius: 8px;
    box-shadow: 0 2px 8px rgba(0,0,0,0.15); z-index: 10;
    font-size: 14px; display: flex; gap: 4px;
  }
  .sep { color: #999; }
</style>
```

- [ ] **Step 4: Wire search and routing into App.svelte**

Add imports and components to `App.svelte`:
```svelte
<script>
  // ... existing imports ...
  import SearchBar from './components/SearchBar.svelte';
  import RoutePanel from './components/RoutePanel.svelte';
  import { initRouting } from './lib/routing.js';

  function handleMapLoad(e) {
    map = e.detail;
    if ($user) {
      initOverlay(map);
      initBrush(map);
      initRouting(map);
    }
  }

  $: if (map && $user) {
    initOverlay(map);
    initBrush(map);
    initRouting(map);
  }
</script>

<Map on:load={handleMapLoad} />

{#if $user}
  <SearchBar />
  <RoutePanel />
  <div class="user-bar">...</div>
  <Toolbar />
{:else}
  <AuthModal />
{/if}
```

- [ ] **Step 5: Commit**

```bash
git add frontend/
git commit -m "Add search bar with geocoding, routing UI with route display"
```

---

### Task 14: Integration Testing — Bring It All Together

Verify the full stack works: compose up, register, paint, route.

**Files:**
- Modify: `backend/Cargo.toml` (add dev-dependencies)

- [ ] **Step 1: Start the compose stack**

```bash
# Download tiles if not present
./scripts/download_berlin_tiles.sh

# Start all services
cd server && docker compose up -d

# Wait for DB
sleep 5

# Run backend (outside Docker for dev)
cd backend && DATABASE_URL=postgres://ortschaft:ortschaft@localhost:5432/ortschaft cargo run &

# Run frontend dev server
cd frontend && npm run dev &
```

- [ ] **Step 2: Manual smoke test**

1. Open `http://localhost:5173`
2. Verify Berlin map loads with vector tiles
3. Register a new account
4. See the toolbar appear
5. Select green (+3), paint a stroke on the map
6. Verify colored polygon appears
7. Select red (-3), paint over part of the green area
8. Verify the green polygon is clipped where red overlaps
9. Press Ctrl+Z — verify undo works
10. Search for "Alexanderplatz" — verify autocomplete works
11. Search for a destination — verify route appears on map
12. Paint a red area on the route, re-request — verify route changes

- [ ] **Step 3: Fix any issues found during smoke test**

Address compilation errors, API mismatches, or UI bugs discovered.

- [ ] **Step 4: Build frontend for production serving**

```bash
cd frontend && npm run build
```

Verify `frontend/dist/` is created and the backend serves it at `http://localhost:3000`.

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "Integration fixes from smoke testing"
```

---

### Task 15: Polish — CORS, Error Handling, .gitignore

Final cleanup for a working MVP.

**Files:**
- Modify: `backend/src/main.rs` (CORS for dev)
- Create or modify: `.gitignore`

- [ ] **Step 1: Add CORS for development**

In `backend/src/main.rs`, add CORS middleware:
```rust
use tower_http::cors::{CorsLayer, Any};

let cors = CorsLayer::new()
    .allow_origin(Any)
    .allow_methods(Any)
    .allow_headers(Any);

let app = Router::new()
    // ... routes ...
    .layer(cors)
    .with_state(state);
```

- [ ] **Step 2: Update .gitignore**

Create/update root `.gitignore`:
```gitignore
# Rust
backend/target/
or-cli/target/

# Frontend
frontend/node_modules/
frontend/dist/

# Data files (large, downloaded)
data/osm/
data/tiles/

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store

# Env
.env
```

- [ ] **Step 3: Commit**

```bash
git add .gitignore backend/src/main.rs
git commit -m "Add CORS for dev, update .gitignore"
```

---

## Summary

| Task | What it builds |
|---|---|
| 1 | Backend scaffold (Axum + health check) |
| 2 | Docker Compose (PostgreSQL, VersaTiles) + tile download script |
| 3 | Database migrations (users, sessions, rated_areas) |
| 4 | Auth (register, login, logout, session middleware) |
| 5 | Ratings API (paint with polygon clipping, overlay GeoJSON) |
| 6 | Routing (GraphHopper Custom Model with user polygon areas) |
| 7 | Geocoding proxy (Photon) |
| 8 | Static file serving |
| 9 | Frontend scaffold (Svelte + Vite + MapLibre + VersaTiles) |
| 10 | Auth UI (login/register modal) |
| 11 | Rating overlay layer (colored polygons on map) |
| 12 | Paint brush with undo/redo + toolbar |
| 13 | Search + routing UI |
| 14 | Integration testing |
| 15 | Polish (CORS, .gitignore) |

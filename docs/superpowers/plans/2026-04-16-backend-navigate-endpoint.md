# Backend `/api/navigate` Endpoint — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new authenticated backend endpoint at `POST /api/navigate` that proxies GraphHopper's navigation response verbatim in Mapbox Directions-compatible JSON so `ferrostar_flutter` can consume it directly for turn-by-turn navigation.

**Architecture:** Keep `POST /api/route` as the lightweight preview endpoint and add a sibling `POST /api/navigate` path that shares the same request body, auth rules, rated-area lookup, and custom-model construction. The backend continues to own route customization; it simply switches GraphHopper upstream path and request flags, then returns the upstream JSON unchanged so the Flutter plugin can parse it natively.

**Tech Stack:** Rust 2021, Axum 0.8, SQLx 0.8, Reqwest 0.12, Wiremock 0.6, GraphHopper OSS, PostGIS.

**Parent spec:** `docs/superpowers/specs/2026-04-16-mobile-navigation-app-design.md`

**Dependencies:** This plan is independent of Plan A at the code level, but its response shape must satisfy Plan A's `createController(osrmJson: ...)` contract. Plan C depends on this plan.

---

## File Structure

```
infra/graphhopper/config.yml         # Enables GraphHopper navigation profile for bike routing
backend/src/routing.rs               # Shared GraphHopper request builder + /api/route + /api/navigate handlers
backend/src/lib.rs                   # Router registration
backend/tests/integration.rs         # Authenticated end-to-end tests with Wiremocked GraphHopper
```

---

## Phase 1: Enable GraphHopper Navigation Mode

### Task 1: Turn on the `bike` navigation profile in local/dev GraphHopper

**Files:**
- Modify: `infra/graphhopper/config.yml`

- [ ] **Step 1: Add `profiles_navigation` for `bike`**

Insert this block between `profiles:` and `profiles_ch:`:

```yaml
graphhopper:
  profiles:
   - name: car
     custom_model_files: [car.json]
   - name: foot
     custom_model_files: [foot.json, foot_elevation.json]
   - name: bike
     custom_model_files: [bike.json, bike_elevation.json]

  profiles_navigation:
    - profile: bike

  profiles_ch:
    - profile: car
```

- [ ] **Step 2: Restart only the GraphHopper service**

```bash
cd /Users/pv/code/ortschaft
docker compose -f compose.yml up -d graphhopper
```
Expected: the `graphhopper` container restarts cleanly.

- [ ] **Step 3: Smoke-test the raw upstream navigate endpoint**

```bash
curl -sS \
  -X POST http://localhost:8989/navigate/directions \
  -H 'Content-Type: application/json' \
  -d '{
    "points": [[13.405, 52.52], [13.45, 52.51]],
    "profile": "bike",
    "locale": "de",
    "points_encoded": false,
    "voice_instructions": true,
    "banner_instructions": true,
    "roundabout_exits": true
  }' | jq '{has_routes: has("routes"), has_message: has("message")}'
```
Expected: either `{"has_routes":true,"has_message":false}` or a JSON validation error from GraphHopper. A 404/HTML response means navigation mode is still not configured correctly.

- [ ] **Step 4: Commit the infra change**

```bash
cd /Users/pv/code/ortschaft
git add infra/graphhopper/config.yml
git commit -m "chore(graphhopper): enable bike navigation profile"
```

---

## Phase 2: Lock the API Contract with Tests

### Task 2: Add failing integration tests for the new endpoint

**Files:**
- Modify: `backend/tests/integration.rs`

- [ ] **Step 1: Write an auth guard test first**

Add this test near the existing routing tests:

```rust
#[tokio::test]
async fn navigate_requires_auth() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server
        .post("/api/navigate")
        .json(&json!({
            "origin": [13.405, 52.52],
            "destination": [13.45, 52.51]
        }))
        .await;

    resp.assert_status(StatusCode::UNAUTHORIZED);
}
```

- [ ] **Step 2: Write the verbatim proxy test**

Add this Wiremock-backed test immediately after it:

```rust
#[tokio::test]
async fn navigate_proxies_graphhopper_response_verbatim() {
    if std::env::var("TEST_DATABASE_URL").is_err() {
        return;
    }

    let graphhopper = MockServer::start().await;
    let navigate_json = json!({
        "routes": [{
            "distance": 1234.5,
            "duration": 678.9,
            "geometry": "yzocFzynhVq}@n}@o}@nzD",
            "legs": [{
                "steps": [{
                    "distance": 120.0,
                    "duration": 19.2,
                    "name": "Kastanienallee",
                    "maneuver": {
                        "type": "turn",
                        "modifier": "left",
                        "location": [13.41, 52.52]
                    },
                    "voiceInstructions": [{
                        "distanceAlongGeometry": 200.0,
                        "announcement": "In 200 Metern links abbiegen"
                    }],
                    "bannerInstructions": [{
                        "distanceAlongGeometry": 200.0,
                        "primary": { "text": "Links abbiegen" }
                    }]
                }]
            }]
        }],
        "waypoints": [
            { "location": [13.405, 52.52], "name": "Start" },
            { "location": [13.45, 52.51], "name": "Ziel" }
        ]
    });

    Mock::given(method("POST"))
        .and(path("/navigate/directions"))
        .and(body_partial_json(json!({
            "profile": "bike",
            "locale": "de",
            "points_encoded": false,
            "voice_instructions": true,
            "banner_instructions": true,
            "roundabout_exits": true,
            "custom_model": {
                "distance_influence": 42.0
            }
        })))
        .respond_with(ResponseTemplate::new(200).set_body_json(navigate_json.clone()))
        .expect(1)
        .mount(&graphhopper)
        .await;

    let Some(server) = setup_with_graphhopper_url(graphhopper.uri()).await else {
        return;
    };
    let session = create_anonymous(&server).await;
    let (hname, hval) = with_session(&session);

    let resp = server
        .post("/api/navigate")
        .add_header(hname, hval)
        .json(&json!({
            "origin": [13.405, 52.52],
            "destination": [13.45, 52.51],
            "rating_weight": 1.0,
            "distance_influence": 42.0
        }))
        .await;

    resp.assert_status_ok();
    let body: Value = resp.json();
    assert_eq!(body, navigate_json);

    graphhopper.verify().await;
}
```

- [ ] **Step 3: Run just the new tests and verify they fail**

```bash
cd /Users/pv/code/ortschaft
TEST_DATABASE_URL=postgres://beebeebike:beebeebike@localhost:5432/beebeebike \
cargo test --manifest-path backend/Cargo.toml --test integration navigate_
```
Expected: failure because `/api/navigate` is not registered yet.

- [ ] **Step 4: Commit the red test state**

```bash
git add backend/tests/integration.rs
git commit -m "test(backend): add failing coverage for navigate endpoint"
```

---

## Phase 3: Share Request-Building Logic

### Task 3: Refactor `routing.rs` so preview and navigation requests share the same core builder

**Files:**
- Modify: `backend/src/routing.rs`

- [ ] **Step 1: Extract a GraphHopper mode enum and shared helpers**

Add these building blocks near the top of `backend/src/routing.rs`:

```rust
#[derive(Clone, Copy)]
enum GraphhopperMode {
    Preview,
    Navigate,
}

impl GraphhopperMode {
    fn upstream_path(self) -> &'static str {
        match self {
            Self::Preview => "/route",
            Self::Navigate => "/navigate/directions",
        }
    }

    fn apply_mode_flags(self, request: &mut serde_json::Map<String, Value>) {
        if matches!(self, Self::Navigate) {
            request.insert("voice_instructions".into(), json!(true));
            request.insert("banner_instructions".into(), json!(true));
            request.insert("roundabout_exits".into(), json!(true));
        }
    }
}

async fn load_rated_areas(
    state: &AppState,
    user_id: uuid::Uuid,
    origin: [f64; 2],
    destination: [f64; 2],
) -> Result<Vec<RatedAreaRow>, AppError> {
    const MARGIN: f64 = 0.02;
    let west = origin[0].min(destination[0]) - MARGIN;
    let south = origin[1].min(destination[1]) - MARGIN;
    let east = origin[0].max(destination[0]) + MARGIN;
    let north = origin[1].max(destination[1]) + MARGIN;

    let rows = sqlx::query_as::<_, RatedAreaRow>(
        r#"
        SELECT id, ST_AsGeoJSON(geometry) AS geometry, value
        FROM rated_areas
        WHERE user_id = $1
          AND ST_Intersects(geometry, ST_MakeEnvelope($2, $3, $4, $5, 4326))
        LIMIT $6
        "#,
    )
    .bind(user_id)
    .bind(west)
    .bind(south)
    .bind(east)
    .bind(north)
    .bind(state.config.max_areas_per_request as i64)
    .fetch_all(&state.db)
    .await?;

    Ok(rows)
}
```

- [ ] **Step 2: Extract a shared JSON request builder**

Continue in the same file with:

```rust
fn build_graphhopper_request(
    state: &AppState,
    body: &RouteRequest,
    rows: &[RatedAreaRow],
    mode: GraphhopperMode,
) -> Result<Value, AppError> {
    let rating_weight = body
        .rating_weight
        .unwrap_or(state.config.rating_weight)
        .clamp(0.0, 1.0);
    let distance_influence =
        resolve_distance_influence(body.distance_influence, state.config.distance_influence);

    let mut gh_request = json!({
        "points": [body.origin, body.destination],
        "profile": "bike",
        "locale": "de",
        "points_encoded": false,
        "ch.disable": true,
    });

    let mut priority_statements: Vec<Value> = Vec::new();
    let mut features: Vec<Value> = Vec::new();

    for row in rows {
        let area_id = format!("area_{}", row.id);
        let geometry: Value = serde_json::from_str(&row.geometry)
            .map_err(|e| AppError::Internal(format!("failed to parse area geometry: {e}")))?;
        let multiplier = rating_to_priority(row.value, rating_weight);

        priority_statements.push(json!({
            "if": format!("in_{}", area_id),
            "multiply_by": multiplier.to_string(),
        }));

        features.push(json!({
            "type": "Feature",
            "id": area_id,
            "properties": {},
            "geometry": geometry,
        }));
    }

    let mut custom_model = json!({
        "distance_influence": distance_influence,
    });

    if !priority_statements.is_empty() {
        let custom_model_obj = custom_model.as_object_mut().unwrap();
        custom_model_obj.insert("priority".into(), json!(priority_statements));
        custom_model_obj.insert(
            "areas".into(),
            json!({
                "type": "FeatureCollection",
                "features": features,
            }),
        );
    }

    let request_obj = gh_request.as_object_mut().unwrap();
    request_obj.insert("custom_model".into(), custom_model);
    mode.apply_mode_flags(request_obj);

    Ok(gh_request)
}
```

- [ ] **Step 3: Extract a single upstream-post helper**

Add one more helper below:

```rust
async fn post_graphhopper(
    state: &AppState,
    mode: GraphhopperMode,
    request: Value,
) -> Result<Value, AppError> {
    let gh_url = format!("{}{}", state.config.graphhopper_url, mode.upstream_path());
    let gh_response = state
        .http_client
        .post(&gh_url)
        .json(&request)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("failed to reach GraphHopper: {e}")))?;

    if !gh_response.status().is_success() {
        let status = gh_response.status();
        let body = gh_response
            .text()
            .await
            .unwrap_or_else(|_| "unknown error".into());
        return Err(AppError::Internal(format!(
            "GraphHopper returned {status}: {body}"
        )));
    }

    gh_response
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("failed to parse GraphHopper response: {e}")))
}
```

- [ ] **Step 4: Rewire `get_route` to use the shared helpers without changing behavior**

Replace the current handler body with the shared flow:

```rust
pub async fn get_route(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<RouteRequest>,
) -> Result<Json<RouteResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let rows = load_rated_areas(&state, user_id, body.origin, body.destination).await?;
    let gh_request = build_graphhopper_request(&state, &body, &rows, GraphhopperMode::Preview)?;
    let gh_json = post_graphhopper(&state, GraphhopperMode::Preview, gh_request).await?;

    let path = gh_json
        .get("paths")
        .and_then(|p| p.get(0))
        .ok_or_else(|| AppError::Internal("GraphHopper returned no paths".into()))?;

    let geometry = path
        .get("points")
        .cloned()
        .ok_or_else(|| AppError::Internal("GraphHopper path missing points".into()))?;

    let distance = path
        .get("distance")
        .and_then(|v| v.as_f64())
        .ok_or_else(|| AppError::Internal("GraphHopper path missing distance".into()))?;

    let time = path
        .get("time")
        .and_then(|v| v.as_f64())
        .ok_or_else(|| AppError::Internal("GraphHopper path missing time".into()))?;

    Ok(Json(RouteResponse { geometry, distance, time }))
}
```

- [ ] **Step 5: Run unit tests for the module**

```bash
cd /Users/pv/code/ortschaft
cargo test --manifest-path backend/Cargo.toml routing::
```
Expected: existing routing unit tests still pass.

- [ ] **Step 6: Commit the refactor**

```bash
git add backend/src/routing.rs
git commit -m "refactor(backend): share graphhopper request construction"
```

---

## Phase 4: Add the New Handler and Route

### Task 4: Implement `POST /api/navigate`

**Files:**
- Modify: `backend/src/routing.rs`
- Modify: `backend/src/lib.rs`

- [ ] **Step 1: Add the new handler to `routing.rs`**

Append this handler directly below `get_route`:

```rust
pub async fn get_navigation_route(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<RouteRequest>,
) -> Result<Json<Value>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let rows = load_rated_areas(&state, user_id, body.origin, body.destination).await?;
    let gh_request = build_graphhopper_request(&state, &body, &rows, GraphhopperMode::Navigate)?;
    let gh_json = post_graphhopper(&state, GraphhopperMode::Navigate, gh_request).await?;

    Ok(Json(gh_json))
}
```

- [ ] **Step 2: Register the route in the router**

Update `backend/src/lib.rs`:

```rust
        .route("/api/ratings", get(ratings::get_overlay))
        .route("/api/ratings/paint", put(ratings::paint))
        .route("/api/route", post(routing::get_route))
        .route("/api/navigate", post(routing::get_navigation_route))
        .route("/api/geocode", get(geocode::geocode))
```

- [ ] **Step 3: Re-run the previously failing integration tests**

```bash
cd /Users/pv/code/ortschaft
TEST_DATABASE_URL=postgres://beebeebike:beebeebike@localhost:5432/beebeebike \
cargo test --manifest-path backend/Cargo.toml --test integration navigate_
```
Expected: both `navigate_requires_auth` and `navigate_proxies_graphhopper_response_verbatim` pass.

- [ ] **Step 4: Run the full backend test suite**

```bash
cd /Users/pv/code/ortschaft
cargo test --manifest-path backend/Cargo.toml
TEST_DATABASE_URL=postgres://beebeebike:beebeebike@localhost:5432/beebeebike \
cargo test --manifest-path backend/Cargo.toml --test integration
```
Expected: all tests pass.

- [ ] **Step 5: Commit the feature**

```bash
git add backend/src/lib.rs backend/src/routing.rs
git commit -m "feat(backend): add navigate endpoint for ferrostar"
```

---

## Phase 5: End-to-End Smoke Test Against the Real Stack

### Task 5: Verify the backend produces Ferrostar-ready payloads in development

**Files:** none (verification only)

- [ ] **Step 1: Start the local stack**

```bash
cd /Users/pv/code/ortschaft
docker compose -f compose.yml -f compose.dev.yml up -d
```

- [ ] **Step 2: Create an anonymous session and keep the cookie**

```bash
curl -sS -c /tmp/ortschaft.cookies \
  -X POST http://localhost:3000/api/auth/anonymous > /tmp/ortschaft-anon.json
cat /tmp/ortschaft-anon.json | jq '{id, account_type}'
```
Expected: a JSON user object with `"account_type": "anonymous"`.

- [ ] **Step 3: Call `/api/navigate` through the backend**

```bash
curl -sS -b /tmp/ortschaft.cookies \
  -X POST http://localhost:3000/api/navigate \
  -H 'Content-Type: application/json' \
  -d '{
    "origin": [13.405, 52.52],
    "destination": [13.45, 52.51],
    "rating_weight": 0.5,
    "distance_influence": 70
  }' | jq '.routes[0].legs[0].steps[0] | {
    name,
    has_voice: (.voiceInstructions | length > 0),
    has_banner: (.bannerInstructions | length > 0)
  }'
```
Expected: `has_voice: true` and `has_banner: true`. If either is false, stop and inspect the upstream GraphHopper config before starting Plan C.

- [ ] **Step 4: Commit nothing here**

This is pure verification. If Steps 1-3 fail, fix the underlying code before moving on.

---

## Self-Review Notes

- **Spec coverage:** This plan covers the only backend delta named in the spec: a new authenticated `POST /api/navigate` endpoint that uses the same request shape as `/api/route`, hits GraphHopper's navigation endpoint, enables voice/banner instructions, and returns the response verbatim.
- **No placeholder gaps:** The plan names the real files already present in this repo and keeps the feature inside `backend/src/routing.rs` plus router registration in `backend/src/lib.rs`; it does not invent a second backend subsystem.
- **Decision gate preserved:** The GraphHopper navigation-profile check is first on purpose. If `/navigate/directions` is not available in the deployed GraphHopper image, stop before writing application code and decide whether to change infra or fall back to the custom adapter path from the spec.

## After This Plan

Plan C can start once this endpoint is green in local development. Plan A and Plan B can progress in parallel, but Plan C should not try to wire live navigation until both this endpoint and `packages/ferrostar_flutter/` are working.

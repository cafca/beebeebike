//! Integration tests — require a running PostGIS database.
//!
//! Run with: TEST_DATABASE_URL=postgres://... cargo test --test integration
//! Or via docker compose which sets the env automatically.
//!
//! Skipped when TEST_DATABASE_URL is not set.
//!
//! Each test creates its own anonymous user so tests are isolated and can
//! run in parallel without interfering with each other.

use axum::http::{HeaderName, HeaderValue, StatusCode};
use axum_test::TestServer;
use beebeebike_backend::{bbox::Bbox, build_router, config::Config, AppState};
use serde_json::{json, Value};
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;
use uuid::Uuid;
use wiremock::{
    matchers::{body_partial_json, method, path},
    Mock, MockServer, ResponseTemplate,
};

async fn setup() -> Option<TestServer> {
    setup_with_graphhopper_url("http://localhost:0".into()).await
}

async fn setup_with_db() -> Option<(TestServer, sqlx::PgPool)> {
    setup_with_db_and_cap(15).await
}

async fn setup_with_db_and_cap(max_undo_history: usize) -> Option<(TestServer, sqlx::PgPool)> {
    let db_url = match std::env::var("TEST_DATABASE_URL") {
        Ok(url) => url,
        Err(_) => return None,
    };
    let db = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
        .expect("failed to connect to test database");
    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .expect("failed to run migrations");
    let config = Config {
        database_url: db_url,
        graphhopper_url: "http://localhost:0".into(),
        photon_url: "http://localhost:0".into(),
        listen_addr: "127.0.0.1:0".into(),
        static_dir: "/nonexistent".into(),
        rating_weight: 1.0,
        distance_influence: 70.0,
        max_areas_per_request: 200,
        max_undo_history,
        // SSE pipeline not exercised by these tests — keeping it off
        // avoids spawning a listener task per test run.
        ratings_events_enabled: false,
        bbox: Bbox::BERLIN,
    };
    let state = Arc::new(AppState {
        db: db.clone(),
        config,
        http_client: reqwest::Client::new(),
        rating_events: None,
    });
    Some((TestServer::new(build_router(state)), db))
}

async fn setup_with_graphhopper_url(graphhopper_url: String) -> Option<TestServer> {
    let db_url = match std::env::var("TEST_DATABASE_URL") {
        Ok(url) => url,
        Err(_) => return None,
    };

    let db = PgPoolOptions::new()
        .max_connections(5)
        .connect(&db_url)
        .await
        .expect("failed to connect to test database");

    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .expect("failed to run migrations");

    let config = Config {
        database_url: db_url,
        graphhopper_url,
        photon_url: "http://localhost:0".into(),
        listen_addr: "127.0.0.1:0".into(),
        static_dir: "/nonexistent".into(),
        rating_weight: 1.0,
        distance_influence: 70.0,
        max_areas_per_request: 200,
        max_undo_history: 15,
        ratings_events_enabled: false,
        bbox: Bbox::BERLIN,
    };

    let state = Arc::new(AppState {
        db,
        config,
        http_client: reqwest::Client::new(),
        rating_events: None,
    });

    let app = build_router(state);
    Some(TestServer::new(app))
}

/// Generate a unique email for test isolation.
fn unique_email(prefix: &str) -> String {
    format!("{}+{}@test.example.com", prefix, Uuid::new_v4())
}

fn cookie_header(name: HeaderName, value: &str) -> (HeaderName, HeaderValue) {
    (name, HeaderValue::from_str(value).unwrap())
}

/// Helper: create an anonymous user and return the session cookie value.
async fn create_anonymous(server: &TestServer) -> String {
    let resp = server.post("/api/auth/anonymous").await;
    resp.assert_status_ok();
    extract_session_cookie(&resp)
}

fn extract_session_cookie(resp: &axum_test::TestResponse) -> String {
    let set_cookie = resp.header("set-cookie");
    let s = set_cookie.to_str().unwrap();
    s.split(';')
        .next()
        .unwrap()
        .strip_prefix("session=")
        .unwrap()
        .to_string()
}

fn with_session(session: &str) -> (HeaderName, HeaderValue) {
    cookie_header(
        HeaderName::from_static("cookie"),
        &format!("session={session}"),
    )
}

// ---------------------------------------------------------------------------
// Health check
// ---------------------------------------------------------------------------

#[tokio::test]
async fn health_check() {
    let Some(server) = setup().await else {
        return;
    };
    let resp = server.get("/api/health").await;
    resp.assert_status_ok();
    resp.assert_text("ok");
}

// ---------------------------------------------------------------------------
// Auth: anonymous flow
// ---------------------------------------------------------------------------

#[tokio::test]
async fn anonymous_creates_user_and_session() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server.post("/api/auth/anonymous").await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["account_type"], "anonymous");
    assert!(body["id"].is_string());
    assert!(body["email"].is_null());

    // Should have a session cookie
    let set_cookie = resp.header("set-cookie");
    assert!(set_cookie.to_str().unwrap().contains("session="));
}

#[tokio::test]
async fn anonymous_returns_existing_user_on_second_call() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;
    let (hname, hval) = with_session(&session);

    let resp = server
        .post("/api/auth/anonymous")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["account_type"], "anonymous");
}

// ---------------------------------------------------------------------------
// Auth: register flow
// ---------------------------------------------------------------------------

#[tokio::test]
async fn register_new_user() {
    let Some(server) = setup().await else {
        return;
    };

    let email = unique_email("register");
    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "email": email,
            "password": "password123",
            "display_name": "Tester"
        }))
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["account_type"], "registered");
    assert_eq!(body["email"], email);
    assert_eq!(body["display_name"], "Tester");
}

#[tokio::test]
async fn register_upgrade_from_anonymous() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // Get the anonymous user's ID
    let (hname, hval) = with_session(&session);
    let me_resp = server.get("/api/auth/me").add_header(hname, hval).await;
    let anon_id = me_resp.json::<Value>()["id"].as_str().unwrap().to_string();

    // Upgrade to registered
    let email = unique_email("upgrade");
    let (hname, hval) = with_session(&session);
    let resp = server
        .post("/api/auth/register")
        .add_header(hname, hval)
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["account_type"], "registered");
    assert_eq!(body["email"], email);
    // Same user ID — upgraded in place
    assert_eq!(body["id"], anon_id);
}

#[tokio::test]
async fn register_rejects_short_password() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "email": unique_email("shortpw"),
            "password": "short"
        }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn register_rejects_empty_email() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "email": "",
            "password": "password123"
        }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn register_rejects_duplicate_email() {
    let Some(server) = setup().await else {
        return;
    };

    let email = unique_email("dupe");
    server
        .post("/api/auth/register")
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await
        .assert_status_ok();

    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);

    let body: Value = resp.json();
    let err = body["error"].as_str().unwrap();
    assert!(err.contains("email already registered"));
}

// ---------------------------------------------------------------------------
// Auth: login/logout
// ---------------------------------------------------------------------------

#[tokio::test]
async fn login_and_logout() {
    let Some(server) = setup().await else {
        return;
    };

    let email = unique_email("login");

    // Register first
    server
        .post("/api/auth/register")
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await
        .assert_status_ok();

    // Login
    let resp = server
        .post("/api/auth/login")
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await;
    resp.assert_status_ok();

    let session = extract_session_cookie(&resp);
    let body: Value = resp.json();
    assert_eq!(body["email"], email);

    // Logout
    let (hname, hval) = with_session(&session);
    let resp = server
        .post("/api/auth/logout")
        .add_header(hname, hval)
        .await;
    resp.assert_status(StatusCode::NO_CONTENT);

    // Session should no longer work
    let (hname, hval) = with_session(&session);
    let resp = server.get("/api/auth/me").add_header(hname, hval).await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn login_wrong_password() {
    let Some(server) = setup().await else {
        return;
    };

    let email = unique_email("wrongpw");
    server
        .post("/api/auth/register")
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await
        .assert_status_ok();

    let resp = server
        .post("/api/auth/login")
        .json(&json!({
            "email": email,
            "password": "wrongpassword"
        }))
        .await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn login_nonexistent_user() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server
        .post("/api/auth/login")
        .json(&json!({
            "email": unique_email("nobody"),
            "password": "password123"
        }))
        .await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

// ---------------------------------------------------------------------------
// Auth: delete account
// ---------------------------------------------------------------------------

#[tokio::test]
async fn delete_account_removes_user_and_ratings() {
    let Some((server, db)) = setup_with_db().await else {
        return;
    };

    let email = unique_email("delete");
    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "email": email,
            "password": "password123"
        }))
        .await;
    resp.assert_status_ok();
    let user_id: Uuid = Uuid::parse_str(resp.json::<Value>()["id"].as_str().unwrap()).unwrap();
    let session = extract_session_cookie(&resp);

    // Paint a rating so there is dependent data to cascade.
    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await
        .assert_status_ok();

    // Delete account.
    let (hname, hval) = with_session(&session);
    let resp = server
        .delete("/api/auth/account")
        .add_header(hname, hval)
        .await;
    resp.assert_status(StatusCode::NO_CONTENT);

    // User row gone.
    let users: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(users, 0);

    // Cascade: rated_areas + sessions gone too.
    let ratings: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM rated_areas WHERE user_id = $1")
        .bind(user_id)
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(ratings, 0);
    let sessions: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM sessions WHERE user_id = $1")
        .bind(user_id)
        .fetch_one(&db)
        .await
        .unwrap();
    assert_eq!(sessions, 0);

    // Session cookie is now invalid.
    let (hname, hval) = with_session(&session);
    let resp = server.get("/api/auth/me").add_header(hname, hval).await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn delete_account_rejects_anonymous() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;
    let (hname, hval) = with_session(&session);
    let resp = server
        .delete("/api/auth/account")
        .add_header(hname, hval)
        .await;
    resp.assert_status(StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn delete_account_requires_auth() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server.delete("/api/auth/account").await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

// ---------------------------------------------------------------------------
// Auth: me endpoint
// ---------------------------------------------------------------------------

#[tokio::test]
async fn me_without_session_is_unauthorized() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server.get("/api/auth/me").await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn me_with_invalid_session_is_unauthorized() {
    let Some(server) = setup().await else {
        return;
    };

    let (hname, hval) = cookie_header(
        HeaderName::from_static("cookie"),
        "session=bogus-session-id",
    );
    let resp = server.get("/api/auth/me").add_header(hname, hval).await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

// ---------------------------------------------------------------------------
// Locations
// ---------------------------------------------------------------------------

#[tokio::test]
async fn home_location_crud() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // GET home — should be null initially
    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/locations/home")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    assert!(body.is_null());

    // PUT home
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/locations/home")
        .add_header(hname, hval)
        .json(&json!({
            "label": "My Home",
            "lng": 13.405,
            "lat": 52.52
        }))
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    assert_eq!(body["label"], "My Home");
    assert!((body["lng"].as_f64().unwrap() - 13.405).abs() < 1e-6);

    // GET home — should return saved location
    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/locations/home")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    assert_eq!(body["label"], "My Home");

    // PUT home again (upsert)
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/locations/home")
        .add_header(hname, hval)
        .json(&json!({
            "label": "New Home",
            "lng": 13.38,
            "lat": 52.50
        }))
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    assert_eq!(body["label"], "New Home");

    // DELETE home
    let (hname, hval) = with_session(&session);
    let resp = server
        .delete("/api/locations/home")
        .add_header(hname, hval)
        .await;
    resp.assert_status(StatusCode::NO_CONTENT);

    // GET home — should be null again
    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/locations/home")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    assert!(body.is_null());
}

#[tokio::test]
async fn home_location_validation() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // Empty label
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/locations/home")
        .add_header(hname, hval)
        .json(&json!({ "label": "", "lng": 13.405, "lat": 52.52 }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);

    // Out-of-range longitude
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/locations/home")
        .add_header(hname, hval)
        .json(&json!({ "label": "Test", "lng": 999.0, "lat": 52.52 }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);

    // Out-of-range latitude
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/locations/home")
        .add_header(hname, hval)
        .json(&json!({ "label": "Test", "lng": 13.405, "lat": -91.0 }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn home_location_requires_auth() {
    let Some(server) = setup().await else {
        return;
    };

    let resp = server.get("/api/locations/home").await;
    resp.assert_status(StatusCode::UNAUTHORIZED);

    let resp = server
        .put("/api/locations/home")
        .json(&json!({ "label": "Test", "lng": 13.405, "lat": 52.52 }))
        .await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

// ---------------------------------------------------------------------------
// Ratings: paint
// ---------------------------------------------------------------------------

#[tokio::test]
async fn paint_creates_area() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert!(body["created_id"].is_number());
    assert_eq!(body["clipped_count"], 0);
    assert_eq!(body["deleted_count"], 0);
}

#[tokio::test]
async fn paint_eraser_creates_no_area() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 0 }))
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert!(body["created_id"].is_null());
}

#[tokio::test]
async fn paint_eraser_deletes_target_feature_even_with_clipped_geometry() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    let painted_polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": painted_polygon, "value": 3 }))
        .await
        .assert_status_ok();

    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    let features = body["features"].as_array().unwrap();
    assert_eq!(features.len(), 1);
    let target_id = features[0]["id"].as_i64().unwrap();

    // Command-click fill acts on an existing rendered feature. The rendered
    // geometry can be clipped or simplified, so the backend must use the
    // clicked feature id to delete the whole rated area.
    let rendered_feature_geometry = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.405, 52.5], [13.405, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": rendered_feature_geometry, "value": 0, "target_id": target_id }))
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert!(body["created_id"].is_null());

    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["features"].as_array().unwrap().len(), 0);
}

#[tokio::test]
async fn paint_rejects_invalid_value() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 5 }))
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);
}

#[tokio::test]
async fn paint_clips_overlapping_areas() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // Create first area
    let poly1 = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.42, 52.5], [13.42, 52.52], [13.4, 52.52], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly1, "value": 3 }))
        .await
        .assert_status_ok();

    // Overlapping second area should clip the first
    let poly2 = json!({
        "type": "Polygon",
        "coordinates": [[[13.41, 52.51], [13.43, 52.51], [13.43, 52.53], [13.41, 52.53], [13.41, 52.51]]]
    });
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly2, "value": -3 }))
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert!(body["created_id"].is_number());
    assert!(body["clipped_count"].as_i64().unwrap() > 0);
}

#[tokio::test]
async fn paint_same_value_over_existing_merges_into_single_row() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // Paint larger V=3 area first.
    let large = json!({
        "type": "Polygon",
        "coordinates": [[[13.40, 52.50], [13.44, 52.50], [13.44, 52.54], [13.40, 52.54], [13.40, 52.50]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": large, "value": 3 }))
        .await
        .assert_status_ok();

    // Paint a smaller V=3 area fully inside the first. Should merge, not
    // create a concentric ring.
    let small = json!({
        "type": "Polygon",
        "coordinates": [[[13.41, 52.51], [13.43, 52.51], [13.43, 52.53], [13.41, 52.53], [13.41, 52.51]]]
    });
    let (hname, hval) = with_session(&session);
    let resp = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": small, "value": 3 }))
        .await;
    resp.assert_status_ok();

    // Merge must be surfaced as deleted_count >= 1 so the client refetches
    // instead of optimistically appending.
    let body: Value = resp.json();
    assert!(
        body["deleted_count"].as_i64().unwrap() >= 1,
        "expected deleted_count >= 1 for same-value merge, got: {body}"
    );

    // Overlay should have exactly one feature (the merged union).
    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    let features = body["features"].as_array().unwrap();
    assert_eq!(
        features.len(),
        1,
        "expected single merged feature, got {}: {body}",
        features.len()
    );
    assert_eq!(features[0]["properties"]["value"], 3);
}

#[tokio::test]
async fn paint_requires_auth() {
    let Some(server) = setup().await else {
        return;
    };

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let resp = server
        .put("/api/ratings/paint")
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await;
    resp.assert_status(StatusCode::UNAUTHORIZED);
}

// ---------------------------------------------------------------------------
// Ratings: get overlay
// ---------------------------------------------------------------------------

#[tokio::test]
async fn get_overlay_returns_feature_collection() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // Paint an area first
    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 7 }))
        .await
        .assert_status_ok();

    // Fetch overlay with bbox covering the area
    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["type"], "FeatureCollection");
    let features = body["features"].as_array().unwrap();
    assert_eq!(features.len(), 1);
    assert_eq!(features[0]["properties"]["value"], 7);
}

#[tokio::test]
async fn get_overlay_bbox_outside_returns_empty() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    // Paint an area in Berlin
    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await
        .assert_status_ok();

    // Fetch with bbox far away
    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/ratings?bbox=-74.0,40.7,-73.9,40.8")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["features"].as_array().unwrap().len(), 0);
}

#[tokio::test]
async fn get_overlay_invalid_bbox() {
    let Some(server) = setup().await else {
        return;
    };

    let session = create_anonymous(&server).await;

    let (hname, hval) = with_session(&session);
    let resp = server
        .get("/api/ratings?bbox=not,a,valid")
        .add_header(hname, hval)
        .await;
    resp.assert_status(StatusCode::BAD_REQUEST);
}

// ---------------------------------------------------------------------------
// Routing
// ---------------------------------------------------------------------------

#[tokio::test]
async fn route_forwards_distance_influence_to_graphhopper() {
    if std::env::var("TEST_DATABASE_URL").is_err() {
        return;
    }

    let graphhopper = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/route"))
        .and(body_partial_json(json!({
            "custom_model": {
                "distance_influence": 42.0
            }
        })))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({
            "paths": [{
                "points": {
                    "type": "LineString",
                    "coordinates": [[13.405, 52.52], [13.45, 52.51]]
                },
                "distance": 1234.5,
                "time": 678000.0
            }]
        })))
        .expect(1)
        .mount(&graphhopper)
        .await;

    let Some(server) = setup_with_graphhopper_url(graphhopper.uri()).await else {
        return;
    };
    let session = create_anonymous(&server).await;
    let (hname, hval) = with_session(&session);

    let resp = server
        .post("/api/route")
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
    assert_eq!(body["distance"], 1234.5);
    assert_eq!(body["time"], 678000.0);
    assert_eq!(body["geometry"]["type"], "LineString");

    graphhopper.verify().await;
}

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
        .and(path("/navigate"))
        .and(body_partial_json(json!({
            "profile": "bike",
            "locale": "de",
            "type": "mapbox",
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
        .add_header(
            axum::http::header::ACCEPT_LANGUAGE,
            axum::http::HeaderValue::from_static("de"),
        )
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

#[tokio::test]
async fn navigate_uses_english_locale_when_accept_language_is_en() {
    if std::env::var("TEST_DATABASE_URL").is_err() {
        return;
    }

    let graphhopper = MockServer::start().await;

    let navigate_json = json!({
        "routes": [{ "legs": [] }],
        "waypoints": []
    });

    Mock::given(method("POST"))
        .and(path("/navigate"))
        .and(body_partial_json(json!({
            "profile": "bike",
            "locale": "en",
            "type": "mapbox"
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
        .add_header(
            axum::http::header::ACCEPT_LANGUAGE,
            axum::http::HeaderValue::from_static("en"),
        )
        .json(&json!({
            "origin": [13.405, 52.52],
            "destination": [13.45, 52.51],
            "rating_weight": 1.0,
            "distance_influence": 42.0
        }))
        .await;

    resp.assert_status_ok();
    graphhopper.verify().await;
}

// ---------------------------------------------------------------------------
// Ratings: undo / redo
// ---------------------------------------------------------------------------

#[tokio::test]
async fn undo_requires_auth() {
    let Some(server) = setup().await else {
        return;
    };
    server
        .post("/api/ratings/undo")
        .await
        .assert_status(StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn redo_requires_auth() {
    let Some(server) = setup().await else {
        return;
    };
    server
        .post("/api/ratings/redo")
        .await
        .assert_status(StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn undo_noop_when_nothing_to_undo() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;
    let (hname, hval) = with_session(&session);
    let resp = server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();
    let body: Value = resp.json();
    assert_eq!(body["can_undo"], false);
    assert_eq!(body["can_redo"], false);
}

#[tokio::test]
async fn undo_simple_paint() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    let paint_resp: Value = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await
        .json();
    assert_eq!(paint_resp["can_undo"], true);
    assert_eq!(paint_resp["can_redo"], false);

    // Undo — area should disappear
    let (hname, hval) = with_session(&session);
    let undo_resp: Value = server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(undo_resp["can_undo"], false);
    assert_eq!(undo_resp["can_redo"], true);

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(overlay["features"].as_array().unwrap().len(), 0);
}

#[tokio::test]
async fn redo_after_undo() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await;

    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await;

    // Redo — area should come back
    let (hname, hval) = with_session(&session);
    let redo_resp: Value = server
        .post("/api/ratings/redo")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(redo_resp["can_undo"], true);
    assert_eq!(redo_resp["can_redo"], false);

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(overlay["features"].as_array().unwrap().len(), 1);
}

#[tokio::test]
async fn new_paint_clears_redo_stack() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    let poly_a = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });
    let poly_b = json!({
        "type": "Polygon",
        "coordinates": [[[13.42, 52.5], [13.43, 52.5], [13.43, 52.51], [13.42, 52.51], [13.42, 52.5]]]
    });

    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_a, "value": 3 }))
        .await;
    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await;

    // Painting clears the redo stack
    let (hname, hval) = with_session(&session);
    let resp: Value = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_b, "value": 1 }))
        .await
        .json();
    assert_eq!(resp["can_redo"], false);
}

#[tokio::test]
async fn undo_restores_partially_clipped_polygon() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    // Paint polygon A
    let poly_a = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.42, 52.5], [13.42, 52.52], [13.4, 52.52], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_a, "value": 3 }))
        .await;

    // Paint polygon B partially overlapping A — clips A into a fragment
    let poly_b = json!({
        "type": "Polygon",
        "coordinates": [[[13.41, 52.51], [13.43, 52.51], [13.43, 52.53], [13.41, 52.53], [13.41, 52.51]]]
    });
    let (hname, hval) = with_session(&session);
    let resp: Value = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_b, "value": -3 }))
        .await
        .json();
    assert!(resp["clipped_count"].as_i64().unwrap() > 0);

    // Undo B — A should be fully restored (just A in the overlay, no fragment + B)
    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await;

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    let features = overlay["features"].as_array().unwrap();
    assert_eq!(
        features.len(),
        1,
        "should have exactly A restored, not A-fragment + nothing"
    );
    assert_eq!(features[0]["properties"]["value"], 3);
}

#[tokio::test]
async fn undo_restores_fully_covered_polygon() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    // Paint small polygon A
    let poly_a = json!({
        "type": "Polygon",
        "coordinates": [[[13.405, 52.505], [13.41, 52.505], [13.41, 52.51], [13.405, 52.51], [13.405, 52.505]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_a, "value": 7 }))
        .await;

    // Paint large polygon B fully covering A
    let poly_b = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.42, 52.5], [13.42, 52.52], [13.4, 52.52], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    let resp: Value = server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_b, "value": -7 }))
        .await
        .json();
    assert!(resp["deleted_count"].as_i64().unwrap() > 0);

    // Undo B — A should reappear with its original value
    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await;

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    let features = overlay["features"].as_array().unwrap();
    assert_eq!(features.len(), 1);
    assert_eq!(features[0]["properties"]["value"], 7);
}

#[tokio::test]
async fn undo_multi_step() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    let polys = [
        json!({ "type": "Polygon", "coordinates": [[[13.40, 52.50], [13.41, 52.50], [13.41, 52.51], [13.40, 52.51], [13.40, 52.50]]] }),
        json!({ "type": "Polygon", "coordinates": [[[13.42, 52.50], [13.43, 52.50], [13.43, 52.51], [13.42, 52.51], [13.42, 52.50]]] }),
        json!({ "type": "Polygon", "coordinates": [[[13.44, 52.50], [13.45, 52.50], [13.45, 52.51], [13.44, 52.51], [13.44, 52.50]]] }),
    ];

    for poly in &polys {
        let (hname, hval) = with_session(&session);
        server
            .put("/api/ratings/paint")
            .add_header(hname, hval)
            .json(&json!({ "geometry": poly, "value": 1 }))
            .await;
    }

    // Undo all three
    for _ in 0..3 {
        let (hname, hval) = with_session(&session);
        server
            .post("/api/ratings/undo")
            .add_header(hname, hval)
            .await;
    }

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(overlay["features"].as_array().unwrap().len(), 0);
    assert_eq!(overlay["can_undo"], false);
    assert_eq!(overlay["can_redo"], true);
}

#[tokio::test]
async fn overlay_includes_history_state_flags() {
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    // Fresh user: no history
    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(overlay["can_undo"], false);
    assert_eq!(overlay["can_redo"], false);

    // After a paint: can undo
    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 3 }))
        .await;

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(overlay["can_undo"], true);
    assert_eq!(overlay["can_redo"], false);
}

#[tokio::test]
async fn undo_after_migration_backfill_preserves_existing_areas() {
    // Regression test for the migration scenario: a user has rated_areas that
    // were painted before migration 006 ran. The migration backfills paint_events
    // from those areas. This test simulates that state directly — bypassing the
    // API to insert rated_areas + matching paint_events — then verifies that a
    // new paint followed by undo leaves the pre-migration areas intact.
    let Some((server, db)) = setup_with_db().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    // Paint two non-overlapping areas via the API (creates rated_areas + paint_events).
    let poly_a = json!({
        "type": "Polygon",
        "coordinates": [[[13.40, 52.50], [13.41, 52.50], [13.41, 52.51], [13.40, 52.51], [13.40, 52.50]]]
    });
    let poly_b = json!({
        "type": "Polygon",
        "coordinates": [[[13.42, 52.50], [13.43, 52.50], [13.43, 52.51], [13.42, 52.51], [13.42, 52.50]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_a, "value": 3 }))
        .await;
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_b, "value": 1 }))
        .await;

    // Simulate pre-migration state: delete paint_events for this user, leaving
    // only the rated_areas rows (as they would exist before migration 006).
    let (hname, hval) = with_session(&session);
    let me: Value = server
        .get("/api/auth/me")
        .add_header(hname, hval)
        .await
        .json();
    let user_id: uuid::Uuid = me["id"].as_str().unwrap().parse().unwrap();

    sqlx::query("DELETE FROM paint_events WHERE user_id = $1")
        .bind(user_id)
        .execute(&db)
        .await
        .unwrap();

    // Re-run the migration backfill SQL for this user.
    sqlx::query(
        r#"
        INSERT INTO paint_events (user_id, seq, geometry, value, status)
        SELECT
            user_id,
            ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY id) AS seq,
            geometry,
            value,
            0 AS status
        FROM rated_areas
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .execute(&db)
    .await
    .unwrap();

    // Verify the backfill produced 2 events.
    let event_count: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM paint_events WHERE user_id = $1")
            .bind(user_id)
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!(
        event_count, 2,
        "backfill should have created one event per rated_area"
    );

    // Now paint a third area (seq 3 will be assigned).
    let poly_c = json!({
        "type": "Polygon",
        "coordinates": [[[13.44, 52.50], [13.45, 52.50], [13.45, 52.51], [13.44, 52.51], [13.44, 52.50]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": poly_c, "value": 7 }))
        .await;

    // Undo the third paint. The rebuild should replay the 2 backfilled events
    // and restore rated_areas to exactly poly_a and poly_b.
    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await;

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    let features = overlay["features"].as_array().unwrap();
    assert_eq!(
        features.len(),
        2,
        "undo should restore the 2 pre-migration areas, not destroy them"
    );
    let values: std::collections::HashSet<i64> = features
        .iter()
        .map(|f| f["properties"]["value"].as_i64().unwrap())
        .collect();
    assert!(values.contains(&3) && values.contains(&1));
}

#[tokio::test]
async fn undo_history_cap_squashes_oldest_events() {
    let Some((server, db)) = setup_with_db_and_cap(3).await else {
        return;
    };
    let session = create_anonymous(&server).await;
    let user_id: uuid::Uuid = {
        let (hname, hval) = with_session(&session);
        let me: Value = server
            .get("/api/auth/me")
            .add_header(hname, hval)
            .await
            .json();
        me["id"].as_str().unwrap().parse().unwrap()
    };

    // Paint 5 non-overlapping squares. cap = 3 → oldest 2 squashed into baseline.
    let values = [-7, -3, 1, 3, 7];
    for (i, v) in values.iter().enumerate() {
        let x0 = 13.40 + (i as f64) * 0.01;
        let polygon = json!({
            "type": "Polygon",
            "coordinates": [[[x0, 52.50], [x0 + 0.005, 52.50], [x0 + 0.005, 52.505], [x0, 52.505], [x0, 52.50]]]
        });
        let (hname, hval) = with_session(&session);
        server
            .put("/api/ratings/paint")
            .add_header(hname, hval)
            .json(&json!({ "geometry": polygon, "value": v }))
            .await
            .assert_status_ok();
    }

    let active: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM paint_events WHERE user_id = $1 AND status = 0")
            .bind(user_id)
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!(active, 3, "active paint_events should be capped at 3");

    let baseline: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM rated_areas_baseline WHERE user_id = $1")
            .bind(user_id)
            .fetch_one(&db)
            .await
            .unwrap();
    assert!(
        baseline > 0,
        "baseline should have received squashed events"
    );

    // Overlay still shows all 5 painted areas — squash is transparent.
    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.6,52.6")
        .add_header(hname, hval)
        .await
        .json();
    let features = overlay["features"].as_array().unwrap();
    assert_eq!(
        features.len(),
        5,
        "all painted areas must survive the squash"
    );
}

#[tokio::test]
async fn undo_stops_at_cap_and_preserves_baseline() {
    let Some((server, _db)) = setup_with_db_and_cap(3).await else {
        return;
    };
    let session = create_anonymous(&server).await;

    // Paint 5 strokes; cap is 3, so 2 are squashed into baseline (immutable).
    for i in 0..5 {
        let x0 = 13.40 + (i as f64) * 0.01;
        let polygon = json!({
            "type": "Polygon",
            "coordinates": [[[x0, 52.50], [x0 + 0.005, 52.50], [x0 + 0.005, 52.505], [x0, 52.505], [x0, 52.50]]]
        });
        let (hname, hval) = with_session(&session);
        server
            .put("/api/ratings/paint")
            .add_header(hname, hval)
            .json(&json!({ "geometry": polygon, "value": 3 }))
            .await;
    }

    // Undo 3 times — should succeed each time.
    for _ in 0..3 {
        let (hname, hval) = with_session(&session);
        let resp: Value = server
            .post("/api/ratings/undo")
            .add_header(hname, hval)
            .await
            .json();
        assert_eq!(resp["can_redo"], true);
    }

    // 4th undo is a no-op: can_undo=false, baseline (first 2 strokes) remains.
    let (hname, hval) = with_session(&session);
    let resp: Value = server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(resp["can_undo"], false, "cannot undo past the cap");

    // The two squashed (baseline) areas are still painted.
    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.6,52.6")
        .add_header(hname, hval)
        .await
        .json();
    let features = overlay["features"].as_array().unwrap();
    assert_eq!(
        features.len(),
        2,
        "pre-cap events should be permanently baked into baseline"
    );
}

#[tokio::test]
async fn redo_after_squash_still_restores_latest_state() {
    let Some((server, _db)) = setup_with_db_and_cap(3).await else {
        return;
    };
    let session = create_anonymous(&server).await;

    for i in 0..5 {
        let x0 = 13.40 + (i as f64) * 0.01;
        let polygon = json!({
            "type": "Polygon",
            "coordinates": [[[x0, 52.50], [x0 + 0.005, 52.50], [x0 + 0.005, 52.505], [x0, 52.505], [x0, 52.50]]]
        });
        let (hname, hval) = with_session(&session);
        server
            .put("/api/ratings/paint")
            .add_header(hname, hval)
            .json(&json!({ "geometry": polygon, "value": 3 }))
            .await;
    }

    // Undo 3, then redo 3 — state should match post-stroke-5.
    for _ in 0..3 {
        let (hname, hval) = with_session(&session);
        server
            .post("/api/ratings/undo")
            .add_header(hname, hval)
            .await;
    }
    for _ in 0..3 {
        let (hname, hval) = with_session(&session);
        server
            .post("/api/ratings/redo")
            .add_header(hname, hval)
            .await;
    }

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.6,52.6")
        .add_header(hname, hval)
        .await
        .json();
    let features = overlay["features"].as_array().unwrap();
    assert_eq!(features.len(), 5, "redo should restore all 5 strokes");
}

#[tokio::test]
async fn backfill_trims_legacy_users_over_cap() {
    let Some((server, db)) = setup_with_db_and_cap(3).await else {
        return;
    };
    let session = create_anonymous(&server).await;
    let user_id: uuid::Uuid = {
        let (hname, hval) = with_session(&session);
        let me: Value = server
            .get("/api/auth/me")
            .add_header(hname, hval)
            .await
            .json();
        me["id"].as_str().unwrap().parse().unwrap()
    };

    // Hand-seed 6 paint_events rows directly to simulate a legacy user.
    for seq in 1..=6i64 {
        let x0 = 13.40 + (seq as f64) * 0.01;
        let polygon = format!(
            r#"{{"type":"Polygon","coordinates":[[[{x0},52.50],[{},52.50],[{},52.505],[{x0},52.505],[{x0},52.50]]]}}"#,
            x0 + 0.005,
            x0 + 0.005
        );
        sqlx::query(
            r#"
            INSERT INTO paint_events (user_id, seq, geometry, value, status)
            SELECT $1, $2, ST_GeomFromGeoJSON($3), 3, 0
            "#,
        )
        .bind(user_id)
        .bind(seq)
        .bind(&polygon)
        .execute(&db)
        .await
        .unwrap();
    }

    // Run the backfill helper and verify the cap is enforced.
    beebeebike_backend::ratings::backfill_baseline_once(&db, 3)
        .await
        .unwrap();

    let active: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM paint_events WHERE user_id = $1 AND status = 0")
            .bind(user_id)
            .fetch_one(&db)
            .await
            .unwrap();
    assert_eq!(active, 3);
    let baseline: i64 =
        sqlx::query_scalar("SELECT COUNT(*) FROM rated_areas_baseline WHERE user_id = $1")
            .bind(user_id)
            .fetch_one(&db)
            .await
            .unwrap();
    assert!(
        baseline >= 3,
        "squashed events should populate the baseline"
    );
}

// ---------------------------------------------------------------------------
// Cross-user isolation
// ---------------------------------------------------------------------------

#[tokio::test]
async fn users_cannot_see_each_others_areas() {
    let Some(server) = setup().await else {
        return;
    };

    let session1 = create_anonymous(&server).await;
    let session2 = create_anonymous(&server).await;

    let polygon = json!({
        "type": "Polygon",
        "coordinates": [[[13.4, 52.5], [13.41, 52.5], [13.41, 52.51], [13.4, 52.51], [13.4, 52.5]]]
    });

    // User 1 paints an area
    let (hname, hval) = with_session(&session1);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": polygon, "value": 7 }))
        .await
        .assert_status_ok();

    // User 2 should see no areas
    let (hname, hval) = with_session(&session2);
    let resp = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await;
    resp.assert_status_ok();

    let body: Value = resp.json();
    assert_eq!(body["features"].as_array().unwrap().len(), 0);
}

#[tokio::test]
async fn undo_handles_self_intersecting_polygon() {
    // Regression: prod 500 from `ST_Difference` on self-intersecting geometry
    // during undo's rebuild. Bowtie-shaped input must be sanitized on write so
    // later clipping and rebuild never see an invalid polygon.
    let Some(server) = setup().await else {
        return;
    };
    let session = create_anonymous(&server).await;

    // Bowtie (figure-eight) — two triangles crossing at (13.405, 52.505).
    let bowtie = json!({
        "type": "Polygon",
        "coordinates": [[
            [13.40, 52.50],
            [13.41, 52.51],
            [13.41, 52.50],
            [13.40, 52.51],
            [13.40, 52.50]
        ]]
    });

    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": bowtie, "value": 3 }))
        .await
        .assert_status_ok();

    // Paint a second, overlapping, valid polygon — exercises ST_Difference
    // against whatever the bowtie was normalized to.
    let overlap = json!({
        "type": "Polygon",
        "coordinates": [[[13.405, 52.505], [13.42, 52.505], [13.42, 52.52], [13.405, 52.52], [13.405, 52.505]]]
    });
    let (hname, hval) = with_session(&session);
    server
        .put("/api/ratings/paint")
        .add_header(hname, hval)
        .json(&json!({ "geometry": overlap, "value": -3 }))
        .await
        .assert_status_ok();

    // Undo the second paint — triggers rebuild_rated_areas_for_user, which
    // replays the bowtie event through apply_paint. Must not 500.
    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await
        .assert_status_ok();

    // Undo the bowtie paint too — rebuild with zero events.
    let (hname, hval) = with_session(&session);
    server
        .post("/api/ratings/undo")
        .add_header(hname, hval)
        .await
        .assert_status_ok();

    let (hname, hval) = with_session(&session);
    let overlay: Value = server
        .get("/api/ratings?bbox=13.3,52.4,13.5,52.6")
        .add_header(hname, hval)
        .await
        .json();
    assert_eq!(overlay["features"].as_array().unwrap().len(), 0);
}

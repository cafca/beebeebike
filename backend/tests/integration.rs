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
use beebeebike_backend::{build_router, config::Config, AppState};
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
    };

    let state = Arc::new(AppState {
        db,
        config,
        http_client: reqwest::Client::new(),
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

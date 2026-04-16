use axum::{extract::State, http::HeaderMap, Json};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;
use std::sync::Arc;

use crate::{auth::require_auth, errors::AppError, AppState};

// ---------------------------------------------------------------------------
// Request / response types
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
pub struct RouteRequest {
    pub origin: [f64; 2],      // [lng, lat]
    pub destination: [f64; 2], // [lng, lat]
    pub rating_weight: Option<f64>,
    pub distance_influence: Option<f64>,
}

#[derive(Serialize)]
pub struct RouteResponse {
    pub geometry: Value,
    pub distance: f64,
    pub time: f64,
}

// ---------------------------------------------------------------------------
// DB row types
// ---------------------------------------------------------------------------

#[derive(FromRow)]
struct RatedAreaRow {
    pub id: i64,
    pub geometry: String,
    pub value: i16,
}

// ---------------------------------------------------------------------------
// GraphHopper request modes
// ---------------------------------------------------------------------------

#[derive(Clone, Copy)]
enum GraphhopperMode {
    Preview,
    Navigate,
}

impl GraphhopperMode {
    fn upstream_path(self) -> &'static str {
        match self {
            // The upstream navigation resource provided by
            // israelhikingmap/graphhopper (GraphHopper Navigation extension)
            // is mounted at `POST /navigate`. It requires `type: "mapbox"` in
            // the body and returns voice/banner instructions by default — all
            // three flags (voice_instructions, banner_instructions,
            // roundabout_exits) are enabled automatically and must NOT be set
            // explicitly or the upstream rejects the request.
            Self::Preview => "/route",
            Self::Navigate => "/navigate",
        }
    }

    fn apply_mode_flags(self, request: &mut serde_json::Map<String, Value>) {
        if matches!(self, Self::Navigate) {
            // Required by GraphHopper's navigation resource. Without this the
            // upstream returns `400 Currently type=mapbox required.`
            request.insert("type".into(), json!("mapbox"));
        }
    }
}

// ---------------------------------------------------------------------------
// Rating-to-priority mapping
// ---------------------------------------------------------------------------

const RATING_UNIT_PRIORITY_FACTOR: f64 = 1.72;

/// Map a signed rating value and user preference strength to a GraphHopper
/// priority multiplier. Ratings are interpreted as effect units: +3 is three
/// times as strong as +1 in log-priority space, while -3 is the equivalent
/// avoidance strength. The preference slider scales that signed effect after
/// the rating magnitude is applied.
fn rating_to_priority(value: i16, preference_strength: f64) -> f64 {
    let rating_effect = match value {
        -7 | -3 | -1 | 0 | 1 | 3 | 7 => value as f64,
        _ => 0.0,
    };

    RATING_UNIT_PRIORITY_FACTOR.powf(rating_effect * preference_strength.clamp(0.0, 1.0))
}

fn resolve_distance_influence(requested: Option<f64>, default: f64) -> f64 {
    requested.unwrap_or(default).clamp(0.0, 100.0)
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

async fn load_rated_areas(
    state: &AppState,
    user_id: uuid::Uuid,
    origin: [f64; 2],
    destination: [f64; 2],
) -> Result<Vec<RatedAreaRow>, AppError> {
    // Build bounding box around origin+destination with ~2km margin (0.02 deg)
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

/// POST /api/route
///
/// Accepts origin and destination coordinates, loads the authenticated user's
/// rated areas intersecting the route corridor, builds a GraphHopper Custom
/// Model request, and returns the route geometry with distance and time.
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

    Ok(Json(RouteResponse {
        geometry,
        distance,
        time,
    }))
}

/// POST /api/navigate
///
/// Accepts the same request shape as `POST /api/route`, loads the user's
/// rated areas, builds a GraphHopper Custom Model request, and forwards it to
/// GraphHopper's navigation endpoint. The upstream response (Mapbox
/// Directions-compatible JSON with voice and banner instructions) is returned
/// verbatim so the Flutter `ferrostar_flutter` plugin can consume it
/// directly.
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

#[cfg(test)]
mod tests {
    use super::*;

    fn assert_close(actual: f64, expected: f64) {
        assert!(
            (actual - expected).abs() < 1e-12,
            "expected {actual} to be close to {expected}"
        );
    }

    #[test]
    fn rating_values_are_signed_effect_units() {
        assert_close(
            rating_to_priority(1, 1.0).powi(3),
            rating_to_priority(3, 1.0),
        );
        assert_close(
            rating_to_priority(1, 1.0).powi(7),
            rating_to_priority(7, 1.0),
        );
        assert_close(
            rating_to_priority(-1, 1.0).powi(3),
            rating_to_priority(-3, 1.0),
        );
        assert_close(
            rating_to_priority(1, 1.0) * rating_to_priority(-1, 1.0),
            1.0,
        );
    }

    #[test]
    fn rating_to_priority_zero_weight_neutralizes() {
        // weight=0.0 means base^0 = 1.0 for any rating
        for value in [-7, -3, -1, 1, 3, 7] {
            let result = rating_to_priority(value, 0.0);
            assert!(
                (result - 1.0).abs() < 1e-9,
                "rating_to_priority({value}, 0.0) should be 1.0, got {result}"
            );
        }
    }

    #[test]
    fn rating_to_priority_half_weight() {
        let result = rating_to_priority(7, 0.5);
        let expected = RATING_UNIT_PRIORITY_FACTOR.powf(7.0 * 0.5);
        assert_close(result, expected);
    }

    #[test]
    fn preference_strength_scales_rating_effect_after_magnitude() {
        assert_close(
            rating_to_priority(7, 0.5),
            RATING_UNIT_PRIORITY_FACTOR.powf(7.0 * 0.5),
        );
        assert_close(
            rating_to_priority(-3, 0.25),
            RATING_UNIT_PRIORITY_FACTOR.powf(-3.0 * 0.25),
        );
    }

    #[test]
    fn rating_to_priority_clamps_weight_above_one() {
        let at_one = rating_to_priority(7, 1.0);
        let above = rating_to_priority(7, 5.0);
        assert!(
            (at_one - above).abs() < 1e-9,
            "weight > 1.0 should clamp to 1.0"
        );
    }

    #[test]
    fn rating_to_priority_clamps_negative_weight() {
        let at_zero = rating_to_priority(7, 0.0);
        let below = rating_to_priority(7, -3.0);
        assert!(
            (at_zero - below).abs() < 1e-9,
            "weight < 0.0 should clamp to 0.0"
        );
    }

    #[test]
    fn rating_to_priority_unknown_value_returns_one() {
        // Any value not in the match table should return 1.0
        for value in [0, 2, -2, 5, 100, -100] {
            let result = rating_to_priority(value, 1.0);
            assert!(
                (result - 1.0).abs() < 1e-9,
                "rating_to_priority({value}, 1.0) should be 1.0, got {result}"
            );
        }
    }

    #[test]
    fn negative_ratings_reduce_priority() {
        for value in [-7, -3, -1] {
            let result = rating_to_priority(value, 1.0);
            assert!(
                result < 1.0,
                "negative rating {value} should produce priority < 1.0, got {result}"
            );
        }
    }

    #[test]
    fn positive_ratings_increase_priority() {
        for value in [1, 3, 7] {
            let result = rating_to_priority(value, 1.0);
            assert!(
                result > 1.0,
                "positive rating {value} should produce priority > 1.0, got {result}"
            );
        }
    }

    #[test]
    fn priority_monotonically_increases_with_rating() {
        let values = [-7, -3, -1, 1, 3, 7];
        let priorities: Vec<f64> = values.iter().map(|&v| rating_to_priority(v, 1.0)).collect();
        for i in 1..priorities.len() {
            assert!(
                priorities[i] > priorities[i - 1],
                "priority for {} ({}) should be > priority for {} ({})",
                values[i],
                priorities[i],
                values[i - 1],
                priorities[i - 1]
            );
        }
    }

    #[test]
    fn distance_influence_uses_request_or_default_and_clamps() {
        assert!((resolve_distance_influence(Some(70.0), 25.0) - 70.0).abs() < 1e-9);
        assert!((resolve_distance_influence(None, 70.0) - 70.0).abs() < 1e-9);
        assert!((resolve_distance_influence(Some(-10.0), 70.0) - 0.0).abs() < 1e-9);
        assert!((resolve_distance_influence(Some(130.0), 70.0) - 100.0).abs() < 1e-9);
    }
}

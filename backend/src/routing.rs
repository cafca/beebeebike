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
// Rating-to-priority mapping
// ---------------------------------------------------------------------------

/// Map a rating value and weight to a GraphHopper priority multiplier.
/// Base values are intentionally non-linear: the light colors nudge, the
/// middle colors pull, and the strongest colors should materially reshape
/// routes. Weight is applied as an exponent so 0.0 neutralizes every rating
/// and 1.0 preserves the full table.
fn rating_to_priority(value: i16, weight: f64) -> f64 {
    let base: f64 = match value {
        -7 => 0.29,
        -3 => 0.56,
        -1 => 0.83,
        1 => 1.20,
        3 => 1.80,
        7 => 3.50,
        _ => 1.0,
    };
    base.powf(weight.clamp(0.0, 1.0))
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

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

    let [orig_lng, orig_lat] = body.origin;
    let [dest_lng, dest_lat] = body.destination;
    let rating_weight = body
        .rating_weight
        .unwrap_or(state.config.rating_weight)
        .clamp(0.0, 1.0);

    // Build bounding box around origin+destination with ~2km margin (0.02 degrees)
    const MARGIN: f64 = 0.02;
    let west = orig_lng.min(dest_lng) - MARGIN;
    let south = orig_lat.min(dest_lat) - MARGIN;
    let east = orig_lng.max(dest_lng) + MARGIN;
    let north = orig_lat.max(dest_lat) + MARGIN;

    // Load user's rated areas intersecting the bounding box
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

    // Build GraphHopper request
    let mut gh_request = json!({
        "points": [[orig_lng, orig_lat], [dest_lng, dest_lat]],
        "profile": "bike",
        "locale": "de",
        "points_encoded": false,
    });

    if !rows.is_empty() {
        // Build priority statements and area features
        let mut priority_statements: Vec<Value> = Vec::new();
        let mut features: Vec<Value> = Vec::new();

        for row in &rows {
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

        let gh_obj = gh_request.as_object_mut().unwrap();
        gh_obj.insert("ch.disable".to_string(), json!(true));
        gh_obj.insert(
            "custom_model".to_string(),
            json!({
                "priority": priority_statements,
                "distance_influence": state.config.distance_influence,
                "areas": {
                    "type": "FeatureCollection",
                    "features": features,
                },
            }),
        );
    }

    // POST to GraphHopper
    let gh_url = format!("{}/route", state.config.graphhopper_url);
    let gh_response = state
        .http_client
        .post(&gh_url)
        .json(&gh_request)
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

    let gh_json: Value = gh_response
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("failed to parse GraphHopper response: {e}")))?;

    // Extract paths[0]
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rating_to_priority_known_values_at_full_weight() {
        let cases = [
            (-7, 0.29),
            (-3, 0.56),
            (-1, 0.83),
            (1, 1.20),
            (3, 1.80),
            (7, 3.50),
        ];
        for (value, expected) in cases {
            let result = rating_to_priority(value, 1.0);
            assert!(
                (result - expected).abs() < 1e-9,
                "rating_to_priority({value}, 1.0) = {result}, expected {expected}"
            );
        }
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
        // weight=0.5 → base^0.5 = sqrt(base)
        let result = rating_to_priority(7, 0.5);
        let expected = 3.5_f64.sqrt();
        assert!(
            (result - expected).abs() < 1e-9,
            "rating_to_priority(7, 0.5) = {result}, expected {expected}"
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
}

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
/// Base values: -7 → 0.05, -3 → 0.3, -1 → 0.7, 1 → 1.3, 3 → 2.0, 7 → 3.0
/// Weight is applied as: 1.0 + (base - 1.0) * weight
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
    1.0 + (base - 1.0) * weight
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

            let multiplier = rating_to_priority(row.value, state.config.rating_weight);

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

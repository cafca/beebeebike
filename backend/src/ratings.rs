use axum::{
    extract::{Query, State},
    http::HeaderMap,
    Json,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sqlx::FromRow;
use std::sync::Arc;
use uuid::Uuid;

use crate::{auth::require_auth, errors::AppError, AppState};

// ---------------------------------------------------------------------------
// Request / response types
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
pub struct PaintRequest {
    pub geometry: Value,
    pub value: i32,
}

#[derive(Serialize)]
pub struct PaintResponse {
    pub created_id: Option<i64>,
    pub clipped_count: i64,
    pub deleted_count: i64,
}

#[derive(Deserialize)]
pub struct BboxQuery {
    pub bbox: String,
}

// ---------------------------------------------------------------------------
// DB row types
// ---------------------------------------------------------------------------

#[derive(FromRow)]
struct RatedAreaRow {
    pub id: i64,
    pub geometry: String,
    pub value: i32,
}

#[derive(FromRow)]
struct CreatedRow {
    pub id: i64,
}

#[derive(FromRow)]
struct CountRow {
    pub count: i64,
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// PUT /api/ratings/paint
///
/// Accepts a GeoJSON Polygon and a rating value. Clips existing polygons
/// belonging to the authenticated user that overlap with the new polygon,
/// then inserts the new polygon (unless value == 0, eraser mode).
pub async fn paint(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<PaintRequest>,
) -> Result<Json<PaintResponse>, AppError> {
    let user_id: Uuid = require_auth(&state.db, &headers).await?;

    // Validate value is in allowed set
    if ![-7, -3, -1, 0, 1, 3, 7].contains(&body.value) {
        return Err(AppError::BadRequest(
            "value must be one of: -7, -3, -1, 0, 1, 3, 7".into(),
        ));
    }

    let geometry_json = body.geometry.to_string();

    let mut tx = state.db.begin().await?;

    // Step 1: Delete fully contained polygons and count them
    let deleted_row = sqlx::query_as::<_, CountRow>(
        r#"
        WITH deleted AS (
            DELETE FROM rated_areas
            WHERE user_id = $1
              AND ST_Contains(ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), geometry)
            RETURNING 1
        )
        SELECT COUNT(*) AS count FROM deleted
        "#,
    )
    .bind(user_id)
    .bind(&geometry_json)
    .fetch_one(&mut *tx)
    .await?;

    let deleted_count = deleted_row.count;

    // Step 2: For overlapping polygons, delete them and re-insert clipped fragments.
    // ST_Difference can return MultiPolygon or GeometryCollection, so we use
    // ST_Dump to split into individual geometries and filter to valid Polygons.
    let clipped_row = sqlx::query_as::<_, CountRow>(
        r#"
        WITH overlapping AS (
            DELETE FROM rated_areas
            WHERE user_id = $1
              AND ST_Intersects(geometry, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326))
            RETURNING user_id, value, ST_Difference(geometry, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326)) AS clipped
        ),
        fragments AS (
            SELECT user_id, value, (ST_Dump(clipped)).geom AS geom
            FROM overlapping
            WHERE NOT ST_IsEmpty(clipped)
        ),
        inserted AS (
            INSERT INTO rated_areas (user_id, geometry, value)
            SELECT user_id, geom, value
            FROM fragments
            WHERE ST_GeometryType(geom) = 'ST_Polygon'
              AND ST_Area(geom) > 0
            RETURNING 1
        )
        SELECT COUNT(*) AS count FROM overlapping
        "#,
    )
    .bind(user_id)
    .bind(&geometry_json)
    .fetch_one(&mut *tx)
    .await?;

    let clipped_count = clipped_row.count;

    // Step 3: Insert new polygon (skip if value == 0, eraser mode)
    let created_id = if body.value != 0 {
        let row = sqlx::query_as::<_, CreatedRow>(
            r#"
            INSERT INTO rated_areas (user_id, geometry, value)
            VALUES ($1, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), $3)
            RETURNING id
            "#,
        )
        .bind(user_id)
        .bind(&geometry_json)
        .bind(body.value)
        .fetch_one(&mut *tx)
        .await?;
        Some(row.id)
    } else {
        None
    };

    tx.commit().await?;

    Ok(Json(PaintResponse {
        created_id,
        clipped_count,
        deleted_count,
    }))
}

/// GET /api/ratings?bbox=west,south,east,north
///
/// Returns the authenticated user's rated polygons as a GeoJSON FeatureCollection
/// filtered to those intersecting the given bounding box.
pub async fn get_overlay(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Query(params): Query<BboxQuery>,
) -> Result<Json<Value>, AppError> {
    let user_id: Uuid = require_auth(&state.db, &headers).await?;

    // Parse bbox: "west,south,east,north"
    let parts: Vec<&str> = params.bbox.split(',').collect();
    if parts.len() != 4 {
        return Err(AppError::BadRequest(
            "bbox must be in the format: west,south,east,north".into(),
        ));
    }

    let parse_coord = |s: &str| {
        s.trim()
            .parse::<f64>()
            .map_err(|_| AppError::BadRequest(format!("invalid bbox coordinate: {s}")))
    };

    let west = parse_coord(parts[0])?;
    let south = parse_coord(parts[1])?;
    let east = parse_coord(parts[2])?;
    let north = parse_coord(parts[3])?;

    let rows = sqlx::query_as::<_, RatedAreaRow>(
        r#"
        SELECT id, ST_AsGeoJSON(geometry) AS geometry, value
        FROM rated_areas
        WHERE user_id = $1
          AND ST_Intersects(geometry, ST_MakeEnvelope($2, $3, $4, $5, 4326))
        "#,
    )
    .bind(user_id)
    .bind(west)
    .bind(south)
    .bind(east)
    .bind(north)
    .fetch_all(&state.db)
    .await?;

    let features: Vec<Value> = rows
        .into_iter()
        .map(|row| {
            let geometry: Value = serde_json::from_str(&row.geometry).unwrap_or(Value::Null);
            json!({
                "type": "Feature",
                "id": row.id,
                "properties": { "value": row.value },
                "geometry": geometry,
            })
        })
        .collect();

    Ok(Json(json!({
        "type": "FeatureCollection",
        "features": features,
    })))
}

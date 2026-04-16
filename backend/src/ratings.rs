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
    pub target_id: Option<i64>,
}

#[derive(Serialize)]
pub struct PaintResponse {
    pub created_id: Option<i64>,
    pub clipped_count: i64,
    pub deleted_count: i64,
    pub can_undo: bool,
    pub can_redo: bool,
}

#[derive(Serialize)]
pub struct UndoRedoResponse {
    pub can_undo: bool,
    pub can_redo: bool,
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
    pub value: i16,
}

#[derive(FromRow)]
struct CreatedRow {
    pub id: i64,
}

#[derive(FromRow)]
struct CountRow {
    pub count: i64,
}

#[derive(FromRow)]
struct SeqRow {
    pub seq: i64,
}

#[derive(FromRow)]
struct EventRow {
    pub id: i64,
    pub geometry: String,
    pub value: i16,
}

// ---------------------------------------------------------------------------
// Validation helpers
// ---------------------------------------------------------------------------

const ALLOWED_VALUES: [i32; 7] = [-7, -3, -1, 0, 1, 3, 7];

fn validate_rating_value(value: i32) -> Result<(), AppError> {
    if !ALLOWED_VALUES.contains(&value) {
        return Err(AppError::BadRequest(
            "value must be one of: -7, -3, -1, 0, 1, 3, 7".into(),
        ));
    }
    Ok(())
}

fn parse_bbox(bbox: &str) -> Result<(f64, f64, f64, f64), AppError> {
    let parts: Vec<&str> = bbox.split(',').collect();
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

    Ok((
        parse_coord(parts[0])?,
        parse_coord(parts[1])?,
        parse_coord(parts[2])?,
        parse_coord(parts[3])?,
    ))
}

// ---------------------------------------------------------------------------
// Core helpers
// ---------------------------------------------------------------------------

/// Apply a single paint operation to `rated_areas` within an open transaction.
/// This is the clipping logic extracted so it can be called both from the
/// paint endpoint and from `rebuild_rated_areas_for_user`.
async fn apply_paint(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user_id: Uuid,
    geometry_json: &str,
    value: i32,
) -> Result<(i64, i64), AppError> {
    // Step 1: Delete fully covered polygons
    let deleted_row = sqlx::query_as::<_, CountRow>(
        r#"
        WITH deleted AS (
            DELETE FROM rated_areas
            WHERE user_id = $1
              AND ST_Covers(ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), geometry)
            RETURNING 1
        )
        SELECT COUNT(*) AS count FROM deleted
        "#,
    )
    .bind(user_id)
    .bind(geometry_json)
    .fetch_one(&mut **tx)
    .await?;

    // Step 2: Clip overlapping polygons
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
    .bind(geometry_json)
    .fetch_one(&mut **tx)
    .await?;

    // Step 3: Insert new polygon (skip if value == 0, eraser mode)
    if value != 0 {
        sqlx::query(
            r#"
            INSERT INTO rated_areas (user_id, geometry, value)
            VALUES ($1, ST_SetSRID(ST_GeomFromGeoJSON($2), 4326), $3)
            "#,
        )
        .bind(user_id)
        .bind(geometry_json)
        .bind(value)
        .execute(&mut **tx)
        .await?;
    }

    Ok((deleted_row.count, clipped_row.count))
}

/// Wipe a user's `rated_areas` and rebuild by replaying all active paint events.
async fn rebuild_rated_areas_for_user(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user_id: Uuid,
) -> Result<(), AppError> {
    sqlx::query("DELETE FROM rated_areas WHERE user_id = $1")
        .bind(user_id)
        .execute(&mut **tx)
        .await?;

    let events = sqlx::query_as::<_, EventRow>(
        r#"
        SELECT id, ST_AsGeoJSON(geometry) AS geometry, value
        FROM paint_events
        WHERE user_id = $1 AND status = 0
        ORDER BY seq
        "#,
    )
    .bind(user_id)
    .fetch_all(&mut **tx)
    .await?;

    for event in events {
        apply_paint(tx, user_id, &event.geometry, event.value as i32).await?;
    }

    Ok(())
}

async fn history_state(db: &sqlx::PgPool, user_id: Uuid) -> Result<(bool, bool), AppError> {
    let can_undo = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM paint_events WHERE user_id = $1 AND status = 0)",
    )
    .bind(user_id)
    .fetch_one(db)
    .await?;

    let can_redo = sqlx::query_scalar::<_, bool>(
        "SELECT EXISTS(SELECT 1 FROM paint_events WHERE user_id = $1 AND status = 1)",
    )
    .bind(user_id)
    .fetch_one(db)
    .await?;

    Ok((can_undo, can_redo))
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

/// PUT /api/ratings/paint
pub async fn paint(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<PaintRequest>,
) -> Result<Json<PaintResponse>, AppError> {
    let user_id: Uuid = require_auth(&state.db, &headers).await?;

    validate_rating_value(body.value)?;

    let geometry_json = body.geometry.to_string();

    let mut tx = state.db.begin().await?;

    if let Some(target_id) = body.target_id {
        let result = if body.value == 0 {
            sqlx::query(
                r#"
                DELETE FROM rated_areas
                WHERE user_id = $1
                  AND id = $2
                "#,
            )
            .bind(user_id)
            .bind(target_id)
            .execute(&mut *tx)
            .await?
        } else {
            sqlx::query(
                r#"
                UPDATE rated_areas
                SET value = $3,
                    updated_at = now()
                WHERE user_id = $1
                  AND id = $2
                "#,
            )
            .bind(user_id)
            .bind(target_id)
            .bind(body.value)
            .execute(&mut *tx)
            .await?
        };

        let affected_count = result.rows_affected() as i64;
        if affected_count == 0 {
            return Err(AppError::NotFound);
        }

        tx.commit().await?;

        let (can_undo, can_redo) = history_state(&state.db, user_id).await?;
        return Ok(Json(PaintResponse {
            created_id: None,
            clipped_count: 0,
            deleted_count: if body.value == 0 { affected_count } else { 0 },
            can_undo,
            can_redo,
        }));
    }

    // Clear redo stack: any undone events are discarded when a new paint arrives
    sqlx::query("DELETE FROM paint_events WHERE user_id = $1 AND status = 1")
        .bind(user_id)
        .execute(&mut *tx)
        .await?;

    // Allocate the next sequence number
    let seq_row = sqlx::query_as::<_, SeqRow>(
        "SELECT COALESCE(MAX(seq), 0) + 1 AS seq FROM paint_events WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_one(&mut *tx)
    .await?;

    // Record the event
    sqlx::query(
        r#"
        INSERT INTO paint_events (user_id, seq, geometry, value, status)
        VALUES ($1, $2, ST_SetSRID(ST_GeomFromGeoJSON($3), 4326), $4, 0)
        "#,
    )
    .bind(user_id)
    .bind(seq_row.seq)
    .bind(&geometry_json)
    .bind(body.value)
    .execute(&mut *tx)
    .await?;

    // Apply to the derived cache
    let (deleted_count, clipped_count) =
        apply_paint(&mut tx, user_id, &geometry_json, body.value).await?;

    // Fetch the id of the newly created rated_area (if any)
    let created_id = if body.value != 0 {
        sqlx::query_as::<_, CreatedRow>(
            "SELECT id FROM rated_areas WHERE user_id = $1 ORDER BY id DESC LIMIT 1",
        )
        .bind(user_id)
        .fetch_optional(&mut *tx)
        .await?
        .map(|r| r.id)
    } else {
        None
    };

    tx.commit().await?;

    let (can_undo, can_redo) = history_state(&state.db, user_id).await?;
    Ok(Json(PaintResponse {
        created_id,
        clipped_count,
        deleted_count,
        can_undo,
        can_redo,
    }))
}

/// POST /api/ratings/undo
pub async fn undo(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<UndoRedoResponse>, AppError> {
    let user_id: Uuid = require_auth(&state.db, &headers).await?;

    let mut tx = state.db.begin().await?;

    // Mark the most recent active event as undone
    let updated = sqlx::query_scalar::<_, i64>(
        r#"
        UPDATE paint_events SET status = 1
        WHERE id = (
            SELECT id FROM paint_events
            WHERE user_id = $1 AND status = 0
            ORDER BY seq DESC
            LIMIT 1
        )
        RETURNING id
        "#,
    )
    .bind(user_id)
    .fetch_optional(&mut *tx)
    .await?;

    if updated.is_some() {
        rebuild_rated_areas_for_user(&mut tx, user_id).await?;
    }

    tx.commit().await?;

    let (can_undo, can_redo) = history_state(&state.db, user_id).await?;
    Ok(Json(UndoRedoResponse { can_undo, can_redo }))
}

/// POST /api/ratings/redo
pub async fn redo(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<UndoRedoResponse>, AppError> {
    let user_id: Uuid = require_auth(&state.db, &headers).await?;

    let mut tx = state.db.begin().await?;

    // Find the earliest undone event
    let event = sqlx::query_as::<_, EventRow>(
        r#"
        SELECT id, ST_AsGeoJSON(geometry) AS geometry, value
        FROM paint_events
        WHERE user_id = $1 AND status = 1
        ORDER BY seq ASC
        LIMIT 1
        "#,
    )
    .bind(user_id)
    .fetch_optional(&mut *tx)
    .await?;

    if let Some(event) = event {
        sqlx::query("UPDATE paint_events SET status = 0 WHERE id = $1")
            .bind(event.id)
            .execute(&mut *tx)
            .await?;

        apply_paint(&mut tx, user_id, &event.geometry, event.value as i32).await?;
    }

    tx.commit().await?;

    let (can_undo, can_redo) = history_state(&state.db, user_id).await?;
    Ok(Json(UndoRedoResponse { can_undo, can_redo }))
}

/// GET /api/ratings?bbox=west,south,east,north
pub async fn get_overlay(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Query(params): Query<BboxQuery>,
) -> Result<Json<Value>, AppError> {
    let user_id: Uuid = require_auth(&state.db, &headers).await?;

    let (west, south, east, north) = parse_bbox(&params.bbox)?;

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

    let (can_undo, can_redo) = history_state(&state.db, user_id).await?;

    let features: Vec<Value> = rows
        .into_iter()
        .map(|row| {
            let geometry: Value = serde_json::from_str(&row.geometry).unwrap_or(Value::Null);
            json!({
                "type": "Feature",
                "id": row.id,
                "properties": { "id": row.id, "value": row.value },
                "geometry": geometry,
            })
        })
        .collect();

    Ok(Json(json!({
        "type": "FeatureCollection",
        "features": features,
        "can_undo": can_undo,
        "can_redo": can_redo,
    })))
}

#[cfg(test)]
mod tests {
    use super::*;

    // -- validate_rating_value ------------------------------------------------

    #[test]
    fn valid_rating_values_accepted() {
        for v in [-7, -3, -1, 0, 1, 3, 7] {
            assert!(
                validate_rating_value(v).is_ok(),
                "value {v} should be valid"
            );
        }
    }

    #[test]
    fn invalid_rating_values_rejected() {
        for v in [-10, -5, -2, 2, 4, 5, 6, 8, 100] {
            assert!(
                validate_rating_value(v).is_err(),
                "value {v} should be invalid"
            );
        }
    }

    #[test]
    fn zero_is_valid_eraser() {
        assert!(validate_rating_value(0).is_ok());
    }

    // -- parse_bbox -----------------------------------------------------------

    #[test]
    fn parse_bbox_valid() {
        let (w, s, e, n) = parse_bbox("13.0,52.3,13.8,52.7").unwrap();
        assert!((w - 13.0).abs() < 1e-9);
        assert!((s - 52.3).abs() < 1e-9);
        assert!((e - 13.8).abs() < 1e-9);
        assert!((n - 52.7).abs() < 1e-9);
    }

    #[test]
    fn parse_bbox_with_whitespace() {
        let (w, s, e, n) = parse_bbox(" 13.0 , 52.3 , 13.8 , 52.7 ").unwrap();
        assert!((w - 13.0).abs() < 1e-9);
        assert!((n - 52.7).abs() < 1e-9);
        let _ = (s, e); // suppress unused warnings
    }

    #[test]
    fn parse_bbox_negative_coords() {
        let (w, s, e, n) = parse_bbox("-74.0,-40.7,-73.9,-40.6").unwrap();
        assert!(w < 0.0);
        assert!(s < 0.0);
        let _ = (e, n);
    }

    #[test]
    fn parse_bbox_too_few_parts() {
        let err = parse_bbox("13.0,52.3,13.8").unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("format")));
    }

    #[test]
    fn parse_bbox_too_many_parts() {
        let err = parse_bbox("13.0,52.3,13.8,52.7,99.0").unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("format")));
    }

    #[test]
    fn parse_bbox_empty_string() {
        let err = parse_bbox("").unwrap_err();
        assert!(matches!(err, AppError::BadRequest(_)));
    }

    #[test]
    fn parse_bbox_non_numeric() {
        let err = parse_bbox("abc,52.3,13.8,52.7").unwrap_err();
        assert!(
            matches!(err, AppError::BadRequest(msg) if msg.contains("invalid bbox coordinate"))
        );
    }
}

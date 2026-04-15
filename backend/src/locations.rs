use axum::{
    extract::State,
    http::{HeaderMap, StatusCode},
    Json,
};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use std::sync::Arc;
use uuid::Uuid;

use crate::{auth::require_auth, errors::AppError, AppState};

#[derive(Deserialize)]
pub struct SaveLocationRequest {
    pub label: String,
    pub lng: f64,
    pub lat: f64,
}

#[derive(Serialize, FromRow)]
pub struct LocationResponse {
    pub id: Uuid,
    pub name: String,
    pub label: String,
    pub lng: f64,
    pub lat: f64,
}

pub async fn get_home(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<Option<LocationResponse>>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let location = get_named_location(&state, user_id, "home").await?;

    Ok(Json(location))
}

pub async fn save_home(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<SaveLocationRequest>,
) -> Result<Json<LocationResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let location = save_named_location(&state, user_id, "home", body).await?;

    Ok(Json(location))
}

pub async fn delete_home(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<StatusCode, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;

    sqlx::query("DELETE FROM user_locations WHERE user_id = $1 AND name = 'home'")
        .bind(user_id)
        .execute(&state.db)
        .await?;

    Ok(StatusCode::NO_CONTENT)
}

async fn get_named_location(
    state: &AppState,
    user_id: Uuid,
    name: &str,
) -> Result<Option<LocationResponse>, AppError> {
    let location = sqlx::query_as::<_, LocationResponse>(
        r#"
        SELECT id, name, label, longitude AS lng, latitude AS lat
        FROM user_locations
        WHERE user_id = $1 AND name = $2
        "#,
    )
    .bind(user_id)
    .bind(name)
    .fetch_optional(&state.db)
    .await?;

    Ok(location)
}

async fn save_named_location(
    state: &AppState,
    user_id: Uuid,
    name: &str,
    body: SaveLocationRequest,
) -> Result<LocationResponse, AppError> {
    validate_location(&body)?;
    let label = body.label.trim();

    let location = sqlx::query_as::<_, LocationResponse>(
        r#"
        INSERT INTO user_locations (user_id, name, label, longitude, latitude)
        VALUES ($1, $2, $3, $4, $5)
        ON CONFLICT (user_id, name)
        DO UPDATE SET
            label = EXCLUDED.label,
            longitude = EXCLUDED.longitude,
            latitude = EXCLUDED.latitude,
            updated_at = now()
        RETURNING id, name, label, longitude AS lng, latitude AS lat
        "#,
    )
    .bind(user_id)
    .bind(name)
    .bind(label)
    .bind(body.lng)
    .bind(body.lat)
    .fetch_one(&state.db)
    .await?;

    Ok(location)
}

fn validate_location(body: &SaveLocationRequest) -> Result<(), AppError> {
    if body.label.trim().is_empty() {
        return Err(AppError::BadRequest("location label is required".into()));
    }
    if !body.lng.is_finite() || !body.lat.is_finite() {
        return Err(AppError::BadRequest(
            "location coordinates must be finite".into(),
        ));
    }
    if !(-180.0..=180.0).contains(&body.lng) || !(-90.0..=90.0).contains(&body.lat) {
        return Err(AppError::BadRequest(
            "location coordinates are out of range".into(),
        ));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_request(label: &str, lng: f64, lat: f64) -> SaveLocationRequest {
        SaveLocationRequest {
            label: label.to_string(),
            lng,
            lat,
        }
    }

    #[test]
    fn valid_location() {
        assert!(validate_location(&make_request("Home", 13.405, 52.52)).is_ok());
    }

    #[test]
    fn empty_label_rejected() {
        let err = validate_location(&make_request("", 13.405, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("label")));
    }

    #[test]
    fn whitespace_only_label_rejected() {
        let err = validate_location(&make_request("   ", 13.405, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("label")));
    }

    #[test]
    fn nan_longitude_rejected() {
        let err = validate_location(&make_request("Home", f64::NAN, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("finite")));
    }

    #[test]
    fn nan_latitude_rejected() {
        let err = validate_location(&make_request("Home", 13.405, f64::NAN)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("finite")));
    }

    #[test]
    fn infinity_rejected() {
        let err = validate_location(&make_request("Home", f64::INFINITY, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("finite")));
    }

    #[test]
    fn neg_infinity_rejected() {
        let err =
            validate_location(&make_request("Home", f64::NEG_INFINITY, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("finite")));
    }

    #[test]
    fn longitude_out_of_range() {
        let err = validate_location(&make_request("Home", 181.0, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("out of range")));

        let err = validate_location(&make_request("Home", -181.0, 52.52)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("out of range")));
    }

    #[test]
    fn latitude_out_of_range() {
        let err = validate_location(&make_request("Home", 13.405, 91.0)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("out of range")));

        let err = validate_location(&make_request("Home", 13.405, -91.0)).unwrap_err();
        assert!(matches!(err, AppError::BadRequest(msg) if msg.contains("out of range")));
    }

    #[test]
    fn boundary_coordinates_accepted() {
        assert!(validate_location(&make_request("Home", 180.0, 90.0)).is_ok());
        assert!(validate_location(&make_request("Home", -180.0, -90.0)).is_ok());
        assert!(validate_location(&make_request("Home", 0.0, 0.0)).is_ok());
    }
}

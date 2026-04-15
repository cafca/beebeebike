use axum::{
    extract::{Query, State},
    Json,
};
use serde::Deserialize;
use std::sync::Arc;

use crate::{errors::AppError, AppState};

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
        .header("User-Agent", "beebeebike/0.1 (bicycle routing app)")
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("Photon request failed: {e}")))?;

    let body: serde_json::Value = resp
        .json()
        .await
        .map_err(|e| AppError::Internal(format!("Photon parse error: {e}")))?;

    Ok(Json(body))
}

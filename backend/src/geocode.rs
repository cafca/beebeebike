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
    let bbox = &state.config.bbox;
    let bias_lon = (bbox.west + bbox.east) / 2.0;
    let bias_lat = (bbox.south + bbox.north) / 2.0;
    let url = format!(
        "{}/api?q={}&limit={}&lat={}&lon={}&bbox={}",
        state.config.photon_url,
        urlencoding::encode(&query.q),
        limit,
        bias_lat,
        bias_lon,
        bbox.to_query_string(),
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

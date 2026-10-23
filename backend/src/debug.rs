use axum::{
    body::Body,
    extract::{Path, RawQuery, State},
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
};
use std::sync::Arc;

use crate::{errors::AppError, AppState};

/// GET /api/debug/mvt/{z}/{x}/{y}
///
/// Proxies GraphHopper's `/mvt/{z}/{x}/{y}.mvt` so the browser can fetch
/// per-edge encoded values as MapboxVectorTiles for the debug overlay.
/// The raw query string is forwarded verbatim so repeated `details=` params
/// (which GraphHopper expects as a `List<String>`) survive the proxy hop.
/// Authentication is intentionally NOT required — this endpoint is dev-only
/// and exposes the same data anyone with access to the routing API can infer.
pub async fn mvt(
    State(state): State<Arc<AppState>>,
    Path((z, x, y)): Path<(u32, u32, u32)>,
    RawQuery(query): RawQuery,
) -> Result<impl IntoResponse, AppError> {
    let mut url = format!("{}/mvt/{}/{}/{}.mvt", state.config.graphhopper_url, z, x, y);
    if let Some(q) = query.as_deref().filter(|s| !s.is_empty()) {
        url.push('?');
        url.push_str(q);
    }

    let upstream = state
        .http_client
        .get(&url)
        .send()
        .await
        .map_err(|e| AppError::Internal(format!("failed to reach GraphHopper MVT: {e}")))?;

    let status = upstream.status();
    let bytes = upstream
        .bytes()
        .await
        .map_err(|e| AppError::Internal(format!("failed to read GraphHopper MVT body: {e}")))?;

    if !status.is_success() {
        let snippet = String::from_utf8_lossy(&bytes);
        return Err(AppError::Internal(format!(
            "GraphHopper MVT returned {status}: {snippet}"
        )));
    }

    let mut headers = HeaderMap::new();
    headers.insert(
        header::CONTENT_TYPE,
        "application/x-protobuf".parse().unwrap(),
    );
    headers.insert(header::CACHE_CONTROL, "no-store".parse().unwrap());

    Ok((StatusCode::OK, headers, Body::from(bytes)))
}

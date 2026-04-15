pub mod auth;
pub mod config;
pub mod errors;
pub mod geocode;
pub mod locations;
pub mod ratings;
pub mod routing;

use axum::{
    routing::{get, post, put},
    Router,
};
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;

pub struct AppState {
    pub db: sqlx::PgPool,
    pub config: config::Config,
    pub http_client: reqwest::Client,
}

pub fn build_router(state: Arc<AppState>) -> Router {
    let static_dir = state.config.static_dir.clone();
    Router::new()
        .route("/api/health", get(|| async { "ok" }))
        .route("/api/auth/register", post(auth::register))
        .route("/api/auth/anonymous", post(auth::anonymous))
        .route("/api/auth/login", post(auth::login))
        .route("/api/auth/logout", post(auth::logout))
        .route("/api/auth/me", get(auth::me))
        .route(
            "/api/locations/home",
            get(locations::get_home)
                .put(locations::save_home)
                .delete(locations::delete_home),
        )
        .route("/api/ratings", get(ratings::get_overlay))
        .route("/api/ratings/paint", put(ratings::paint))
        .route("/api/route", post(routing::get_route))
        .route("/api/geocode", get(geocode::geocode))
        .fallback_service(ServeDir::new(static_dir).append_index_html_on_directories(true))
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(state)
}

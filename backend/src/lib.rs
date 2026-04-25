pub mod auth;
pub mod bbox;
pub mod config;
pub mod errors;
pub mod geocode;
pub mod locations;
pub mod ratings;
pub mod ratings_events;
pub mod routing;

use axum::{
    http::header,
    response::IntoResponse,
    routing::{delete, get, post, put},
    Router,
};
use std::sync::Arc;
use tokio::sync::broadcast;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;

pub struct AppState {
    pub db: sqlx::PgPool,
    pub config: config::Config,
    pub http_client: reqwest::Client,
    /// `Some` when [`config::Config::ratings_events_enabled`] is true and the
    /// backend has spawned a Postgres LISTEN task. `None` means the SSE
    /// pipeline is disabled — the `/api/ratings/events` route is absent and
    /// mutation handlers skip their `pg_notify` call.
    pub rating_events: Option<broadcast::Sender<ratings_events::Invalidation>>,
}

pub fn build_router(state: Arc<AppState>) -> Router {
    let static_dir = state.config.static_dir.clone();
    let sse_enabled = state.rating_events.is_some();
    let router = Router::new()
        .route("/api/health", get(|| async { "ok" }))
        .route("/api/auth/register", post(auth::register))
        .route("/api/auth/anonymous", post(auth::anonymous))
        .route("/api/auth/login", post(auth::login))
        .route("/api/auth/logout", post(auth::logout))
        .route("/api/auth/account", delete(auth::delete_account))
        .route("/api/auth/me", get(auth::me))
        .route(
            "/api/locations/home",
            get(locations::get_home)
                .put(locations::save_home)
                .delete(locations::delete_home),
        )
        .route("/api/ratings", get(ratings::get_overlay))
        .route("/api/ratings/paint", put(ratings::paint))
        .route("/api/ratings/undo", post(ratings::undo))
        .route("/api/ratings/redo", post(ratings::redo))
        .route("/api/route", post(routing::get_route))
        .route("/api/navigate", post(routing::get_navigation_route))
        .route("/api/geocode", get(geocode::geocode))
        .route(
            "/.well-known/apple-app-site-association",
            get(apple_app_site_association),
        );
    // Only register the SSE route when the feature is on. A disabled server
    // then returns the same 404 for this path as for any unknown URL, and
    // the mobile client uses that as its signal to stop retrying.
    let router = if sse_enabled {
        router.route("/api/ratings/events", get(ratings_events::events))
    } else {
        router
    };
    router
        .fallback_service(ServeDir::new(static_dir).append_index_html_on_directories(true))
        .layer(
            CorsLayer::new()
                .allow_origin(Any)
                .allow_methods(Any)
                .allow_headers(Any),
        )
        .with_state(state)
}

// Apple fetches this file anonymously over HTTPS; content-type must be
// application/json and the path has no extension, so we serve it as a
// dedicated route rather than through ServeDir.
async fn apple_app_site_association() -> impl IntoResponse {
    const BODY: &str = r#"{"webcredentials":{"apps":["37FTP2QTRQ.com.beebeebike.app"]}}"#;
    ([(header::CONTENT_TYPE, "application/json")], BODY)
}

mod auth;
mod config;
mod errors;
mod geocode;
mod ratings;
mod routing;

use axum::{
    routing::{get, post, put},
    Router,
};
use config::Config;
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::ServeDir;

pub struct AppState {
    pub db: sqlx::PgPool,
    pub config: Config,
    pub http_client: reqwest::Client,
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "beebeebike_backend=debug,tower_http=debug".into()),
        )
        .init();

    dotenvy::dotenv().ok();
    let config = Config::from_env();
    let listen_addr = config.listen_addr.clone();
    let static_dir = config.static_dir.clone();

    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&config.database_url)
        .await
        .expect("Failed to connect to database");

    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .expect("Failed to run migrations");

    let state = Arc::new(AppState {
        db,
        config,
        http_client: reqwest::Client::new(),
    });

    let app = Router::new()
        .route("/api/health", get(|| async { "ok" }))
        .route("/api/auth/register", post(auth::register))
        .route("/api/auth/anonymous", post(auth::anonymous))
        .route("/api/auth/login", post(auth::login))
        .route("/api/auth/logout", post(auth::logout))
        .route("/api/auth/me", get(auth::me))
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
        .with_state(state);

    let listener = tokio::net::TcpListener::bind(&listen_addr)
        .await
        .expect("Failed to bind");

    tracing::info!("Listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}

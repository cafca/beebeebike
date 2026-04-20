use beebeebike_backend::{build_router, config::Config, ratings_events, AppState};
use sqlx::postgres::PgPoolOptions;
use std::sync::Arc;

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

    let db = PgPoolOptions::new()
        .max_connections(10)
        .connect(&config.database_url)
        .await
        .expect("Failed to connect to database");

    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .expect("Failed to run migrations");

    // Spawn the Postgres LISTEN task only when the SSE pipeline is enabled.
    // Flipping BEEBEEBIKE_RATINGS_SSE_ENABLED=false and restarting the
    // backend is the designated kill switch if push traffic becomes a
    // problem; mobile clients fall back to camera-idle polling.
    let rating_events = if config.ratings_events_enabled {
        Some(ratings_events::spawn_listener(db.clone()))
    } else {
        tracing::info!("ratings SSE pipeline disabled via BEEBEEBIKE_RATINGS_SSE_ENABLED");
        None
    };

    let state = Arc::new(AppState {
        db,
        config,
        http_client: reqwest::Client::new(),
        rating_events,
    });

    let app = build_router(state);

    let listener = tokio::net::TcpListener::bind(&listen_addr)
        .await
        .expect("Failed to bind");

    tracing::info!("Listening on {}", listener.local_addr().unwrap());
    axum::serve(listener, app).await.unwrap();
}

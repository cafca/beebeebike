use std::env;

pub struct Config {
    pub database_url: String,
    pub graphhopper_url: String,
    pub photon_url: String,
    pub listen_addr: String,
    pub static_dir: String,
    pub rating_weight: f64,
    pub distance_influence: f64,
    pub max_areas_per_request: usize,
}

impl Config {
    pub fn from_env() -> Self {
        Self {
            database_url: env::var("DATABASE_URL").unwrap_or_else(|_| {
                "postgres://beebeebike:beebeebike@localhost:5432/beebeebike".into()
            }),
            graphhopper_url: env::var("GRAPHHOPPER_URL")
                .unwrap_or_else(|_| "http://localhost:8989".into()),
            photon_url: env::var("PHOTON_URL")
                .unwrap_or_else(|_| "https://photon.komoot.io".into()),
            listen_addr: env::var("LISTEN_ADDR").unwrap_or_else(|_| "0.0.0.0:3000".into()),
            static_dir: env::var("STATIC_DIR").unwrap_or_else(|_| "../frontend/dist".into()),
            rating_weight: env::var("RATING_WEIGHT")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(1.0),
            distance_influence: env::var("DISTANCE_INFLUENCE")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(70.0),
            max_areas_per_request: env::var("MAX_AREAS_PER_REQUEST")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(200),
        }
    }
}

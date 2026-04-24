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
    /// Maximum active undo steps kept in `paint_events`. Events beyond this
    /// are squashed into `rated_areas_baseline` and removed. Bounds the cost
    /// of `rebuild_rated_areas_for_user` (O(cap) per undo). Tune with the
    /// `undo_bench` binary against your DB/hardware.
    pub max_undo_history: usize,
    /// Kill switch for the rating-change SSE pipeline. When `false` the
    /// backend neither spawns the Postgres LISTEN task nor registers the
    /// `/api/ratings/events` route, and paint/undo/redo skip their
    /// `pg_notify` call. Clients that hit the disabled endpoint get a 404
    /// and fall back to camera-idle polling.
    pub ratings_events_enabled: bool,
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
            static_dir: env::var("STATIC_DIR").unwrap_or_else(|_| "../web/dist".into()),
            rating_weight: env::var("RATING_WEIGHT")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(0.5),
            distance_influence: env::var("DISTANCE_INFLUENCE")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(70.0),
            max_areas_per_request: env::var("MAX_AREAS_PER_REQUEST")
                .ok()
                .and_then(|v| v.parse().ok())
                .unwrap_or(200),
            max_undo_history: env::var("BEEBEEBIKE_MAX_UNDO_HISTORY")
                .ok()
                .and_then(|v| v.parse().ok())
                .filter(|&n: &usize| n >= 1)
                .unwrap_or(15),
            ratings_events_enabled: env::var("BEEBEEBIKE_RATINGS_SSE_ENABLED")
                .ok()
                .map(|v| !matches!(v.to_lowercase().as_str(), "0" | "false" | "no"))
                .unwrap_or(true),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    // Env-var tests must run sequentially because env vars are process-global.
    static ENV_LOCK: Mutex<()> = Mutex::new(());

    fn with_env_vars<F: FnOnce()>(vars: &[(&str, &str)], f: F) {
        let _guard = ENV_LOCK.lock().unwrap();
        let keys: Vec<&str> = vars.iter().map(|(k, _)| *k).collect();
        unsafe {
            for key in &keys {
                env::remove_var(key);
            }
            for (key, val) in vars {
                env::set_var(key, val);
            }
        }
        f();
        unsafe {
            for key in &keys {
                env::remove_var(key);
            }
        }
    }

    #[test]
    fn defaults_when_no_env_vars() {
        let _guard = ENV_LOCK.lock().unwrap();
        // Clear all config vars
        unsafe {
            for var in [
                "DATABASE_URL",
                "GRAPHHOPPER_URL",
                "PHOTON_URL",
                "LISTEN_ADDR",
                "STATIC_DIR",
                "RATING_WEIGHT",
                "DISTANCE_INFLUENCE",
                "MAX_AREAS_PER_REQUEST",
                "BEEBEEBIKE_MAX_UNDO_HISTORY",
                "BEEBEEBIKE_RATINGS_SSE_ENABLED",
            ] {
                env::remove_var(var);
            }
        }
        let config = Config::from_env();
        assert!(config.database_url.contains("beebeebike"));
        assert_eq!(config.graphhopper_url, "http://localhost:8989");
        assert_eq!(config.photon_url, "https://photon.komoot.io");
        assert_eq!(config.listen_addr, "0.0.0.0:3000");
        assert!((config.rating_weight - 0.5).abs() < 1e-9);
        assert!((config.distance_influence - 70.0).abs() < 1e-9);
        assert_eq!(config.max_areas_per_request, 200);
        assert_eq!(config.max_undo_history, 15);
        assert!(
            config.ratings_events_enabled,
            "SSE should default to enabled"
        );
    }

    #[test]
    fn max_undo_history_env_override() {
        with_env_vars(&[("BEEBEEBIKE_MAX_UNDO_HISTORY", "25")], || {
            let config = Config::from_env();
            assert_eq!(config.max_undo_history, 25);
        });
    }

    #[test]
    fn max_undo_history_rejects_zero_and_non_numeric() {
        for bad in ["0", "abc", ""] {
            with_env_vars(&[("BEEBEEBIKE_MAX_UNDO_HISTORY", bad)], || {
                let config = Config::from_env();
                assert_eq!(
                    config.max_undo_history, 15,
                    "invalid value {bad:?} should fall back to default"
                );
            });
        }
    }

    #[test]
    fn ratings_events_kill_switch_via_env() {
        for (value, expected) in [
            ("0", false),
            ("false", false),
            ("FALSE", false),
            ("no", false),
            ("1", true),
            ("true", true),
            ("anything-else", true),
        ] {
            with_env_vars(&[("BEEBEEBIKE_RATINGS_SSE_ENABLED", value)], || {
                let config = Config::from_env();
                assert_eq!(
                    config.ratings_events_enabled, expected,
                    "env value {value:?} → expected ratings_events_enabled={expected}"
                );
            });
        }
    }

    #[test]
    fn overrides_from_env() {
        with_env_vars(
            &[
                ("DATABASE_URL", "postgres://test:test@db/test"),
                ("GRAPHHOPPER_URL", "http://gh:9999"),
                ("RATING_WEIGHT", "0.5"),
                ("DISTANCE_INFLUENCE", "100.0"),
                ("MAX_AREAS_PER_REQUEST", "50"),
            ],
            || {
                let config = Config::from_env();
                assert_eq!(config.database_url, "postgres://test:test@db/test");
                assert_eq!(config.graphhopper_url, "http://gh:9999");
                assert!((config.rating_weight - 0.5).abs() < 1e-9);
                assert!((config.distance_influence - 100.0).abs() < 1e-9);
                assert_eq!(config.max_areas_per_request, 50);
            },
        );
    }

    #[test]
    fn invalid_numeric_env_falls_back_to_default() {
        with_env_vars(
            &[
                ("RATING_WEIGHT", "not-a-number"),
                ("MAX_AREAS_PER_REQUEST", "abc"),
            ],
            || {
                let config = Config::from_env();
                assert!((config.rating_weight - 0.5).abs() < 1e-9);
                assert_eq!(config.max_areas_per_request, 200);
            },
        );
    }
}

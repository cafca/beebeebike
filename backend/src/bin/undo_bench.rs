//! Undo replay benchmark.
//!
//! Measures how long `rebuild_rated_areas_for_user` takes at various active-
//! history depths, so operators can pick an informed value for
//! `BEEBEEBIKE_MAX_UNDO_HISTORY`.
//!
//! Run with `just bench-undo` or directly:
//!
//! ```text
//! cargo run --release --bin undo_bench -- --confirm \
//!     --depths 1,5,10,15,20,25,50 --geometry-size medium
//! ```
//!
//! The tool creates an ephemeral anonymous user, seeds `paint_events` with
//! synthetic polygons, re-runs `rebuild_rated_areas_for_user` in a rolled-back
//! transaction N times per depth, and prints a latency table plus a
//! recommendation derived from `--rtt-ms` and `--target-ms`.

use std::time::{Duration, Instant};

use beebeebike_backend::ratings::{apply_paint, Target};
use rand::Rng;
use sqlx::postgres::PgPoolOptions;
use uuid::Uuid;

#[derive(Clone, Copy)]
enum GeomSize {
    Small,
    Medium,
    Large,
}

impl GeomSize {
    fn parse(s: &str) -> Result<Self, String> {
        match s {
            "small" => Ok(GeomSize::Small),
            "medium" => Ok(GeomSize::Medium),
            "large" => Ok(GeomSize::Large),
            other => Err(format!("unknown --geometry-size {other:?}")),
        }
    }

    fn radius_deg(self) -> f64 {
        match self {
            GeomSize::Small => 0.001,  // ~ 100 m
            GeomSize::Medium => 0.003, // ~ 300 m
            GeomSize::Large => 0.008,  // ~ 900 m
        }
    }

    fn label(self) -> &'static str {
        match self {
            GeomSize::Small => "small",
            GeomSize::Medium => "medium",
            GeomSize::Large => "large",
        }
    }
}

struct Args {
    depths: Vec<usize>,
    iterations: usize,
    geom_size: GeomSize,
    rtt_ms: u64,
    target_ms: u64,
    confirm: bool,
    confirm_prod: bool,
}

impl Args {
    fn parse() -> Result<Self, String> {
        let mut args = std::env::args().skip(1);
        let mut depths: Option<Vec<usize>> = None;
        let mut iterations = 10usize;
        let mut geom_size = GeomSize::Medium;
        let mut rtt_ms = 120u64;
        let mut target_ms = 250u64;
        let mut confirm = false;
        let mut confirm_prod = false;

        while let Some(arg) = args.next() {
            match arg.as_str() {
                "--depths" => {
                    let raw = args.next().ok_or("--depths needs a value")?;
                    depths = Some(
                        raw.split(',')
                            .map(|s| s.trim().parse::<usize>().map_err(|e| e.to_string()))
                            .collect::<Result<Vec<_>, _>>()?,
                    );
                }
                "--iterations" => {
                    iterations = args
                        .next()
                        .ok_or("--iterations needs a value")?
                        .parse()
                        .map_err(|e: std::num::ParseIntError| e.to_string())?;
                }
                "--geometry-size" => {
                    geom_size =
                        GeomSize::parse(&args.next().ok_or("--geometry-size needs a value")?)?;
                }
                "--rtt-ms" => {
                    rtt_ms = args
                        .next()
                        .ok_or("--rtt-ms needs a value")?
                        .parse()
                        .map_err(|e: std::num::ParseIntError| e.to_string())?;
                }
                "--target-ms" => {
                    target_ms = args
                        .next()
                        .ok_or("--target-ms needs a value")?
                        .parse()
                        .map_err(|e: std::num::ParseIntError| e.to_string())?;
                }
                "--confirm" => confirm = true,
                "--confirm-prod" => confirm_prod = true,
                "--help" | "-h" => {
                    print_help();
                    std::process::exit(0);
                }
                other => return Err(format!("unknown arg {other:?}")),
            }
        }

        let depths = depths.unwrap_or_else(|| vec![1, 5, 10, 15, 20, 25, 35, 50, 75, 100]);
        if depths.is_empty() {
            return Err("--depths must contain at least one value".into());
        }
        if iterations == 0 {
            return Err("--iterations must be >= 1".into());
        }
        Ok(Self {
            depths,
            iterations,
            geom_size,
            rtt_ms,
            target_ms,
            confirm,
            confirm_prod,
        })
    }
}

fn print_help() {
    eprintln!(
        "undo_bench — measure undo replay latency across stack depths

  --confirm                Required. Acknowledges the tool writes throwaway rows.
  --confirm-prod           Required if the DB looks like production (many users).
  --depths a,b,c           Stack depths to measure. Default: 1,5,10,15,20,25,35,50,75,100
  --iterations N           Samples per depth. Default: 10
  --geometry-size SIZE     small | medium | large (default: medium)
  --rtt-ms N               Assumed client RTT for recommendation. Default: 120
  --target-ms N            End-to-end snappiness budget. Default: 250
  --help                   Show this message
"
    );
}

fn random_polygon_geojson(rng: &mut impl Rng, size: GeomSize) -> String {
    // Berlin-ish bbox, roomy enough that strokes overlap occasionally
    let cx = rng.gen_range(13.30..13.50);
    let cy = rng.gen_range(52.45..52.55);
    let r = size.radius_deg();
    // Square polygon with small random skew, winding CCW
    let skew = rng.gen_range(-0.0002..0.0002);
    let coords = [
        (cx - r, cy - r),
        (cx + r, cy - r + skew),
        (cx + r, cy + r),
        (cx - r + skew, cy + r),
        (cx - r, cy - r),
    ];
    let coords_json: Vec<serde_json::Value> = coords
        .iter()
        .map(|(x, y)| serde_json::json!([x, y]))
        .collect();
    serde_json::json!({
        "type": "Polygon",
        "coordinates": [coords_json]
    })
    .to_string()
}

fn percentile(sorted_ms: &[f64], p: f64) -> f64 {
    if sorted_ms.is_empty() {
        return 0.0;
    }
    let idx = ((sorted_ms.len() as f64 - 1.0) * p).round() as usize;
    sorted_ms[idx.min(sorted_ms.len() - 1)]
}

async fn rebuild_for_user(
    tx: &mut sqlx::Transaction<'_, sqlx::Postgres>,
    user_id: Uuid,
) -> Result<(), sqlx::Error> {
    // Mirrors ratings::rebuild_rated_areas_for_user, inlined here to keep
    // that function pub(crate) while still exercising the same work.
    sqlx::query("DELETE FROM rated_areas WHERE user_id = $1")
        .bind(user_id)
        .execute(&mut **tx)
        .await?;
    sqlx::query(
        r#"
        INSERT INTO rated_areas (user_id, geometry, value)
        SELECT user_id, geometry, value
        FROM rated_areas_baseline
        WHERE user_id = $1
        "#,
    )
    .bind(user_id)
    .execute(&mut **tx)
    .await?;
    let events: Vec<(String, i16)> = sqlx::query_as(
        r#"
        SELECT ST_AsGeoJSON(geometry), value
        FROM paint_events
        WHERE user_id = $1 AND status = 0
        ORDER BY seq
        "#,
    )
    .bind(user_id)
    .fetch_all(&mut **tx)
    .await?;
    for (geom_json, value) in events {
        apply_paint(tx, user_id, &geom_json, value as i32, Target::RatedAreas)
            .await
            .map_err(|e| sqlx::Error::Protocol(format!("apply_paint: {e:?}")))?;
    }
    Ok(())
}

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();
    let args = match Args::parse() {
        Ok(a) => a,
        Err(e) => {
            eprintln!("error: {e}");
            print_help();
            std::process::exit(2);
        }
    };

    if !args.confirm {
        eprintln!("refusing to run without --confirm (the tool writes throwaway rows)");
        std::process::exit(2);
    }

    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://beebeebike:beebeebike@localhost:5432/beebeebike".into());
    let db = PgPoolOptions::new()
        .max_connections(2)
        .connect(&db_url)
        .await
        .expect("connect");

    // Prod guard: hand-wavy user-count heuristic.
    let user_count: i64 = sqlx::query_scalar("SELECT COUNT(*) FROM users")
        .fetch_one(&db)
        .await
        .expect("count users");
    if user_count > 100 && !args.confirm_prod {
        eprintln!(
            "database has {user_count} users — looks like production. \
             Pass --confirm-prod if you really mean it."
        );
        std::process::exit(2);
    }

    let max_depth = *args.depths.iter().max().expect("non-empty");
    let email = format!("undo-bench-{}@example.invalid", Uuid::new_v4());
    let user_id: Uuid = sqlx::query_scalar(
        "INSERT INTO users (email, password_hash, account_type) VALUES ($1, 'x', 'registered') RETURNING id",
    )
    .bind(&email)
    .fetch_one(&db)
    .await
    .expect("insert user");

    eprintln!(
        "Seeding {max_depth} paint events for synthetic user {user_id} ({} polygons)…",
        args.geom_size.label()
    );

    let mut rng = rand::thread_rng();
    // Insert all events as status=0; no baseline rows yet. rebuild will replay
    // exactly the active slice chosen per-depth below.
    const VALUES: [i32; 6] = [-7, -3, -1, 1, 3, 7];
    for seq in 1..=max_depth {
        let geom = random_polygon_geojson(&mut rng, args.geom_size);
        let value: i32 = VALUES[rng.gen_range(0..VALUES.len())];
        sqlx::query(
            r#"
            INSERT INTO paint_events (user_id, seq, geometry, value, status)
            SELECT $1, $2, ST_GeomFromGeoJSON($3), $4, 0
            "#,
        )
        .bind(user_id)
        .bind(seq as i64)
        .bind(&geom)
        .bind(value as i16)
        .execute(&db)
        .await
        .expect("insert paint_event");
    }

    println!(
        "\nUndo replay benchmark — {}\nDB: {}  |  geometry-size: {}  |  iterations: {}\n",
        chrono::Utc::now().to_rfc3339(),
        redact(&db_url),
        args.geom_size.label(),
        args.iterations,
    );
    println!(" depth |  mean    p50    p95    p99  | active rows");
    println!("-------+------------------------------+-------------");

    let mut results: Vec<(usize, f64, f64)> = Vec::new(); // (depth, p95_ms, mean_ms)

    let mut depths_sorted = args.depths.clone();
    depths_sorted.sort_unstable();
    for &depth in &depths_sorted {
        if depth > max_depth {
            continue;
        }
        // Set exactly `depth` events active (the most recent by seq).
        sqlx::query("UPDATE paint_events SET status = 0 WHERE user_id = $1")
            .bind(user_id)
            .execute(&db)
            .await
            .expect("reset status");
        if depth < max_depth {
            let cutoff = (max_depth - depth) as i64;
            sqlx::query("UPDATE paint_events SET status = 1 WHERE user_id = $1 AND seq <= $2")
                .bind(user_id)
                .bind(cutoff)
                .execute(&db)
                .await
                .expect("trim status");
        }

        let mut samples: Vec<Duration> = Vec::with_capacity(args.iterations);
        for _ in 0..args.iterations {
            let mut tx = db.begin().await.expect("begin");
            let start = Instant::now();
            rebuild_for_user(&mut tx, user_id)
                .await
                .expect("rebuild_for_user");
            samples.push(start.elapsed());
            // Roll back so the next iteration starts with the same rated_areas
            // shape (empty — rebuild fills it, rollback drops it).
            tx.rollback().await.expect("rollback");
        }

        let mut ms: Vec<f64> = samples.iter().map(|d| d.as_secs_f64() * 1000.0).collect();
        ms.sort_by(|a, b| a.partial_cmp(b).unwrap());
        let mean = ms.iter().sum::<f64>() / ms.len() as f64;
        let p50 = percentile(&ms, 0.50);
        let p95 = percentile(&ms, 0.95);
        let p99 = percentile(&ms, 0.99);
        println!(
            "{:>6} | {:>5.1}ms {:>5.1}ms {:>5.1}ms {:>5.1}ms | {:>10}",
            depth, mean, p50, p95, p99, depth
        );
        results.push((depth, p95, mean));
    }

    // Recommendation
    let budget = args.target_ms as f64 - args.rtt_ms as f64;
    let recommended = results
        .iter()
        .rev()
        .find(|(_, p95, _)| *p95 <= budget)
        .map(|(d, _, _)| *d);

    println!();
    println!("Assumed client RTT budget: {}ms (--rtt-ms)", args.rtt_ms);
    println!(
        "Target end-to-end snappiness: {}ms (--target-ms)",
        args.target_ms
    );
    println!("  Server-side p95 budget: {:.0}ms", budget);
    match recommended {
        Some(d) => println!(
            "  Recommendation: BEEBEEBIKE_MAX_UNDO_HISTORY={d}  (largest depth with p95 within budget)"
        ),
        None => println!(
            "  Recommendation: BEEBEEBIKE_MAX_UNDO_HISTORY={}  (no depth met the budget — consider raising --target-ms or improving hardware)",
            results.first().map(|(d, _, _)| *d).unwrap_or(1)
        ),
    }

    // Cleanup
    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user_id)
        .execute(&db)
        .await
        .expect("delete user");
    sqlx::query("DELETE FROM rated_areas_baseline WHERE user_id = $1")
        .bind(user_id)
        .execute(&db)
        .await
        .expect("delete baseline");
}

fn redact(url: &str) -> String {
    // Strip any password between `://user:PW@` so we don't print credentials.
    if let Some(scheme_end) = url.find("://") {
        let rest = &url[scheme_end + 3..];
        if let Some(at) = rest.find('@') {
            let creds = &rest[..at];
            if let Some(colon) = creds.find(':') {
                return format!(
                    "{}://{}:***@{}",
                    &url[..scheme_end],
                    &creds[..colon],
                    &rest[at + 1..]
                );
            }
        }
    }
    url.to_string()
}

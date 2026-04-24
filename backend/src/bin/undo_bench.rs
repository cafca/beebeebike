//! Undo replay benchmark.
//!
//! Measures how long `rebuild_rated_areas_for_user` takes at various active-
//! history depths, so operators can pick an informed value for
//! `BEEBEEBIKE_MAX_UNDO_HISTORY`.
//!
//! Run via `just bench-undo` (local) or `just bench-undo-prod` (prod host).
//!
//! The tool never touches the application database. It connects to the
//! Postgres server referenced by `DATABASE_URL`, creates a fresh throwaway
//! database (`beebeebike_bench_<uuid>`), runs migrations into it, seeds
//! synthetic paint events, benchmarks replay, and drops the database on exit.
//! Safe to run against prod.
use std::time::{Duration, Instant};

use beebeebike_backend::ratings::{apply_paint, Target};
use rand::Rng;
use sqlx::postgres::{PgConnectOptions, PgPoolOptions};
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
            GeomSize::Small => 0.001,
            GeomSize::Medium => 0.003,
            GeomSize::Large => 0.008,
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
}

impl Args {
    fn parse() -> Result<Self, String> {
        let mut args = std::env::args().skip(1);
        let mut depths: Option<Vec<usize>> = None;
        let mut iterations = 10usize;
        let mut geom_size = GeomSize::Medium;
        let mut rtt_ms = 120u64;
        let mut target_ms = 250u64;

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
        })
    }
}

fn print_help() {
    eprintln!(
        "undo_bench — measure undo replay latency across stack depths

Connects to the Postgres server at DATABASE_URL, creates a throwaway
database, runs migrations, benchmarks, and drops the database. The
application DB is never touched.

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
    let cx = rng.gen_range(13.30..13.50);
    let cy = rng.gen_range(52.45..52.55);
    let r = size.radius_deg();
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

    let db_url = std::env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://beebeebike:beebeebike@localhost:5432/beebeebike".into());

    if let Err(e) = run(&db_url, args).await {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

async fn run(db_url: &str, args: Args) -> Result<(), String> {
    let base_opts: PgConnectOptions = db_url
        .parse()
        .map_err(|e| format!("invalid DATABASE_URL: {e}"))?;

    let admin = PgPoolOptions::new()
        .max_connections(1)
        .connect_with(base_opts.clone())
        .await
        .map_err(|e| format!("connect admin: {e}"))?;

    let bench_db = format!("beebeebike_bench_{}", Uuid::new_v4().simple());
    sqlx::query(&format!("CREATE DATABASE \"{bench_db}\""))
        .execute(&admin)
        .await
        .map_err(|e| format!("CREATE DATABASE: {e}"))?;

    eprintln!("Created throwaway DB {bench_db}; will DROP on exit.");

    let bench_opts = base_opts.clone().database(&bench_db);
    let result = run_with_db(bench_opts, &args).await;

    // Drop the bench DB no matter what. FORCE disconnects any leftover sessions.
    if let Err(e) = sqlx::query(&format!("DROP DATABASE \"{bench_db}\" WITH (FORCE)"))
        .execute(&admin)
        .await
    {
        eprintln!("warning: failed to drop bench DB {bench_db}: {e}");
    }

    result
}

async fn run_with_db(bench_opts: PgConnectOptions, args: &Args) -> Result<(), String> {
    let db = PgPoolOptions::new()
        .max_connections(2)
        .connect_with(bench_opts)
        .await
        .map_err(|e| format!("connect bench: {e}"))?;

    sqlx::migrate!("./migrations")
        .run(&db)
        .await
        .map_err(|e| format!("migrate: {e}"))?;

    let max_depth = *args.depths.iter().max().expect("non-empty");
    let email = format!("undo-bench-{}@example.invalid", Uuid::new_v4());
    let user_id: Uuid = sqlx::query_scalar(
        "INSERT INTO users (email, password_hash, account_type) VALUES ($1, 'x', 'registered') RETURNING id",
    )
    .bind(&email)
    .fetch_one(&db)
    .await
    .map_err(|e| format!("insert user: {e}"))?;

    eprintln!(
        "Seeding {max_depth} paint events ({} polygons)…",
        args.geom_size.label()
    );

    let mut rng = rand::thread_rng();
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
        .map_err(|e| format!("insert paint_event: {e}"))?;
    }

    println!(
        "\nUndo replay benchmark — {}\nServer: {}  |  geometry-size: {}  |  iterations: {}\n",
        chrono::Utc::now().to_rfc3339(),
        redact_host(db.connect_options().as_ref()),
        args.geom_size.label(),
        args.iterations,
    );
    println!(" depth |  mean    p50    p95    p99  | active rows");
    println!("-------+------------------------------+-------------");

    let mut results: Vec<(usize, f64, f64)> = Vec::new();

    let mut depths_sorted = args.depths.clone();
    depths_sorted.sort_unstable();
    for &depth in &depths_sorted {
        if depth > max_depth {
            continue;
        }
        sqlx::query("UPDATE paint_events SET status = 0 WHERE user_id = $1")
            .bind(user_id)
            .execute(&db)
            .await
            .map_err(|e| format!("reset status: {e}"))?;
        if depth < max_depth {
            let cutoff = (max_depth - depth) as i64;
            sqlx::query("UPDATE paint_events SET status = 1 WHERE user_id = $1 AND seq <= $2")
                .bind(user_id)
                .bind(cutoff)
                .execute(&db)
                .await
                .map_err(|e| format!("trim status: {e}"))?;
        }

        let mut samples: Vec<Duration> = Vec::with_capacity(args.iterations);
        for _ in 0..args.iterations {
            let mut tx = db.begin().await.map_err(|e| format!("begin tx: {e}"))?;
            let start = Instant::now();
            rebuild_for_user(&mut tx, user_id)
                .await
                .map_err(|e| format!("rebuild_for_user: {e}"))?;
            samples.push(start.elapsed());
            tx.rollback().await.map_err(|e| format!("rollback: {e}"))?;
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

    db.close().await;
    Ok(())
}

fn redact_host(opts: &PgConnectOptions) -> String {
    // sqlx doesn't expose host/port getters cleanly; print a stable summary
    // using Debug + regex-free extraction is overkill. Just show "postgres:<bench_db>".
    format!("postgres:{}", opts.get_database().unwrap_or("<unknown>"))
}

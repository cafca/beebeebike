//! Rating-change push pipeline.
//!
//! Flow:
//!   1. `paint`, `undo`, `redo` execute `SELECT pg_notify('ratings_changed', …)`
//!      inside their transaction, so the notify is atomic with the row change.
//!   2. A single background task holds a dedicated Postgres listener
//!      connection, parses each notification, and re-broadcasts it over a
//!      `tokio::sync::broadcast` channel.
//!   3. The `/api/ratings/events` SSE handler subscribes to the broadcast,
//!      filters by the requesting user's id, and writes an `invalidate` event
//!      per matching notification. Clients respond by nulling their local
//!      cache and refetching the current viewport.
//!
//! The whole pipeline is controlled by `Config::ratings_events_enabled` —
//! when disabled, `spawn_listener` is never called, the route is absent from
//! the router, and the paint handlers skip their notify. This is the
//! "scale escape hatch" the feature was designed around.

use axum::{
    extract::State,
    http::HeaderMap,
    response::sse::{Event, KeepAlive, Sse},
};
use futures_util::Stream;
use serde::{Deserialize, Serialize};
use sqlx::postgres::PgListener;
use std::{convert::Infallible, sync::Arc, time::Duration};
use tokio::sync::broadcast;
use uuid::Uuid;

use crate::{auth::require_auth, errors::AppError, AppState};

/// Postgres channel used for paint/undo/redo notifications. Must match the
/// `pg_notify` calls in `ratings.rs`.
pub const CHANNEL: &str = "ratings_changed";

/// Payload broadcast to every SSE subscriber whenever rated areas change.
/// Kept intentionally minimal: the SSE handler filters by `user_id`, and
/// the client just invalidates and refetches — it doesn't need the bbox or
/// the polygon itself.
#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Invalidation {
    pub user_id: Uuid,
}

/// Spawn the single listener task. Returns a `broadcast::Sender` that is
/// cloned into `AppState.rating_events` so SSE handlers can each call
/// `.subscribe()` to get their own receiver.
///
/// The buffer size (256) is generous for our scale — even the slowest
/// subscriber would need to be >256 events behind to lag. Invalidations
/// are idempotent, so a dropped Lagged event only costs one redundant
/// refetch on the client.
pub fn spawn_listener(pool: sqlx::PgPool) -> broadcast::Sender<Invalidation> {
    let (tx, _rx) = broadcast::channel::<Invalidation>(256);
    let sender = tx.clone();
    tokio::spawn(async move {
        loop {
            let mut listener = match PgListener::connect_with(&pool).await {
                Ok(l) => l,
                Err(e) => {
                    tracing::warn!("ratings_events: listener connect failed: {e}");
                    tokio::time::sleep(Duration::from_secs(3)).await;
                    continue;
                }
            };
            if let Err(e) = listener.listen(CHANNEL).await {
                tracing::warn!("ratings_events: LISTEN {CHANNEL} failed: {e}");
                tokio::time::sleep(Duration::from_secs(3)).await;
                continue;
            }
            tracing::info!("ratings_events: listening on {CHANNEL}");
            loop {
                match listener.recv().await {
                    Ok(notif) => match serde_json::from_str::<Invalidation>(notif.payload()) {
                        Ok(inv) => {
                            // `send` errors only when there are zero
                            // receivers, which is the common case when no
                            // clients are connected — harmless.
                            let _ = tx.send(inv);
                        }
                        Err(e) => {
                            tracing::warn!(
                                "ratings_events: bad notify payload: {} ({e})",
                                notif.payload()
                            );
                        }
                    },
                    Err(e) => {
                        tracing::warn!("ratings_events: listener error: {e}, reconnecting");
                        break;
                    }
                }
            }
        }
    });
    sender
}

/// GET /api/ratings/events
///
/// Opens a long-lived SSE stream. Emits an `invalidate` event every time
/// the authenticated user's rated areas change on *any* device. Clients
/// null their cached bbox and refetch the current viewport in response.
///
/// Returns 404 when the SSE feature is disabled via config — that's the
/// signal clients use to stop retrying and fall back to camera-idle
/// polling.
pub async fn events(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Sse<impl Stream<Item = Result<Event, Infallible>>>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;
    let sender = state
        .rating_events
        .as_ref()
        .ok_or(AppError::NotFound)?
        .clone();
    let mut rx = sender.subscribe();

    let stream = async_stream::stream! {
        loop {
            match rx.recv().await {
                Ok(inv) if inv.user_id == user_id => {
                    let data = serde_json::to_string(&inv)
                        .unwrap_or_else(|_| "{}".to_string());
                    yield Ok(Event::default().event("invalidate").data(data));
                }
                Ok(_) => continue,
                Err(broadcast::error::RecvError::Lagged(_)) => {
                    // Fell behind: we can't tell which events were for us,
                    // so invalidate unconditionally. The client's response
                    // is idempotent, so a spurious refetch is cheap.
                    yield Ok(Event::default().event("invalidate").data("{}"));
                }
                Err(broadcast::error::RecvError::Closed) => break,
            }
        }
    };

    Ok(Sse::new(stream).keep_alive(
        KeepAlive::new()
            .interval(Duration::from_secs(20))
            .text("keepalive"),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalidation_roundtrips_as_json() {
        let id = Uuid::new_v4();
        let inv = Invalidation { user_id: id };
        let text = serde_json::to_string(&inv).unwrap();
        let parsed: Invalidation = serde_json::from_str(&text).unwrap();
        assert_eq!(parsed.user_id, id);
    }

    #[tokio::test]
    async fn broadcast_fans_out_to_subscribers_of_same_user() {
        let (tx, _) = broadcast::channel::<Invalidation>(16);
        let user_a = Uuid::new_v4();
        let user_b = Uuid::new_v4();

        let mut rx1 = tx.subscribe();
        let mut rx2 = tx.subscribe();

        tx.send(Invalidation { user_id: user_a }).unwrap();
        tx.send(Invalidation { user_id: user_b }).unwrap();

        // Both subscribers see both events — the per-user filtering lives
        // in the SSE handler, not in the broadcast layer.
        assert_eq!(rx1.recv().await.unwrap().user_id, user_a);
        assert_eq!(rx1.recv().await.unwrap().user_id, user_b);
        assert_eq!(rx2.recv().await.unwrap().user_id, user_a);
        assert_eq!(rx2.recv().await.unwrap().user_id, user_b);
    }
}

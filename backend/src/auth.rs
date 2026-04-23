use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
    Argon2,
};
use axum::{
    extract::State,
    http::{HeaderMap, HeaderValue},
    response::{IntoResponse, Response},
    Json,
};
use chrono::{DateTime, Duration, Utc};
use serde::{Deserialize, Serialize};
use sqlx::{FromRow, PgPool};
use std::sync::Arc;
use uuid::Uuid;

use crate::{errors::AppError, AppState};

// ---------------------------------------------------------------------------
// Request / response types
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
pub struct RegisterRequest {
    pub email: String,
    pub password: String,
    pub display_name: Option<String>,
}

#[derive(Deserialize)]
pub struct LoginRequest {
    pub email: String,
    pub password: String,
}

#[derive(Serialize)]
pub struct UserResponse {
    pub id: Uuid,
    pub email: Option<String>,
    pub display_name: String,
    pub account_type: String,
}

// ---------------------------------------------------------------------------
// Internal DB row types
// ---------------------------------------------------------------------------

#[derive(FromRow)]
struct UserRow {
    id: Uuid,
    email: String,
    password_hash: String,
    display_name: String,
    account_type: String,
}

#[derive(FromRow)]
struct UserRowNoHash {
    id: Uuid,
    email: Option<String>,
    display_name: String,
    account_type: String,
}

#[derive(FromRow)]
struct SessionRow {
    user_id: Uuid,
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

fn session_cookie(session_id: &str) -> HeaderValue {
    let cookie = format!(
        "session={}; Path=/; HttpOnly; SameSite=Lax; Max-Age=2592000",
        session_id
    );
    HeaderValue::from_str(&cookie).expect("cookie value is valid ASCII")
}

fn clear_session_cookie() -> HeaderValue {
    HeaderValue::from_static("session=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0")
}

fn extract_session_from_headers(headers: &HeaderMap) -> Option<String> {
    let cookie_header = headers.get("cookie")?.to_str().ok()?;
    for part in cookie_header.split(';') {
        let part = part.trim();
        if let Some(value) = part.strip_prefix("session=") {
            return Some(value.to_owned());
        }
    }
    None
}

async fn create_session(db: &PgPool, user_id: Uuid) -> Result<String, AppError> {
    let session_id = Uuid::new_v4().to_string();
    let expires_at: DateTime<Utc> = Utc::now() + Duration::seconds(2_592_000); // 30 days

    sqlx::query("INSERT INTO sessions (id, user_id, expires_at) VALUES ($1, $2, $3)")
        .bind(&session_id)
        .bind(user_id)
        .bind(expires_at)
        .execute(db)
        .await?;

    Ok(session_id)
}

async fn optional_session_user(db: &PgPool, headers: &HeaderMap) -> Result<Option<Uuid>, AppError> {
    let Some(session_id) = extract_session_from_headers(headers) else {
        return Ok(None);
    };

    let row = sqlx::query_as::<_, SessionRow>(
        "SELECT user_id FROM sessions WHERE id = $1 AND expires_at > now()",
    )
    .bind(&session_id)
    .fetch_optional(db)
    .await?;

    Ok(row.map(|row| row.user_id))
}

fn user_response(user: UserRowNoHash) -> UserResponse {
    UserResponse {
        id: user.id,
        email: user.email,
        display_name: user.display_name,
        account_type: user.account_type,
    }
}

fn user_response_with_hash(user: UserRow) -> UserResponse {
    UserResponse {
        id: user.id,
        email: Some(user.email),
        display_name: user.display_name,
        account_type: user.account_type,
    }
}

// ---------------------------------------------------------------------------
// Public helper used by other modules
// ---------------------------------------------------------------------------

/// Extracts the session cookie from the request headers, validates the session
/// against the database, and returns the authenticated user's UUID.
pub async fn require_auth(db: &PgPool, headers: &HeaderMap) -> Result<Uuid, AppError> {
    let session_id = extract_session_from_headers(headers).ok_or(AppError::Unauthorized)?;

    let row = sqlx::query_as::<_, SessionRow>(
        "SELECT user_id FROM sessions WHERE id = $1 AND expires_at > now()",
    )
    .bind(&session_id)
    .fetch_optional(db)
    .await?
    .ok_or(AppError::Unauthorized)?;

    Ok(row.user_id)
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

pub async fn register(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
    Json(body): Json<RegisterRequest>,
) -> Result<Response, AppError> {
    // Validate inputs
    if body.email.is_empty() {
        return Err(AppError::BadRequest("email is required".into()));
    }
    if body.password.len() < 8 {
        return Err(AppError::BadRequest(
            "password must be at least 8 characters".into(),
        ));
    }

    // Hash password
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    let password_hash = argon2
        .hash_password(body.password.as_bytes(), &salt)
        .map_err(|e| AppError::Internal(format!("failed to hash password: {e}")))?
        .to_string();

    let display_name = body.display_name.unwrap_or_default();

    let existing_user_id = optional_session_user(&state.db, &headers).await?;

    let user = if let Some(user_id) = existing_user_id {
        let current = sqlx::query_as::<_, UserRowNoHash>(
            "SELECT id, email, display_name, account_type FROM users WHERE id = $1",
        )
        .bind(user_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or(AppError::Unauthorized)?;

        if current.account_type != "anonymous" {
            return Err(AppError::BadRequest(
                "current account is already registered".into(),
            ));
        }

        sqlx::query_as::<_, UserRow>(
            r#"
            UPDATE users
            SET email = $1,
                password_hash = $2,
                display_name = $3,
                account_type = 'registered'
            WHERE id = $4
            RETURNING id, email, password_hash, display_name, account_type
            "#,
        )
        .bind(&body.email)
        .bind(&password_hash)
        .bind(&display_name)
        .bind(user_id)
        .fetch_one(&state.db)
        .await
        .map_err(map_unique_email_error)?
    } else {
        sqlx::query_as::<_, UserRow>(
            r#"
            INSERT INTO users (email, password_hash, display_name, account_type)
            VALUES ($1, $2, $3, 'registered')
            RETURNING id, email, password_hash, display_name, account_type
            "#,
        )
        .bind(&body.email)
        .bind(&password_hash)
        .bind(&display_name)
        .fetch_one(&state.db)
        .await
        .map_err(map_unique_email_error)?
    };

    sqlx::query("DELETE FROM sessions WHERE user_id = $1")
        .bind(user.id)
        .execute(&state.db)
        .await?;
    let session_id = create_session(&state.db, user.id).await?;

    let mut response = Json(user_response_with_hash(user)).into_response();
    response
        .headers_mut()
        .insert("Set-Cookie", session_cookie(&session_id));
    Ok(response)
}

pub async fn login(
    State(state): State<Arc<AppState>>,
    Json(body): Json<LoginRequest>,
) -> Result<Response, AppError> {
    // Look up user
    let user = sqlx::query_as::<_, UserRow>(
        r#"
        SELECT id, email, password_hash, display_name, account_type
        FROM users
        WHERE email = $1
          AND account_type = 'registered'
        "#,
    )
    .bind(&body.email)
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::Unauthorized)?;

    // Verify password
    let parsed_hash = PasswordHash::new(&user.password_hash)
        .map_err(|e| AppError::Internal(format!("failed to parse password hash: {e}")))?;
    Argon2::default()
        .verify_password(body.password.as_bytes(), &parsed_hash)
        .map_err(|_| AppError::Unauthorized)?;

    let session_id = create_session(&state.db, user.id).await?;

    let mut response = Json(user_response_with_hash(user)).into_response();
    response
        .headers_mut()
        .insert("Set-Cookie", session_cookie(&session_id));
    Ok(response)
}

pub async fn anonymous(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Response, AppError> {
    if let Some(user_id) = optional_session_user(&state.db, &headers).await? {
        let user = sqlx::query_as::<_, UserRowNoHash>(
            "SELECT id, email, display_name, account_type FROM users WHERE id = $1",
        )
        .bind(user_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or(AppError::Unauthorized)?;

        return Ok(Json(user_response(user)).into_response());
    }

    let user = sqlx::query_as::<_, UserRowNoHash>(
        r#"
        INSERT INTO users (display_name, account_type)
        VALUES ('', 'anonymous')
        RETURNING id, email, display_name, account_type
        "#,
    )
    .fetch_one(&state.db)
    .await?;

    let session_id = create_session(&state.db, user.id).await?;

    let mut response = Json(user_response(user)).into_response();
    response
        .headers_mut()
        .insert("Set-Cookie", session_cookie(&session_id));
    Ok(response)
}

pub async fn logout(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Response, AppError> {
    if let Some(session_id) = extract_session_from_headers(&headers) {
        sqlx::query("DELETE FROM sessions WHERE id = $1")
            .bind(session_id)
            .execute(&state.db)
            .await?;
    }

    let mut response = axum::http::StatusCode::NO_CONTENT.into_response();
    response
        .headers_mut()
        .insert("Set-Cookie", clear_session_cookie());
    Ok(response)
}

pub async fn delete_account(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Response, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;

    let account_type: String = sqlx::query_scalar("SELECT account_type FROM users WHERE id = $1")
        .bind(user_id)
        .fetch_optional(&state.db)
        .await?
        .ok_or(AppError::Unauthorized)?;

    if account_type != "registered" {
        return Err(AppError::BadRequest(
            "only registered accounts can be deleted".into(),
        ));
    }

    // ON DELETE CASCADE on sessions, rated_areas, user_locations, paint_events
    // removes all dependent rows.
    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user_id)
        .execute(&state.db)
        .await?;

    let mut response = axum::http::StatusCode::NO_CONTENT.into_response();
    response
        .headers_mut()
        .insert("Set-Cookie", clear_session_cookie());
    Ok(response)
}

pub async fn me(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<UserResponse>, AppError> {
    let user_id = require_auth(&state.db, &headers).await?;

    let user = sqlx::query_as::<_, UserRowNoHash>(
        "SELECT id, email, display_name, account_type FROM users WHERE id = $1",
    )
    .bind(user_id)
    .fetch_optional(&state.db)
    .await?
    .ok_or(AppError::Unauthorized)?;

    Ok(Json(user_response(user)))
}

fn map_unique_email_error(e: sqlx::Error) -> AppError {
    if let sqlx::Error::Database(ref db_err) = e {
        if db_err.code().as_deref() == Some("23505") {
            return AppError::BadRequest("email already registered".into());
        }
    }
    AppError::from(e)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extract_session_simple() {
        let mut headers = HeaderMap::new();
        headers.insert("cookie", "session=abc123".parse().unwrap());
        assert_eq!(
            extract_session_from_headers(&headers),
            Some("abc123".to_string())
        );
    }

    #[test]
    fn extract_session_among_multiple_cookies() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "cookie",
            "theme=dark; session=xyz789; lang=de".parse().unwrap(),
        );
        assert_eq!(
            extract_session_from_headers(&headers),
            Some("xyz789".to_string())
        );
    }

    #[test]
    fn extract_session_missing() {
        let mut headers = HeaderMap::new();
        headers.insert("cookie", "theme=dark; lang=de".parse().unwrap());
        assert_eq!(extract_session_from_headers(&headers), None);
    }

    #[test]
    fn extract_session_no_cookie_header() {
        let headers = HeaderMap::new();
        assert_eq!(extract_session_from_headers(&headers), None);
    }

    #[test]
    fn extract_session_empty_value() {
        let mut headers = HeaderMap::new();
        headers.insert("cookie", "session=".parse().unwrap());
        assert_eq!(extract_session_from_headers(&headers), Some("".to_string()));
    }

    #[test]
    fn extract_session_with_uuid_value() {
        let mut headers = HeaderMap::new();
        let uuid = "550e8400-e29b-41d4-a716-446655440000";
        headers.insert("cookie", format!("session={uuid}").parse().unwrap());
        assert_eq!(
            extract_session_from_headers(&headers),
            Some(uuid.to_string())
        );
    }

    #[test]
    fn session_cookie_format() {
        let cookie = session_cookie("test-session-id");
        let s = cookie.to_str().unwrap();
        assert!(s.contains("session=test-session-id"));
        assert!(s.contains("HttpOnly"));
        assert!(s.contains("SameSite=Lax"));
        assert!(s.contains("Path=/"));
        assert!(s.contains("Max-Age=2592000"));
    }

    #[test]
    fn clear_session_cookie_expires() {
        let cookie = clear_session_cookie();
        let s = cookie.to_str().unwrap();
        assert!(s.contains("session="));
        assert!(s.contains("Max-Age=0"));
    }
}

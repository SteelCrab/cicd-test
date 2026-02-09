use axum::extract::State;
use axum::http::StatusCode;
use axum::Json;
use serde::{Deserialize, Serialize};

use crate::s3;
use crate::AppState;

#[derive(Deserialize)]
pub struct PresignRequest {
    pub filename: String,
    pub content_type: String,
}

#[derive(Serialize)]
pub struct PresignResponse {
    pub key: String,
    pub presigned_url: String,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    pub error: String,
}

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: String,
}

/// POST /presign - 업로드용 Presigned URL 반환
pub async fn presign_handler(
    State(state): State<AppState>,
    Json(payload): Json<PresignRequest>,
) -> Result<Json<PresignResponse>, (StatusCode, Json<ErrorResponse>)> {
    // UUID + 원본 파일명으로 고유 키 생성
    let key = format!("{}-{}", uuid::Uuid::new_v4(), payload.filename);

    // Presigned PUT URL 생성
    let presigned_url = s3::generate_presigned_put_url(
        &state.s3_client,
        &state.bucket,
        &key,
        state.presigned_expiry,
        &payload.content_type,
    )
    .await
    .map_err(|e| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(ErrorResponse {
                error: e.to_string(),
            }),
        )
    })?;

    Ok(Json(PresignResponse { key, presigned_url }))
}

/// GET /health - 헬스체크
pub async fn health_handler() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".into(),
    })
}

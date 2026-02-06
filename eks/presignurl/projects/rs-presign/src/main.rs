mod handlers;
mod s3;

use axum::{
    routing::{get, post},
    Router,
};
use std::env;

#[derive(Clone)]
pub struct AppState {
    pub s3_client: aws_sdk_s3::Client,
    pub bucket: String,
    pub presigned_expiry: u64,
}

#[tokio::main]
async fn main() {
    let bucket = env::var("S3_BUCKET_NAME").expect("S3_BUCKET_NAME is required");
    let presigned_expiry: u64 = env::var("PRESIGNED_EXPIRY")
        .unwrap_or_else(|_| "3600".into())
        .parse()
        .expect("PRESIGNED_EXPIRY must be a number");
    let port = env::var("PORT").unwrap_or_else(|_| "8080".into());

    // AWS SDK 설정 로드 (환경변수/IAM Role 자동 인식)
    let config = aws_config::load_defaults(aws_config::BehaviorVersion::latest()).await;
    let s3_client = aws_sdk_s3::Client::new(&config);

    let state = AppState {
        s3_client,
        bucket,
        presigned_expiry,
    };

    let app = Router::new()
        .route("/presign", post(handlers::presign_handler))
        .route("/health", get(handlers::health_handler))
        .with_state(state);

    let addr = format!("0.0.0.0:{port}");
    println!("Listening on {addr}");

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

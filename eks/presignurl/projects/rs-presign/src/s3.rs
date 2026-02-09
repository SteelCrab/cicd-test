use aws_sdk_s3::presigning::PresigningConfig;
use aws_sdk_s3::primitives::ByteStream;
use aws_sdk_s3::Client;
use std::time::Duration;

/// S3에 파일 업로드
#[allow(dead_code)]
pub async fn upload_object(
    client: &Client,
    bucket: &str,
    key: &str,
    body: Vec<u8>,
    content_type: &str,
) -> Result<(), aws_sdk_s3::Error> {
    client
        .put_object()
        .bucket(bucket)
        .key(key)
        .body(ByteStream::from(body))
        .content_type(content_type)
        .send()
        .await?;
    Ok(())
}

/// Presigned GET URL 생성
#[allow(dead_code)]
pub async fn generate_presigned_url(
    client: &Client,
    bucket: &str,
    key: &str,
    expiry_secs: u64,
) -> Result<String, Box<dyn std::error::Error>> {
    let presigning_config = PresigningConfig::builder()
        .expires_in(Duration::from_secs(expiry_secs))
        .build()?;

    let presigned = client
        .get_object()
        .bucket(bucket)
        .key(key)
        .presigned(presigning_config)
        .await?;

    Ok(presigned.uri().to_string())
}

/// Presigned PUT URL 생성 (업로드용)
pub async fn generate_presigned_put_url(
    client: &Client,
    bucket: &str,
    key: &str,
    expiry_secs: u64,
    content_type: &str,
) -> Result<String, Box<dyn std::error::Error>> {
    let presigning_config = PresigningConfig::builder()
        .expires_in(Duration::from_secs(expiry_secs))
        .build()?;

    let presigned = client
        .put_object()
        .bucket(bucket)
        .key(key)
        .content_type(content_type)
        .presigned(presigning_config)
        .await?;

    Ok(presigned.uri().to_string())
}

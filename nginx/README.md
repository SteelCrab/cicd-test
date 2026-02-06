# Nginx Frontend - S3 Upload UI

Rust API와 연동하여 S3 파일 업로드를 수행하는 프론트엔드 웹 서버.
`nginx:alpine` 기반의 경량 컨테이너 이미지.

---
---

## 기능 (Routing)

| Path       | 설명                                      | Target |
|------------|-------------------------------------------|--------|
| `/`        | 파일 업로드 UI 제공 (`index.html`)        | Local  |
| `/presign` | Presigned URL 발급 요청을 백엔드로 프록시 | `http://rust-api:8080` |

## 구성 파일 및 디렉토리

*   `nginx.conf`: Nginx 메인 설정
*   `default.conf`: 리버스 프록시 및 정적 파일 서빙 설정
*   `html/index.html`: 업로드 UI 및 로직 (Direct S3 Upload)
*   `images/`: 정적 이미지 리소스

---

## Docker 빌드 및 실행 (로컬 테스트)

Dockerfile은 `nginx` 디렉토리 루트에 위치하며, 하위의 `html`, `images`, 설정 파일들을 복사합니다.

```bash
cd nginx
docker build -t nginx-web .

# Rust API와 함께 실행 시 (Docker Network 필요)
docker run -d -p 80:80 \
  --name nginx-web \
  --link rust-api \
  nginx-web
```

---

## ECR 배포 (이미지 업로드)

ECS 배포를 위해 이미지를 Amazon ECR에 업로드합니다.

### 1. ECR 리포지토리 생성

```bash
aws ecr create-repository \
  --repository-name nginx-web \
  --region ap-southeast-1
```

### 2. ECR 이미지 Build & Push

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-southeast-1
ECR_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/nginx-web

# ECR 로그인
aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${ECR_URI}

# 빌드 및 태그 설정 (nginx 디렉토리에서 실행)
cd nginx
docker build -t nginx-web .
docker tag nginx-web:latest ${ECR_URI}:latest

# 이미지 Push
docker push ${ECR_URI}:latest
```

---

## 배포 가이드

이 프로젝트는 다양한 배포 방식을 지원합니다.

### 1. CI/CD Workflows
`.github/workflows` 디렉토리에 정의된 파이프라인을 확인하세요.
*   [nginx-asg-s3](../../.github/workflows/nginx-asg-s3.yaml): EC2 Auto Scaling Group 배포
*   [nginx-ecr.yaml](../../.github/workflows/nginx-ecr.yaml): ECR 이미지 빌드 및 Push
*   [nginx-dockerhub.yml](../../.github/workflows/nginx-dockerhub.yml): DockerHub 배포

### 2. Kubernetes (EKS)
`eks_yaml/nginx-web` 디렉토리의 매니페스트를 사용합니다.

```bash
kubectl apply -f eks_yaml/nginx-web/deployment.yaml
kubectl apply -f eks_yaml/nginx-web/service.yaml
```

---

## 아키텍처

```
User (Browser)
  │
  ▼
Nginx (Port 80) ───proxy───▶ Rust API (Port 8080)
  │                                │
  │ (Static File)                  │ (Generate URL)
  ▼                                ▼
index.html                    Presigned URL
  │                                │
  └─────────── PUT ───────────────▶ S3 Bucket
```
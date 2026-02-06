# Rust Presigned URL API

S3 업로드용 Presigned URL을 발급하는 초경량 Rust API 서비스임.

---

## 1. 로컬 실행 (Quick Start)

필수 환경변수를 설정하고 실행함.

```bash
# 환경변수 설정 (본인 AWS 정보로 수정)
export S3_BUCKET_NAME="my-bucket-name"
export AWS_REGION="ap-southeast-1"
# AWS 프로필이 default가 아닌 경우 설정
# export AWS_PROFILE="my-profile"

# 실행
cd rust-api
cargo run
```

테스트 (새 터미널):

```bash
curl -X POST http://localhost:8080/presign \
  -H "Content-Type: application/json" \
  -d '{"filename": "test.png", "content_type": "image/png"}'
```

---

## 2. Docker 빌드

```bash
cd rust-api
docker build -t rust-api .
```

---

## 3. AWS ECS/EKS 배포 준비

### Step 1: 리소스 준비 (최초 1회)

아래 명령어들을 순서대로 실행하여 필요한 AWS 리소스를 생성함.

**1. ECR 리포지토리 생성**

```bash
aws ecr create-repository --repository-name rust-api --region ap-southeast-1
```

**2. S3 버킷 생성**

```bash
aws s3 mb s3://my-upload-bucket --region ap-southeast-1
```

**3. 보안 그룹(Security Group) 생성**

EKS 및 로드밸런서 연동을 위한 보안 그룹을 생성함.

```bash
# VPC ID 확인 (기존 클러스터 사용 시)
export VPC_ID="<VPC_ID>"

# 1) 로드밸런서용 SG 생성 (외부 접근 허용)
LB_SG_ID=$(aws ec2 create-security-group --group-name pista-sg-lb --description "Nginx LB SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $LB_SG_ID --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "Created LB SG: $LB_SG_ID"

# 2) 워크로드(Node)용 SG 생성
RUST_SG_ID=$(aws ec2 create-security-group --group-name pista-sg-rust-api --description "Rust API Node SG" --vpc-id $VPC_ID --query 'GroupId' --output text)
echo "Created Workload SG: $RUST_SG_ID"

# 3) (선택) LB -> 워크로드 트래픽 허용 규칙 추가
# aws ec2 authorize-security-group-ingress --group-id $RUST_SG_ID --protocol tcp --port 0-65535 --source-group $LB_SG_ID
```

**4. IAM 역할 생성 (S3 권한)**

`trust-policy.json` 파일을 생성함:

```json
{ "Version": "2012-10-17", "Statement": [{ "Effect": "Allow", "Principal": { "Service": "ecs-tasks.amazonaws.com" }, "Action": "sts:AssumeRole" }] }
```

명령어를 실행함:

```bash
aws iam create-role --role-name pista-presign-role --assume-role-policy-document file://trust-policy.json
aws iam put-role-policy --role-name pista-presign-role --policy-name s3-access --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["s3:PutObject","s3:GetObject"],"Resource":"arn:aws:s3:::my-upload-bucket/*"}]}'
```

### Step 2: 이미지 배포 (업데이트 시 반복)

```bash
# 계정 ID 가져오기
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_URI=${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-1.amazonaws.com/rust-api

# ECR 로그인 & Push
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ${ECR_URI}
docker tag rust-api:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest
```

> ECS Fargate로 배포하려면 [ECS 배포 가이드(ECS_GUIDE.md)](ECS_GUIDE.md) 문서를 참고함.

---

## 4. Kubernetes (EKS) 배포

`eks_yaml/rust-api/` 폴더의 매니페스트를 사용함.

1. `configmap.yaml`에서 S3 버킷명 등 설정을 수정함
2. `deployment.yaml`에서 이미지 주소(`<ACCOUNT_ID>`)를 수정함
3. `nginx-web/service.yaml`에서 `aws-load-balancer-security-groups`에 위에서 생성한 **LB_SG_ID**를 입력함
4. 배포를 실행함:
    ```bash
    kubectl apply -f eks_yaml/rust-api/
    kubectl apply -f eks_yaml/nginx-web/
    ```

---

## API 명세

| Method | Path | Body (JSON) | 설명 |
| :--- | :--- | :--- | :--- |
| `POST` | `/presign` | `{"filename": "a.png", "content_type": "image/png"}` | 업로드 URL 발급 |
| `GET` | `/health` | - | 상태 확인 |

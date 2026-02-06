# Pista Presign URL - EKS

S3 Presigned URL 업로드 서비스의 EKS 배포 설정임. Kustomize base/overlays 패턴으로 관리함.

## 디렉토리 구조

```
eks/presignurl/
├── cluster/                          # 클러스터 인프라 (K8s 매니페스트 아님)
│   ├── eks-cluster-init.yaml         # eksctl 클러스터 생성 설정
│   └── install-lbc.sh               # AWS Load Balancer Controller 설치
├── kubernetes/                       # K8s 매니페스트 (Kustomize base)
│   ├── rust-api/                     # Rust API 백엔드
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── service-account.yaml
│   └── nginx-web/                    # Nginx 프론트엔드
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       └── service.yaml
├── overlays/
│   └── production/                   # production 환경
│       ├── kustomization.yaml        # 전체 스택 진입점
│       ├── rust-api/
│       │   └── kustomization.yaml    # images transformer
│       └── nginx-web/
│           └── kustomization.yaml    # images transformer
└── projects/                         # 애플리케이션 소스 코드
    ├── rs-presign/                   # Rust API 소스
    └── nginx/                        # Nginx 프론트엔드 소스
```

## 플레이스홀더 설정 (배포 전 필수)

K8s 매니페스트와 클러스터 설정에 `<PLACEHOLDER>` 값이 포함되어 있음. 배포 전에 실제 값으로 교체해야 함.

### 플레이스홀더 목록

| 플레이스홀더 | 설명 | 예시 |
| :--- | :--- | :--- |
| `<ACCOUNT_ID>` | AWS 계정 ID | `123456789012` |
| `<REGION>` | AWS 리전 | `ap-southeast-1` |
| `<S3_BUCKET_NAME>` | S3 버킷 이름 | `my-upload-bucket` |
| `<IAM_ROLE_NAME>` | IRSA용 IAM Role 이름 | `my-presign-role` |
| `<VPC_ID>` | VPC ID | `vpc-0abc1234def567890` |
| `<PUBLIC_SUBNET_1A>` | 퍼블릭 서브넷 (AZ-a) | `subnet-0abc1234def567890` |
| `<PUBLIC_SUBNET_1B>` | 퍼블릭 서브넷 (AZ-b) | `subnet-0abc1234def567891` |
| `<PUBLIC_SUBNET_1C>` | 퍼블릭 서브넷 (AZ-c) | `subnet-0abc1234def567892` |
| `<PRIVATE_SUBNET_1A>` | 프라이빗 서브넷 (AZ-a) | `subnet-0abc1234def567893` |
| `<PRIVATE_SUBNET_1B>` | 프라이빗 서브넷 (AZ-b) | `subnet-0abc1234def567894` |
| `<PRIVATE_SUBNET_1C>` | 프라이빗 서브넷 (AZ-c) | `subnet-0abc1234def567895` |
| `<NODE_SG_ID>` | 워커 노드 보안 그룹 ID | `sg-0abc1234def567890` |
| `<LB_SG_ID>` | 로드밸런서 보안 그룹 ID | `sg-0abc1234def567891` |

### VSCode Search & Replace로 일괄 교체

VSCode에서 `eks/presignurl/` 경로 내 플레이스홀더를 한번에 교체할 수 있음.

1. `Cmd+Shift+H` (macOS) / `Ctrl+Shift+H` (Windows/Linux)로 **Search and Replace** 패널을 열음
2. **"files to include"** 칸에 경로 제한을 입력함:
   ```
   eks/presignurl/**/*.yaml
   ```
3. **Search** 칸에 플레이스홀더, **Replace** 칸에 실제 값을 입력 후 **Replace All** (`Cmd+Option+Enter`)을 클릭함
4. 아래 순서대로 반복함:

| # | Search | Replace (본인 값으로 수정) |
| :--- | :--- | :--- |
| 1 | `<ACCOUNT_ID>` | `123456789012` |
| 2 | `<REGION>` | `ap-southeast-1` |
| 3 | `<S3_BUCKET_NAME>` | `my-upload-bucket` |
| 4 | `<IAM_ROLE_NAME>` | `my-presign-role` |
| 5 | `<VPC_ID>` | `vpc-0xxxxxxxxxxxxxxxxx` |
| 6 | `<PUBLIC_SUBNET_1A>` | `subnet-0xxxxxxxxxxxxxxxxx` |
| 7 | `<PUBLIC_SUBNET_1B>` | `subnet-0xxxxxxxxxxxxxxxxx` |
| 8 | `<PUBLIC_SUBNET_1C>` | `subnet-0xxxxxxxxxxxxxxxxx` |
| 9 | `<PRIVATE_SUBNET_1A>` | `subnet-0xxxxxxxxxxxxxxxxx` |
| 10 | `<PRIVATE_SUBNET_1B>` | `subnet-0xxxxxxxxxxxxxxxxx` |
| 11 | `<PRIVATE_SUBNET_1C>` | `subnet-0xxxxxxxxxxxxxxxxx` |
| 12 | `<NODE_SG_ID>` | `sg-0xxxxxxxxxxxxxxxxx` |
| 13 | `<LB_SG_ID>` | `sg-0xxxxxxxxxxxxxxxxx` |

> `<ACCOUNT_ID>`와 `<REGION>`을 먼저 교체하면 ECR 이미지 URL이 한번에 완성됨.

### 교체 확인

```bash
# 남은 플레이스홀더 확인 (0건이면 완료)
grep -rn '<[A-Z_]*>' eks/presignurl/ --include='*.yaml' | grep -v ALLOWED_IP | grep -v NAMESPACE
```

## 클러스터 생성

```bash
eksctl create cluster -f eks/presignurl/cluster/eks-cluster-init.yaml
```

### AWS Load Balancer Controller 설치

클러스터당 1회만 실행함. NLB/ALB 생성을 위해 필수임.

```bash
./eks/presignurl/cluster/install-lbc.sh
```

## 배포

### 로컬 배포 (kubernetes 직접 적용)

```bash
# 개별 서비스
kubectl apply -k eks/presignurl/kubernetes/rust-api -n <NAMESPACE>
kubectl apply -k eks/presignurl/kubernetes/nginx-web -n <NAMESPACE>
```

### Production 배포 (overlay)

```bash
# 전체 스택
kubectl apply -k eks/presignurl/overlays/production -n <NAMESPACE>

# 개별 서비스 (이미지 태그 지정)
cd eks/presignurl/overlays/production/rust-api
kustomize edit set image \
  "<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/rust-api=<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/rust-api:<TAG>"
kubectl apply -k . -n <NAMESPACE>
```

### Kustomize 빌드 미리보기

```bash
kustomize build eks/presignurl/overlays/production
```

## 새 환경 추가 (예: dev)

```bash
mkdir -p eks/presignurl/overlays/dev/rust-api eks/presignurl/overlays/dev/nginx-web
```

각 서비스의 `kustomization.yaml`에서 kubernetes를 참조하고 환경별 patches/images를 설정함.

## CI/CD 파이프라인

GitHub Actions를 통해 자동 빌드 및 배포함. CI 워크플로우는 GitHub Secrets에서 동적으로 ECR Registry 주소를 구성하므로 매니페스트 플레이스홀더 교체 없이 배포함.

### CI Secrets 설정

```shell
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_REGION --body "ap-southeast-1"
gh secret set EKS_CLUSTER_NAME --body "pista-cluster"
gh secret set K8S_NAMESPACE --body "default"
gh secret set ECR_REPOSITORY_RUST_API --body "rust-api"
gh secret set ECR_REPOSITORY_NGINX_WEB --body "nginx-web"
```

| 워크플로우 | 트리거 경로 | 설명 |
| :--- | :--- | :--- |
| `rust-api-eks.yaml` | `eks/presignurl/projects/rs-presign/**`, `eks/presignurl/kubernetes/rust-api/**` | Rust API 빌드 → ECR 푸시 → EKS 배포 |
| `nginx-web-eks.yaml` | `eks/presignurl/projects/nginx/**`, `eks/presignurl/kubernetes/nginx-web/**` | Nginx 빌드 → ECR 푸시 → EKS + NLB 배포 |

### 필요한 GitHub Secrets

| Secret 이름 | 설명 |
| :--- | :--- |
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM Secret Key |
| `AWS_REGION` | AWS 리전 (예: `ap-southeast-1`) |
| `ECR_REPOSITORY_RUST_API` | Rust API ECR 리포지토리 이름 |
| `ECR_REPOSITORY_NGINX_WEB` | Nginx Web ECR 리포지토리 이름 |
| `EKS_CLUSTER_NAME` | EKS 클러스터 이름 |
| `K8S_NAMESPACE` | Kubernetes 네임스페이스 |

### GitHub Environment 설정

Deploy job은 `production` Environment의 승인을 거쳐 실행함.

Settings → Environments → New environment → `production`에서 **Required reviewers** 체크 후 승인자를 추가함.

### 배포 흐름

```
Push to main/ci/eks → Build & Test → ECR Push → [승인 대기] → kustomize edit set image → kubectl apply -k
```

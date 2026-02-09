# Pista FastAPI - EKS

Nginx 프론트엔드 + FastAPI 백엔드의 EKS 배포 설정임. Kustomize base/overlays 패턴으로 관리함.

## 디렉토리 구조

```
eks/fastapi/
├── argocd/                           # ArgoCD 설정
│   ├── install.sh                    # ArgoCD 클러스터 설치 스크립트
│   └── application.yaml             # ArgoCD Application (fastapi-app + nginx-web)
├── cluster/                          # 클러스터 인프라 (K8s 매니페스트 아님)
│   ├── eks-cluster-init.yaml         # eksctl 클러스터 생성 설정
│   └── install-lbc.sh               # AWS Load Balancer Controller 설치
├── kubernetes/                       # K8s 매니페스트 (Kustomize base)
│   ├── fastapi-app/                  # FastAPI 백엔드 (ClusterIP)
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── nginx-web/                    # Nginx 프론트엔드 (NLB)
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       └── service.yaml
├── overlays/
│   └── production/
│       ├── kustomization.yaml        # 전체 스택 진입점
│       ├── fastapi-app/
│       │   └── kustomization.yaml    # images transformer
│       └── nginx-web/
│           └── kustomization.yaml    # images transformer
└── projects/                         # 애플리케이션 소스 코드
    ├── fastapi/                      # FastAPI 백엔드 소스
    └── nginx/                        # Nginx 프론트엔드 소스
```

## 아키텍처

```
Client → NLB → Nginx (port 80) → FastAPI (port 8000, ClusterIP)
                 ├── /           → 정적 HTML 페이지 (Nginx)
                 ├── /api        → proxy_pass → fastapi-app:8000
                 └── /health     → proxy_pass → fastapi-app:8000
```

## 초기 셋업 (1회)

아래 순서대로 진행함. 모든 단계가 완료되어야 CI/CD가 동작함.

### Step 1. EKS 클러스터 생성

```bash
eksctl create cluster -f eks/fastapi/cluster/eks-cluster-init.yaml
```

### Step 2. kubeconfig 설정

eksctl이 자동으로 설정하지만, 다른 환경에서 작업할 경우 수동으로 연결함.

```bash
aws eks update-kubeconfig --name pista-vpc --region ap-southeast-1
```

확인:

```bash
kubectl get nodes
```

### Step 3. AWS Load Balancer Controller 설치

NLB 생성을 위해 필수임.

```bash
./eks/fastapi/cluster/install-lbc.sh
```

### Step 4. ECR 리포지토리 생성

서비스별 ECR 리포지토리를 생성함.

```bash
aws ecr create-repository --repository-name fastapi-app --region ap-southeast-1
aws ecr create-repository --repository-name nginx-web --region ap-southeast-1
```

### Step 5. 초기 Docker 이미지 빌드 및 ECR 푸시

ArgoCD Application 등록 전에 이미지가 ECR에 존재해야 Pod가 정상 기동함.

```bash
# ECR 로그인
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com

# FastAPI 이미지 빌드 & 푸시
docker build -t <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/fastapi-app:latest \
  ./eks/fastapi/projects/fastapi/
docker push <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/fastapi-app:latest

# Nginx 이미지 빌드 & 푸시
docker build -t <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/nginx-web:latest \
  ./eks/fastapi/projects/nginx/
docker push <ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/nginx-web:latest
```

### Step 6. ArgoCD 설치

```bash
./eks/fastapi/argocd/install.sh
```

또는 수동으로:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Step 7. ArgoCD Server 주소 및 비밀번호 확인

```bash
# ARGOCD_SERVER 확인 (EXTERNAL-IP 값)
kubectl get svc argocd-server -n argocd

# ARGOCD_PASSWORD 확인
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

### Step 8. ArgoCD 비밀번호 변경

초기 비밀번호는 보안상 변경을 권장함.

```bash
argocd login <ARGOCD_SERVER> --username admin --password <초기 비밀번호> --grpc-web
argocd account update-password
```

### Step 9. GitHub Secrets 등록

```bash
# AWS
gh secret set AWS_ACCESS_KEY_ID
gh secret set AWS_SECRET_ACCESS_KEY
gh secret set AWS_REGION --body "ap-southeast-1"

# ECR (서비스별 리포지토리)
gh secret set ECR_REPOSITORY_FASTAPI_APP --body "fastapi-app"
gh secret set ECR_REPOSITORY_NGINX_WEB --body "nginx-web"

# ArgoCD (Step 7~8에서 확인/변경한 값)
gh secret set ARGOCD_SERVER --body "<Step 7에서 확인한 EXTERNAL-IP>"
gh secret set ARGOCD_PASSWORD --body "<Step 8에서 변경한 비밀번호>"
```

### Step 10. GitHub Environment 설정

Deploy job은 `production` Environment의 승인을 거쳐 실행함.

Settings → Environments → New environment → `production`에서 **Required reviewers** 체크 후 승인자를 추가함.

### Step 11. ArgoCD Application 등록

fastapi-app, nginx-web 두 개의 Application을 등록함.

```bash
kubectl apply -f eks/fastapi/argocd/application.yaml
```

**왜 2개인가?** 각 서비스의 빌드/배포 주기가 다르기 때문임.
- Application이 1개면 FastAPI만 수정해도 nginx까지 재배포되고, 동시 Push 시 sync 충돌이 발생할 수 있음
- 2개로 분리하면 서비스별 독립 배포/롤백이 가능하고, ArgoCD 대시보드에서 개별 상태를 확인할 수 있음

### Step 12. 배포 확인

```bash
# ArgoCD Application 상태 확인
argocd app get fastapi-app
argocd app get nginx-web

# Pod 상태 확인
kubectl get pods

# NLB 주소 확인 (EXTERNAL-IP로 브라우저 접속)
kubectl get svc pista-svc-nginx-web
```

> 여기까지 완료하면 이후 Push만으로 자동 배포됨.

## CI/CD 파이프라인

GitHub Actions + ArgoCD를 통해 자동 빌드 및 EKS 배포함.

| 워크플로우 | 트리거 경로 | 설명 |
| :--- | :--- | :--- |
| `fastapi-eks.yml` | `eks/fastapi/projects/fastapi/**`, `eks/fastapi/kubernetes/fastapi-app/**` | FastAPI 빌드 → ECR 푸시 → ArgoCD 배포 |
| `nginx-web-eks.yml` | `eks/fastapi/projects/nginx/**`, `eks/fastapi/kubernetes/nginx-web/**` | Nginx 빌드 → ECR 푸시 → ArgoCD 배포 |

### 배포 흐름

```
Push to main/ci/eks-fastapi
  → build job: Lint & Test
  → deploy job (승인 대기):
      → ECR Login → Docker Build & Push
      → ArgoCD Login → argocd app set image → argocd app sync → wait
```

### 필요한 GitHub Secrets

| Secret 이름 | 확인 방법 | 설명 |
| :--- | :--- | :--- |
| `AWS_ACCESS_KEY_ID` | AWS IAM 콘솔 | AWS IAM Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM 콘솔 | AWS IAM Secret Key |
| `AWS_REGION` | - | AWS 리전 (예: `ap-southeast-1`) |
| `ECR_REPOSITORY_FASTAPI_APP` | - | FastAPI ECR 리포지토리 이름 |
| `ECR_REPOSITORY_NGINX_WEB` | - | Nginx ECR 리포지토리 이름 |
| `ARGOCD_SERVER` | Step 7: `kubectl get svc` | ArgoCD Server EXTERNAL-IP |
| `ARGOCD_PASSWORD` | Step 8: `argocd account update-password` | ArgoCD admin 비밀번호 |

## 플레이스홀더 설정

K8s 매니페스트의 `<PLACEHOLDER>` 값을 실제 값으로 교체해야 함. CI 워크플로우는 GitHub Secrets에서 동적으로 ECR Registry 주소를 구성하므로 매니페스트 플레이스홀더 교체 없이 배포함.

| 플레이스홀더 | 설명 | 예시 |
| :--- | :--- | :--- |
| `<ACCOUNT_ID>` | AWS 계정 ID | `123456789012` |
| `<REGION>` | AWS 리전 | `ap-southeast-1` |
| `<LB_SG_ID>` | 로드밸런서 보안 그룹 ID | `sg-0abc1234def567891` |

## 수동 배포

ArgoCD 없이 직접 배포할 경우.

```bash
# 개별 서비스
kubectl apply -k eks/fastapi/kubernetes/fastapi-app -n <NAMESPACE>
kubectl apply -k eks/fastapi/kubernetes/nginx-web -n <NAMESPACE>

# 전체 스택 (overlay)
kubectl apply -k eks/fastapi/overlays/production -n <NAMESPACE>
```

## 엔드포인트

| 경로 | 서비스 | 설명 |
| :--- | :--- | :--- |
| `GET /` | nginx | HTML 웹 페이지 |
| `GET /api` | nginx → fastapi | JSON API (프록시) |
| `GET /health` | nginx → fastapi | 헬스체크 (프록시) |

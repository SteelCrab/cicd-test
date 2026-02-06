# EKS Cluster & Kubernetes Manifests

AWS EKS 클러스터 및 애플리케이션 배포 설정입니다.

## 📑 목차

- [설정 변수](#설정-변수)
- [디렉토리 구조](#-디렉토리-구조)
- [클러스터 생성](#-클러스터-생성)
- [애플리케이션 배포](#-애플리케이션-배포)
- [CI/CD 파이프라인](#-cicd-파이프라인)

---

## 설정 변수

| 플레이스 홀더 | 설명 | 예시 |
| :--- | :--- | :--- |
| `<VPC_ID>` | 클러스터가 설치될 VPC ID | `vpc-067604da147fbd40a` |
| `<SUBNET_ID>` | 서브넷 ID (Public/Private) | `subnet-0f088b6509fe031b3` |
| `<SG_ID>` | 노드 그룹 보안 그룹 ID | `sg-03c40d9a7665fd3d8` |

### 🔐 보안 그룹이 없는 경우

**노드 그룹용 보안 그룹 생성:**
```bash
# 보안 그룹 생성
aws ec2 create-security-group \
  --group-name pista-eks-node-sg \
  --description "EKS Node Group Security Group" \
  --vpc-id <VPC_ID>

# 노드 간 통신 허용 (자기 자신 참조)
aws ec2 authorize-security-group-ingress \
  --group-id <SG_ID> \
  --source-group <SG_ID> \
  --protocol all
```

---

## 📂 디렉토리 구조

| 파일/폴더 | 설명 |
| :--- | :--- |
| `eks-cluster-init.yaml` | EKS 클러스터 생성을 위한 eksctl 설정 파일. VPC, 서브넷, 노드 그룹, IAM 정책 등을 정의 |
| `install_lbc.sh` | AWS Load Balancer Controller 설치 자동화 스크립트. IAM 정책 생성, ServiceAccount 설정, Helm 설치 수행 |
| `nginx-web/` | Nginx 기반 Frontend 웹 서버 배포 매니페스트 (Deployment + LoadBalancer Service) |
| `rust-api/` | Rust 기반 Backend API 서버 배포 매니페스트 (Deployment + ClusterIP Service + ConfigMap + ServiceAccount) |

## 🚀 클러스터 생성

```bash
eksctl create cluster -f eks-cluster-init.yaml
```

### AWS Load Balancer Controller 설치

> ⚠️ **클러스터당 1회만 실행** - NLB/ALB 생성을 위해 필수

```bash
./install-lbc.sh
```

**설치 확인:**
```bash
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## 📦 애플리케이션 배포

```bash
kubectl apply -f rust-api/
kubectl apply -f nginx-web/
```

## 🔄 CI/CD 파이프라인

GitHub Actions를 통한 자동 빌드 및 배포가 설정되어 있습니다.
### CI Fast Secrets 

```shell
# gh CLI로 한번에 설정
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
| `rust-api-eks.yaml` | `rust-api/**`, `eks_yaml/rust-api/**` | Rust API 빌드 → ECR 푸시 → EKS 배포 |
| `nginx-web-eks.yaml` | `nginx/**`, `eks_yaml/nginx-web/**` | Nginx 빌드 → ECR 푸시 → EKS + NLB 배포 |

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

Deploy job은 `production` Environment의 승인을 거쳐 실행됩니다.

**설정 방법:** Settings → Environments → New environment → `production`
- **Required reviewers** 체크 → 승인자 추가

### 배포 흐름

```
Push to main/ci/eks → Build & Test → ECR Push → [승인 대기] → kubectl apply → Rolling Restart
```
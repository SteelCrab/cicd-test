# Rust API Backend Deployment

Rust API 백엔드 서비스의 K8s 배포 설정임.

## 설정 변수

배포 전 아래 플레이스홀더를 실제 값으로 교체함.

| 플레이스홀더 | 설명 | 예시 |
| :--- | :--- | :--- |
| `<ACCOUNT_ID>` | AWS 계정 ID | `123456789012` |
| `<REGION>` | AWS 리전 | `ap-southeast-1` |
| `<S3_BUCKET_NAME>` | S3 버킷 이름 | `my-bucket` |
| `<IAM_ROLE_NAME>` | IRSA용 IAM Role 이름 | `my-presign-role` |

## 파일 설명

| 파일 | 설명 |
| :--- | :--- |
| `deployment.yaml` | Rust API 컨테이너를 Pod 2개 복제본으로 배포함. ConfigMap 환경변수를 참조하며 Readiness/Liveness Probe로 헬스체크를 설정함 |
| `service.yaml` | 클러스터 내부 통신용 ClusterIP 서비스임. 8080 포트로 Pod에 연결함 |
| `configmap.yaml` | 애플리케이션 환경변수를 관리함 (S3 버킷명, AWS 리전, Presigned URL 만료시간) |
| `service-account.yaml` | IRSA(IAM Roles for Service Accounts)를 설정함. S3 Presigned URL 생성을 위한 IAM Role을 연결함 |

## 배포 방법

```bash
kubectl apply -f .
```

## 배포 확인

```bash
kubectl get pods -l app=rust-api
```

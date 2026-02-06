# Rust API Backend Deployment

Rust API 백엔드 서비스 배포 설정입니다.

## 📑 목차

- [설정 변수](#설정-변수)
- [파일 설명](#파일-설명)
- [배포 방법](#-배포-방법)
- [배포 확인](#-배포-확인)

---

## 설정 변수

| 플레이스 홀더 | 설명 | 예시 |
| :--- | :--- | :--- |
| `<BUCKET_NAME>` | S3 버킷 이름 | `pista-s3` |
| `<REGION>` | AWS 리전 | `ap-southeast-1` |
| `<ACCOUNT_ID>` | AWS 계정 ID | `__ACCOUNT_ID__` |

---

## 파일 설명

| 파일 | 설명 |
| :--- | :--- |
| `deployment.yaml` | Rust API 컨테이너 Pod 2개 복제본 배포. ConfigMap 환경변수 참조, Readiness/Liveness Probe로 헬스체크 설정 |
| `service.yaml` | 클러스터 내부 통신용 ClusterIP 서비스. 8080 포트로 Pod 연결 |
| `configmap.yaml` | 애플리케이션 환경변수 관리 (S3 버킷명, AWS 리전, Presigned URL 만료시간) |
| `service-account.yaml` | IRSA(IAM Roles for Service Accounts) 설정. S3 Presigned URL 생성을 위한 IAM Role 연결 |

## 🚀 배포 방법

```bash
kubectl apply -f .
```

## ✅ 배포 확인

```bash
kubectl get pods -l app=rust-api
```

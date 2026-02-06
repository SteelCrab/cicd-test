# Nginx Web Frontend Deployment

Nginx 웹 서버 및 로드밸런서 배포 설정입니다.

## 📑 목차

- [설정 변수](#설정-변수)
- [파일 설명](#-파일-설명)
- [배포 방법](#-배포-방법)
- [배포 확인](#-배포-확인)

---

## 설정 변수

| 플레이스 홀더 | 설명 | 예시 |
| :--- | :--- | :--- |
| `<ACCOUNT_ID>` | AWS 계정 ID (이미지 주소용) | `__ACCOUNT_ID__` |
| `<LB_SG_ID>` | 로드밸런서용 보안 그룹 ID | `sg-06972396556137697` |

### 🔐 보안 그룹이 없는 경우

**로드밸런서용 보안 그룹 생성:**
```bash
# 보안 그룹 생성
aws ec2 create-security-group \
  --group-name pista-nlb-sg \
  --description "NLB Security Group for Nginx Web" \
  --vpc-id <VPC_ID>

# HTTP(80) 인바운드 허용
aws ec2 authorize-security-group-ingress \
  --group-id <LB_SG_ID> \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

---

## 📂 파일 설명

| 파일 | 설명 |
| :--- | :--- |
| `deployment.yaml` | Nginx 컨테이너의 Pod를 2개 복제본으로 배포. ECR 이미지를 사용하며 CPU/메모리 리소스 제한 설정 |
| `service.yaml` | 외부 접근용 Network Load Balancer(NLB) 생성. AWS LBC 어노테이션으로 internet-facing 설정 |

## 🚀 배포 방법

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

## ✅ 배포 확인

```bash
kubectl get svc pista-svc-nginx-web
```
---
#!/bin/bash
set -e

echo "=== ArgoCD 설치 스크립트 ==="

# 1. ArgoCD 네임스페이스 생성
echo "1. ArgoCD 네임스페이스 생성..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# 2. ArgoCD 설치
echo "2. ArgoCD 설치..."
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 3. ArgoCD Pod 준비 대기
echo "3. ArgoCD Pod 준비 대기..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=120s

# 4. ArgoCD Server를 LoadBalancer로 노출
echo "4. ArgoCD Server Service 타입 변경 (LoadBalancer)..."
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# 5. 초기 admin 비밀번호 출력
echo "5. 초기 admin 비밀번호:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""

echo ""
echo "=== 설치 완료 ==="
echo "ArgoCD URL 확인:"
echo "  kubectl get svc argocd-server -n argocd"
echo "Username: admin"
echo "비밀번호 변경: argocd account update-password"
echo ""
echo "=== Private 레포 사용 시 ==="
echo "ArgoCD에 GitHub 레포 credential 등록이 필요함:"
echo "  argocd repo add https://github.com/<OWNER>/<REPO>.git \\"
echo "    --username <GITHUB_USERNAME> \\"
echo "    --password <GITHUB_PAT>"
echo ""
echo "GitHub PAT 생성: Settings → Developer settings → Personal access tokens → Fine-grained tokens"
echo "  필요 권한: Contents (Read-only)"

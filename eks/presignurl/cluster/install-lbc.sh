#!/bin/bash
set -e

CLUSTER_NAME="pista-cluster"
REGION="ap-southeast-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
POLICY_ARN="arn:aws:iam::$ACCOUNT_ID:policy/AWSLoadBalancerControllerIAMPolicy"

echo "=== AWS Load Balancer Controller 설치 스크립트 ==="

# 1. IAM Policy 생성 (없으면 생성)
echo "1. IAM Policy 확인 및 생성..."
if ! aws iam get-policy --policy-arn $POLICY_ARN >/dev/null 2>&1; then
    curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json
    rm iam_policy.json
    echo "IAM Policy 생성 완료."
else
    echo "IAM Policy가 이미 존재합니다."
fi

# 2. ServiceAccount 생성 (IRSA)
echo "2. ServiceAccount 생성..."
eksctl create iamserviceaccount \
  --cluster=$CLUSTER_NAME \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --role-name AmazonEKSLoadBalancerControllerRole \
  --attach-policy-arn=$POLICY_ARN \
  --approve \
  --region $REGION \
  --override-existing-serviceaccounts

# 3. Helm 설치
echo "3. Helm Chart 설치..."
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller

echo "=== 설치 완료 ==="
kubectl get deployment -n kube-system aws-load-balancer-controller

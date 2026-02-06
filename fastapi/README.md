# FastAPI Hello World - ECS 배포 가이드

Python FastAPI 기반 REST API 서비스.
Alpine 경량 이미지로 빌드, ECS Fargate 배포.

---

## API

| Method | Path | 설명                       |
|--------|------|----------------------------|
| GET    | `/`  | Hello World 메시지 반환    |

## 로컬 실행

```bash
cd fastapi
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

## 테스트

```bash
pytest test_main.py
```

---

## Docker 빌드

```bash
cd fastapi
docker build -t fastapi-app .
docker run -p 8000:8000 fastapi-app
```

---

## ECS 배포

### 1. ECR 리포지토리 생성

```bash
aws ecr create-repository \
  --repository-name fastapi-app \
  --region ap-southeast-1
```

### 2. ECR 이미지 Push

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=ap-southeast-1
ECR_URI=${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/fastapi-app

aws ecr get-login-password --region ${REGION} | \
  docker login --username AWS --password-stdin ${ECR_URI}

docker build -t fastapi-app .
docker tag fastapi-app:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest
```

### 3. IAM Role 생성

**신뢰 정책 (trust-policy.json)**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

```bash
# Task Execution Role (ECR pull, CloudWatch logs)
aws iam create-role \
  --role-name fastapi-execution-role \
  --assume-role-policy-document file://trust-policy.json

aws iam attach-role-policy \
  --role-name fastapi-execution-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### 4. ECS 클러스터 생성

```bash
aws ecs create-cluster \
  --cluster-name fastapi-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

### 5. CloudWatch 로그 그룹 생성

```bash
aws logs create-log-group \
  --log-group-name /ecs/fastapi-app \
  --region ap-southeast-1
```

### 6. Task Definition 등록

**task-definition.json**:
```json
{
  "family": "fastapi-app",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/fastapi-execution-role",
  "containerDefinitions": [
    {
      "name": "fastapi-app",
      "image": "<ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/fastapi-app:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -qO- http://localhost:8000/ || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/fastapi-app",
          "awslogs-region": "ap-southeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

```bash
aws ecs register-task-definition \
  --cli-input-json file://task-definition.json
```

### 7. ALB 생성 (Application Load Balancer)

```bash
# ALB 생성
aws elbv2 create-load-balancer \
  --name fastapi-alb \
  --subnets <PUBLIC_SUBNET_1> <PUBLIC_SUBNET_2> \
  --security-groups <ALB_SG_ID> \
  --scheme internet-facing

# Target Group 생성
aws elbv2 create-target-group \
  --name fastapi-tg \
  --protocol HTTP \
  --port 8000 \
  --vpc-id <VPC_ID> \
  --target-type ip \
  --health-check-path /

# Listener 생성
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<TG_ARN>
```

### 8. ECS Service 생성

```bash
aws ecs create-service \
  --cluster fastapi-cluster \
  --service-name fastapi-service \
  --task-definition fastapi-app \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[<PRIVATE_SUBNET_1>,<PRIVATE_SUBNET_2>],
    securityGroups=[<TASK_SG_ID>],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=<TG_ARN>,containerName=fastapi-app,containerPort=8000"
```

---

## 아키텍처

```
Client
  │
  ▼
ALB (port 80)
  │
  ▼
ECS Fargate Service (port 8000)
  ├── Task 1: fastapi-app container
  └── Task 2: fastapi-app container
```

---

## 배포 확인

```bash
# Service 상태 확인
aws ecs describe-services \
  --cluster fastapi-cluster \
  --services fastapi-service \
  --query 'services[0].{status:status,running:runningCount,desired:desiredCount}'

# ALB DNS로 테스트
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names fastapi-alb \
  --query 'LoadBalancers[0].DNSName' --output text)

curl http://${ALB_DNS}/
# {"message": "Hello World"}
```

---

## 서비스 업데이트 (재배포)

```bash
# 새 이미지 빌드 & push
docker build -t fastapi-app .
docker tag fastapi-app:latest ${ECR_URI}:latest
docker push ${ECR_URI}:latest

# ECS 서비스 강제 재배포
aws ecs update-service \
  --cluster fastapi-cluster \
  --service fastapi-service \
  --force-new-deployment
```

---

## 리소스 정리

```bash
aws ecs update-service --cluster fastapi-cluster --service fastapi-service --desired-count 0
aws ecs delete-service --cluster fastapi-cluster --service fastapi-service
aws ecs delete-cluster --cluster fastapi-cluster
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>
aws elbv2 delete-target-group --target-group-arn <TG_ARN>
aws ecr delete-repository --repository-name fastapi-app --force
aws logs delete-log-group --log-group-name /ecs/fastapi-app
```

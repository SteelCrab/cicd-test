# AWS ECS (Fargate) 배포 가이드

`rust-api` 서비스를 AWS ECS Fargate 환경에 배포하는 상세 절차입니다.
공통 리소스(ECR, S3, IAM, 보안그룹) 생성이 완료된 상태라고 가정합니다.

---

## 1. ECS 클러스터 생성

```bash
aws ecs create-cluster \
  --cluster-name rust-api-cluster \
  --capacity-providers FARGATE \
  --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

## 2. CloudWatch 로그 그룹 생성

```bash
aws logs create-log-group \
  --log-group-name /ecs/rust-api \
  --region ap-southeast-1
```

## 3. Task Definition 등록

아래 내용을 `task-definition.json`으로 저장한 후 등록합니다.
( `<ACCOUNT_ID>` 부분은 본인 계정 ID로 수정 필요)

**task-definition.json**:
```json
{
  "family": "rust-api",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/rust-api-execution-role",
  "taskRoleArn": "arn:aws:iam::<ACCOUNT_ID>:role/pista-presign-role",
  "containerDefinitions": [
    {
      "name": "rust-api",
      "image": "<ACCOUNT_ID>.dkr.ecr.ap-southeast-1.amazonaws.com/rust-api:latest",
      "portMappings": [
        {
          "containerPort": 8080,
          "protocol": "tcp"
        }
      ],
      "environment": [
        { "name": "S3_BUCKET_NAME", "value": "my-upload-bucket" },
        { "name": "AWS_REGION", "value": "ap-southeast-1" },
        { "name": "PRESIGNED_EXPIRY", "value": "3600" }
      ],
      "healthCheck": {
        "command": ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      },
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/rust-api",
          "awslogs-region": "ap-southeast-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

**등록 명령어:**
```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

## 4. ALB (Application Load Balancer) 생성

보안 그룹(`pista-sg-lb`)은 `README.md` 가이드에 따라 생성되어 있어야 합니다.

```bash
# ALB 생성
aws elbv2 create-load-balancer \
  --name rust-api-alb \
  --subnets <PUBLIC_SUBNET_1> <PUBLIC_SUBNET_2> \
  --security-groups <LB_SG_ID> \
  --scheme internet-facing

# Target Group 생성
aws elbv2 create-target-group \
  --name rust-api-tg \
  --protocol HTTP \
  --port 8080 \
  --vpc-id <VPC_ID> \
  --target-type ip \
  --health-check-path /health

# Listener 생성
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTP \
  --port 80 \
  --default-actions Type=forward,TargetGroupArn=<TG_ARN>
```

## 5. ECS 서비스 생성

보안 그룹(`pista-sg-rust-api`)은 `README.md` 가이드에 따라 생성되어 있어야 합니다.

```bash
aws ecs create-service \
  --cluster rust-api-cluster \
  --service-name rust-api-service \
  --task-definition rust-api \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={
    subnets=[<PRIVATE_SUBNET_1>,<PRIVATE_SUBNET_2>],
    securityGroups=[<RUST_SG_ID>],
    assignPublicIp=DISABLED
  }" \
  --load-balancers "targetGroupArn=<TG_ARN>,containerName=rust-api,containerPort=8080"
```

## 6. 서비스 업데이트 (재배포)

새 이미지를 Push한 후 강제 재배포를 수행합니다.

```bash
aws ecs update-service \
  --cluster rust-api-cluster \
  --service rust-api-service \
  --force-new-deployment
```

## 7. 리소스 정리

```bash
aws ecs update-service --cluster rust-api-cluster --service rust-api-service --desired-count 0
aws ecs delete-service --cluster rust-api-cluster --service rust-api-service
aws ecs delete-cluster --cluster rust-api-cluster
aws elbv2 delete-load-balancer --load-balancer-arn <ALB_ARN>
aws elbv2 delete-target-group --target-group-arn <TG_ARN>
aws ecr delete-repository --repository-name rust-api --force
aws logs delete-log-group --log-group-name /ecs/rust-api
```

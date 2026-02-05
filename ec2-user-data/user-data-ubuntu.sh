#!/bin/bash

# 1. SSM 에이전트 설치 (최우선 실행)
# 인스턴스가 뜨자마자 AWS 콘솔에서 제어 가능하도록 먼저 설치합니다.
snap install amazon-ssm-agent --classic
snap start amazon-ssm-agent

# 2. 패키지 업데이트 및 필수 도구 설치
apt-get update -y
apt-get install -y curl unzip net-tools apt-transport-https ca-certificates gnupg lsb-release

# 3. Docker 설치 (공식 저장소 등록 방식)
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update -y
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Docker 권한 설정 및 실행
systemctl enable --now docker
usermod -aG docker ubuntu

# 4. AWS CLI v2 설치 (ECR 로그인 및 SSM 통신에 필수)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws/

# 5. 최신 Docker 이미지 자동 배포 (인스턴스 최초 시작 시)
# EC2 메타데이터에서 리전 정보 가져오기
AWS_REGION=$(ec2-metadata --availability-zone | sed 's/.*: \(.*\).$/\1/')
ECR_REGISTRY="__ACCOUNT_ID__.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO="pista/web"

# ECR 로그인
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# latest 이미지 pull 및 실행
docker pull $ECR_REGISTRY/$ECR_REPO:latest
docker run -d --name nginx-server -p 80:80 $ECR_REGISTRY/$ECR_REPO:latest

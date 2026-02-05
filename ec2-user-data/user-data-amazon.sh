#!/bin/bash
# Amazon Linux 2023 User Data Script
# Private EC2 인스턴스용 - SSM + Docker 환경 구성

set -e

# 1. SSM 에이전트 확인 (Amazon Linux 2023은 기본 설치됨)
# 인스턴스가 뜨자마자 AWS 콘솔에서 제어 가능하도록 활성화합니다.
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

# 2. 패키지 업데이트 및 필수 도구 설치
dnf update -y
dnf install -y curl unzip net-tools

# 3. Docker 설치 (Amazon Linux 2023 공식 저장소)
dnf install -y docker
systemctl enable docker
systemctl start docker

# Docker 권한 설정 (ec2-user는 Amazon Linux 기본 사용자)
usermod -aG docker ec2-user

# 4. AWS CLI v2 (Amazon Linux 2023은 기본 설치됨, 최신 버전 확인용)
# 이미 설치되어 있으면 스킵
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/
fi

# 5. 설치 확인 로그
echo "=== Installation Complete ==="
echo "SSM Agent: $(amazon-ssm-agent --version 2>/dev/null || echo 'installed')"
echo "Docker: $(docker --version)"
echo "AWS CLI: $(aws --version)"

# EKS

AWS EKS 관련 프로젝트 및 도구 모음임.

## 디렉토리 구조

```
eks/
├── eks_install_linux.sh    # EKS 도구 원클릭 설치 (Linux)
├── eks_install_mac.sh      # EKS 도구 원클릭 설치 (macOS)
└── presignurl/             # S3 Presigned URL 업로드 서비스
```

## 설치 스크립트

EKS 클러스터 운영에 필요한 CLI 도구를 한번에 설치함.

| 도구 | 설명 |
| :--- | :--- |
| Docker | 컨테이너 빌드/실행 |
| AWS CLI v2 | AWS 서비스 접근 |
| kubectl | Kubernetes 클러스터 제어 |
| eksctl | EKS 클러스터 생성/관리 |
| Helm | Kubernetes 패키지 관리 |

### Linux (Ubuntu/Debian)

```bash
sudo ./eks/eks_install_linux.sh
```

Docker 설치, apt 패키지 설정, docker 그룹 추가, kubectl/eksctl 바이너리 설치, bash 자동완성까지 포함함.

### macOS

```bash
./eks/eks_install_mac.sh
```

Homebrew 기반 설치함. Apple Silicon / Intel 자동 감지함. zsh/bash 자동완성 설정 포함함.

## 프로젝트

| 프로젝트 | 설명 |
| :--- | :--- |
| [presignurl](presignurl/) | S3 Presigned URL 기반 파일 업로드 서비스 (Rust API + Nginx) |

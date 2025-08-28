# Kubernetes 배포 스크립트 가이드

이 디렉토리에는 AKS Demo 프로젝트의 Kubernetes 배포를 자동화하는 스크립트들이 포함되어 있습니다.

## 📋 스크립트 목록

### 🚀 배포 스크립트
- **`deploy-production.sh`** - Production 환경 배포
- **`deploy-local.sh`** - 로컬 환경 배포 (기존)

### 🧹 정리 스크립트
- **`cleanup-production.sh`** - Production 환경 정리
- **`cleanup-local.sh`** - 로컬 환경 정리 (기존)

### 🔧 관리 스크립트
- **`check-status.sh`** - 배포 상태 확인
- **`restart-apps.sh`** - 애플리케이션 재시작
- **`logs.sh`** - 로그 확인
- **`port-forward.sh`** - 포트 포워딩 설정

## 🚀 빠른 시작

### 1. Production 환경 배포
```bash
# 스크립트 실행 권한 부여
chmod +x *.sh

# Production 환경 배포
./deploy-production.sh
```

### 2. 배포 상태 확인
```bash
./check-status.sh
```

### 3. 애플리케이션 접근
```bash
# 포트 포워딩으로 로컬 접근
./port-forward.sh

# 또는 LoadBalancer IP 확인
kubectl get service frontend-service -n sungho
```

## 📊 스크립트별 상세 설명

### 🚀 deploy-production.sh
Production 환경에 애플리케이션을 배포합니다.

**주요 기능:**
- 네임스페이스 생성/확인
- ACR Registry Secret 확인
- Backend Secret 배포
- Backend/Frontend Deployment 배포
- 배포 상태 확인
- OpenTelemetry 상태 확인

**사전 요구사항:**
- ACR Registry Secret 생성
- OpenTelemetry Collector 배포

### 🧹 cleanup-production.sh
Production 환경의 모든 리소스를 정리합니다.

**주요 기능:**
- 애플리케이션 리소스 삭제
- 네임스페이스 삭제 (선택사항)
- 정리 상태 확인

### 📊 check-status.sh
배포된 리소스들의 상태를 확인합니다.

**확인 항목:**
- 네임스페이스 상태
- Secret 상태
- Deployment 상태
- Service 상태
- Pod 상태
- OpenTelemetry Collector 상태
- 로그 샘플

### 🔄 restart-apps.sh
애플리케이션을 재시작합니다.

**옵션:**
- Backend만 재시작
- Frontend만 재시작
- 둘 다 재시작
- 재시작 후 로그 확인

### 📋 logs.sh
애플리케이션 로그를 확인합니다.

**옵션:**
- Backend 로그
- Frontend 로그
- OpenTelemetry Collector 로그
- 모든 애플리케이션 로그

### 🌐 port-forward.sh
포트 포워딩을 설정하여 로컬에서 애플리케이션에 접근합니다.

**옵션:**
- Frontend만 (포트 8080)
- Backend만 (포트 5000)
- 둘 다 (Frontend: 8080, Backend: 5000)
- 사용자 정의 포트

## 🔧 사전 요구사항

### 1. ACR Registry Secret 생성
```bash
kubectl create secret docker-registry acr-registry -n sungho \
  --docker-server=ktech4.azurecr.io \
  --docker-username=<your-acr-username> \
  --docker-password=<your-acr-password>
```

### 2. Backend Secret 확인
`k8s/backend-secret.yaml` 파일이 올바르게 설정되어 있는지 확인하세요.

### 3. OpenTelemetry Collector 배포
OpenTelemetry Collector가 `otel-collector-rnr` 네임스페이스에 배포되어 있어야 합니다.

## 📁 배포 파일 구조

```
k8s/
├── backend-deployment.yaml      # Backend Production 배포
├── backend-deployment-local.yaml # Backend 로컬 배포
├── frontend-deployment.yaml     # Frontend Production 배포
├── frontend-deployment-local.yaml # Frontend 로컬 배포
├── backend-secret.yaml          # Backend Secret
└── backend-secret-local.yaml    # Backend 로컬 Secret
```

## 🌐 접근 방법

### LoadBalancer를 통한 접근
```bash
# LoadBalancer IP 확인
kubectl get service frontend-service -n sungho
kubectl get service backend-service -n sungho
```

### 포트 포워딩을 통한 접근
```bash
# Frontend 접근
kubectl port-forward service/frontend-service 8080:80 -n sungho
# 브라우저에서 http://localhost:8080

# Backend 접근
kubectl port-forward service/backend-service 5000:5000 -n sungho
# 브라우저에서 http://localhost:5000
```

## 🔍 문제 해결

### 배포 실패 시
```bash
# Pod 상태 확인
kubectl get pods -n sungho

# Pod 상세 정보 확인
kubectl describe pod <pod-name> -n sungho

# 이벤트 확인
kubectl get events -n sungho --sort-by='.lastTimestamp'
```

### 이미지 풀 실패 시
```bash
# ACR Secret 확인
kubectl get secret acr-registry -n sungho

# 이미지 접근 테스트
kubectl run test-pod --image=ktech4.azurecr.io/aks-demo-backend:latest --rm -it --restart=Never -n sungho
```

### OpenTelemetry 문제 시
```bash
# Collector 상태 확인
kubectl get pods -n otel-collector-rnr

# Collector 로그 확인
kubectl logs -f deployment/collector-opentelemetry-collector -n otel-collector-rnr
```

## 📞 지원

문제가 발생하면 다음을 확인하세요:
1. 네임스페이스가 올바르게 생성되었는지
2. Secret이 올바르게 설정되었는지
3. 이미지가 ACR에서 접근 가능한지
4. OpenTelemetry Collector가 실행 중인지

## 🎯 다음 단계

배포가 완료되면:
1. 애플리케이션 기능 테스트
2. OpenTelemetry 트레이스 확인
3. 성능 모니터링 설정
4. 로그 수집 및 분석

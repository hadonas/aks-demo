#!/bin/bash

echo "🚀 Production Kubernetes 환경 배포 시작..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 에러 처리 함수
handle_error() {
    echo -e "${RED}❌ 오류 발생: $1${NC}"
    echo -e "${YELLOW}💡 해결 방법을 확인하세요.${NC}"
    exit 1
}

# 성공 메시지 함수
success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 정보 메시지 함수
info_msg() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# 경고 메시지 함수
warning_msg() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# 1. 네임스페이스 확인 및 생성
echo "🏷️ 네임스페이스 확인 중..."
if ! kubectl get namespace sungho >/dev/null 2>&1; then
    info_msg "네임스페이스 'sungho' 생성 중..."
    kubectl create namespace sungho || handle_error "네임스페이스 생성 실패"
    success_msg "네임스페이스 'sungho' 생성 완료"
else
    success_msg "네임스페이스 'sungho' 이미 존재"
fi

# 2. ACR Registry Secret 확인
echo ""
echo "🔐 ACR Registry Secret 확인 중..."
if ! kubectl get secret acr-registry -n sungho >/dev/null 2>&1; then
    warning_msg "ACR Registry Secret이 존재하지 않습니다."
    echo "다음 명령어로 ACR 인증 정보를 생성하세요:"
    echo "kubectl create secret docker-registry acr-registry -n sungho \\"
    echo "  --docker-server=ktech4.azurecr.io \\"
    echo "  --docker-username=<your-acr-username> \\"
    echo "  --docker-password=<your-acr-password>"
    echo ""
    read -p "ACR Secret을 생성하셨나요? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        handle_error "ACR Registry Secret이 필요합니다."
    fi
else
    success_msg "ACR Registry Secret 확인 완료"
fi

# 3. Backend Secret 배포
echo ""
echo "🔐 Backend Secret 배포 중..."
kubectl apply -f k8s/backend-secret.yaml || handle_error "Backend Secret 배포 실패"
success_msg "Backend Secret 배포 완료"

# 4. Backend Deployment 배포
echo ""
echo "🔧 Backend Deployment 배포 중..."
kubectl apply -f k8s/backend-deployment.yaml || handle_error "Backend Deployment 배포 실패"
success_msg "Backend Deployment 배포 완료"

# 5. Frontend Deployment 배포
echo ""
echo "🎨 Frontend Deployment 배포 중..."
kubectl apply -f k8s/frontend-deployment.yaml || handle_error "Frontend Deployment 배포 실패"
success_msg "Frontend Deployment 배포 완료"

# 6. 배포 상태 확인
echo ""
echo "⏳ 배포 상태 확인 중..."
info_msg "Backend 배포 상태 확인..."
kubectl rollout status deployment/backend -n sungho --timeout=300s || handle_error "Backend 배포 타임아웃"

info_msg "Frontend 배포 상태 확인..."
kubectl rollout status deployment/frontend -n sungho --timeout=300s || handle_error "Frontend 배포 타임아웃"

# 7. 최종 상태 확인
echo ""
echo "📊 최종 배포 상태:"
kubectl get all -n sungho

echo ""
echo "🔍 Pod 상태 상세 확인:"
kubectl get pods -n sungho -o wide

echo ""
echo "🌐 서비스 정보:"
kubectl get services -n sungho

# 8. 접근 방법 안내
echo ""
echo "🎯 접근 방법:"
echo "1. LoadBalancer를 통한 접근:"
echo "   Frontend: kubectl get service frontend-service -n sungho"
echo "   Backend: kubectl get service backend-service -n sungho"
echo ""
echo "2. 포트 포워딩을 통한 로컬 접근:"
echo "   Frontend: kubectl port-forward service/frontend-service 8080:80 -n sungho"
echo "   Backend: kubectl port-forward service/backend-service 5000:5000 -n sungho"
echo ""
echo "3. 브라우저에서 접근:"
echo "   Frontend: http://localhost:8080 (포트 포워딩 후)"
echo "   Backend: http://localhost:5000 (포트 포워딩 후)"

# 9. 로그 확인 방법 안내
echo ""
echo "📋 로그 확인 방법:"
echo "Backend 로그: kubectl logs -f deployment/backend -n sungho"
echo "Frontend 로그: kubectl logs -f deployment/frontend -n sungho"

# 10. OpenTelemetry 확인
echo ""
echo "📊 OpenTelemetry 상태 확인:"
if kubectl get pods -n otel-collector-rnr >/dev/null 2>&1; then
    success_msg "OpenTelemetry Collector가 실행 중입니다."
    echo "Collector 로그: kubectl logs -f deployment/collector-opentelemetry-collector -n otel-collector-rnr"
else
    warning_msg "OpenTelemetry Collector가 실행되지 않고 있습니다."
    echo "Collector가 배포되어 있는지 확인하세요."
fi

echo ""
success_msg "Production 배포 완료! 🎉"
echo ""
echo "💡 추가 명령어:"
echo "  - 전체 상태 확인: kubectl get all -n sungho"
echo "  - Pod 재시작: kubectl rollout restart deployment/backend -n sungho"
echo "  - 배포 삭제: kubectl delete -f k8s/backend-deployment.yaml -f k8s/frontend-deployment.yaml -f k8s/backend-secret.yaml"

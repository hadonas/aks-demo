#!/bin/bash

echo "🧹 Production Kubernetes 환경 정리 시작..."

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

# 확인 메시지 함수
confirm_msg() {
    echo -e "${YELLOW}❓ $1${NC}"
}

# 1. 사용자 확인
confirm_msg "Production 환경의 모든 리소스를 삭제하시겠습니까?"
echo "삭제될 리소스:"
echo "  - Backend Deployment & Service"
echo "  - Frontend Deployment & Service"
echo "  - Backend Secrets"
echo "  - 네임스페이스: sungho"
echo ""
read -p "정말로 삭제하시겠습니까? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ 삭제가 취소되었습니다."
    exit 0
fi

# 2. 애플리케이션 리소스 삭제
echo ""
echo "🗑️ 애플리케이션 리소스 삭제 중..."

info_msg "Frontend Deployment & Service 삭제 중..."
kubectl delete -f k8s/frontend-deployment.yaml --ignore-not-found=true || handle_error "Frontend 삭제 실패"
success_msg "Frontend 리소스 삭제 완료"

info_msg "Backend Deployment & Service 삭제 중..."
kubectl delete -f k8s/backend-deployment.yaml --ignore-not-found=true || handle_error "Backend 삭제 실패"
success_msg "Backend 리소스 삭제 완료"

info_msg "Backend Secret 삭제 중..."
kubectl delete -f k8s/backend-secret.yaml --ignore-not-found=true || handle_error "Backend Secret 삭제 실패"
success_msg "Backend Secret 삭제 완료"

# 3. 직접 리소스 삭제 (이름이 변경된 경우 대비)
echo ""
echo "🔗 직접 리소스 삭제 중..."

info_msg "Deployment 직접 삭제..."
kubectl delete deployment backend -n sungho --ignore-not-found=true
kubectl delete deployment frontend -n sungho --ignore-not-found=true

info_msg "Service 직접 삭제..."
kubectl delete service backend-service -n sungho --ignore-not-found=true
kubectl delete service frontend-service -n sungho --ignore-not-found=true

info_msg "Secret 직접 삭제..."
kubectl delete secret backend-secrets -n sungho --ignore-not-found=true

echo ""
success_msg "Production 환경 정리 완료! 🎉"
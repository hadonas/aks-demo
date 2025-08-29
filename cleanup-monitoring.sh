#!/bin/bash

echo "🧹 Monitoring Stack 정리 시작..."

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
confirm_msg "Monitoring Stack의 리소스를 삭제하시겠습니까?"
echo "삭제될 리소스:"
echo "  - NGINX Ingress Controller (Deployment, Service, RBAC)"
echo "  - Ingress Resources"
echo "  - 관련 ConfigMaps"
echo ""
echo "⚠️  주의: 애플리케이션 서비스(backend, frontend, redis, kafka, mariadb)는 삭제되지 않습니다."
echo ""
read -p "정말로 삭제하시겠습니까? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo "❌ 삭제가 취소되었습니다."
    exit 0
fi

# 2. kubectl 연결 확인
info_msg "Kubernetes 클러스터 연결 확인 중..."
if ! kubectl cluster-info &> /dev/null; then
    handle_error "Kubernetes 클러스터에 연결할 수 없습니다"
fi
success_msg "Kubernetes 클러스터 연결 확인 완료"

# 3. Ingress 리소스 삭제
echo ""
echo "🔗 Ingress 리소스 삭제 중..."

info_msg "Ingress 리소스 삭제 중..."
kubectl delete -f k8s/ingress.yaml --ignore-not-found=true || handle_error "Ingress 삭제 실패"
success_msg "Ingress 리소스 삭제 완료"


# 5. Ingress Controller 삭제
echo ""
echo "🌐 Ingress Controller 삭제 중..."

info_msg "NGINX Ingress Controller 삭제 중..."
kubectl delete -f k8s/nginx-ingress-controller.yaml --ignore-not-found=true || handle_error "NGINX Ingress Controller 삭제 실패"
success_msg "NGINX Ingress Controller 삭제 완료"

# 4. RBAC 리소스 삭제
echo ""
echo "🔐 RBAC 리소스 삭제 중..."

info_msg "ClusterRoleBinding 삭제 중..."
kubectl delete clusterrolebinding nginx-ingress-controller --ignore-not-found=true || handle_error "ClusterRoleBinding 삭제 실패"

info_msg "ClusterRole 삭제 중..."
kubectl delete clusterrole nginx-ingress-controller --ignore-not-found=true || handle_error "ClusterRole 삭제 실패"

info_msg "ServiceAccount 삭제 중..."
kubectl delete serviceaccount nginx-ingress-controller -n sungho --ignore-not-found=true || handle_error "ServiceAccount 삭제 실패"

success_msg "RBAC 리소스 삭제 완료"

# 5. 직접 리소스 삭제 (이름이 변경된 경우 대비)
echo ""
echo "🔗 직접 리소스 삭제 중..."

info_msg "Deployment 직접 삭제..."
kubectl delete deployment nginx-ingress-controller -n sungho --ignore-not-found=true

info_msg "Service 직접 삭제..."
kubectl delete service nginx-ingress-controller -n sungho --ignore-not-found=true

info_msg "ConfigMap 직접 삭제..."
kubectl delete configmap nginx-configuration -n sungho --ignore-not-found=true

info_msg "Ingress 직접 삭제..."
kubectl delete ingress aks-demo-ingress -n sungho --ignore-not-found=true


# 6. 최종 확인
echo ""
info_msg "남은 리소스 확인 중..."
echo "sungho 네임스페이스의 남은 리소스:"
kubectl get all -n sungho

echo ""
info_msg "애플리케이션 서비스 상태 확인:"
kubectl get pods -n sungho -l app=backend
kubectl get pods -n sungho -l app=frontend
kubectl get pods -n sungho -l app=redis
kubectl get pods -n sungho -l app=kafka
kubectl get pods -n sungho -l app=mariadb

echo ""
success_msg "Monitoring Stack 정리 완료! 🎉"
echo ""
info_msg "정리된 리소스:"
echo "  ✅ NGINX Ingress Controller (Deployment, Service, RBAC)"
echo "  ✅ Ingress Resources"
echo "  ✅ 관련 ConfigMaps"
echo ""
info_msg "유지된 리소스:"
echo "  ✅ Backend 애플리케이션"
echo "  ✅ Frontend 애플리케이션"
echo "  ✅ Redis 서비스"
echo "  ✅ Kafka 서비스"
echo "  ✅ MariaDB 서비스"
echo ""
warning_msg "참고: sungho 네임스페이스와 애플리케이션 서비스는 유지됩니다."
echo "       모니터링 관련 리소스만 정리되었습니다."

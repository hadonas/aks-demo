#!/bin/bash

echo "📊 Kubernetes 환경 상태 확인..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 상태 확인 함수
check_status() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    if kubectl get $resource_type $resource_name -n $namespace >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $resource_type/$resource_name${NC}"
        return 0
    else
        echo -e "${RED}❌ $resource_type/$resource_name${NC}"
        return 1
    fi
}

# Pod 상태 확인 함수
check_pod_status() {
    local pod_name=$1
    local namespace=$2
    
    local status=$(kubectl get pod $pod_name -n $namespace -o jsonpath='{.status.phase}' 2>/dev/null)
    local ready=$(kubectl get pod $pod_name -n $namespace -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
    
    if [[ "$status" == "Running" && "$ready" == "true" ]]; then
        echo -e "${GREEN}✅ Pod/$pod_name: Running & Ready${NC}"
        return 0
    elif [[ "$status" == "Running" && "$ready" == "false" ]]; then
        echo -e "${YELLOW}⚠️ Pod/$pod_name: Running but Not Ready${NC}"
        return 1
    else
        echo -e "${RED}❌ Pod/$pod_name: $status${NC}"
        return 1
    fi
}

# 1. 네임스페이스 확인
echo "🏷️ 네임스페이스 상태:"
if kubectl get namespace sungho >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Namespace/sungho${NC}"
else
    echo -e "${RED}❌ Namespace/sungho${NC}"
    echo "네임스페이스가 존재하지 않습니다."
    exit 1
fi

# 2. Secret 확인
echo ""
echo "🔐 Secret 상태:"
check_status "secret" "backend-secrets" "sungho"
check_status "secret" "acr-registry" "sungho"

# 3. Deployment 확인
echo ""
echo "🚀 Deployment 상태:"
check_status "deployment" "backend" "sungho"
check_status "deployment" "frontend" "sungho"

# 4. Service 확인
echo ""
echo "🌐 Service 상태:"
check_status "service" "backend-service" "sungho"
check_status "service" "frontend-service" "sungho"

# 5. Pod 상태 상세 확인
echo ""
echo "📦 Pod 상태 상세:"
backend_pods=$(kubectl get pods -n sungho -l app=backend -o name 2>/dev/null)
frontend_pods=$(kubectl get pods -n sungho -l app=frontend -o name 2>/dev/null)

if [[ -n "$backend_pods" ]]; then
    for pod in $backend_pods; do
        pod_name=$(echo $pod | cut -d'/' -f2)
        check_pod_status $pod_name "sungho"
    done
else
    echo -e "${RED}❌ Backend Pods not found${NC}"
fi

if [[ -n "$frontend_pods" ]]; then
    for pod in $frontend_pods; do
        pod_name=$(echo $pod | cut -d'/' -f2)
        check_pod_status $pod_name "sungho"
    done
else
    echo -e "${RED}❌ Frontend Pods not found${NC}"
fi

# 6. 전체 리소스 상태
echo ""
echo "📊 전체 리소스 상태:"
kubectl get all -n sungho

# 7. 서비스 엔드포인트 확인
echo ""
echo "🔗 서비스 엔드포인트:"
kubectl get endpoints -n sungho

# 8. OpenTelemetry Collector 상태
echo ""
echo "📊 OpenTelemetry Collector 상태:"
if kubectl get namespace otel-collector-rnr >/dev/null 2>&1; then
    echo -e "${GREEN}✅ OpenTelemetry Namespace exists${NC}"
    if kubectl get deployment collector-opentelemetry-collector -n otel-collector-rnr >/dev/null 2>&1; then
        echo -e "${GREEN}✅ OpenTelemetry Collector Deployment exists${NC}"
        kubectl get pods -n otel-collector-rnr -l app.kubernetes.io/name=opentelemetry-collector
    else
        echo -e "${RED}❌ OpenTelemetry Collector Deployment not found${NC}"
    fi
else
    echo -e "${RED}❌ OpenTelemetry Namespace not found${NC}"
fi

# 9. 로그 샘플 확인
echo ""
echo "📋 최근 로그 샘플:"
backend_pod=$(kubectl get pods -n sungho -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$backend_pod" ]]; then
    echo "Backend 로그 (마지막 5줄):"
    kubectl logs $backend_pod -n sungho --tail=5 2>/dev/null || echo "로그를 가져올 수 없습니다."
fi

frontend_pod=$(kubectl get pods -n sungho -l app=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [[ -n "$frontend_pod" ]]; then
    echo ""
    echo "Frontend 로그 (마지막 5줄):"
    kubectl logs $frontend_pod -n sungho --tail=5 2>/dev/null || echo "로그를 가져올 수 없습니다."
fi

# 10. 접근 방법 안내
echo ""
echo "🌐 접근 방법:"
echo "1. LoadBalancer IP 확인:"
kubectl get service frontend-service -n sungho -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null && echo "" || echo "LoadBalancer IP가 아직 할당되지 않았습니다."

echo ""
echo "2. 포트 포워딩 명령어:"
echo "Frontend: kubectl port-forward service/frontend-service 8080:80 -n sungho"
echo "Backend: kubectl port-forward service/backend-service 5000:5000 -n sungho"

echo ""
echo "3. 실시간 로그 확인:"
echo "Backend: kubectl logs -f deployment/backend -n sungho"
echo "Frontend: kubectl logs -f deployment/frontend -n sungho"

echo ""
echo "✅ 상태 확인 완료!"

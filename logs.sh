#!/bin/bash

echo "📋 로그 확인 스크립트..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 정보 메시지 함수
info_msg() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# 1. 로그 확인할 애플리케이션 선택
echo "어떤 애플리케이션의 로그를 확인하시겠습니까?"
echo "1) Backend"
echo "2) Frontend"
echo "3) OpenTelemetry Collector"
echo "4) 모든 애플리케이션"
echo "5) 취소"
echo ""
read -p "선택하세요 (1-5): " -n 1 -r
echo

case $REPLY in
    1)
        echo "📋 Backend 로그 확인:"
        info_msg "Backend Pod 목록:"
        kubectl get pods -n sungho -l app=backend
        echo ""
        info_msg "Backend 로그 (실시간, Ctrl+C로 종료):"
        kubectl logs -f deployment/backend -n sungho
        ;;
    2)
        echo "📋 Frontend 로그 확인:"
        info_msg "Frontend Pod 목록:"
        kubectl get pods -n sungho -l app=frontend
        echo ""
        info_msg "Frontend 로그 (실시간, Ctrl+C로 종료):"
        kubectl logs -f deployment/frontend -n sungho
        ;;
    3)
        echo "📋 OpenTelemetry Collector 로그 확인:"
        if kubectl get deployment collector-opentelemetry-collector -n otel-collector-rnr >/dev/null 2>&1; then
            info_msg "OpenTelemetry Collector Pod 목록:"
            kubectl get pods -n otel-collector-rnr -l app.kubernetes.io/name=opentelemetry-collector
            echo ""
            info_msg "OpenTelemetry Collector 로그 (실시간, Ctrl+C로 종료):"
            kubectl logs -f deployment/collector-opentelemetry-collector -n otel-collector-rnr
        else
            echo -e "${RED}❌ OpenTelemetry Collector가 실행되지 않고 있습니다.${NC}"
        fi
        ;;
    4)
        echo "📋 모든 애플리케이션 로그 확인:"
        echo "여러 터미널에서 각각 실행하거나, 아래 명령어를 사용하세요:"
        echo ""
        echo "Backend 로그:"
        echo "kubectl logs -f deployment/backend -n sungho"
        echo ""
        echo "Frontend 로그:"
        echo "kubectl logs -f deployment/frontend -n sungho"
        echo ""
        echo "OpenTelemetry Collector 로그:"
        echo "kubectl logs -f deployment/collector-opentelemetry-collector -n otel-collector-rnr"
        echo ""
        
        read -p "Backend 로그부터 확인하시겠습니까? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info_msg "Backend 로그 (Ctrl+C로 종료):"
            kubectl logs -f deployment/backend -n sungho
        fi
        ;;
    5)
        echo "❌ 로그 확인이 취소되었습니다."
        exit 0
        ;;
    *)
        echo "❌ 잘못된 선택입니다."
        exit 1
        ;;
esac

echo ""
echo "💡 추가 로그 명령어:"
echo "  - 특정 라인 수만 확인: kubectl logs deployment/backend -n sungho --tail=50"
echo "  - 특정 시간 이후 로그: kubectl logs deployment/backend -n sungho --since=1h"
echo "  - 특정 Pod 로그: kubectl logs <pod-name> -n sungho"
echo "  - 이전 컨테이너 로그: kubectl logs deployment/backend -n sungho --previous"

#!/bin/bash

echo "🔄 애플리케이션 재시작 스크립트..."

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

# 1. 재시작할 애플리케이션 선택
echo "어떤 애플리케이션을 재시작하시겠습니까?"
echo "1) Backend만"
echo "2) Frontend만"
echo "3) 둘 다"
echo "4) 취소"
echo ""
read -p "선택하세요 (1-4): " -n 1 -r
echo

case $REPLY in
    1)
        echo "🔧 Backend 재시작 중..."
        kubectl rollout restart deployment/backend -n sungho || handle_error "Backend 재시작 실패"
        info_msg "Backend 재시작 상태 확인 중..."
        kubectl rollout status deployment/backend -n sungho --timeout=300s || handle_error "Backend 재시작 타임아웃"
        success_msg "Backend 재시작 완료"
        ;;
    2)
        echo "🎨 Frontend 재시작 중..."
        kubectl rollout restart deployment/frontend -n sungho || handle_error "Frontend 재시작 실패"
        info_msg "Frontend 재시작 상태 확인 중..."
        kubectl rollout status deployment/frontend -n sungho --timeout=300s || handle_error "Frontend 재시작 타임아웃"
        success_msg "Frontend 재시작 완료"
        ;;
    3)
        echo "🔄 Backend와 Frontend 모두 재시작 중..."
        
        info_msg "Backend 재시작 중..."
        kubectl rollout restart deployment/backend -n sungho || handle_error "Backend 재시작 실패"
        
        info_msg "Frontend 재시작 중..."
        kubectl rollout restart deployment/frontend -n sungho || handle_error "Frontend 재시작 실패"
        
        info_msg "Backend 재시작 상태 확인 중..."
        kubectl rollout status deployment/backend -n sungho --timeout=300s || handle_error "Backend 재시작 타임아웃"
        
        info_msg "Frontend 재시작 상태 확인 중..."
        kubectl rollout status deployment/frontend -n sungho --timeout=300s || handle_error "Frontend 재시작 타임아웃"
        
        success_msg "모든 애플리케이션 재시작 완료"
        ;;
    4)
        echo "❌ 재시작이 취소되었습니다."
        exit 0
        ;;
    *)
        echo "❌ 잘못된 선택입니다."
        exit 1
        ;;
esac

# 2. 재시작 후 상태 확인
echo ""
echo "📊 재시작 후 상태 확인:"
kubectl get pods -n sungho -l app=backend
kubectl get pods -n sungho -l app=frontend

# 3. 로그 확인 옵션
echo ""
read -p "재시작된 애플리케이션의 로그를 확인하시겠습니까? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    case $REPLY in
        1)
            echo "📋 Backend 로그 확인:"
            kubectl logs -f deployment/backend -n sungho --tail=20
            ;;
        2)
            echo "📋 Frontend 로그 확인:"
            kubectl logs -f deployment/frontend -n sungho --tail=20
            ;;
        3)
            echo "📋 Backend 로그 확인 (Ctrl+C로 종료):"
            kubectl logs -f deployment/backend -n sungho --tail=20 &
            BACKEND_PID=$!
            
            echo "📋 Frontend 로그 확인 (Ctrl+C로 종료):"
            kubectl logs -f deployment/frontend -n sungho --tail=20 &
            FRONTEND_PID=$!
            
            # 사용자가 Ctrl+C를 누를 때까지 대기
            trap "kill $BACKEND_PID $FRONTEND_PID 2>/dev/null; exit" INT
            wait
            ;;
    esac
fi

echo ""
success_msg "재시작 작업 완료! 🎉"

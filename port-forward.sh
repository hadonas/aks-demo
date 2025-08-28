#!/bin/bash

echo "🌐 포트 포워딩 스크립트..."

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

# 성공 메시지 함수
success_msg() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 1. 포트 포워딩할 서비스 선택
echo "어떤 서비스의 포트 포워딩을 설정하시겠습니까?"
echo "1) Frontend만 (포트 8080)"
echo "2) Backend만 (포트 5000)"
echo "3) 둘 다 (Frontend: 8080, Backend: 5000)"
echo "4) 사용자 정의 포트"
echo "5) 취소"
echo ""
read -p "선택하세요 (1-5): " -n 1 -r
echo

case $REPLY in
    1)
        echo "🌐 Frontend 포트 포워딩 설정 중..."
        info_msg "Frontend 서비스 상태 확인:"
        kubectl get service frontend-service -n sungho
        echo ""
        info_msg "포트 포워딩 시작 (Ctrl+C로 종료):"
        echo "Frontend 접근: http://localhost:8080"
        echo ""
        kubectl port-forward service/frontend-service 8080:80 -n sungho
        ;;
    2)
        echo "🌐 Backend 포트 포워딩 설정 중..."
        info_msg "Backend 서비스 상태 확인:"
        kubectl get service backend-service -n sungho
        echo ""
        info_msg "포트 포워딩 시작 (Ctrl+C로 종료):"
        echo "Backend 접근: http://localhost:5000"
        echo ""
        kubectl port-forward service/backend-service 5000:5000 -n sungho
        ;;
    3)
        echo "🌐 Frontend와 Backend 포트 포워딩 설정 중..."
        info_msg "서비스 상태 확인:"
        kubectl get services -n sungho
        echo ""
        info_msg "포트 포워딩 시작 (Ctrl+C로 종료):"
        echo "Frontend 접근: http://localhost:8080"
        echo "Backend 접근: http://localhost:5000"
        echo ""
        
        # 백그라운드에서 Frontend 포트 포워딩 시작
        kubectl port-forward service/frontend-service 8080:80 -n sungho &
        FRONTEND_PID=$!
        
        # 백그라운드에서 Backend 포트 포워딩 시작
        kubectl port-forward service/backend-service 5000:5000 -n sungho &
        BACKEND_PID=$!
        
        # 사용자가 Ctrl+C를 누를 때까지 대기
        trap "kill $FRONTEND_PID $BACKEND_PID 2>/dev/null; exit" INT
        wait
        ;;
    4)
        echo "🌐 사용자 정의 포트 포워딩 설정..."
        echo ""
        read -p "Frontend 로컬 포트 (기본값: 8080): " frontend_port
        frontend_port=${frontend_port:-8080}
        
        read -p "Backend 로컬 포트 (기본값: 5000): " backend_port
        backend_port=${backend_port:-5000}
        
        echo ""
        info_msg "포트 포워딩 설정:"
        echo "Frontend: localhost:$frontend_port -> frontend-service:80"
        echo "Backend: localhost:$backend_port -> backend-service:5000"
        echo ""
        
        read -p "이 설정으로 포트 포워딩을 시작하시겠습니까? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            info_msg "포트 포워딩 시작 (Ctrl+C로 종료):"
            echo "Frontend 접근: http://localhost:$frontend_port"
            echo "Backend 접근: http://localhost:$backend_port"
            echo ""
            
            # 백그라운드에서 포트 포워딩 시작
            kubectl port-forward service/frontend-service $frontend_port:80 -n sungho &
            FRONTEND_PID=$!
            
            kubectl port-forward service/backend-service $backend_port:5000 -n sungho &
            BACKEND_PID=$!
            
            # 사용자가 Ctrl+C를 누를 때까지 대기
            trap "kill $FRONTEND_PID $BACKEND_PID 2>/dev/null; exit" INT
            wait
        else
            echo "❌ 포트 포워딩이 취소되었습니다."
        fi
        ;;
    5)
        echo "❌ 포트 포워딩이 취소되었습니다."
        exit 0
        ;;
    *)
        echo "❌ 잘못된 선택입니다."
        exit 1
        ;;
esac

echo ""
success_msg "포트 포워딩 완료! 🎉"

echo ""
echo "💡 추가 정보:"
echo "  - LoadBalancer IP 확인: kubectl get service frontend-service -n sungho"
echo "  - 포트 포워딩 중지: Ctrl+C"
echo "  - 백그라운드 포트 포워딩: kubectl port-forward service/frontend-service 8080:80 -n sungho &"
echo "  - 포트 포워딩 프로세스 확인: ps aux | grep kubectl"

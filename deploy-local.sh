#!/bin/bash

echo "🚀 로컬 Kubernetes 환경 배포 시작..."

# GitHub 사용자명 설정 (실제 GitHub 사용자명으로 변경)
GITHUB_USERNAME="hadonas"

echo "📋 Secret 생성 중..."
kubectl apply -f k8s/backend-secret-local.yaml

echo "🗄️ MariaDB 배포 중..."
kubectl apply -f k8s/mariadb-local.yaml

echo "🔴 Redis 배포 중..."
kubectl apply -f k8s/redis-local.yaml

echo "🔧 백엔드 배포 중..."
kubectl apply -f k8s/backend-deployment-local.yaml

echo "🎨 프론트엔드 배포 중..."
kubectl apply -f k8s/frontend-deployment-local.yaml

echo "⏳ 배포 상태 확인 중..."
kubectl rollout status deployment/mariadb-local --timeout=300s
kubectl rollout status deployment/redis-local --timeout=300s
kubectl rollout status deployment/backend-local --timeout=300s
kubectl rollout status deployment/frontend-local --timeout=300s

echo "✅ 배포 완료!"
echo ""
echo "📊 현재 상태:"
kubectl get all

echo ""
echo "🌐 접근 방법:"
echo "Frontend: kubectl port-forward service/frontend-service 8080:80"
echo "Backend: kubectl port-forward service/backend-service 5000:5000"
echo ""
echo "포트 포워딩 후 브라우저에서:"
echo "Frontend: http://localhost:8080"
echo "Backend: http://localhost:5000"
echo ""
echo "🔍 로그 확인:"
echo "MariaDB: kubectl logs -f deployment/mariadb-local"
echo "Redis: kubectl logs -f deployment/redis-local"
echo "Backend: kubectl logs -f deployment/backend-local"
echo "Frontend: kubectl logs -f deployment/frontend-local"
echo ""
echo "📦 사용된 이미지:"
echo "Backend: ghcr.io/$GITHUB_USERNAME/aks-demo-backend:local"
echo "Frontend: ghcr.io/$GITHUB_USERNAME/aks-demo-frontend:local"

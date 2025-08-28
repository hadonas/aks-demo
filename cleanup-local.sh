#!/bin/bash

echo "🧹 로컬 Kubernetes 환경 정리 시작..."

# 1. 모든 로컬 리소스 삭제
echo "🗑️ 로컬 리소스 삭제 중..."
kubectl delete -f k8s/frontend-deployment-local.yaml --ignore-not-found=true
kubectl delete -f k8s/backend-deployment-local.yaml --ignore-not-found=true
kubectl delete -f k8s/redis-local.yaml --ignore-not-found=true
kubectl delete -f k8s/mariadb-local.yaml --ignore-not-found=true
kubectl delete -f k8s/backend-secret-local.yaml --ignore-not-found=true

# 1-1. 직접 서비스 삭제 (이름이 변경된 경우)
echo "🔗 서비스 직접 삭제 중..."
kubectl delete service backend-local --ignore-not-found=true
kubectl delete service frontend-local --ignore-not-found=true
kubectl delete service backend-service --ignore-not-found=true
kubectl delete service frontend-service --ignore-not-found=true

# 1-2. 직접 Deployment 삭제
echo "🚀 Deployment 직접 삭제 중..."
kubectl delete deployment backend-local --ignore-not-found=true
kubectl delete deployment frontend-local --ignore-not-found=true

# 2. PVC 정리 (데이터 영구 삭제)
echo "💾 PVC 정리 중..."
kubectl get pvc | grep local | awk '{print $1}' | xargs -r kubectl delete pvc

# 3. ConfigMap 정리
echo "⚙️ ConfigMap 정리 중..."
kubectl get configmap | grep local | awk '{print $1}' | xargs -r kubectl delete configmap

# 4. Secret 정리
echo "🔐 Secret 정리 중..."
kubectl get secret | grep local | awk '{print $1}' | xargs -r kubectl delete secret

echo "✅ 정리 완료!"
echo ""
echo "📊 현재 상태:"
kubectl get all

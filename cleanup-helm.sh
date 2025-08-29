#!/bin/bash

echo "🧹 Helm으로 배포된 Redis, Kafka, MariaDB 정리 시작..."

# 1. Helm 릴리스 삭제
echo "🗑️ Helm 릴리스 삭제 중..."
helm uninstall redis -n sungho --ignore-not-found=true
helm uninstall kafka -n sungho --ignore-not-found=true
helm uninstall mariadb -n sungho --ignore-not-found=true

# 2. PVC 정리
echo "💾 PVC 정리 중..."
kubectl get pvc -n sungho | grep -E "(redis|kafka|mariadb)" | awk '{print $1}' | xargs -r kubectl delete pvc -n sungho

echo "✅ Helm 정리 완료!"
echo ""
echo "📊 현재 상태:"
kubectl get all --all-namespaces | grep sungho || echo "sungho 네임스페이스가 정리되었습니다."

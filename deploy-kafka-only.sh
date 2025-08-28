#!/bin/bash

echo "📨 Kafka 단독 배포 시작..."

# 1. 기존 Kafka 정리
echo "🧹 기존 Kafka 정리 중..."
helm uninstall kafka -n sungho --ignore-not-found=true
kubectl delete pvc -n sungho -l app.kubernetes.io/instance=kafka --ignore-not-found=true

# 2. Kafka 배포 (타임아웃 30분)
echo "📨 Kafka 배포 중..."
helm install kafka bitnami/kafka \
  --namespace sungho \
  --values k8s/kafka-values.yaml \
  --wait \
  --timeout 30m

if [ $? -eq 0 ]; then
    echo "✅ Kafka 배포 성공!"
    echo ""
    echo "📊 Kafka 상태:"
    kubectl get pods -n sungho | grep kafka
    echo ""
    echo "🔍 서비스 정보:"
    echo "Kafka: kafka.sungho.svc.cluster.local:9092"
else
    echo "❌ Kafka 배포 실패!"
    echo "로그 확인:"
    kubectl get events -n sungho | grep kafka
fi

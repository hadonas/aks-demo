#!/bin/bash

echo "🚀 Helm을 사용한 Redis, Kafka, MariaDB 배포 시작..."

# 1. Bitnami Helm 저장소 추가
echo "📦 Bitnami Helm 저장소 추가 중..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. 네임스페이스 생성
echo "🏷️ 네임스페이스 생성 중..."
kubectl create namespace sungho --dry-run=client -o yaml | kubectl apply -f -

# 3. Redis 배포
echo "🔴 Redis 배포 중..."
helm install redis bitnami/redis \
  --namespace sungho \
  --values k8s/redis-values.yaml

# 4. Kafka 배포
echo "📨 Kafka 배포 중..."
helm install kafka bitnami/kafka \
  --namespace sungho \
  --values k8s/kafka-values.yaml 

# 5. MariaDB 배포
echo "🗄️ MariaDB 배포 중..."
helm install mariadb bitnami/mariadb \
  --namespace sungho \
  --values k8s/mariadb-values.yaml

echo "✅ Helm 배포 완료!"
echo ""
echo "📊 배포 상태 확인:"
kubectl get all -n sungho

echo ""
echo "🔍 서비스 정보:"
echo "Redis Master: redis-master.sungho.svc.cluster.local:6379"
echo "Redis Replica: redis-replicas.sungho.svc.cluster.local:6379"
echo "Kafka: kafka.sungho.svc.cluster.local:9092"
echo "MariaDB: mariadb.sungho.svc.cluster.local:3306"

echo ""
echo "🔐 접속 정보:"
echo "Redis Password: New1234!"
echo "MariaDB Root Password: MyRootPass123!"
echo "MariaDB User: testuser"
echo "MariaDB User Password: TestUserPass123!"
echo "MariaDB Database: testdb"

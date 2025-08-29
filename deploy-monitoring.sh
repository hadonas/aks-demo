#!/bin/bash

# AKS Demo Monitoring Stack Deployment Script
# This script deploys Ingress, Grafana, and Prometheus to the sungho namespace

set -e

echo "🚀 Starting AKS Demo Monitoring Stack Deployment..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to the cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster"

# Deploy NGINX Ingress Controller
echo "🌐 Deploying NGINX Ingress Controller..."
kubectl apply -f k8s/nginx-ingress-controller.yaml

# Wait for Ingress Controller to be ready
echo "⏳ Waiting for Ingress Controller to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/nginx-ingress-controller -n sungho

# Deploy Ingress
echo "🔗 Deploying Ingress..."
kubectl apply -f k8s/ingress.yaml

# Get the external IP of the LoadBalancer
echo "🔍 Getting external IP..."
EXTERNAL_IP=$(kubectl get service nginx-ingress-controller -n sungho -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
    echo "⚠️  External IP not available yet. Please check with:"
    echo "   kubectl get service nginx-ingress-controller -n sungho"
else
    echo "✅ External IP: $EXTERNAL_IP"
    echo ""
    echo "🌐 Access URLs:"
    echo "   AKS Demo App: http://$EXTERNAL_IP (add to /etc/hosts: $EXTERNAL_IP aks-demo.sungho.local)"
    echo "   External Grafana: http://grafana.20.249.154.255.nip.io"
    echo ""
    echo "📝 Add this line to your /etc/hosts file:"
    echo "   $EXTERNAL_IP aks-demo.sungho.local"
fi

echo ""
echo "🎉 Monitoring stack deployment completed!"
echo ""
echo "📋 Next steps:"
echo "1. Add the external IP to your /etc/hosts file"
echo "2. Access external Grafana at http://grafana.20.249.154.255.nip.io"
echo "3. Configure data sources in Grafana:"
echo "   - Prometheus: http://collector.lgtm.20.249.154.255.nip.io:9090"
echo "   - Jaeger: http://collector.lgtm.20.249.154.255.nip.io:16686"
echo "   - Loki: http://collector.lgtm.20.249.154.255.nip.io:3100"
echo "4. Import or create dashboards for OpenTelemetry data"
echo "5. Check application metrics at http://<EXTERNAL_IP>/metrics"
echo ""
echo "🔧 Useful commands:"
echo "   kubectl get pods -n sungho"
echo "   kubectl get services -n sungho"
echo "   kubectl get ingress -n sungho"
echo "   kubectl logs -f deployment/grafana -n sungho"

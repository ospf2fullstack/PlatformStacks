#!/bin/bash
set -euo pipefail

# Apache Kafka on Kubernetes - Installation Script
# Uses Strimzi Operator with KRaft mode (no ZooKeeper)
# Author: Gary Innerarity
# Date: 2026-06-01

NAMESPACE="${KAFKA_NAMESPACE:-kafka}"
STRIMZI_VERSION="${STRIMZI_VERSION:-0.42.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE_DIR="${SCRIPT_DIR}/../kubernetes"

echo "============================================="
echo "  Apache Kafka on Kubernetes - Installer"
echo "  Strimzi ${STRIMZI_VERSION} | KRaft Mode"
echo "============================================="
echo ""

# Pre-flight checks
echo "🔍 Running pre-flight checks..."

if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

if ! command -v helm &> /dev/null; then
    echo "❌ helm not found. Please install Helm 3 first."
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Check your kubeconfig."
    exit 1
fi

echo "✅ Pre-flight checks passed"
echo ""

# Create namespace
echo "📦 Creating namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Install Strimzi Operator
echo "🚀 Installing Strimzi Kafka Operator v${STRIMZI_VERSION}..."
helm repo add strimzi https://strimzi.io/charts/ 2>/dev/null || true
helm repo update

helm upgrade --install strimzi strimzi/strimzi-kafka-operator \
  --namespace "${NAMESPACE}" \
  --version "${STRIMZI_VERSION}" \
  --wait \
  --timeout 5m

echo "✅ Strimzi Operator installed"
echo ""

# Wait for operator to be ready
echo "⏳ Waiting for Strimzi Operator to be ready..."
kubectl wait deployment/strimzi-cluster-operator \
  --for=condition=available \
  --timeout=120s \
  -n "${NAMESPACE}"

echo "✅ Strimzi Operator ready"
echo ""

# Apply storage class (if not exists)
echo "💾 Applying storage class..."
kubectl apply -f "${KUBE_DIR}/storage-class.yaml" 2>/dev/null || echo "⚠️  Storage class already exists or not applicable"

# Deploy Kafka cluster
echo "🎯 Deploying Kafka cluster..."
kubectl apply -f "${KUBE_DIR}/kafka-cluster.yaml"

echo ""
echo "⏳ Waiting for Kafka cluster to be ready (this may take 3-5 minutes)..."
kubectl wait kafka/production-kafka \
  --for=condition=Ready \
  --timeout=600s \
  -n "${NAMESPACE}" || {
    echo "⚠️  Kafka cluster not ready within timeout. Checking status..."
    kubectl get kafka -n "${NAMESPACE}"
    kubectl get pods -n "${NAMESPACE}"
    exit 1
}

echo "✅ Kafka cluster is ready!"
echo ""

# Deploy topics
echo "📋 Creating default topics..."
kubectl apply -f "${KUBE_DIR}/topics/" 2>/dev/null || echo "⚠️  No topic manifests found"

echo ""
echo "============================================="
echo "  ✅ Installation Complete!"
echo "============================================="
echo ""
echo "Cluster: production-kafka"
echo "Namespace: ${NAMESPACE}"
echo "Bootstrap (internal): production-kafka-kafka-bootstrap.${NAMESPACE}:9092"
echo "Bootstrap (TLS):      production-kafka-kafka-bootstrap.${NAMESPACE}:9093"
echo ""
echo "Next steps:"
echo "  1. Run ./validate.sh to verify the deployment"
echo "  2. Create topics: kubectl apply -f kubernetes/topics/"
echo "  3. Configure monitoring: kubectl apply -f kubernetes/monitoring/"
echo ""

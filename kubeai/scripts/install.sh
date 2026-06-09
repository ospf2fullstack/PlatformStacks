#!/bin/bash
# KubeAI Installation Script
# Installs KubeAI operator and configures models on a Kubernetes cluster
# Usage: ./install.sh [--gpu] [--namespace NAMESPACE]

set -euo pipefail

NAMESPACE="${NAMESPACE:-kubeai}"
ENABLE_GPU=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --gpu) ENABLE_GPU=true; shift ;;
    --namespace) NAMESPACE="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--gpu] [--namespace NAMESPACE]"
      echo "  --gpu        Enable GPU model profiles"
      echo "  --namespace  Kubernetes namespace (default: kubeai)"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🚀 Installing KubeAI..."
echo "  Namespace: ${NAMESPACE}"
echo "  GPU mode:  ${ENABLE_GPU}"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ helm not found"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "❌ Cannot connect to cluster"; exit 1; }
echo "✅ Prerequisites met"

# Create namespace
echo ""
echo "📦 Creating namespace ${NAMESPACE}..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Add Helm repo
echo ""
echo "📦 Adding KubeAI Helm repository..."
helm repo add kubeai https://www.kubeai.org
helm repo update

# Install KubeAI operator
echo ""
echo "⚙️  Installing KubeAI operator..."
helm upgrade --install kubeai kubeai/kubeai \
  --namespace "${NAMESPACE}" \
  -f "${SCRIPT_DIR}/../helm/values.yaml" \
  --wait \
  --timeout 5m

# Wait for operator to be ready
echo ""
echo "⏳ Waiting for KubeAI operator to be ready..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=kubeai \
  -n "${NAMESPACE}" \
  --timeout=120s

# Install models
echo ""
echo "🤖 Deploying models..."
helm upgrade --install kubeai-models kubeai/models \
  --namespace "${NAMESPACE}" \
  -f "${SCRIPT_DIR}/../helm/models-values.yaml" \
  --wait \
  --timeout 5m

# Verify installation
echo ""
echo "🔍 Verifying installation..."
echo ""
echo "Models:"
kubectl get models -n "${NAMESPACE}" 2>/dev/null || echo "  (waiting for CRD registration)"
echo ""
echo "Pods:"
kubectl get pods -n "${NAMESPACE}"

echo ""
echo "✅ KubeAI installation complete!"
echo ""
echo "📌 Next steps:"
echo "  1. Check model status: kubectl get models -n ${NAMESPACE}"
echo "  2. Port-forward API: kubectl port-forward svc/kubeai -n ${NAMESPACE} 8000:80"
echo "  3. Test endpoint: curl http://localhost:8000/openai/v1/models"

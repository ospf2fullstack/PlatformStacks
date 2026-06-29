#!/bin/bash
# LiteLLM Quick Install Script
# Deploys LiteLLM to a Kubernetes cluster using raw manifests
# Usage: ./install.sh [NAMESPACE] [MASTER_KEY]

set -euo pipefail

NAMESPACE="${1:-litellm}"
MASTER_KEY="${2:-$(openssl rand -hex 16)}"

echo "=== LiteLLM Kubernetes Installer ==="
echo "Namespace: ${NAMESPACE}"
echo "Master Key: ${MASTER_KEY}"
echo ""

# Create namespace if not exists
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# Apply manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f ../kubernetes/litellm-deployment.yaml -n "${NAMESPACE}"

echo ""
echo "=== Installation Complete ==="
echo "Gateway endpoint: http://litellm.${NAMESPACE}.svc.cluster.local:4000"
echo "Health check:     curl http://litellm.${NAMESPACE}.svc.cluster.local:4000/health/liveliness"
echo ""
echo "IMPORTANT: Update the litellm-secrets Secret with your actual API keys!"
echo "  kubectl edit secret litellm-secrets -n ${NAMESPACE}"

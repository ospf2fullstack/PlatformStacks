#!/usr/bin/env bash
set -euo pipefail

# KServe Installation Script - Standard Mode with LLMInferenceService
# Installs KServe for both predictive and generative AI inference on Kubernetes

KSERVE_VERSION="${KSERVE_VERSION:-v0.19.0}"
CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.16.0}"
ENVOY_GATEWAY_VERSION="${ENVOY_GATEWAY_VERSION:-v1.3.0}"
NAMESPACE="${KSERVE_NAMESPACE:-kserve}"

echo "=== KServe Installation Script ==="
echo "KServe Version: ${KSERVE_VERSION}"
echo "Cert-Manager Version: ${CERT_MANAGER_VERSION}"
echo "Envoy Gateway Version: ${ENVOY_GATEWAY_VERSION}"
echo ""

# Check prerequisites
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl is required"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm is required"; exit 1; }

echo "[1/7] Installing cert-manager..."
kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
echo "Waiting for cert-manager to be ready..."
kubectl wait --for=condition=Available deployment/cert-manager -n cert-manager --timeout=120s
kubectl wait --for=condition=Available deployment/cert-manager-webhook -n cert-manager --timeout=120s

echo "[2/7] Installing Envoy Gateway..."
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_GATEWAY_VERSION}" \
  -n envoy-gateway-system --create-namespace \
  --wait --timeout 5m

echo "[3/7] Creating KServe namespace and Gateway..."
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f "$(dirname "$0")/../kubernetes/gateway.yaml"

echo "[4/7] Installing KServe CRDs..."
helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd --version "${KSERVE_VERSION}"

echo "[5/7] Installing KServe controller (Standard mode)..."
helm upgrade --install kserve oci://ghcr.io/kserve/charts/kserve-resources \
  --version "${KSERVE_VERSION}" \
  --namespace "${NAMESPACE}" --create-namespace \
  -f "$(dirname "$0")/../helm/values-standard.yaml" \
  --wait --timeout 5m

echo "[6/7] Installing LLMInferenceService CRDs..."
helm install kserve-llmisvc-crd oci://ghcr.io/kserve/charts/kserve-llmisvc-crd --version "${KSERVE_VERSION}"

echo "[7/7] Installing LLMIsvc controller..."
helm install kserve-llmisvc oci://ghcr.io/kserve/charts/kserve-llmisvc-resources --version "${KSERVE_VERSION}"
echo "Waiting for LLMIsvc controller..."
kubectl wait --for=condition=Available deployment/llmisvc-controller-manager -n "${NAMESPACE}" --timeout=180s

echo ""
echo "=== Installation Complete ==="
echo "KServe is ready for both predictive and generative AI inference."
echo ""
echo "Next steps:"
echo "  1. Create a test namespace: kubectl create ns kserve-test"
echo "  2. Deploy a model: kubectl apply -f ../kubernetes/examples/"
echo "  3. Check status: kubectl get inferenceservices -A"
echo ""

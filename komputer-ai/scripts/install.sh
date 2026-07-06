#!/usr/bin/env bash
set -euo pipefail

# Komputer.AI Installation Script
# Deploys the complete Komputer.AI platform on a Kubernetes cluster

NAMESPACE="${KOMPUTER_NAMESPACE:-komputer-ai}"
RELEASE_NAME="${KOMPUTER_RELEASE:-komputer-ai}"
ANTHROPIC_KEY="${ANTHROPIC_API_KEY:-}"

echo "=== Komputer.AI Installer ==="
echo ""

# Preflight checks
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }

# Check cluster connectivity
if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "ERROR: Cannot connect to Kubernetes cluster"
  exit 1
fi

echo "[1/5] Creating namespace: ${NAMESPACE}"
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "[2/5] Creating Anthropic API secret"
if [ -z "${ANTHROPIC_KEY}" ]; then
  echo "WARNING: ANTHROPIC_API_KEY not set. Set it with:"
  echo "  export ANTHROPIC_API_KEY=<your-key>"
  echo "  kubectl create secret generic anthropic-api-key -n ${NAMESPACE} --from-literal=ANTHROPIC_API_KEY=\$ANTHROPIC_API_KEY"
else
  kubectl create secret generic anthropic-api-key \
    --namespace "${NAMESPACE}" \
    --from-literal=ANTHROPIC_API_KEY="${ANTHROPIC_KEY}" \
    --dry-run=client -o yaml | kubectl apply -f -
fi

echo "[3/5] Adding Helm repository"
helm repo add komputer-ai https://komputer-ai.github.io/komputer-ai 2>/dev/null || true
helm repo update

echo "[4/5] Installing Komputer.AI"
helm upgrade --install "${RELEASE_NAME}" komputer-ai/komputer-ai \
  --namespace "${NAMESPACE}" \
  --set api.anthropicSecret=anthropic-api-key \
  --set operator.enabled=true \
  --set ui.enabled=true \
  --set redis.enabled=true \
  --wait --timeout 5m

echo "[5/5] Verifying installation"
echo ""
kubectl get pods -n "${NAMESPACE}"
echo ""
echo "CRDs installed:"
kubectl get crd | grep komputer || echo "  (none found — check operator logs)"
echo ""
echo "=== Installation complete ==="
echo ""
echo "Access the dashboard:"
echo "  kubectl port-forward svc/komputer-ui 3000:3000 -n ${NAMESPACE}"
echo "  Open http://localhost:3000"
echo ""
echo "Access the API:"
echo "  kubectl port-forward svc/komputer-api 8080:8080 -n ${NAMESPACE}"
echo ""
echo "Create your first agent:"
echo "  kubectl apply -f kubernetes/example-agent.yaml"

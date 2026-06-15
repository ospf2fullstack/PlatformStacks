#!/bin/bash
set -euo pipefail

# Hearth Quick Install Script
# Installs KEDA + Hearth on a Kubernetes cluster

NAMESPACE="${HEARTH_NAMESPACE:-hearth-system}"
KEDA_NAMESPACE="${KEDA_NAMESPACE:-keda}"
HEARTH_VERSION="${HEARTH_VERSION:-v0.1.0}"

echo "=== Hearth Quick Install ==="
echo "Namespace: ${NAMESPACE}"
echo "KEDA Namespace: ${KEDA_NAMESPACE}"
echo "Version: ${HEARTH_VERSION}"
echo ""

# Pre-flight checks
echo "[1/5] Pre-flight checks..."
command -v kubectl >/dev/null 2>&1 || { echo "ERROR: kubectl not found"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "ERROR: helm not found"; exit 1; }
kubectl cluster-info >/dev/null 2>&1 || { echo "ERROR: Cannot reach cluster"; exit 1; }
echo "  ✓ kubectl and helm available, cluster reachable"

# Install KEDA
echo "[2/5] Installing KEDA..."
if kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
  echo "  ✓ KEDA already installed"
else
  helm repo add kedacore https://kedacore.github.io/charts
  helm repo update
  helm install keda kedacore/keda \
    -n "${KEDA_NAMESPACE}" \
    --create-namespace \
    --wait --timeout 120s
  echo "  ✓ KEDA installed"
fi

# Install Hearth
echo "[3/5] Installing Hearth operator..."
helm repo add hearth https://hearth-project.github.io/charts
helm repo update
helm install hearth hearth/hearth \
  -n "${NAMESPACE}" \
  --create-namespace \
  --set gateway.image.tag="${HEARTH_VERSION}" \
  --wait --timeout 120s
echo "  ✓ Hearth operator installed"

# Apply default InferenceRuntimes
echo "[4/5] Applying default InferenceRuntimes..."
kubectl apply -f - <<EOF
apiVersion: serving.hearth.dev/v1alpha1
kind: InferenceRuntime
metadata:
  name: vllm-nvidia
spec:
  family: vllm
  vendor: nvidia
  priority: 100
  container:
    image: vllm/vllm-openai:latest
    args:
      - --served-model-name=\$(MODEL_NAME)
      - --model=\$(MODEL_PATH)
  accelerator:
    resourceName: nvidia.com/gpu
    sharing:
      supported: false
  probes:
    readiness:
      path: /health
      port: 8000
  metrics:
    path: /metrics
    port: 8000
EOF
echo "  ✓ Default NVIDIA runtime applied"

# Verification
echo "[5/5] Verifying installation..."
kubectl wait --for=condition=Available deployment -l app.kubernetes.io/name=hearth \
  -n "${NAMESPACE}" --timeout=60s
echo "  ✓ Hearth controller is running"
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
echo "  1. Create a namespace for your models: kubectl create ns ai"
echo "  2. Apply an LLMService manifest (see README.md for examples)"
echo "  3. Monitor with: kubectl get llmservice -A -w"

#!/bin/bash
# KubeAI Validation Script
# Validates the KubeAI installation is healthy and models are serving
# Usage: ./validate.sh [--namespace NAMESPACE]

set -euo pipefail

NAMESPACE="${NAMESPACE:-kubeai}"
ERRORS=0

echo "🔍 Validating KubeAI installation..."
echo "  Namespace: ${NAMESPACE}"
echo ""

# Check operator pod
echo "1️⃣  Checking KubeAI operator..."
if kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=kubeai --no-headers 2>/dev/null | grep -q Running; then
  echo "   ✅ Operator is running"
else
  echo "   ❌ Operator is NOT running"
  ((ERRORS++))
fi

# Check models
echo ""
echo "2️⃣  Checking deployed models..."
MODEL_COUNT=$(kubectl get models -n "${NAMESPACE}" --no-headers 2>/dev/null | wc -l)
if [[ ${MODEL_COUNT} -gt 0 ]]; then
  echo "   ✅ ${MODEL_COUNT} model(s) configured"
  kubectl get models -n "${NAMESPACE}" -o custom-columns=NAME:.metadata.name,ENGINE:.spec.engine,MIN:.spec.minReplicas,MAX:.spec.maxReplicas,REPLICAS:.spec.replicas 2>/dev/null
else
  echo "   ⚠️  No models configured"
fi

# Check model pods
echo ""
echo "3️⃣  Checking model server pods..."
POD_COUNT=$(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/managed-by=kubeai --no-headers 2>/dev/null | grep -c Running || echo "0")
echo "   ℹ️  ${POD_COUNT} model server pod(s) running"

# Test API endpoint
echo ""
echo "4️⃣  Testing API endpoint..."
# Try port-forward in background
kubectl port-forward svc/kubeai -n "${NAMESPACE}" 18000:80 &>/dev/null &
PF_PID=$!
sleep 2

if curl -sf http://localhost:18000/openai/v1/models >/dev/null 2>&1; then
  echo "   ✅ API is responding"
  MODELS_RESPONSE=$(curl -sf http://localhost:18000/openai/v1/models 2>/dev/null)
  echo "   Available models:"
  echo "${MODELS_RESPONSE}" | jq -r '.data[].id' 2>/dev/null | while read -r model; do
    echo "     - ${model}"
  done
else
  echo "   ⚠️  API not reachable (may need manual port-forward)"
fi

# Cleanup port-forward
kill ${PF_PID} 2>/dev/null || true

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ ${ERRORS} -eq 0 ]]; then
  echo "✅ Validation PASSED - KubeAI is healthy"
else
  echo "❌ Validation FAILED - ${ERRORS} error(s) found"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit ${ERRORS}

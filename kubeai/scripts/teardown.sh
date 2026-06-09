#!/bin/bash
# KubeAI Teardown Script
# Removes KubeAI operator and all deployed models
# Usage: ./teardown.sh [--namespace NAMESPACE] [--keep-pvcs]

set -euo pipefail

NAMESPACE="${NAMESPACE:-kubeai}"
KEEP_PVCS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --namespace) NAMESPACE="$2"; shift 2 ;;
    --keep-pvcs) KEEP_PVCS=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NAMESPACE] [--keep-pvcs]"
      echo "  --namespace  Kubernetes namespace (default: kubeai)"
      echo "  --keep-pvcs  Keep PVCs (model cache) after uninstall"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo "🗑️  Tearing down KubeAI..."
echo "  Namespace: ${NAMESPACE}"
echo "  Keep PVCs: ${KEEP_PVCS}"
echo ""

read -p "⚠️  This will remove all KubeAI resources. Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# Uninstall models first
echo ""
echo "🤖 Removing models..."
helm uninstall kubeai-models --namespace "${NAMESPACE}" 2>/dev/null || echo "  (models release not found)"

# Wait for model pods to terminate
echo "⏳ Waiting for model pods to terminate..."
kubectl wait --for=delete pod -l app.kubernetes.io/managed-by=kubeai \
  -n "${NAMESPACE}" --timeout=120s 2>/dev/null || true

# Uninstall operator
echo ""
echo "⚙️  Removing KubeAI operator..."
helm uninstall kubeai --namespace "${NAMESPACE}" 2>/dev/null || echo "  (kubeai release not found)"

# Clean up PVCs if requested
if [[ "${KEEP_PVCS}" == "false" ]]; then
  echo ""
  echo "💾 Removing PVCs..."
  kubectl delete pvc -n "${NAMESPACE}" -l app.kubernetes.io/name=kubeai --ignore-not-found
fi

# Remove namespace (optional)
echo ""
read -p "🗂️  Delete namespace '${NAMESPACE}'? [y/N] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  kubectl delete namespace "${NAMESPACE}" --ignore-not-found
  echo "✅ Namespace deleted"
fi

echo ""
echo "✅ KubeAI teardown complete!"

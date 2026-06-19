#!/bin/bash
# KAITO Installation Script
# Installs KAITO workspace operator on any Kubernetes cluster
# Usage: ./install.sh [--byo-nodes] [--cluster-name NAME]

set -euo pipefail

# Defaults
CLUSTER_NAME="${CLUSTER_NAME:-my-cluster}"
BYO_NODES=false
NAMESPACE="kaito-workspace"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --byo-nodes)
      BYO_NODES=true
      shift
      ;;
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

echo "=== KAITO Installation ==="
echo "Cluster: $CLUSTER_NAME"
echo "Namespace: $NAMESPACE"
echo "BYO Nodes: $BYO_NODES"
echo ""

# Add Helm repo
echo "[1/4] Adding KAITO Helm repository..."
helm repo add kaito https://kaito-project.github.io/kaito/charts/kaito
helm repo update

# Install KAITO workspace
echo "[2/4] Installing KAITO workspace operator..."
HELM_ARGS=(
  upgrade --install kaito-workspace kaito/workspace
  --namespace "$NAMESPACE"
  --create-namespace
  --set "clusterName=$CLUSTER_NAME"
  --wait
  --take-ownership
)

if [ "$BYO_NODES" = true ]; then
  HELM_ARGS+=(--set "featureGates.disableNodeAutoProvisioning=true")
  echo "  → Auto-provisioning DISABLED (BYO nodes mode)"
else
  echo "  → Auto-provisioning ENABLED"
fi

helm "${HELM_ARGS[@]}"

# Verify installation
echo "[3/4] Verifying installation..."
kubectl get pods -n "$NAMESPACE" -l app=kaito-workspace
echo ""

# Check CRDs
echo "[4/4] Checking CRDs..."
kubectl get crd workspaces.kaito.sh 2>/dev/null && echo "✓ Workspace CRD installed" || echo "✗ Workspace CRD missing"
kubectl get crd inferencesets.kaito.sh 2>/dev/null && echo "✓ InferenceSet CRD installed" || echo "✗ InferenceSet CRD missing"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Next steps:"
if [ "$BYO_NODES" = true ]; then
  echo "  1. Label your GPU nodes: kubectl label node <node> accelerator=nvidia"
  echo "  2. Apply a workspace: kubectl apply -f ../kubernetes/workspace-phi4.yaml"
else
  echo "  1. Verify GPU provisioner is running (cloud-specific)"
  echo "  2. Apply a workspace: kubectl apply -f ../kubernetes/workspace-phi4.yaml"
fi
echo "  3. Monitor: kubectl get workspace -w"

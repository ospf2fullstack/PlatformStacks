#!/bin/bash
# Strimzi Kafka Installation Script
# This script installs Strimzi operator and deploys a Kafka cluster

set -e

NAMESPACE="${NAMESPACE:-strimzi-operator}"
KAFKA_CLUSTER_NAME="${KAFKA_CLUSTER_NAME:-my-cluster}"

echo "=== Strimzi Kafka Installation ==="
echo "Namespace: $NAMESPACE"
echo "Cluster Name: $KAFKA_CLUSTER_NAME"

# Check prerequisites
echo "Checking prerequisites..."
command -v kubectl >/dev/null 2>&1 || { echo "kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "helm is required but not installed. Aborting." >&2; exit 1; }

# Add Strimzi Helm repository
echo "Adding Strimzi Helm repository..."
helm repo add strimzi https://strimzi.io/charts 2>/dev/null || true
helm repo update

# Create namespace
echo "Creating namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" 2>/dev/null || true

# Install Strimzi operator
echo "Installing Strimzi operator..."
helm install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace "$NAMESPACE" \
  --set operator.namespace="$NAMESPACE"

# Wait for operator to be ready
echo "Waiting for Strimzi operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=strimzi-kafka-operator \
  --namespace "$NAMESPACE" --timeout=300s

# Deploy Kafka cluster
echo "Deploying Kafka cluster: $KAFKA_CLUSTER_NAME"
kubectl apply -f kubernetes/kafka-cluster.yaml -n "$NAMESPACE"

# Wait for Kafka cluster to be ready
echo "Waiting for Kafka cluster to be ready..."
kubectl wait --for=condition=Ready kafka/"$KAFKA_CLUSTER_NAME" \
  --namespace "$NAMESPACE" --timeout=600s

echo "=== Installation Complete ==="
echo ""
echo "Kafka cluster '$KAFKA_CLUSTER_NAME' is ready!"
echo ""
echo "Useful commands:"
echo "  kubectl get kafka -n $NAMESPACE"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -n $NAMESPACE deployment/strimzi-kafka-operator"
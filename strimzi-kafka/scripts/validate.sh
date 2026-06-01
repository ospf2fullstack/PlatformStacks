#!/bin/bash
# Strimzi Kafka Validation Script
# This script validates the Strimzi Kafka deployment

set -e

NAMESPACE="${NAMESPACE:-strimzi-operator}"
KAFKA_CLUSTER_NAME="${KAFKA_CLUSTER_NAME:-my-cluster}"

echo "=== Strimzi Kafka Validation ==="

# Check operator status
echo "Checking Strimzi operator..."
OPERATOR_READY=$(kubectl get deployment strimzi-kafka-operator -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [ "$OPERATOR_READY" -ge "1" ]; then
    echo "✓ Strimzi operator is running"
else
    echo "✗ Strimzi operator is not ready"
    exit 1
fi

# Check Kafka cluster status
echo "Checking Kafka cluster..."
KAFKA_STATUS=$(kubectl get kafka "$KAFKA_CLUSTER_NAME" -n "$NAMESPACE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
if [ "$KAFKA_STATUS" = "True" ]; then
    echo "✓ Kafka cluster is ready"
else
    echo "✗ Kafka cluster is not ready"
    kubectl describe kafka "$KAFKA_CLUSTER_NAME" -n "$NAMESPACE"
    exit 1
fi

# Check Kafka pods
echo "Checking Kafka pods..."
KAFKA_PODS=$(kubectl get pods -n "$NAMESPACE" -l strimzi.io/kafka="$KAFKA_CLUSTER_NAME" --no-headers 2>/dev/null | wc -l)
if [ "$KAFKA_PODS" -ge "3" ]; then
    echo "✓ Kafka brokers are running ($KAFKA_PODS pods)"
else
    echo "✗ Expected at least 3 Kafka brokers, found $KAFKA_PODS"
    exit 1
fi

# Check ZooKeeper pods
echo "Checking ZooKeeper pods..."
ZK_PODS=$(kubectl get pods -n "$NAMESPACE" -l strimzi.io/zookeeper="$KAFKA_CLUSTER_NAME" --no-headers 2>/dev/null | wc -l)
if [ "$ZK_PODS" -ge "3" ]; then
    echo "✓ ZooKeeper nodes are running ($ZK_PODS pods)"
else
    echo "✗ Expected at least 3 ZooKeeper nodes, found $ZK_PODS"
    exit 1
fi

# Check topics
echo "Checking Kafka topics..."
TOPICS=$(kubectl get kafkatopic -n "$NAMESPACE" -l strimzi.io/cluster="$KAFKA_CLUSTER_NAME" --no-headers 2>/dev/null | wc -l)
echo "✓ Found $TOPICS topic(s)"

# Check users
echo "Checking Kafka users..."
USERS=$(kubectl get kafkauser -n "$NAMESPACE" -l strimzi.io/cluster="$KAFKA_CLUSTER_NAME" --no-headers 2>/dev/null | wc -l)
echo "✓ Found $USER user(s)"

echo ""
echo "=== Validation Complete ==="
echo "All checks passed!"

# Show cluster info
echo ""
echo "Cluster Information:"
kubectl get kafka "$KAFKA_CLUSTER_NAME" -n "$NAMESPACE" -o wide
# Strimzi - Apache Kafka on Kubernetes

**Strimzi** is an open-source Kubernetes operator that provides a way to run Apache Kafka clusters on Kubernetes using native Kubernetes concepts and APIs.

## Overview

Strimzi simplifies deploying and managing Kafka on Kubernetes by providing:
- **Cluster Operator**: Manages Kafka clusters and related components
- **Topic Operator**: Manages Kafka topics via `KafkaTopic` custom resources
- **User Operator**: Manages Kafka users via `KafkaUser` custom resources
- **Entity Operator**: Combines Topic and User operators in a single deployment

## Prerequisites

- Kubernetes cluster (v1.27+ for Strimzi 0.48+)
- `kubectl` configured with cluster access
- Helm 3.x (for Helm-based installation)
- Optional: Strimzi Drain Cleaner for node maintenance

## Quick Start

### Install Strimzi Operator via Helm

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts

# Update Helm repositories
helm repo update

# Install Strimzi operator
helm install strimzi strimzi/strimzi-kafka-operator -n strimzi-operator --create-namespace
```

### Deploy a Kafka Cluster

Create a `Kafka` custom resource:

```yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: my-cluster
spec:
  kafka:
    version: 3.9.0
    replicas: 3
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
      - name: tls
        port: 9093
        type: internal
        tls: true
    storage:
      type: ephemeral
  zookeeper:
    replicas: 3
    storage:
      type: ephemeral
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

Apply the configuration:

```bash
kubectl apply -f kafka-cluster.yaml -n strimzi-operator
```

### Verify Deployment

```bash
# Check Kafka pods
kubectl get pods -n strimzi-operator -l strimzi.io/kafka=my-cluster

# Check Kafka status
kubectl get kafka my-cluster -n strimzi-operator
```

## Architecture

### Components

| Component | Description |
|-----------|-------------|
| **Cluster Operator** | Main operator managing Kafka broker deployment |
| **Topic Operator** | Watches `KafkaTopic` resources and manages topics |
| **User Operator** | Watches `KafkaUser` resources and manages users |
| **Entity Operator** | Combined deployment of Topic and User operators |

### Custom Resources

| Resource | Purpose |
|----------|---------|
| `Kafka` | Defines Kafka cluster configuration |
| `KafkaTopic` | Defines Kafka topics |
| `KafkaUser` | Defines Kafka users and access |
| `KafkaConnect` | Defines Kafka Connect deployments |
| `KafkaMirrorMaker2` | Defines MirrorMaker 2 deployments |
| `KafkaBridge` | Defines HTTP bridge configuration |
| `KafkaRebalance` | Defines Cruise Control rebalances |
| `KafkaNodePool` | Defines Kafka node configurations |

## Configuration Reference

### Kafka Resource Keys

```yaml
spec:
  kafka:
    version: "3.9.0"        # Kafka version
    replicas: 3             # Number of brokers
    resources:              # Resource requests/limits
      requests:
        memory: 2Gi
        cpu: 500m
      limits:
        memory: 4Gi
        cpu: 1000m
    storage:                # Storage configuration
      type: persistent-claim
      size: 100Gi
      class: standard
    listeners:              # Listener configuration
    config:                 # Broker configuration
  zookeeper:
    replicas: 3
    storage:
      type: ephemeral
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

### Security Configuration

```yaml
spec:
  kafka:
    listeners:
      - name: tls
        port: 9093
        type: internal
        tls: true
        authentication:
          type: tls
      - name: external
        port: 9094
        type: loadbalancer
        tls: true
        authentication:
          type: scram-sha-512
```

## Monitoring

Strimzi provides built-in metrics integration:

```yaml
spec:
  kafka:
    metricsConfig:
      type: jmxPrometheusExporter
      valueFrom:
        configMapKeyRef:
          name: kafka-metrics
          key: kafka-metrics-config.yml
```

## Troubleshooting

### Common Issues

1. **Pod not starting**: Check resource quotas and storage class availability
2. **Topic creation fails**: Verify Topic Operator is running
3. **User authentication issues**: Check `KafkaUser` configuration and ACLs

### Useful Commands

```bash
# View operator logs
kubectl logs -n strimzi-operator deployment/strimzi-cluster-operator

# Describe Kafka resource for events
kubectl describe kafka my-cluster -n strimzi-operator

# Check pod status
kubectl get pods -n strimzi-operator -o wide

# Forward Kafka broker port
kubectl port-forward -n strimzi-operator kafka-my-cluster-0 9092:9092
```

## Links

- **Blog Post**: [Strimzi: Running Apache Kafka on Kubernetes](https://garyinnerarity.com/blog/?post=strimzi-kubernetes-kafka)
- **Official Documentation**: https://strimzi.io/documentation/
- **GitHub Repository**: https://github.com/strimzi/strimzi-kafka-operator
# Apache Kafka on Kubernetes

Production-grade Apache Kafka deployment using KRaft mode (no ZooKeeper) with the Strimzi Operator on Kubernetes.

## Overview

Apache Kafka is a distributed event streaming platform capable of handling millions of messages per second with low latency. This deployment stack provides a production-ready Kafka cluster on Kubernetes using:

- **Strimzi Operator** — Kubernetes-native Kafka lifecycle management
- **KRaft Mode** — Kafka's built-in consensus protocol (ZooKeeper removed in Kafka 4.0)
- **Helm Charts** — Declarative, repeatable deployment
- **Terraform** — Infrastructure provisioning for cloud-native environments
- **Monitoring** — Prometheus + Grafana observability stack

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Kubernetes cluster | 1.25+ |
| Helm | 3.12+ |
| kubectl | 1.25+ |
| Terraform (optional) | 1.5+ |
| Storage class with PV support | - |
| Minimum nodes | 3 (one per broker) |

### Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| Kafka Broker (x3) | 2 CPU | 8 Gi | 500 Gi SSD |
| Controller (KRaft, x3) | 500m | 2 Gi | 50 Gi SSD |
| Strimzi Operator | 500m | 512 Mi | — |
| Entity Operator | 250m | 512 Mi | — |

## Quick Start

### 1. Install Strimzi Operator

```bash
# Add Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/
helm repo update

# Install operator
kubectl create namespace kafka
helm install strimzi strimzi/strimzi-kafka-operator \
  --namespace kafka \
  --version 0.42.0
```

### 2. Deploy Kafka Cluster

```bash
# Apply the Kafka cluster manifest
kubectl apply -f kubernetes/kafka-cluster.yaml

# Wait for cluster to be ready
kubectl wait kafka/production-kafka \
  --for=condition=Ready \
  --timeout=300s \
  -n kafka
```

### 3. Create Topics

```bash
kubectl apply -f kubernetes/topics/
```

### 4. Verify Deployment

```bash
# Check broker pods
kubectl get pods -n kafka -l strimzi.io/name=production-kafka-kafka

# Check controller pods
kubectl get pods -n kafka -l strimzi.io/name=production-kafka-controllers

# Verify cluster status
kubectl get kafka -n kafka
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                         │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Controller-0 │  │ Controller-1 │  │ Controller-2 │      │
│  │  (KRaft)     │  │  (KRaft)     │  │  (KRaft)     │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Broker-0    │  │  Broker-1    │  │  Broker-2    │      │
│  │  500Gi SSD   │  │  500Gi SSD   │  │  500Gi SSD   │      │
│  │  Zone-A      │  │  Zone-B      │  │  Zone-C      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│         │                  │                  │              │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Strimzi Cluster Operator                │    │
│  │  • Rolling Upgrades    • Auto-rebalancing           │    │
│  │  • TLS Certificate Mgmt • Topic/User Operators      │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                              │
│  ┌──────────────────────┐  ┌──────────────────────┐        │
│  │ Prometheus + Grafana │  │   Schema Registry    │        │
│  └──────────────────────┘  └──────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Key Design Decisions

- **Separated Mode**: Dedicated controller and broker nodes for production isolation
- **KRaft Consensus**: No ZooKeeper dependency (Kafka 4.0+ requirement)
- **Multi-AZ Spread**: Pod anti-affinity and rack awareness across availability zones
- **JBOD Storage**: Persistent volumes with fast SSD storage class
- **mTLS**: Mutual TLS for all inter-broker and client communication

## Configuration Reference

### Kafka Broker Settings

| Parameter | Default | Description |
|-----------|---------|-------------|
| `replicas` | 3 | Number of Kafka broker pods |
| `version` | 3.9.0 | Kafka version |
| `log.retention.hours` | 168 | Log retention (7 days) |
| `log.retention.bytes` | 10737418240 | 10 GB per partition |
| `default.replication.factor` | 3 | Default topic replication |
| `min.insync.replicas` | 2 | Minimum ISR for acks=all |
| `num.partitions` | 6 | Default partition count |
| `num.network.threads` | 8 | Network handler threads |
| `num.io.threads` | 16 | I/O handler threads |
| `auto.create.topics.enable` | false | Disable auto topic creation |

### JVM Settings

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `-Xms` | 4096m | Initial heap size |
| `-Xmx` | 4096m | Maximum heap size |
| GC | G1GC | Low-latency garbage collection |

### Storage Classes

The deployment expects a storage class named `fast-ssd` with:
- Volume expansion enabled
- `WaitForFirstConsumer` binding mode
- Backed by SSD/NVMe storage

## Validation & Testing

### Health Checks

```bash
# Produce a test message
kubectl run kafka-producer -it --rm \
  --image=apache/kafka:3.9.0 \
  --namespace=kafka \
  -- /opt/kafka/bin/kafka-console-producer.sh \
    --bootstrap-server production-kafka-kafka-bootstrap:9092 \
    --topic test-topic

# Consume the message
kubectl run kafka-consumer -it --rm \
  --image=apache/kafka:3.9.0 \
  --namespace=kafka \
  -- /opt/kafka/bin/kafka-console-consumer.sh \
    --bootstrap-server production-kafka-kafka-bootstrap:9092 \
    --topic test-topic \
    --from-beginning
```

### Performance Benchmarks

```bash
# Throughput test (producer)
kubectl run kafka-perf -it --rm \
  --image=apache/kafka:3.9.0 \
  --namespace=kafka \
  -- /opt/kafka/bin/kafka-producer-perf-test.sh \
    --topic perf-test \
    --num-records 1000000 \
    --record-size 1024 \
    --throughput -1 \
    --producer-props \
      bootstrap.servers=production-kafka-kafka-bootstrap:9092 \
      acks=all
```

### Expected Results

| Metric | Target | Notes |
|--------|--------|-------|
| Producer throughput | > 100 MB/s | 3-broker cluster, 1KB messages |
| p99 latency | < 10ms | Internal network, acks=all |
| Consumer throughput | > 200 MB/s | Single consumer group |
| Recovery time | < 60s | Single broker failure |

## Troubleshooting

### Common Issues

#### Pods stuck in Pending
```bash
# Check PVC status
kubectl get pvc -n kafka
# Verify storage class exists
kubectl get storageclass fast-ssd
```
**Fix**: Ensure your cluster has a provisioner for the `fast-ssd` storage class.

#### Under-replicated partitions
```bash
kubectl exec -n kafka production-kafka-kafka-0 -- \
  /opt/kafka/bin/kafka-topics.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --under-replicated-partitions
```
**Fix**: Check broker pod health and network connectivity between brokers.

#### Controller election failures
```bash
kubectl logs -n kafka production-kafka-controllers-0 | grep -i "election"
```
**Fix**: Ensure all controller pods are running and can communicate on port 9093.

#### High consumer lag
```bash
kubectl exec -n kafka production-kafka-kafka-0 -- \
  /opt/kafka/bin/kafka-consumer-groups.sh \
    --bootstrap-server localhost:9092 \
    --describe \
    --all-groups
```
**Fix**: Scale consumer instances or increase partition count for the topic.

## Monitoring

Key metrics to alert on:

| Metric | Alert Threshold | Severity |
|--------|-----------------|----------|
| `UnderReplicatedPartitions` | > 0 for 5 min | Critical |
| `ActiveControllerCount` | != 1 | Critical |
| `OfflinePartitionsCount` | > 0 | Critical |
| Consumer lag | Growing unbounded | Warning |
| Broker disk usage | > 80% | Warning |
| JVM heap usage | > 80% | Warning |
| Request queue time p99 | > 100ms | Warning |

## Directory Structure

```
apache-kafka/
├── README.md                    # This file
├── helm/
│   ├── Chart.yaml              # Helm chart metadata
│   ├── values.yaml             # Default configuration values
│   └── templates/
│       ├── namespace.yaml      # Kafka namespace
│       ├── kafka-cluster.yaml  # Strimzi Kafka CR
│       └── topics.yaml         # Default topics
├── kubernetes/
│   ├── kafka-cluster.yaml      # Full Kafka cluster manifest
│   ├── storage-class.yaml      # SSD storage class
│   ├── monitoring/
│   │   ├── prometheus-rules.yaml
│   │   └── grafana-dashboard.json
│   └── topics/
│       └── sample-topics.yaml  # Example topic definitions
├── terraform/
│   ├── main.tf                 # EKS/GKE/AKS cluster setup
│   ├── variables.tf            # Input variables
│   └── outputs.tf              # Output values
├── scripts/
│   ├── install.sh              # One-click install script
│   ├── validate.sh             # Health validation script
│   └── teardown.sh             # Cleanup script
└── docs/
    └── adr-001-kraft-mode.md   # Architecture decision record
```

## Related

- **Blog Post**: [Apache Kafka: Event Streaming from Zero to Production](https://garyinnerarity.com/blog/?post=apache-kafka)
- **Strimzi Documentation**: https://strimzi.io/documentation/
- **Apache Kafka**: https://kafka.apache.org/documentation/

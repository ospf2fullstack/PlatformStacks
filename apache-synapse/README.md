# Apache Synapse ESB Deployment

Production-ready Kubernetes and Docker deployment configurations for Apache Synapse ESB.

## Overview

This directory contains deployment artifacts for Apache Synapse, a lightweight Enterprise Service Bus. The configurations support both Docker Compose (development) and Kubernetes (production) deployments.

## Prerequisites

- Docker 20.10+
- Kubernetes 1.24+ (for K8s deployments)
- Helm 3.8+ (for Helm deployments)

## Quick Start

### Docker Compose (Development)

```bash
cd docker-compose
docker-compose up -d
```

### Kubernetes Deployment

```bash
# Apply Kubernetes manifests
kubectl apply -f kubernetes/

# Or use Helm
helm install synapse ./helm/synapse -n integration
```

## Contents

```
apache-synapse/
├── docker-compose/
│   ├── docker-compose.yaml
│   └── config/
│       └── synapse.properties
├── kubernetes/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   └── ingress.yaml
├── helm/
│   └── synapse/
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
└── README.md
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SYNAPSE_HTTP_PORT` | HTTP listener port | 8080 |
| `SYNAPSE_HTTPS_PORT` | HTTPS listener port | 8443 |
| `SYNAPSE_WORKERS` | Thread pool workers | 20 |

### ConfigMap Usage

For cloud-native configuration, use the `$SYSTEM` parameter injection pattern:

```xml
<endpoint>
  <address uri="$SYSTEM:backend_url"/>
</endpoint>
```

## Security

- Update default credentials in production
- Enable TLS/SSL for production deployments
- Use Kubernetes Secrets for sensitive data

## Monitoring

The deployment includes JMX support for monitoring. Configure Prometheus scraping via the JMX exporter endpoint.

## License

Apache License 2.0 - See [Apache Synapse](https://synapse.apache.org/) for original project license.
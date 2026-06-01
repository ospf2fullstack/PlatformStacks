# PlatformStacks

Engineering deployment documentation and artifacts for various platforms and technologies.

## Platforms

| Platform | Description | Documentation |
|----------|-------------|---------------|
| [Strimzi Kafka](/strimzi-kafka/README.md) | Apache Kafka on Kubernetes operator | [Full Docs](/strimzi-kafka/README.md) |
| [Apache Kafka](/apache-kafka/README.md) | Production Kafka with KRaft mode on Kubernetes via Strimzi | [Full Docs](/apache-kafka/README.md) |

## Getting Started

Each platform directory contains:
- **README.md**: Platform-specific documentation
- **helm/**: Helm chart configurations
- **kubernetes/**: Kubernetes manifests
- **scripts/**: Automation scripts

## Contributing

To add a new platform:
1. Create a new directory for your platform
2. Add a README.md with deployment documentation
3. Include relevant Helm charts, Kubernetes manifests, and scripts
4. Update this README with the new platform entry

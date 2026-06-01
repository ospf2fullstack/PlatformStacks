# PlatformStacks

Engineering deployment documentation, Helm charts, Terraform modules, Kubernetes manifests, and automation scripts for platform technologies.

Each platform directory contains everything needed to deploy, configure, and operate a specific technology stack in production Kubernetes environments.

## Platforms

| Platform | Description | Documentation |
|----------|-------------|---------------|
| [Strimzi Kafka](./strimzi-kafka/README.md) | Apache Kafka on Kubernetes via Strimzi operator | [Full Docs](./strimzi-kafka/README.md) |
| [Apache Synapse](./apache-synapse/README.md) | Enterprise Service Bus (ESB) and mediation engine | [Full Docs](./apache-synapse/README.md) |
| [Transformers in AI Systems](./transformers-in-ai-systems/README.md) | Transformer architecture training and inference on Kubernetes with GPU scheduling | [Full Docs](./transformers-in-ai-systems/README.md) |

## Repository Structure

```
PlatformStacks/
├── README.md                    # This file
├── strimzi-kafka/               # Strimzi Kafka deployment
├── apache-synapse/              # Apache Synapse ESB deployment
└── transformers-in-ai-systems/  # Transformer ML platform
    ├── README.md                # Platform documentation
    ├── kubernetes/              # K8s manifests (jobs, services, namespaces)
    ├── scripts/                 # Automation (train.py, validate.sh)
    └── helm/                    # Helm charts for inference serving
```

## Usage

Each platform directory is self-contained. Navigate to the desired platform and follow its README for deployment instructions.

## Related

- Blog posts with deep-dive explanations: [garyinnerarity.com/blog](https://garyinnerarity.com/blog)

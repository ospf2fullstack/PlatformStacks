# PlatformStacks

Engineering deployment documentation, Helm charts, Terraform modules, and scripts for platform technologies explored on [garyinnerarity.com](https://garyinnerarity.com).

Each subdirectory contains complete deployment documentation for a specific platform, including quickstart guides, configuration references, and production-ready artifacts.

## Platforms

| Platform | Description | Documentation |
|----------|-------------|---------------|
| [Strimzi Kafka](./strimzi-kafka/README.md) | Apache Kafka on Kubernetes via Strimzi Operator | [Full Docs](./strimzi-kafka/README.md) |
| [Apache Synapse](./apache-synapse/README.md) | Enterprise Service Bus for message mediation | [Full Docs](./apache-synapse/README.md) |
| [Kafka Streaming](./kafka-streaming/README.md) | Apache Kafka distributed streaming platform | [Full Docs](./kafka-streaming/README.md) |
| [Transformers in AI](./transformers-in-ai-systems/README.md) | Transformer architecture for AI/ML systems | [Full Docs](./transformers-in-ai-systems/README.md) |
| [Tiny LLM Training](./tiny-llm-training/README.md) | Train small language models (10-30M params) from scratch | [Full Docs](./tiny-llm-training/README.md) |

## Structure

Each platform directory follows a standard layout:

```
/{platform-name}/
├── README.md              # Overview, prerequisites, quickstart
├── configs/               # Configuration files (YAML, TOML, etc.)
├── helm/                  # Helm charts for Kubernetes deployment
├── terraform/             # Terraform modules (if applicable)
├── kubernetes/            # Raw K8s manifests (if applicable)
├── scripts/               # Automation scripts (install, validate, teardown)
└── docs/                  # Extended documentation and ADRs
```

## Usage

1. Navigate to the platform directory you're interested in
2. Follow the README.md for prerequisites and quickstart
3. Customize configuration files for your environment
4. Deploy using the provided Helm charts or scripts

## Related

- **Blog**: [garyinnerarity.com/blog](https://garyinnerarity.com/blog/) — Engineering write-ups for each platform
- **Author**: Gary Innerarity — Solutions Engineer & MBA

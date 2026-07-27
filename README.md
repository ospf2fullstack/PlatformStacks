# PlatformStacks

Engineering deployment documentation, Helm charts, Terraform modules, and deployment guides for production platform technologies.

## Platforms

| Platform | Description | Documentation |
|----------|-------------|---------------|
| [Strimzi Kafka](/strimzi-kafka/README.md) | Apache Kafka on Kubernetes via Strimzi operator | [Full Docs](/strimzi-kafka/README.md) |
| [KubeAI](/kubeai/README.md) | AI Inference Operator for Kubernetes | [Full Docs](/kubeai/README.md) |
| [Hearth](/hearth/README.md) | Declarative LLM Serving on Kubernetes | [Full Docs](/hearth/README.md) |
| [Komputer.AI](/komputer-ai/README.md) | Distributed Claude AI Agents on K8s | [Full Docs](/komputer-ai/README.md) |
| [Kthena](/kthena-llm-inference/README.md) | Kubernetes-Native LLM Inference with PD Disaggregation | [Full Docs](/kthena-llm-inference/README.md) |
<<<<<<< HEAD
| [KServe](/kserve-inference-platform/README.md) | CNCF Inference Service Platform for Kubernetes | [Full Docs](/kserve-inference-platform/README.md) |
| [KAITO](/kaito/README.md) | Auto-Provisioning GPU AI Inference on Kubernetes | [Full Docs](/kaito/README.md) |
| [LiteLLM](/litellm/README.md) | Unified LLM API Gateway for 100+ Providers | [Full Docs](/litellm/README.md) |
=======
| [KServe](/kserve-inference-platform/README.md) | CNCF Incubating inference platform for predictive and generative AI model serving on Kubernetes | [Full Docs](/kserve-inference-platform/README.md) |
>>>>>>> origin/main

## Structure

Each platform directory contains:
- `README.md` — Platform overview, prerequisites, quick-start, architecture, troubleshooting
- `helm/` or `charts/` — Helm charts (where applicable)
- `kubernetes/` — Raw Kubernetes manifests
- `terraform/` — Terraform modules (where applicable)
- `scripts/` — Automation scripts
- `docs/` — Extended documentation

## Contributing

1. Create a branch: `platform/{slug}-{YYYYMMDD}`
2. Add platform directory with at minimum a README.md
3. Update this root README with the platform link
4. Open a PR for review

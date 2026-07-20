# PlatformStacks

Engineering deployment documentation, Helm charts, Terraform modules, and automation scripts for platform technologies explored on [garyinnerarity.com](https://garyinnerarity.com).

Each platform directory contains complete deployment guides, configuration references, and production-ready artifacts.

## Platforms

| Platform | Description | Documentation |
|----------|-------------|---------------|
| [ML Network Simulation](ml-network-simulation/README.md) | ML models that simulate network infrastructure behavior for traffic prediction, failure detection, and routing optimization | [Full Docs](ml-network-simulation/README.md) |
| [KubeAI](kubeai/README.md) | AI Inference Operator for Kubernetes — deploy and scale vLLM, Ollama, FasterWhisper with scale-to-zero and prefix-aware load balancing | [Full Docs](kubeai/README.md) |
| [Hearth](hearth-kubernetes-llm-serving/README.md) | Declarative scale-to-zero LLM serving on Kubernetes — one CRD + KEDA, vendor-neutral across NVIDIA & Ascend | [Full Docs](hearth-kubernetes-llm-serving/README.md) |
| [KAITO](kaito/README.md) | Kubernetes AI Toolchain Operator — CNCF Sandbox project that automates LLM inference, fine-tuning, and RAG with automatic GPU node provisioning via Karpenter | [Full Docs](kaito/README.md) |
| [Roboflow Supervision](roboflow-supervision/README.md) | Model-agnostic Python CV toolkit — unified Detections API, 20+ annotators, object tracking, zone counting, and dataset management for production computer vision | [Full Docs](roboflow-supervision/README.md) |
| [LiteLLM](litellm/README.md) | Unified LLM API Gateway — single OpenAI-compatible endpoint for 100+ providers with virtual keys, spend tracking, latency-based routing, and componentized Kubernetes deployment | [Full Docs](litellm/README.md) |
| [Komputer.AI](komputer-ai/README.md) | Distributed Claude AI Agents on Kubernetes — stateless, CRD-driven platform with persistent agent workspaces, manager/worker orchestration, MCP connectors, and real-time event streaming | [Full Docs](komputer-ai/README.md) |
| [KServe](kserve-inference-platform/README.md) | CNCF Incubating inference platform — unified predictive + generative AI serving with InferenceService CRD, LLMInferenceService for LLMs, canary rollouts, scale-to-zero, and KV-cache aware routing | [Full Docs](kserve-inference-platform/README.md) |

## Repository Structure

```
PlatformStacks/
├── {platform-name}/
│   ├── README.md          # Platform overview and quickstart
│   ├── configs/           # Configuration files
│   ├── scripts/           # Automation and utility scripts
│   ├── kubernetes/        # Docker and K8s manifests
│   ├── helm/              # Helm charts (if applicable)
│   ├── terraform/         # Infrastructure as code (if applicable)
│   └── docs/              # Extended documentation
└── README.md              # This file
```

## Usage

Each platform is self-contained. Navigate to the platform directory and follow its README for quickstart instructions.

## Related

- Blog: [garyinnerarity.com/blog](https://garyinnerarity.com/blog/)
- Author: Gary Innerarity

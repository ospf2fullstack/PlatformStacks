# Kthena - Kubernetes-Native LLM Inference Platform

Kthena is a Kubernetes-native AI serving platform from the Volcano.sh project that transforms how organizations deploy and manage Large Language Models in production. It provides declarative model lifecycle management, intelligent request routing, and enterprise-grade scalability for LLM inference workloads.

## Overview

| Property | Value |
|----------|-------|
| **Project** | Kthena (Volcano.sh sub-project) |
| **GitHub** | [volcano-sh/kthena](https://github.com/volcano-sh/kthena) |
| **License** | Apache 2.0 |
| **Language** | Go |
| **Engines** | vLLM, SGLang, Triton, TorchServe |
| **CRDs** | ModelServing, ModelServer, ModelRoute, ModelBooster, AutoScalingPolicy |

## Prerequisites

- Kubernetes cluster v1.24+
- [Volcano scheduler](https://github.com/volcano-sh/volcano/) installed
- GPU-enabled nodes (NVIDIA or Huawei Ascend) with device plugin
- Helm 3.x (for Helm-based installation)
- kubectl configured with cluster access
- Access to container images:
  - `ghcr.io/volcano-sh/vllm-openai:v0.10.0-cu128-nixl-v0.4.1-lmcache-0.3.2` (vLLM)
  - `docker.io/lmsysorg/sglang:latest` (SGLang)
  - `ghcr.io/volcano-sh/downloader:latest` (model downloader)
  - `kthena/runtime:latest` (runtime sidecar)

## Quick Start

### 1. Install Kthena

```bash
# Install Volcano first (if not already installed)
kubectl apply -f https://raw.githubusercontent.com/volcano-sh/volcano/master/installer/volcano-development.yaml

# Install Kthena via Helm
helm repo add kthena https://volcano-sh.github.io/kthena
helm install kthena kthena/kthena -n kthena-system --create-namespace
```

### 2. Deploy a Model (ModelBooster - Simplified)

```yaml
apiVersion: workload.serving.volcano.sh/v1alpha1
kind: ModelBooster
metadata:
  name: qwen3-8b
spec:
  name: qwen3-8b
  backend:
    name: "qwen3-8b-vllm"
    type: "vLLM"
    modelURI: "Qwen/Qwen3-8B"
    minReplicas: 1
    maxReplicas: 3
    workers:
      - type: server
        image: ghcr.io/volcano-sh/vllm-openai:v0.10.0-cu128-nixl-v0.4.1-lmcache-0.3.2
        replicas: 1
        pods: 1
```

### 3. Deploy with Prefill-Decode Disaggregation (ModelServing - Advanced)

```yaml
apiVersion: workload.serving.volcano.sh/v1alpha1
kind: ModelServing
metadata:
  name: qwen3-pd
  namespace: default
spec:
  schedulerName: volcano
  replicas: 1
  template:
    roles:
      - name: prefill
        replicas: 1
        entryTemplate:
          spec:
            initContainers:
              - name: downloader
                image: ghcr.io/volcano-sh/downloader:latest
                args:
                  - --source
                  - Qwen/Qwen3-0.6B
                  - --output-dir
                  - /models/Qwen3-0.6B/
                volumeMounts:
                  - name: models
                    mountPath: /models
            containers:
              - name: vllm-prefill
                image: ghcr.io/volcano-sh/vllm-openai:v0.10.0-cu128-nixl-v0.4.1-lmcache-0.3.2
                args:
                  - --model
                  - /models/Qwen3-0.6B
                  - --served-model-name
                  - Qwen/Qwen3-0.6B
                  - --port
                  - "8000"
                  - --kv-transfer-config
                  - '{"kv_connector":"NixlConnector","kv_role":"kv_both"}'
                resources:
                  limits:
                    nvidia.com/gpu: 1
                ports:
                  - containerPort: 8000
                volumeMounts:
                  - name: models
                    mountPath: /models
            volumes:
              - name: models
                emptyDir: {}
        workerReplicas: 0
      - name: decode
        replicas: 1
        entryTemplate:
          spec:
            initContainers:
              - name: downloader
                image: ghcr.io/volcano-sh/downloader:latest
                args:
                  - --source
                  - Qwen/Qwen3-0.6B
                  - --output-dir
                  - /models/Qwen3-0.6B/
                volumeMounts:
                  - name: models
                    mountPath: /models
            containers:
              - name: vllm-decode
                image: ghcr.io/volcano-sh/vllm-openai:v0.10.0-cu128-nixl-v0.4.1-lmcache-0.3.2
                args:
                  - --model
                  - /models/Qwen3-0.6B
                  - --served-model-name
                  - Qwen/Qwen3-0.6B
                  - --port
                  - "8000"
                  - --kv-transfer-config
                  - '{"kv_connector":"NixlConnector","kv_role":"kv_both"}'
                resources:
                  limits:
                    nvidia.com/gpu: 1
                ports:
                  - containerPort: 8000
                volumeMounts:
                  - name: models
                    mountPath: /models
            volumes:
              - name: models
                emptyDir: {}
        workerReplicas: 0
```

### 4. Create ModelServer and ModelRoute

```yaml
---
apiVersion: networking.serving.volcano.sh/v1alpha1
kind: ModelServer
metadata:
  name: qwen3-pd
  namespace: default
spec:
  workloadSelector:
    matchLabels:
      modelserving.volcano.sh/name: qwen3-pd
    pdGroup:
      groupKey: "modelserving.volcano.sh/group-name"
      prefillLabels:
        modelserving.volcano.sh/role: prefill
      decodeLabels:
        modelserving.volcano.sh/role: decode
  workloadPort:
    port: 8000
  model: "Qwen/Qwen3-0.6B"
  inferenceEngine: "vLLM"
  trafficPolicy:
    timeout: 10s
---
apiVersion: networking.serving.volcano.sh/v1alpha1
kind: ModelRoute
metadata:
  name: qwen3-pd
  namespace: default
spec:
  modelName: "Qwen/Qwen3-0.6B"
  rules:
    - name: "default"
      targetModels:
        - modelServerName: "qwen3-pd"
```

### 5. Send an Inference Request

```bash
export ROUTER_IP=$(kubectl get svc kthena-router -n kthena-system -o jsonpath='{.spec.clusterIP}')

curl -v http://$ROUTER_IP:80/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen3-0.6B","messages":[{"role":"user","content":"Hello, explain Kubernetes in one sentence."}]}'
```

## Architecture

Kthena implements a Kubernetes-native architecture with separate control plane and data plane:

```
┌─────────────────────────────────────────────────────────────┐
│                     Control Plane                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │         Kthena Controller Manager                    │    │
│  │  - Reconciles ModelServing/ModelBooster CRDs         │    │
│  │  - Manages pod lifecycle (create, scale, update)     │    │
│  │  - Integrates with Volcano scheduler                 │    │
│  │  - Applies autoscaling policies                      │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      Data Plane                               │
│  ┌──────────────┐    ┌──────────────┐   ┌──────────────┐   │
│  │ Kthena Router│───▶│ Prefill Pods │◀─▶│ Decode Pods  │   │
│  │  - Routing   │    │ (compute)    │KV │ (memory)     │   │
│  │  - LB        │    └──────────────┘   └──────────────┘   │
│  │  - PD-aware  │                                           │
│  └──────────────┘                                           │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Role |
|-----------|------|
| **Kthena Controller Manager** | Control plane – reconciles CRDs, manages lifecycle, integrates Volcano scheduler |
| **Kthena Router** | Data plane – classifies requests, applies routing policies, PD-aware distribution |
| **Kthena Runtime** | Sidecar – metrics standardization, LoRA lifecycle, model downloading |
| **Volcano Scheduler** | Gang scheduling, topology-aware placement, resource optimization |

## Configuration Reference

### ModelServing Key Fields

| Field | Description |
|-------|-------------|
| `spec.schedulerName` | Scheduler to use (set to `volcano`) |
| `spec.replicas` | Number of ServingGroups |
| `spec.template.roles[].name` | Role name (e.g., `prefill`, `decode`) |
| `spec.template.roles[].replicas` | Pods per role |
| `spec.template.gangPolicy.minRoleReplicas` | Min replicas for gang scheduling |
| `spec.recoveryPolicy` | `ServingGroupRecreate` or `RoleRecreate` |

### ModelServer Key Fields

| Field | Description |
|-------|-------------|
| `spec.workloadSelector.matchLabels` | Select pods for this server |
| `spec.workloadSelector.pdGroup` | PD-aware routing config |
| `spec.workloadPort.port` | Port for inference traffic |
| `spec.model` | Model identifier |
| `spec.inferenceEngine` | Engine name (vLLM, SGLang, etc.) |
| `spec.trafficPolicy` | Timeout, rate limiting configs |

### KV Transfer Connectors

| Connector | Use Case |
|-----------|----------|
| `NixlConnector` | NVIDIA GPU RDMA-friendly transfers |
| `MooncakeConnectorV1` | Huawei Ascend NPU deployments |
| `LMCache` | General-purpose KV cache coordination |

## Dynamic LoRA Management

Kthena supports hot-swapping LoRA adapters without restarting pods:

```yaml
apiVersion: workload.serving.volcano.sh/v1alpha1
kind: ModelBooster
metadata:
  name: deepseek-r1-lora
spec:
  backend:
    env:
      - name: "VLLM_ALLOW_RUNTIME_LORA_UPDATING"
        value: "True"
    loraAdapters:
      - name: "lora-finance"
        artifactURL: "s3://model-bucket/lora-finance-v2"
      - name: "lora-medical"
        artifactURL: "huggingface://org/lora-medical-v1"
```

### LoRA-Aware Routing

```yaml
apiVersion: networking.serving.volcano.sh/v1alpha1
kind: ModelRoute
metadata:
  name: deepseek-lora
spec:
  loraAdapters:
    - "lora-finance"
    - "lora-medical"
  rules:
    - name: "lora-route"
      targetModels:
        - modelServerName: "deepseek-r1-lora"
```

## Validation & Testing

```bash
# Check Kthena system pods
kubectl get pods -n kthena-system

# Check ModelServing status
kubectl get modelserving -A

# Check router service
kubectl get svc kthena-router -n kthena-system

# Verify prefill and decode pods
kubectl get pods -l modelserving.volcano.sh/name=qwen3-pd

# Send test request
curl http://$ROUTER_IP:80/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Qwen/Qwen3-0.6B","messages":[{"role":"user","content":"Test"}]}'
```

## Troubleshooting

| Issue | Resolution |
|-------|-----------|
| Pods stuck in Pending | Check GPU device plugin; verify Volcano scheduler is running |
| Gang scheduling timeout | Verify `minRoleReplicas` matches available resources |
| KV transfer failures | Ensure RDMA/network connectivity between prefill and decode pods |
| Model download failures | Verify HuggingFace token or S3 credentials in secrets |
| Router not routing | Check ModelServer labels match pod labels exactly |
| LoRA load failures | Ensure `VLLM_ALLOW_RUNTIME_LORA_UPDATING=True` is set |

## Related Resources

- [Blog Post: Kthena - LLM Inference with Disaggregation](https://garyinnerarity.com/blog/?post=kthena-llm-inference)
- [Kthena Official Documentation](https://kthena.volcano.sh/)
- [Volcano Scheduler](https://github.com/volcano-sh/volcano/)
- [vLLM Documentation](https://docs.vllm.ai/)

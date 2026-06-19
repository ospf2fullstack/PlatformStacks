# KAITO - Kubernetes AI Toolchain Operator

## Overview

KAITO is a CNCF Sandbox project that automates LLM model inference, fine-tuning, and RAG (Retrieval Augmented Generation) engine deployment in Kubernetes clusters. It integrates with vLLM as the inference engine and uses Karpenter-compatible APIs for automatic GPU node provisioning.

**Key Features:**
- Automatic GPU node provisioning via Karpenter APIs
- vLLM inference engine with optimized scheduling
- LoRA/QLoRA fine-tuning support
- RAG engine deployment
- KEDA-based autoscaling
- OpenAI-compatible API endpoints
- Multi-cloud support (Azure AKS, AWS EKS, any K8s cluster)

## Prerequisites

| Requirement | Minimum Version | Notes |
|-------------|----------------|-------|
| Kubernetes | v1.27+ | Any conformant cluster |
| Helm | v3.12+ | For installation |
| NVIDIA GPU Operator | Latest | GPU driver + container runtime |
| kubectl | v1.27+ | Cluster access |
| GPU Nodes | NVIDIA T4+ | V100, A100, H100 recommended |

### Cloud-Specific Requirements

**Azure (AKS):**
- AKS cluster with GPU node pool quota
- Azure subscription with GPU VM quota
- Managed identity with contributor access

**AWS (EKS):**
- EKS cluster with Karpenter installed
- GPU instance quota (g5, p4d, p5 families)
- IAM roles for Karpenter node provisioning

**Self-managed / On-prem:**
- NVIDIA GPU Operator installed
- Node labels for GPU scheduling
- Sufficient GPU memory for target models

## Quick-Start Deployment

### Option 1: BYO GPU Nodes (Simplest)

```bash
# Add KAITO Helm repo
helm repo add kaito https://kaito-project.github.io/kaito/charts/kaito
helm repo update

# Install KAITO with auto-provisioning disabled (BYO nodes)
export CLUSTER_NAME=my-cluster

helm upgrade --install kaito-workspace kaito/workspace \
  --namespace kaito-workspace \
  --create-namespace \
  --set clusterName="$CLUSTER_NAME" \
  --set featureGates.disableNodeAutoProvisioning=true \
  --wait \
  --take-ownership

# Label your GPU nodes
kubectl label node <gpu-node-name> accelerator=nvidia
```

### Option 2: Auto-Provisioning (Production)

```bash
# Install KAITO with auto-provisioning enabled
helm upgrade --install kaito-workspace kaito/workspace \
  --namespace kaito-workspace \
  --create-namespace \
  --set clusterName="$CLUSTER_NAME" \
  --wait \
  --take-ownership

# For Azure: Install GPU provisioner
helm upgrade --install gpu-provisioner kaito/gpu-provisioner \
  --namespace gpu-provisioner \
  --create-namespace \
  --set settings.azure.clusterName="$CLUSTER_NAME"
```

### Deploy Your First Model

```yaml
# phi-4-workspace.yaml
apiVersion: kaito.sh/v1beta1
kind: Workspace
metadata:
  name: workspace-phi-4-mini
  namespace: default
spec:
  resource:
    instanceType: "Standard_NC6s_v3"  # Azure example
    labelSelector:
      matchLabels:
        apps: phi-4-mini
  inference:
    preset:
      name: phi-4-mini-instruct
```

```bash
kubectl apply -f phi-4-workspace.yaml

# Watch provisioning
kubectl get workspace workspace-phi-4-mini -w

# Test inference endpoint
kubectl port-forward svc/workspace-phi-4-mini 8080:80
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi-4-mini-instruct",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Configuration Reference

### Workspace CRD

| Field | Type | Description |
|-------|------|-------------|
| `spec.resource.instanceType` | string | GPU VM SKU (e.g., Standard_NC24ads_A100_v4) |
| `spec.resource.labelSelector` | object | Node selector for scheduling |
| `spec.resource.count` | int | Number of nodes for distributed inference |
| `spec.inference.preset.name` | string | Model preset name from KAITO registry |
| `spec.inference.preset.accessMode` | string | `public` or `private` |
| `spec.tuning.preset.name` | string | Model for fine-tuning |
| `spec.tuning.method` | string | `lora` or `qlora` |
| `spec.tuning.input` | object | Training data source |
| `spec.tuning.output` | object | Adapter output destination |

### InferenceSet CRD (Autoscaling)

| Field | Type | Description |
|-------|------|-------------|
| `spec.workspaceName` | string | Target workspace to scale |
| `spec.minReplicas` | int | Minimum replica count |
| `spec.maxReplicas` | int | Maximum replica count |

### Key Helm Values

```yaml
# values.yaml overrides
clusterName: "my-cluster"
featureGates:
  disableNodeAutoProvisioning: false  # true for BYO nodes
  enableKEDAScaler: true

controller:
  resources:
    limits:
      cpu: "2"
      memory: "4Gi"
    requests:
      cpu: "500m"
      memory: "1Gi"
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                 KAITO Architecture                    │
├─────────────────────────────────────────────────────┤
│                                                      │
│  ┌──────────┐    ┌──────────────────┐               │
│  │ Workspace│───▶│ KAITO Controller │               │
│  │   CRD    │    └────────┬─────────┘               │
│  └──────────┘             │                          │
│                           ▼                          │
│  ┌────────────────────────────────────────┐         │
│  │         Node Provisioner               │         │
│  │  (Karpenter / GPU Provisioner)         │         │
│  └────────────────┬───────────────────────┘         │
│                   │                                  │
│                   ▼                                  │
│  ┌────────────────────────────────────────┐         │
│  │          GPU Node Pool                  │         │
│  │  ┌──────┐  ┌──────┐  ┌──────┐        │         │
│  │  │ vLLM │  │ vLLM │  │ vLLM │        │         │
│  │  │Engine│  │Engine│  │Engine│        │         │
│  │  └──────┘  └──────┘  └──────┘        │         │
│  └────────────────────────────────────────┘         │
│                   │                                  │
│                   ▼                                  │
│  ┌────────────────────────────────────────┐         │
│  │  OpenAI-Compatible API Service          │         │
│  │  (ClusterIP / LoadBalancer)             │         │
│  └────────────────────────────────────────┘         │
│                                                      │
│  ┌──────────────┐    ┌────────────────────┐         │
│  │ InferenceSet │───▶│  KEDA Autoscaler   │         │
│  │     CRD      │    └────────────────────┘         │
│  └──────────────┘                                   │
│                                                      │
└─────────────────────────────────────────────────────┘
```

**Flow:**
1. User creates a `Workspace` CRD specifying model + GPU type
2. KAITO Controller estimates GPU memory requirements
3. Node Provisioner auto-provisions GPU nodes (or uses BYO nodes)
4. vLLM inference engine deploys with optimized parameters (TP, PP, DP)
5. OpenAI-compatible API endpoint is exposed as a Kubernetes Service
6. InferenceSet + KEDA handle autoscaling based on vLLM metrics

## Validation / Testing

```bash
# Check KAITO controller is running
kubectl get pods -n kaito-workspace

# Verify workspace status
kubectl get workspace -A
kubectl describe workspace workspace-phi-4-mini

# Check GPU node provisioning
kubectl get nodes -l accelerator=nvidia
kubectl get machines -A  # Karpenter machines

# Test inference endpoint
SERVICE_IP=$(kubectl get svc workspace-phi-4-mini -o jsonpath='{.spec.clusterIP}')
curl http://$SERVICE_IP/v1/models

# Run a completion test
curl http://$SERVICE_IP/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "phi-4-mini-instruct",
    "messages": [{"role": "user", "content": "Explain Kubernetes in one sentence."}],
    "max_tokens": 100
  }'
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Workspace stuck in `Pending` | No GPU quota | Request GPU VM quota increase in your cloud provider |
| Node not provisioning | Karpenter not configured | Verify gpu-provisioner or Karpenter pods are running |
| OOM during inference | Model too large for GPU | Use larger instanceType or enable multi-node with `count` |
| Slow model download | Large model + slow network | Use NVMe-backed instances; KAITO caches to local disk |
| API returns 503 | Pod not ready yet | Wait for model to load; check pod logs |
| Fine-tuning OOM | Batch size too large | Use QLoRA instead of LoRA, or reduce batch size in ConfigMap |

## Supported Models (Presets)

| Model Family | Example Models | Min GPU |
|-------------|---------------|---------|
| Phi-4 | phi-4-mini-instruct | 1x V100 |
| Llama 3 | llama-3.2-11b-vision | 1x A100 |
| Llama 3 (70B) | llama-3.3-70b | 2x A100 |
| Mistral | mistral-7b-instruct | 1x T4 |
| Falcon | falcon-7b | 1x T4 |
| DeepSeek | deepseek-r1 | 4x A100 |

For the full list, see the [KAITO Model Registry](https://kaito-project.github.io/kaito/docs/presets).

## Links

- [KAITO GitHub Repository](https://github.com/kaito-project/kaito)
- [Official Documentation](https://kaito-project.github.io/kaito/docs/)
- [CNCF Project Page](https://www.cncf.io/projects/kaito/)
- [Blog Post](https://garyinnerarity.com/blog/?post=kaito-kubernetes-ai-inference)

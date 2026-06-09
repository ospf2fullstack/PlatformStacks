# KubeAI - AI Inference Operator for Kubernetes

Deploy and scale machine learning models on Kubernetes with zero dependencies.

## Overview

KubeAI is an open-source Kubernetes operator that provides production-grade AI model serving with intelligent autoscaling, prefix-aware load balancing, and scale-to-zero capability. It supports vLLM, Ollama, FasterWhisper, and Infinity engines out of the box.

**Key Features:**
- 🚀 LLM Inferencing via vLLM and Ollama
- 🎙️ Speech-to-Text via FasterWhisper
- 🔢 Vector Embeddings via Infinity
- 📚 Reranking with cross-encoder models
- ⚡️ Scale from zero to meet demand
- 📊 Prefix-aware load balancing (optimized KV cache utilization)
- 💾 Automated model caching (EFS, PVC, S3, GCS)
- 🧩 Dynamic LoRA adapter orchestration
- 📨 Event streaming (Kafka, PubSub)
- 🔗 OpenAI-compatible API
- 🛠️ Zero dependencies (no Istio, Knative required)
- 🖥️ Hardware flexible (CPU, GPU, TPU)

## Prerequisites

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| Kubernetes | v1.26+ | v1.28+ |
| Helm | v3.12+ | v3.14+ |
| kubectl | v1.26+ | v1.28+ |
| GPU (optional) | NVIDIA driver 535+ | NVIDIA driver 550+ |
| Storage | 50GB+ per model | NFS/EFS for shared caching |

### GPU Requirements (if using GPU models)
- NVIDIA GPU Operator installed
- CUDA 12.x compatible drivers
- For k3s: `nvidia-container-runtime` configured

### Supported Environments
- Any Kubernetes cluster (k3s, k8s, microk8s)
- Amazon EKS
- Google GKE
- Azure AKS
- Lambda Cloud
- Vultr Managed Kubernetes

## Quick Start

### 1. Add Helm Repository

```bash
helm repo add kubeai https://www.kubeai.org
helm repo update
```

### 2. Install KubeAI Operator

```bash
# Create namespace
kubectl create namespace kubeai

# Install with default configuration
helm install kubeai kubeai/kubeai \
  --namespace kubeai \
  --wait
```

### 3. Deploy Models

```bash
cat <<EOF > kubeai-models.yaml
catalog:
  deepseek-r1-1.5b-cpu:
    enabled: true
    features: [TextGeneration]
    url: 'ollama://deepseek-r1:1.5b'
    engine: OLlama
    minReplicas: 1
    resourceProfile: 'cpu:1'
  qwen2-500m-cpu:
    enabled: true
    minReplicas: 0
  nomic-embed-text-cpu:
    enabled: true
EOF

helm install kubeai-models kubeai/models \
  -f ./kubeai-models.yaml \
  --namespace kubeai
```

### 4. Verify Deployment

```bash
# Check models are running
kubectl get models -n kubeai

# Check pods
kubectl get pods -n kubeai

# Test the API
kubectl port-forward svc/kubeai -n kubeai 8000:80
curl http://localhost:8000/openai/v1/models
```

## Architecture

KubeAI consists of two primary components:

### 1. Model Proxy
The KubeAI proxy provides an OpenAI-compatible API with:
- **Prefix-aware load balancing** — optimizes KV cache utilization across vLLM replicas
- **Request queueing** — buffers requests during scale-from-zero initialization
- **Request retries** — seamlessly handles backend failures
- **Streaming support** — full SSE streaming for chat completions

### 2. Model Operator
The KubeAI model operator manages backend Pods directly via the `Model` CRD:
- Automates model downloading and caching
- Manages volume mounts for model storage
- Orchestrates dynamic LoRA adapter loading
- Handles autoscaling decisions based on request load

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Applications                         │
│                (OpenAI SDK / HTTP / gRPC)                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                     KubeAI Proxy                              │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │ OpenAI API  │  │ Prefix-Aware │  │  Request Queue &  │  │
│  │  Endpoint   │  │ Load Balancer│  │     Retry Logic   │  │
│  └─────────────┘  └──────────────┘  └───────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                   KubeAI Model Operator                       │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────────┐  │
│  │   Model CRD │  │  Autoscaler  │  │  Cache Manager    │  │
│  │  Controller │  │  (0 → N)     │  │  (PVC/S3/GCS)     │  │
│  └─────────────┘  └──────────────┘  └───────────────────┘  │
└──────────────────────────┬──────────────────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌──────────────┐ ┌────────┐ ┌──────────────┐
     │   vLLM Pod   │ │ Ollama │ │ FasterWhisper│
     │  (GPU/CPU)   │ │  Pod   │ │     Pod      │
     └──────────────┘ └────────┘ └──────────────┘
```

## Configuration Reference

### Model CRD Spec

```yaml
apiVersion: kubeai.org/v1
kind: Model
metadata:
  name: my-model
spec:
  features: [TextGeneration]        # TextGeneration, TextEmbedding, Reranking, SpeechToText
  url: "hf://meta-llama/Llama-3.1-8B-Instruct"
  engine: VLLM                       # VLLM, OLlama, FasterWhisper, Infinity
  args:                              # Engine-specific arguments
    - --dtype=float16
    - --max-model-len=32768
    - --gpu-memory-utilization=0.90
  resourceProfile: "nvidia-gpu-l4:1" # GPU/CPU resource profile
  minReplicas: 0                     # Enable scale-to-zero
  maxReplicas: 5                     # Maximum replicas
  targetRequests: 100                # Target active requests per replica
  scaleDownDelaySeconds: 30          # Cooldown before scaling down
  adapters:                          # Optional LoRA adapters
    - name: my-lora
      url: "hf://my-org/my-lora-adapter"
```

### Key Configuration Values (Helm)

| Value | Description | Default |
|-------|-------------|---------|
| `replicaCount` | KubeAI operator replicas | `1` |
| `image.tag` | KubeAI version | `latest` |
| `proxy.replicas` | Proxy instances | `2` |
| `cacheProfiles.default.storageClassName` | Storage class for model cache | `standard` |
| `cacheProfiles.default.accessModes` | PVC access modes | `[ReadWriteOnce]` |
| `resourceProfiles` | Named GPU/CPU profiles | See defaults |
| `messaging.enabled` | Enable Kafka/PubSub | `false` |

### Resource Profiles

```yaml
resourceProfiles:
  cpu:1:
    requests:
      cpu: "1"
      memory: "4Gi"
  nvidia-gpu-l4:1:
    requests:
      cpu: "4"
      memory: "24Gi"
    limits:
      nvidia.com/gpu: "1"
  nvidia-gpu-a100:1:
    requests:
      cpu: "8"
      memory: "80Gi"
    limits:
      nvidia.com/gpu: "1"
```

## Validation & Testing

### Health Check

```bash
# Check operator health
kubectl get pods -n kubeai -l app.kubernetes.io/name=kubeai

# Check model status
kubectl get models -n kubeai -o wide

# Verify API endpoint
curl -s http://localhost:8000/openai/v1/models | jq .
```

### Functional Test

```bash
# Text generation test
curl http://localhost:8000/openai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "deepseek-r1-1.5b-cpu",
    "messages": [{"role": "user", "content": "Hello, how are you?"}],
    "max_tokens": 100
  }'

# Embedding test (if embedding model deployed)
curl http://localhost:8000/openai/v1/embeddings \
  -H "Content-Type: application/json" \
  -d '{
    "model": "nomic-embed-text-cpu",
    "input": "Test embedding generation"
  }'
```

### Scale-to-Zero Validation

```bash
# Set a model to minReplicas: 0
kubectl patch model qwen2-500m-cpu -n kubeai \
  --type merge -p '{"spec":{"minReplicas":0}}'

# Wait for scale-down (default 30s delay)
sleep 60
kubectl get pods -n kubeai -l model=qwen2-500m-cpu
# Should show 0 pods

# Send a request to trigger scale-up
curl http://localhost:8000/openai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen2-500m-cpu","messages":[{"role":"user","content":"Hi"}]}'
# Request will be queued while pod starts, then responded to
```

## Troubleshooting

### Common Issues

| Issue | Cause | Resolution |
|-------|-------|------------|
| Model stuck in `Pending` | Insufficient GPU resources | Check node GPU availability with `kubectl describe node` |
| Slow first response | Scale-from-zero cold start | Expected behavior; increase `minReplicas` for latency-sensitive models |
| OOMKilled pods | Model too large for allocated memory | Increase memory in `resourceProfile` or use quantization |
| Download failures | Network/auth issues | Check PVC storage, verify HuggingFace token if using gated models |
| Proxy 502 errors | Backend not ready | Check model pod logs; increase `scaleDownDelaySeconds` |

### Useful Commands

```bash
# View model operator logs
kubectl logs -n kubeai -l app.kubernetes.io/name=kubeai -f

# View model server logs
kubectl logs -n kubeai -l model=<model-name> -f

# Describe model for events
kubectl describe model <model-name> -n kubeai

# Force scale-up
kubectl patch model <model-name> -n kubeai \
  --type merge -p '{"spec":{"minReplicas":1}}'
```

## Related Blog Post

For a comprehensive introduction to KubeAI, its architecture, and when to use it:

👉 **[Read the full blog post →](https://garyinnerarity.com/blog/?post=kubeai-kubernetes-inference-operator)**

## References

- [KubeAI Official Documentation](https://www.kubeai.org/)
- [KubeAI GitHub Repository](https://github.com/kubeai-project/kubeai)
- [KubeAI Prefix-Aware Load Balancing Paper](https://www.kubeai.org/)
- [vLLM Integration Guide](https://docs.vllm.ai/en/stable/deployment/integrations/kubeai/)

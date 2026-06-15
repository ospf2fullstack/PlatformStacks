# Hearth — Declarative Scale-to-Zero LLM Serving on Kubernetes

## Overview

Hearth is a lightweight Kubernetes operator that turns "run an open-source LLM on my private cluster" into a single `LLMService` manifest. It provides declarative deployment, queue-driven autoscaling via KEDA, and **scale-to-zero** — all while remaining vendor-neutral across NVIDIA, Ascend, and Cambricon accelerators.

**Key Differentiators:**
- One user-facing CRD (`LLMService`) + KEDA — no platform to adopt
- Scale-to-zero is the center of gravity (idle models hold zero accelerators)
- Vendor-neutral: same manifest runs on NVIDIA or Ascend without spec changes
- Lightweight gateway handles cold-start buffering with SSE heartbeats

**Status:** v0.1.0 (alpha) — NVIDIA backend verified end-to-end on real GPUs

---

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Kubernetes | ≥ 1.27 | Any distribution (k3s, EKS, GKE, AKS, kind) |
| KEDA | ≥ 2.12 | Required for autoscaling/scale-to-zero |
| Helm | ≥ 3.12 | For installation |
| kubectl | ≥ 1.27 | Cluster access |
| GPU/NPU | NVIDIA (recommended) or Ascend | With device plugin installed |
| Prometheus Operator | Optional | For ServiceMonitor + Grafana dashboard |

---

## Quick-Start Deployment

### 1. Install KEDA

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda -n keda --create-namespace
```

### 2. Install Hearth

```bash
helm repo add hearth https://hearth-project.github.io/charts
helm repo update
helm install hearth hearth/hearth \
  -n hearth-system \
  --create-namespace \
  --set gateway.image.tag=v0.1.0
```

### 3. Deploy an LLM Service

```yaml
apiVersion: serving.hearth.dev/v1alpha1
kind: LLMService
metadata:
  name: qwen3-8b
  namespace: ai
spec:
  model:
    source:
      uri: modelscope://Qwen/Qwen3-8B-Instruct
  runtime:
    selector:
      vendor: [nvidia, ascend]
  resources:
    accelerators: 1
  scaling:
    min: 0
    max: 3
    metric: queueDepth
    target: 10
```

```bash
kubectl apply -f llmservice.yaml
kubectl get llmservice -n ai -w
```

### 4. Send a Request

```bash
kubectl port-forward -n ai svc/qwen3-8b 8000:80

curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3-8b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

---

## Architecture

```
┌─────────┐     OpenAI API     ┌───────────────┐     forward when Ready    ┌──────────────┐
│  Client  │ ────────────────→ │ Hearth Gateway │ ─────────────────────────→│ vLLM Pods    │
└─────────┘                    └───────────────┘                           │  (0..N)      │
                                       ↑                                   └──────────────┘
                                       │ poll /hearth/queue                        ↑
                                       │                                           │
                                ┌──────┴──────┐          scale 0..N        ┌───────┴──────┐
                                │    KEDA      │ ─────────────────────────→ │  Deployment  │
                                └─────────────┘                            └──────────────┘
                                                                                   │
                                                                           ┌───────┴──────┐
                                                                           │ Model Cache   │
                                                                           │ (PVC/hostPath)│
                                                                           └──────────────┘
```

### Components

| Component | Role |
|-----------|------|
| **LLMService CRD** | User-facing declaration of model + scaling intent |
| **InferenceRuntime CRD** | Pluggable backend definition (image, args, accelerator) |
| **Hearth Controller** | Reconciles LLMService → Deployment + Service + ScaledObject |
| **Hearth Gateway** | Buffers requests during cold start, exposes `/hearth/queue` metric |
| **KEDA ScaledObject** | Polls gateway queue depth, scales pods 0..N |
| **Model Cache** | Pre-warmed PVC for fast model loading on cold start |

### Scale-to-Zero Flow

1. **Idle State:** Model deployment has 0 replicas; gateway is active
2. **Request Arrives:** Gateway accepts request, buffers it, increments `pending` counter
3. **KEDA Scales Up:** Polls `/hearth/queue`, sees `pending > 0`, scales `0 → 1`
4. **Cold Start:** Pod loads weights from warm cache; gateway sends SSE heartbeats to client
5. **Ready:** Backend becomes Ready; gateway forwards buffered request, streams tokens
6. **Idle Again:** After stabilization window, KEDA scales back to 0

---

## Configuration Reference

### LLMService Spec

| Field | Type | Description |
|-------|------|-------------|
| `spec.model.source.uri` | string | Model URI (`modelscope://`, `hf://`, `pvc://`, `oci://`) |
| `spec.runtime.selector.vendor` | []string | Preferred backend vendors in priority order |
| `spec.resources.accelerators` | int | Number of accelerators per replica |
| `spec.scaling.min` | int | Minimum replicas (0 for scale-to-zero) |
| `spec.scaling.max` | int | Maximum replicas |
| `spec.scaling.metric` | string | Scaling metric (`queueDepth`) |
| `spec.scaling.target` | int | Target queue depth per replica |
| `spec.scaling.scaleDownStabilization` | duration | Cooldown before scale-down (default: 5m) |
| `spec.coldStart.mode` | string | `buffer` (hold request) or `reject` (503) |
| `spec.coldStart.activationTimeout` | duration | Max wait for cold start before error |

### InferenceRuntime Spec

| Field | Type | Description |
|-------|------|-------------|
| `spec.family` | string | Engine family (e.g., `vllm`) |
| `spec.vendor` | string | Hardware vendor (`nvidia`, `ascend`, `cambricon`) |
| `spec.priority` | int | Selection priority (higher = preferred) |
| `spec.container.image` | string | Container image for the backend |
| `spec.container.args` | []string | Extra arguments for the container |
| `spec.accelerator.resourceName` | string | K8s device plugin resource (e.g., `nvidia.com/gpu`) |

### Helm Values (Key Overrides)

```yaml
# charts/hearth/values.yaml
controller:
  replicas: 1
  resources:
    limits:
      cpu: 500m
      memory: 256Mi

gateway:
  image:
    repository: ghcr.io/hearth-project/hearth-gateway
    tag: v0.1.0
  resources:
    limits:
      cpu: 200m
      memory: 128Mi

modelCache:
  storageClass: ""  # Use cluster default
  size: 50Gi
```

---

## Validation & Testing

### No-GPU Testing (Development)

Hearth provides a complete no-GPU test path using a CPU `vllm-stub`:

```bash
# Create a kind cluster
kind create cluster --name hearth-test

# Install KEDA
helm install keda kedacore/keda -n keda --create-namespace

# Run the e2e test suite (no GPU required)
make test-e2e
```

The test suite exercises the full `0→1→N→0` scale-to-zero loop with a fake accelerator resource.

### Production Validation

```bash
# Check operator health
kubectl get pods -n hearth-system

# Verify LLMService status
kubectl get llmservice -A

# Watch scaling events
kubectl get events -n ai --field-selector reason=ScaledUp

# Check KEDA ScaledObject
kubectl get scaledobject -n ai
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Pod stuck in `Pending` | No GPU/NPU available | Check device plugin, verify `nvidia.com/gpu` resource exists |
| Gateway returns 503 | `coldStart.mode: reject` + timeout | Increase `activationTimeout` or switch to `buffer` mode |
| Model load timeout | Large model, slow storage | Use faster storage class, pre-warm cache, increase probe timeouts |
| KEDA not scaling | ScaledObject misconfigured | Verify KEDA CRDs, check `kubectl get scaledobject` status |
| SSE heartbeat timeout | Client-side timeout too short | Increase client timeout to accommodate cold start (30-120s typical) |

---

## Supported Backends

| Backend | Engine | Accelerator | Status |
|---------|--------|-------------|--------|
| NVIDIA | vLLM | `nvidia.com/gpu` | ✅ Verified on real GPUs |
| Ascend | vLLM-Ascend | `huawei.com/Ascend910` | 🧪 Scaffolded, awaiting NPU validation |
| Cambricon | vLLM-MLU | `cambricon.com/mlu` | 🗺️ Planned |

---

## Related Resources

- **GitHub:** [hearth-project/hearth](https://github.com/hearth-project/hearth)
- **Blog Post:** [https://garyinnerarity.com/blog/?post=hearth-kubernetes-llm-serving](https://garyinnerarity.com/blog/?post=hearth-kubernetes-llm-serving)
- **KEDA Documentation:** [https://keda.sh](https://keda.sh)
- **vLLM Documentation:** [https://docs.vllm.ai](https://docs.vllm.ai)

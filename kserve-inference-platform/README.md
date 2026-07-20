# KServe - CNCF Inference Service Platform

Standardized distributed generative and predictive AI inference platform for scalable, multi-framework deployment on Kubernetes.

## Overview

KServe is a CNCF Incubating project that provides a unified platform for deploying, scaling, and managing AI/ML models on Kubernetes. It supports both traditional predictive AI workloads (scikit-learn, TensorFlow, PyTorch, XGBoost, ONNX) and modern generative AI workloads (LLMs via vLLM, llm-d) through a standardized Kubernetes CRD-based approach.

**Key Facts:**
- **CNCF Status:** Incubating (accepted September 2025)
- **License:** Apache 2.0
- **GitHub:** [github.com/kserve/kserve](https://github.com/kserve/kserve)
- **Stars:** 5.7k+ | **Forks:** 1.6k+ | **Contributors:** 330+
- **Latest Version:** v0.19.0
- **Origin:** 2019 (Google, IBM, Bloomberg, NVIDIA, Seldon)

## Prerequisites

- Kubernetes cluster v1.32+
- `kubectl` configured with cluster access
- `helm` v3.x installed
- cert-manager v1.15.0+
- **For Predictive AI (Knative mode):** Knative Serving
- **For Generative AI (Standard mode):** Gateway API controller (Envoy Gateway recommended)
- **Optional:** KEDA for custom metric autoscaling
- GPU nodes (for LLM workloads)

## Quick-Start Deployment

### Option A: Standard Mode (Recommended for LLMs/GenAI)

```bash
# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.0/cert-manager.yaml

# 2. Install Envoy Gateway (Gateway API provider)
helm install eg oci://docker.io/envoyproxy/gateway-helm --version v1.3.0 -n envoy-gateway-system --create-namespace

# 3. Create Gateway resource
kubectl apply -f kubernetes/gateway.yaml

# 4. Install KServe CRDs
helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd --version v0.19.0

# 5. Install KServe in Standard mode
helm install kserve oci://ghcr.io/kserve/charts/kserve-resources --version v0.19.0 \
  --set kserve.controller.deploymentMode=Standard \
  --set kserve.controller.gateway.ingressGateway.enableGatewayApi=true \
  --set kserve.controller.gateway.ingressGateway.kserveGateway=kserve/kserve-ingress-gateway

# 6. Install LLMInferenceService CRDs (for GenAI)
helm install kserve-llmisvc-crd oci://ghcr.io/kserve/charts/kserve-llmisvc-crd --version v0.19.0

# 7. Install LLMIsvc controller
helm install kserve-llmisvc oci://ghcr.io/kserve/charts/kserve-llmisvc-resources --version v0.19.0
```

### Option B: Knative Mode (Scale-to-Zero for Predictive AI)

```bash
# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.16.0/cert-manager.yaml

# 2. Install Knative Serving
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.16.0/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/knative-v1.16.0/serving-core.yaml

# 3. Install networking layer (Istio or Kourier)
kubectl apply -f https://github.com/knative/net-istio/releases/download/knative-v1.16.0/net-istio.yaml

# 4. Install KServe CRDs
helm install kserve-crd oci://ghcr.io/kserve/charts/kserve-crd --version v0.19.0

# 5. Install KServe Resources (Knative mode is default)
helm install kserve oci://ghcr.io/kserve/charts/kserve-resources --version v0.19.0

# 6. Install ClusterServingRuntimes
kubectl apply --server-side -f https://github.com/kserve/kserve/releases/download/v0.19.0/kserve-cluster-resources.yaml
```

## Configuration Reference

### InferenceService CRD (Predictive AI)

| Field | Description | Default |
|-------|-------------|---------|
| `spec.predictor.model.modelFormat.name` | Framework (sklearn, tensorflow, pytorch, xgboost, onnx, huggingface) | Required |
| `spec.predictor.model.storageUri` | Model artifact location (s3://, gs://, hf://, pvc://) | Required |
| `spec.predictor.minReplicas` | Minimum pod replicas (0 for scale-to-zero) | 1 |
| `spec.predictor.maxReplicas` | Maximum pod replicas | unlimited |
| `spec.predictor.scaleTarget` | Target concurrent requests per pod | 1 |
| `spec.predictor.scaleMetric` | Scaling metric (concurrency, qps) | concurrency |
| `spec.predictor.canaryTrafficPercent` | Traffic percentage to canary revision | - |

### LLMInferenceService CRD (Generative AI)

| Field | Description | Default |
|-------|-------------|---------|
| `spec.model.uri` | Model URI (hf://, s3://, pvc://) | Required |
| `spec.model.name` | Model name for API requests | Required |
| `spec.replicas` | Number of serving replicas | 1 |
| `spec.parallelism.tensor` | Tensor parallelism (GPUs per model shard) | 1 |
| `spec.parallelism.data` | Data parallelism (total replicas) | 1 |
| `spec.parallelism.expert` | Expert parallelism (for MoE models) | - |
| `spec.router.gateway` | Gateway configuration | {} |
| `spec.router.scheduler` | Intelligent routing (EPP) | {} |
| `spec.prefill` | Disaggregated prefill workload spec | - |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                    CONTROL PLANE                          │
├─────────────────────────────────────────────────────────┤
│  KServe Controller    │  LLMIsvc Controller             │
│  ─────────────────    │  ────────────────────           │
│  • InferenceService   │  • LLMInferenceService          │
│  • InferenceGraph     │  • LLMInferenceServiceConfig    │
│  • ServingRuntime     │  • Gateway Inference Extension  │
│  • TrainedModel       │  • Endpoint Picker Pod (EPP)    │
│  • LocalModelCache    │  • Workload Variant Autoscaler  │
└─────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────┐
│                     DATA PLANE                            │
├─────────────────────────────────────────────────────────┤
│  Predictor              │  LLM Serving Stack            │
│  ──────────             │  ──────────────────           │
│  • Model inference      │  • vLLM / llm-d engine        │
│  • Pre/post processing  │  • KV-cache aware routing     │
│  • Explainability       │  • Prefill-Decode separation  │
│  • Batch predictions    │  • Multi-node inference       │
└─────────────────────────────────────────────────────────┘
```

### Deployment Modes

| Mode | Use Case | Scaling | Dependencies |
|------|----------|---------|--------------|
| **Standard** | GenAI/LLMs (recommended) | HPA/KEDA/WVA | cert-manager, Gateway API |
| **Knative** | Predictive AI (scale-to-zero) | KPA (request-based) | cert-manager, Knative, Istio/Kourier |

## Validation & Testing

### Deploy a Test InferenceService (Predictive)

```bash
kubectl apply -n kserve-test -f - <<EOF
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "sklearn-iris"
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      storageUri: "gs://kfserving-examples/models/sklearn/1.0/model"
EOF

# Wait for ready
kubectl wait --for=condition=Ready inferenceservice/sklearn-iris -n kserve-test --timeout=300s

# Test inference
curl -v http://sklearn-iris.kserve-test.example.com/v1/models/sklearn-iris:predict \
  -d '{"instances": [[6.8, 2.8, 4.8, 1.4]]}'
```

### Deploy a Test LLMInferenceService (Generative)

```bash
kubectl apply -n kserve-test -f - <<EOF
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  name: qwen-llm
spec:
  model:
    uri: hf://Qwen/Qwen2.5-0.5B-Instruct
    name: qwen
  replicas: 1
  template:
    containers:
      - name: main
        image: vllm/vllm-openai:latest
        resources:
          limits:
            nvidia.com/gpu: "1"
            cpu: "8"
            memory: 32Gi
  router:
    gateway: {}
    route: {}
    scheduler: {}
EOF

# Test OpenAI-compatible chat completion
curl http://qwen-llm.kserve-test.example.com/openai/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Troubleshooting

| Issue | Cause | Resolution |
|-------|-------|------------|
| Pod stuck in `Init` | Storage initializer can't download model | Check storageUri, credentials, and network policies |
| `No such file or directory: /mnt/models` | Deployed in control-plane namespace | Move InferenceService to a non-control-plane namespace |
| Scale-to-zero not working | Standard mode doesn't support scale-to-zero for HTTP | Use Knative mode or set minReplicas >= 1 |
| Canary not splitting traffic | Not using Knative mode | Canary rollout requires serverless (Knative) deployment mode |
| LLMInferenceService stuck | Missing GPU resources or wrong image | Verify GPU availability and vLLM image compatibility |
| High TTFT (Time to First Token) | Cold model loading | Enable LocalModelCache CRD for faster startup |

## Related Blog Post

For an in-depth overview of KServe's architecture, deployment patterns, and when to use it, see the companion blog post:

👉 [**KServe: The CNCF Standard for AI Model Serving on Kubernetes**](https://garyinnerarity.com/blog/?post=kserve-inference-platform)
